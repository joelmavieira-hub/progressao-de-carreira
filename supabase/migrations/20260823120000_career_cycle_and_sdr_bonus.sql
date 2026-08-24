-- New deterministic career cycle and independent SDR bonus state.
-- Business-rule epoch: 2026-06-01. This migration installs the model and replay;
-- the controlled backfill lives in supabase/operations/20260823_*.

ALTER TABLE public.colaboradores_perfis
  ADD COLUMN IF NOT EXISTS progresso_meta2 integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS progresso_ciclo integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS bonificacao_sdr integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS streak_meta3_bonificacao integer NOT NULL DEFAULT 0;

-- Compatibility seed only; the controlled replay replaces it with the new rule.
UPDATE public.colaboradores_perfis
SET progresso_ciclo=progresso_meta3+progresso_meta2
WHERE progresso_ciclo IS DISTINCT FROM progresso_meta3+progresso_meta2;

ALTER TABLE public.colaboradores_perfis
  DROP CONSTRAINT IF EXISTS colaboradores_perfis_progresso_meta2_check,
  DROP CONSTRAINT IF EXISTS colaboradores_perfis_progresso_ciclo_check,
  DROP CONSTRAINT IF EXISTS colaboradores_perfis_bonificacao_sdr_check,
  DROP CONSTRAINT IF EXISTS colaboradores_perfis_streak_bonus_check;
ALTER TABLE public.colaboradores_perfis
  ADD CONSTRAINT colaboradores_perfis_progresso_meta2_check CHECK (progresso_meta2 IN (0,1)),
  ADD CONSTRAINT colaboradores_perfis_progresso_ciclo_check CHECK (progresso_ciclo BETWEEN 0 AND 2),
  ADD CONSTRAINT colaboradores_perfis_bonificacao_sdr_check CHECK (bonificacao_sdr IN (0,30,40)),
  ADD CONSTRAINT colaboradores_perfis_streak_bonus_check CHECK (streak_meta3_bonificacao BETWEEN 0 AND 2),
  ADD CONSTRAINT colaboradores_perfis_ciclo_consistente CHECK (progresso_ciclo = progresso_meta3 + progresso_meta2);

ALTER TABLE public.career_progression_events
  DROP CONSTRAINT IF EXISTS career_progression_events_event_type_check;
ALTER TABLE public.career_progression_events
  ADD CONSTRAINT career_progression_events_event_type_check CHECK (event_type IN (
    'career_cycle_completed', 'seniority_promotion', 'role_promotion',
    'sdr_bonus_unlocked_40', 'sdr_bonus_reduced_30',
    'sdr_bonus_recovered_40', 'sdr_bonus_lost'
  ));

DROP POLICY IF EXISTS "Career events are readable" ON public.career_progression_events;
CREATE POLICY "Career events are readable" ON public.career_progression_events
  FOR SELECT TO anon,authenticated USING (true);
GRANT SELECT ON public.career_progression_events TO anon,authenticated;

