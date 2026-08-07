-- A competence-level seniority from the synchronized source is authoritative.
-- When it changes, start the new seniority cycle at zero before evaluating the
-- competence. This prevents a historical bootstrap level from leaking forever.
CREATE OR REPLACE FUNCTION public.recalcular_progressao_colaborador(p_colaborador_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE
  profile public.colaboradores_perfis%ROWTYPE;
  item public.colaboradores%ROWTYPE;
  current_level text := NULL;
  informed_level text;
  next_level text;
  current_progress integer := 0;
  promoted boolean;
  normalized_goal text;
  previous_position text := NULL;
  current_position text;
  completed_competences date[] := ARRAY[]::date[];
BEGIN
  SELECT * INTO STRICT profile FROM public.colaboradores_perfis
  WHERE id=p_colaborador_id FOR UPDATE;

  SELECT public.normalize_career_seniority(c.senioridade_informada)
  INTO current_level
  FROM public.colaboradores c
  WHERE c.colaborador_id=p_colaborador_id
    AND public.normalize_career_seniority(c.senioridade_informada) IS NOT NULL
  ORDER BY c.competencia,c.id LIMIT 1;
  IF current_level IS NULL THEN
    SELECT public.normalize_career_seniority(c.senioridade)
    INTO current_level
    FROM public.colaboradores c
    WHERE c.colaborador_id=p_colaborador_id
      AND public.normalize_career_seniority(c.senioridade) IS NOT NULL
    ORDER BY c.competencia,c.id LIMIT 1;
  END IF;
  current_level := coalesce(current_level,public.normalize_career_seniority(profile.senioridade_atual));

  FOR item IN
    SELECT c.* FROM public.colaboradores c
    WHERE c.id IN (
      SELECT DISTINCT ON (competencia) id
      FROM public.colaboradores
      WHERE colaborador_id=p_colaborador_id AND competencia IS NOT NULL
      ORDER BY competencia,id DESC
    )
    ORDER BY c.competencia,c.id
    FOR UPDATE OF c
  LOOP
    normalized_goal := public.normalize_career_goal(item.meta_alcancada);
    IF normalized_goal IS NULL THEN
      RAISE EXCEPTION 'Meta inválida no resultado %',item.id USING ERRCODE='22023';
    END IF;

    current_position := upper(trim(coalesce(item.posicao,'')));
    informed_level := public.normalize_career_seniority(item.senioridade_informada);
    IF previous_position='SDR' AND current_position='CLOSER' THEN
      current_progress := 0;
      current_level := coalesce(informed_level,current_level);
    END IF;
    IF current_position<>'' THEN previous_position := current_position; END IF;

    IF informed_level IS NOT NULL AND informed_level IS DISTINCT FROM current_level THEN
      current_level := informed_level;
      current_progress := 0;
    END IF;
    IF current_level IS NULL THEN
      RAISE EXCEPTION 'Sem senioridade válida no resultado %',item.id USING ERRCODE='22023';
    END IF;

    promoted := false;
    IF normalized_goal='Meta 3' THEN
      next_level := public.next_career_seniority(current_level);
      IF current_progress=2 THEN
        current_progress := 0;
        IF next_level IS NOT NULL THEN
          promoted := true;
        ELSE
          completed_competences := array_append(completed_competences,item.competencia);
          INSERT INTO public.career_progression_events(
            colaborador_id,competencia,event_type,senioridade,recebeu_promocao
          ) VALUES (
            p_colaborador_id,item.competencia,'career_cycle_completed',current_level,false
          ) ON CONFLICT (colaborador_id,competencia,event_type) DO UPDATE SET
            senioridade=excluded.senioridade,recebeu_promocao=false;
        END IF;
      ELSE
        current_progress := least(current_progress+1,2);
      END IF;
    END IF;

    UPDATE public.colaboradores SET
      meta_alcancada=normalized_goal,senioridade=current_level,
      recebeu_promocao=promoted,updated_at=now()
    WHERE id=item.id AND (
      meta_alcancada IS DISTINCT FROM normalized_goal OR
      senioridade IS DISTINCT FROM current_level OR
      recebeu_promocao IS DISTINCT FROM promoted
    );
    IF promoted THEN current_level := next_level; END IF;
  END LOOP;

  DELETE FROM public.career_progression_events e
  WHERE e.colaborador_id=p_colaborador_id
    AND e.event_type='career_cycle_completed'
    AND NOT (e.competencia=ANY(completed_competences));

  current_level := coalesce(current_level,public.normalize_career_seniority(profile.senioridade_atual));
  UPDATE public.colaboradores_perfis SET
    senioridade_atual=current_level,progresso_meta3=current_progress,updated_at=now()
  WHERE id=p_colaborador_id AND (
    senioridade_atual IS DISTINCT FROM current_level OR
    progresso_meta3 IS DISTINCT FROM current_progress
  );
END $$;

REVOKE ALL ON FUNCTION public.recalcular_progressao_colaborador(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.recalcular_progressao_colaborador(uuid) TO service_role;
