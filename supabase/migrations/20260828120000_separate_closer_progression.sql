-- Closer seniority progression is independent from SDR progression.
-- The replay remains the single source of truth for persisted progress.
CREATE OR REPLACE FUNCTION public.normalize_career_goal(raw_value text)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path=pg_catalog,public AS $$
  SELECT CASE regexp_replace(translate(upper(trim(coalesce(raw_value,''))),
    'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','AAAAAEEEEIIIIOOOOOUUUUC'),'[[:space:]]+',' ','g')
    WHEN '' THEN 'Sem presença'
    WHEN 'SEM PRESENCA' THEN 'Sem presença'
    WHEN 'AUSENTE' THEN 'Sem presença'
    WHEN 'META NAO DEFINIDA' THEN 'Sem presença'
    WHEN 'META 1' THEN 'Meta 1'
    WHEN 'META 2' THEN 'Meta 2'
    WHEN 'META 3' THEN 'Meta 3'
    WHEN 'NENHUMA META' THEN 'Nenhuma meta'
    WHEN 'SEM META' THEN 'Nenhuma meta'
    WHEN 'SEM REGISTRO' THEN 'Nenhuma meta'
    ELSE NULL END
$$;

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
  entered_closer boolean;
  effective_goal boolean;
  ramping_month boolean;
  closer_ramping_meta_consumida boolean := false;
  expected_event_keys text[] := ARRAY[]::text[];
BEGIN
  SELECT * INTO STRICT profile
  FROM public.colaboradores_perfis
  WHERE id=p_colaborador_id
  FOR UPDATE;

  -- Only level and position immediately before the epoch cross the boundary.
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

  IF previous_position='CLOSER' THEN
    SELECT EXISTS(
      SELECT 1
      FROM public.colaboradores c
      WHERE c.colaborador_id=p_colaborador_id
        AND c.competencia<epoch
        AND upper(trim(coalesce(c.posicao,'')))='CLOSER'
        AND public.normalize_career_goal(c.meta_alcancada) IN ('Meta 1','Meta 2','Meta 3')
        AND c.competencia>coalesce((
          SELECT max(c2.competencia)
          FROM public.colaboradores c2
          WHERE c2.colaborador_id=p_colaborador_id
            AND c2.competencia<epoch
            AND upper(trim(coalesce(c2.posicao,'')))<>'CLOSER'
        ),date '-infinity')
    ) INTO closer_ramping_meta_consumida;
  END IF;

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
    role_changed := coalesce(previous_position='SDR' AND current_position='CLOSER',false);
    entered_closer := current_position='CLOSER' AND previous_position IS DISTINCT FROM 'CLOSER';
    effective_goal := normalized_goal IN ('Meta 1','Meta 2','Meta 3');
    IF entered_closer THEN closer_ramping_meta_consumida:=false; END IF;
    ramping_month := current_position='CLOSER' AND effective_goal AND NOT closer_ramping_meta_consumida;

    IF role_changed THEN
      meta3_count:=0; meta2_count:=0; bonus:=0; bonus_streak:=0;
      current_level:=coalesce(informed_level,current_level);
      INSERT INTO public.career_progression_events(colaborador_id,competencia,event_type,senioridade,recebeu_promocao)
      VALUES(p_colaborador_id,item.competencia,'role_promotion',current_level,false)
      ON CONFLICT (colaborador_id,competencia,event_type) DO UPDATE SET senioridade=excluded.senioridade,recebeu_promocao=false;
      expected_event_keys:=array_append(expected_event_keys,item.competencia::text||'|role_promotion');
    ELSIF informed_level IS NOT NULL AND informed_level IS DISTINCT FROM current_level THEN
      current_level:=informed_level; meta3_count:=0; meta2_count:=0;
    END IF;
    IF current_position<>'' THEN previous_position:=current_position; END IF;
    IF current_level IS NULL THEN
      RAISE EXCEPTION 'Sem senioridade válida no resultado %',item.id USING ERRCODE='22023';
    END IF;
    IF ramping_month THEN closer_ramping_meta_consumida:=true; END IF;

    promoted:=false;
    -- Only the first effective Closer goal is consumed by ramping; empty slots remain neutral.
    IF NOT ramping_month THEN
      IF current_position='SDR' THEN
        -- Approved SDR rule: 3 M3 or 2 M3 + 1 M2; second M2 preserves only its anchor.
        IF normalized_goal='Meta 1' THEN
          meta3_count:=0; meta2_count:=0;
        ELSIF normalized_goal='Meta 2' THEN
          IF meta2_count=1 THEN meta3_count:=0; END IF;
          meta2_count:=1;
        ELSIF normalized_goal='Meta 3' THEN
          meta3_count:=meta3_count+1;
        END IF;
      ELSE
        -- Closer rule: only consecutive M3 count. M2 and M1 break/reset the streak.
        meta2_count:=0;
        IF normalized_goal IN ('Meta 1','Meta 2') THEN
          meta3_count:=0;
        ELSIF normalized_goal='Meta 3' THEN
          meta3_count:=meta3_count+1;
        END IF;
      END IF;

      IF meta3_count>=3 OR (current_position='SDR' AND meta3_count>=2 AND meta2_count=1) THEN
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
REVOKE ALL ON FUNCTION public.normalize_career_goal(text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.recalcular_progressao_colaborador(uuid) TO service_role;