CREATE OR REPLACE FUNCTION public.recalcular_progressao_colaborador(p_colaborador_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=pg_catalog,public
AS $$
DECLARE
  epoch constant date := date '2026-06-01';
  profile public.colaboradores_perfis%ROWTYPE;
  item public.colaboradores%ROWTYPE;
  current_level text;
  informed_level text;
  next_level text;
  previous_position text;
  current_position text;
  normalized_goal text;
  meta3_count integer := 0;
  meta2_count integer := 0;
  bonus integer := 0;
  bonus_streak integer := 0;
  promoted boolean;
  role_changed boolean;
  expected_event_keys text[] := ARRAY[]::text[];
BEGIN
  SELECT * INTO STRICT profile
  FROM public.colaboradores_perfis
  WHERE id=p_colaborador_id
  FOR UPDATE;

  -- Establish only the level/position that existed immediately before the epoch.
  -- Progress and bonus deliberately never cross this boundary.
  SELECT
    CASE WHEN c.recebeu_promocao
      THEN coalesce(public.next_career_seniority(c.senioridade),public.normalize_career_seniority(c.senioridade))
      ELSE coalesce(public.normalize_career_seniority(c.senioridade_informada),public.normalize_career_seniority(c.senioridade))
    END,
    upper(trim(coalesce(c.posicao,'')))
  INTO current_level,previous_position
  FROM public.colaboradores c
  WHERE c.colaborador_id=p_colaborador_id AND c.competencia<epoch
  ORDER BY c.competencia DESC,c.id DESC
  LIMIT 1;

  IF current_level IS NULL THEN
    SELECT coalesce(
      public.normalize_career_seniority(c.senioridade_informada),
      public.normalize_career_seniority(c.senioridade)
    ) INTO current_level
    FROM public.colaboradores c
    WHERE c.colaborador_id=p_colaborador_id AND c.competencia>=epoch
    ORDER BY c.competencia,c.id LIMIT 1;
  END IF;
  current_level := coalesce(current_level,public.normalize_career_seniority(profile.senioridade_atual));

  FOR item IN
    SELECT c.* FROM public.colaboradores c
    WHERE c.id IN (
      SELECT DISTINCT ON (competencia) id
      FROM public.colaboradores
      WHERE colaborador_id=p_colaborador_id AND competencia>=epoch
      ORDER BY competencia,id DESC
    )
    ORDER BY c.competencia,c.id
    FOR UPDATE OF c
  LOOP
    normalized_goal := public.normalize_career_goal(item.meta_alcancada);
    IF normalized_goal IS NULL THEN
      RAISE EXCEPTION 'Meta inválida no resultado %',item.id USING ERRCODE='22023';
    END IF;
    informed_level := public.normalize_career_seniority(item.senioridade_informada);
    current_position := upper(trim(coalesce(item.posicao,'')));
    role_changed := previous_position='SDR' AND current_position='CLOSER';

    IF role_changed THEN
      meta3_count:=0; meta2_count:=0; bonus:=0; bonus_streak:=0;
      current_level:=coalesce(informed_level,current_level);
      INSERT INTO public.career_progression_events(colaborador_id,competencia,event_type,senioridade,recebeu_promocao)
      VALUES(p_colaborador_id,item.competencia,'role_promotion',current_level,false)
      ON CONFLICT (colaborador_id,competencia,event_type) DO UPDATE SET senioridade=excluded.senioridade,recebeu_promocao=false;
      expected_event_keys:=array_append(expected_event_keys,item.competencia::text||'|role_promotion');
    ELSIF informed_level IS NOT NULL AND informed_level IS DISTINCT FROM current_level THEN
      -- Preserve the established competence-level authority behavior.
      current_level:=informed_level; meta3_count:=0; meta2_count:=0;
    END IF;
    IF current_position<>'' THEN previous_position:=current_position; END IF;
    IF current_level IS NULL THEN
      RAISE EXCEPTION 'Sem senioridade válida no resultado %',item.id USING ERRCODE='22023';
    END IF;

    promoted:=false;
    -- The transition competence is a reset boundary; its goal feeds neither machine.
    IF NOT role_changed THEN
      IF normalized_goal='Meta 1' THEN
        meta3_count:=0; meta2_count:=0;
      ELSIF normalized_goal='Meta 2' THEN
        IF meta2_count=1 THEN meta3_count:=0; END IF;
        meta2_count:=1;
      ELSIF normalized_goal='Meta 3' THEN
        meta3_count:=meta3_count+1;
      END IF;

      IF meta3_count>=3 OR (meta3_count>=2 AND meta2_count=1) THEN
        next_level:=public.next_career_seniority(current_level);
        meta3_count:=0; meta2_count:=0;
        IF next_level IS NOT NULL THEN
          promoted:=true;
          INSERT INTO public.career_progression_events(colaborador_id,competencia,event_type,senioridade,recebeu_promocao)
          VALUES(p_colaborador_id,item.competencia,'seniority_promotion',current_level,true)
          ON CONFLICT (colaborador_id,competencia,event_type) DO UPDATE SET senioridade=excluded.senioridade,recebeu_promocao=true;
          expected_event_keys:=array_append(expected_event_keys,item.competencia::text||'|seniority_promotion');
        ELSE
          INSERT INTO public.career_progression_events(colaborador_id,competencia,event_type,senioridade,recebeu_promocao)
          VALUES(p_colaborador_id,item.competencia,'career_cycle_completed',current_level,false)
          ON CONFLICT (colaborador_id,competencia,event_type) DO UPDATE SET senioridade=excluded.senioridade,recebeu_promocao=false;
          expected_event_keys:=array_append(expected_event_keys,item.competencia::text||'|career_cycle_completed');
        END IF;
      END IF;

      IF current_position='SDR' THEN
        IF normalized_goal='Meta 1' THEN
          IF bonus<>0 THEN
            INSERT INTO public.career_progression_events(colaborador_id,competencia,event_type,senioridade,recebeu_promocao)
            VALUES(p_colaborador_id,item.competencia,'sdr_bonus_lost',current_level,false)
            ON CONFLICT (colaborador_id,competencia,event_type) DO UPDATE SET senioridade=excluded.senioridade,recebeu_promocao=false;
            expected_event_keys:=array_append(expected_event_keys,item.competencia::text||'|sdr_bonus_lost');
          END IF;
          bonus:=0; bonus_streak:=0;
        ELSIF normalized_goal='Meta 2' THEN
          bonus_streak:=0;
          IF bonus=40 THEN
            bonus:=30;
            INSERT INTO public.career_progression_events(colaborador_id,competencia,event_type,senioridade,recebeu_promocao)
            VALUES(p_colaborador_id,item.competencia,'sdr_bonus_reduced_30',current_level,false)
            ON CONFLICT (colaborador_id,competencia,event_type) DO UPDATE SET senioridade=excluded.senioridade,recebeu_promocao=false;
            expected_event_keys:=array_append(expected_event_keys,item.competencia::text||'|sdr_bonus_reduced_30');
          END IF;
        ELSIF normalized_goal='Meta 3' THEN
          IF bonus=30 THEN
            bonus:=40; bonus_streak:=0;
            INSERT INTO public.career_progression_events(colaborador_id,competencia,event_type,senioridade,recebeu_promocao)
            VALUES(p_colaborador_id,item.competencia,'sdr_bonus_recovered_40',current_level,false)
            ON CONFLICT (colaborador_id,competencia,event_type) DO UPDATE SET senioridade=excluded.senioridade,recebeu_promocao=false;
            expected_event_keys:=array_append(expected_event_keys,item.competencia::text||'|sdr_bonus_recovered_40');
          ELSIF bonus=0 THEN
            bonus_streak:=bonus_streak+1;
            IF bonus_streak>=3 THEN
              bonus:=40; bonus_streak:=0;
              INSERT INTO public.career_progression_events(colaborador_id,competencia,event_type,senioridade,recebeu_promocao)
              VALUES(p_colaborador_id,item.competencia,'sdr_bonus_unlocked_40',current_level,false)
              ON CONFLICT (colaborador_id,competencia,event_type) DO UPDATE SET senioridade=excluded.senioridade,recebeu_promocao=false;
              expected_event_keys:=array_append(expected_event_keys,item.competencia::text||'|sdr_bonus_unlocked_40');
            END IF;
          END IF;
        END IF;
      ELSE
        bonus:=0; bonus_streak:=0;
      END IF;
    END IF;

    UPDATE public.colaboradores SET
      meta_alcancada=normalized_goal,
      senioridade=current_level,
      recebeu_promocao=promoted,
      updated_at=now()
    WHERE id=item.id AND (
      meta_alcancada IS DISTINCT FROM normalized_goal OR
      senioridade IS DISTINCT FROM current_level OR
      recebeu_promocao IS DISTINCT FROM promoted
    );
    IF promoted THEN current_level:=next_level; END IF;
  END LOOP;

  DELETE FROM public.career_progression_events e
  WHERE e.colaborador_id=p_colaborador_id AND e.competencia>=epoch
    AND NOT ((e.competencia::text||'|'||e.event_type)=ANY(expected_event_keys));

  UPDATE public.colaboradores_perfis SET
    senioridade_atual=current_level,
    progresso_meta3=meta3_count,
    progresso_meta2=meta2_count,
    progresso_ciclo=meta3_count+meta2_count,
    bonificacao_sdr=CASE WHEN upper(trim(coalesce(posicao_atual,'')))='SDR' THEN bonus ELSE 0 END,
    streak_meta3_bonificacao=CASE WHEN upper(trim(coalesce(posicao_atual,'')))='SDR' THEN bonus_streak ELSE 0 END,
    updated_at=now()
  WHERE id=p_colaborador_id AND (
    senioridade_atual IS DISTINCT FROM current_level OR
    progresso_meta3 IS DISTINCT FROM meta3_count OR
    progresso_meta2 IS DISTINCT FROM meta2_count OR
    progresso_ciclo IS DISTINCT FROM meta3_count+meta2_count OR
    bonificacao_sdr IS DISTINCT FROM CASE WHEN upper(trim(coalesce(posicao_atual,'')))='SDR' THEN bonus ELSE 0 END OR
    streak_meta3_bonificacao IS DISTINCT FROM CASE WHEN upper(trim(coalesce(posicao_atual,'')))='SDR' THEN bonus_streak ELSE 0 END
  );
END $$;

REVOKE ALL ON FUNCTION public.recalcular_progressao_colaborador(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.recalcular_progressao_colaborador(uuid) TO service_role;
