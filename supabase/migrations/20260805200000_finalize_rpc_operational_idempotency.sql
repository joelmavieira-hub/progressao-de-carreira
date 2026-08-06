CREATE OR REPLACE FUNCTION public.sincronizar_progressao_planilha(
  p_perfis jsonb,
  p_resultados jsonb,
  p_origem text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  item jsonb;
  profile public.colaboradores_perfis%ROWTYPE;
  existing public.colaboradores%ROWTYPE;
  history_item public.colaboradores%ROWTYPE;
  normalized_name text;
  normalized_goal text;
  normalized_seniority text;
  parsed_competence date;
  bootstrap_seniority text;
  current_level text;
  next_level text;
  current_progress integer;
  promoted boolean;
  affected_ids uuid[] := ARRAY[]::uuid[];
  affected_id uuid;
  profiles_received integer := 0;
  profiles_inserted integer := 0;
  profiles_updated integer := 0;
  results_received integer := 0;
  results_inserted integer := 0;
  results_corrected integer := 0;
  results_ignored integer := 0;
  recalculated integer := 0;
BEGIN
  IF p_perfis IS NULL OR jsonb_typeof(p_perfis) <> 'array' THEN
    RAISE EXCEPTION 'p_perfis deve ser um array JSON' USING ERRCODE = '22023';
  END IF;
  IF p_resultados IS NULL OR jsonb_typeof(p_resultados) <> 'array' THEN
    RAISE EXCEPTION 'p_resultados deve ser um array JSON' USING ERRCODE = '22023';
  END IF;
  IF nullif(trim(p_origem), '') IS NULL THEN
    RAISE EXCEPTION 'p_origem é obrigatório' USING ERRCODE = '22023';
  END IF;
  profiles_received := jsonb_array_length(p_perfis);
  results_received := jsonb_array_length(p_resultados);

  -- Validate the complete batch before the first write, so domain failures are all-or-nothing.
  FOR item IN SELECT value FROM jsonb_array_elements(p_perfis) LOOP
    IF jsonb_typeof(item) <> 'object' THEN
      RAISE EXCEPTION 'cada item de p_perfis deve ser um objeto JSON' USING ERRCODE = '22023';
    END IF;
    normalized_name := public.normalize_career_name(item->>'nome_colaborador');
    IF normalized_name IS NULL THEN
      RAISE EXCEPTION 'perfil com nome_colaborador vazio' USING ERRCODE = '22023';
    END IF;
    IF NOT item ? 'ativo' OR jsonb_typeof(item->'ativo') <> 'boolean' THEN
      RAISE EXCEPTION 'ativo deve ser boolean para %', item->>'nome_colaborador' USING ERRCODE = '22023';
    END IF;
    IF NOT item ? 'squad' OR jsonb_typeof(item->'squad') <> 'string'
      OR nullif(trim(item->>'squad'), '') IS NULL THEN
      RAISE EXCEPTION 'squad deve ser texto não vazio para %', item->>'nome_colaborador' USING ERRCODE = '22023';
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM public.colaboradores_perfis p WHERE p.nome_normalizado = normalized_name
    ) AND NOT EXISTS (
      SELECT 1 FROM jsonb_array_elements(p_resultados) r
      WHERE public.normalize_career_name(r->>'nome_colaborador') = normalized_name
    ) THEN
      RAISE EXCEPTION 'perfil novo sem resultado para bootstrap de senioridade: %', item->>'nome_colaborador'
        USING ERRCODE = '22023';
    END IF;
  END LOOP;

  IF EXISTS (
    SELECT 1 FROM jsonb_array_elements(p_perfis) value
    GROUP BY public.normalize_career_name(value->>'nome_colaborador')
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION 'p_perfis contém nomes equivalentes duplicados' USING ERRCODE = '22023';
  END IF;

  FOR item IN SELECT value FROM jsonb_array_elements(p_resultados) LOOP
    IF jsonb_typeof(item) <> 'object' THEN
      RAISE EXCEPTION 'cada item de p_resultados deve ser um objeto JSON' USING ERRCODE = '22023';
    END IF;
    normalized_name := public.normalize_career_name(item->>'nome_colaborador');
    IF normalized_name IS NULL THEN
      RAISE EXCEPTION 'resultado com nome_colaborador vazio' USING ERRCODE = '22023';
    END IF;
    IF coalesce(item->>'competencia', '') !~ '^\d{4}-(0[1-9]|1[0-2])-01$' THEN
      RAISE EXCEPTION 'competencia inválida para %: %', item->>'nome_colaborador', item->>'competencia'
        USING ERRCODE = '22023';
    END IF;
    parsed_competence := (item->>'competencia')::date;
    normalized_goal := public.normalize_career_goal(item->>'meta_alcancada');
    IF normalized_goal IS NULL THEN
      RAISE EXCEPTION 'meta inválida para %: %', item->>'nome_colaborador', item->>'meta_alcancada'
        USING ERRCODE = '22023';
    END IF;
    normalized_seniority := public.normalize_career_seniority(item->>'senioridade_informada');
    IF normalized_seniority IS NULL AND NOT (
      normalized_goal = 'Sem presença'
      AND nullif(trim(coalesce(item->>'senioridade_informada', '')), '') IS NULL
    ) THEN
      RAISE EXCEPTION 'senioridade inválida para %: %', item->>'nome_colaborador', item->>'senioridade_informada'
        USING ERRCODE = '22023';
    END IF;
    IF NOT item ? 'squad' OR jsonb_typeof(item->'squad') <> 'string'
      OR nullif(trim(item->>'squad'), '') IS NULL THEN
      RAISE EXCEPTION 'squad deve ser texto não vazio para %', item->>'nome_colaborador' USING ERRCODE = '22023';
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM jsonb_array_elements(p_perfis) p
      WHERE public.normalize_career_name(p->>'nome_colaborador') = normalized_name
    ) AND NOT EXISTS (
      SELECT 1 FROM public.colaboradores_perfis p WHERE p.nome_normalizado = normalized_name
    ) THEN
      RAISE EXCEPTION 'resultado sem perfil conhecido no lote ou banco: %', item->>'nome_colaborador'
        USING ERRCODE = '22023';
    END IF;
  END LOOP;

  IF EXISTS (
    SELECT 1 FROM jsonb_array_elements(p_resultados) value
    GROUP BY public.normalize_career_name(value->>'nome_colaborador'), value->>'competencia'
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION 'p_resultados contém colaborador/competência duplicado' USING ERRCODE = '22023';
  END IF;

  FOR item IN SELECT value FROM jsonb_array_elements(p_perfis) LOOP
    normalized_name := public.normalize_career_name(item->>'nome_colaborador');
    PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(normalized_name, 0));
    SELECT * INTO profile FROM public.colaboradores_perfis
    WHERE nome_normalizado = normalized_name FOR UPDATE;
    IF FOUND THEN
      UPDATE public.colaboradores_perfis SET
        nome_colaborador = trim(regexp_replace(item->>'nome_colaborador', '[[:space:]]+', ' ', 'g')),
        posicao_atual = nullif(trim(item->>'posicao'), ''),
        squad_atual = nullif(trim(item->>'squad'), ''),
        ativo = (item->>'ativo')::boolean,
        updated_at = now()
      WHERE id = profile.id
        AND (
          nome_colaborador IS DISTINCT FROM trim(regexp_replace(item->>'nome_colaborador', '[[:space:]]+', ' ', 'g'))
          OR posicao_atual IS DISTINCT FROM nullif(trim(item->>'posicao'), '')
          OR squad_atual IS DISTINCT FROM nullif(trim(item->>'squad'), '')
          OR ativo IS DISTINCT FROM (item->>'ativo')::boolean
        );
      IF FOUND THEN profiles_updated := profiles_updated + 1; END IF;
    ELSE
      SELECT public.normalize_career_seniority(r->>'senioridade_informada') INTO bootstrap_seniority
      FROM jsonb_array_elements(p_resultados) r
      WHERE public.normalize_career_name(r->>'nome_colaborador') = normalized_name
        AND public.normalize_career_seniority(r->>'senioridade_informada') IS NOT NULL
      ORDER BY (r->>'competencia')::date LIMIT 1;
      IF bootstrap_seniority IS NULL THEN
        RAISE EXCEPTION 'perfil novo sem resultado para bootstrap de senioridade: %', item->>'nome_colaborador'
          USING ERRCODE = '22023';
      END IF;
      INSERT INTO public.colaboradores_perfis(
        nome_colaborador,nome_normalizado,posicao_atual,squad_atual,senioridade_atual,progresso_meta3,ativo
      ) VALUES (
        trim(regexp_replace(item->>'nome_colaborador', '[[:space:]]+', ' ', 'g')),
        normalized_name,nullif(trim(item->>'posicao'),''),nullif(trim(item->>'squad'),''),
        bootstrap_seniority,0,(item->>'ativo')::boolean
      );
      profiles_inserted := profiles_inserted + 1;
    END IF;
  END LOOP;

  FOR item IN
    SELECT value FROM jsonb_array_elements(p_resultados)
    ORDER BY (value->>'competencia')::date, public.normalize_career_name(value->>'nome_colaborador')
  LOOP
    normalized_name := public.normalize_career_name(item->>'nome_colaborador');
    normalized_goal := public.normalize_career_goal(item->>'meta_alcancada');
    normalized_seniority := public.normalize_career_seniority(item->>'senioridade_informada');
    parsed_competence := (item->>'competencia')::date;
    SELECT * INTO STRICT profile FROM public.colaboradores_perfis
    WHERE nome_normalizado = normalized_name FOR UPDATE;

    SELECT * INTO existing FROM public.colaboradores
    WHERE colaborador_id = profile.id AND competencia = parsed_competence FOR UPDATE;
    IF FOUND THEN
      IF public.normalize_career_goal(existing.meta_alcancada) IS NOT DISTINCT FROM normalized_goal
        AND public.normalize_career_seniority(existing.senioridade_informada) IS NOT DISTINCT FROM normalized_seniority
        AND nullif(trim(existing.origem), '') IS NOT DISTINCT FROM trim(p_origem) THEN
        results_ignored := results_ignored + 1;
      ELSE
        UPDATE public.colaboradores SET
          meta_alcancada = normalized_goal,
          senioridade_informada = normalized_seniority,
          origem = trim(p_origem),
          updated_at = now()
        WHERE id = existing.id;
        results_corrected := results_corrected + 1;
        IF NOT profile.id = ANY(affected_ids) THEN
          affected_ids := array_append(affected_ids, profile.id);
        END IF;
      END IF;
    ELSE
      INSERT INTO public.colaboradores(
        colaborador_id,nome_colaborador,competencia,mes_referencia,posicao,squad,
        senioridade,senioridade_informada,meta_alcancada,recebeu_promocao,origem
      ) VALUES (
        profile.id,trim(regexp_replace(item->>'nome_colaborador','[[:space:]]+',' ','g')),
        parsed_competence,to_char(parsed_competence,'YYYY-MM'),nullif(trim(item->>'posicao'),''),
        nullif(trim(item->>'squad'),''),profile.senioridade_atual,normalized_seniority,
        normalized_goal,false,trim(p_origem)
      );
      results_inserted := results_inserted + 1;
      IF NOT profile.id = ANY(affected_ids) THEN
        affected_ids := array_append(affected_ids, profile.id);
      END IF;
    END IF;
  END LOOP;

  FOREACH affected_id IN ARRAY affected_ids LOOP
    SELECT public.normalize_career_seniority(senioridade_informada) INTO current_level
    FROM public.colaboradores
    WHERE colaborador_id = affected_id
      AND public.normalize_career_seniority(senioridade_informada) IS NOT NULL
    ORDER BY competencia,id LIMIT 1;
    IF current_level IS NULL THEN
      SELECT public.normalize_career_seniority(senioridade) INTO current_level
      FROM public.colaboradores WHERE colaborador_id = affected_id
      ORDER BY competencia,id LIMIT 1;
    END IF;
    IF current_level IS NULL THEN
      RAISE EXCEPTION 'Sem senioridade inicial válida para %', affected_id USING ERRCODE = '22023';
    END IF;
    current_progress := 0;

    FOR history_item IN
      SELECT * FROM public.colaboradores
      WHERE colaborador_id = affected_id ORDER BY competencia,id FOR UPDATE
    LOOP
      normalized_goal := public.normalize_career_goal(history_item.meta_alcancada);
      IF normalized_goal IS NULL THEN
        RAISE EXCEPTION 'Meta inválida no resultado %', history_item.id USING ERRCODE = '22023';
      END IF;
      promoted := false;
      IF normalized_goal = 'Meta 3' THEN
        IF current_progress = 2 AND public.next_career_seniority(current_level) IS NOT NULL THEN
          next_level := public.next_career_seniority(current_level);
          promoted := true;
          current_progress := 0;
        ELSE
          current_progress := least(current_progress + 1, 2);
        END IF;
      ELSIF normalized_goal = 'Nenhuma meta' THEN
        current_progress := 0;
      END IF;

      UPDATE public.colaboradores SET
        senioridade = current_level,
        recebeu_promocao = promoted,
        updated_at = now()
      WHERE id = history_item.id
        AND (
          senioridade IS DISTINCT FROM current_level
          OR recebeu_promocao IS DISTINCT FROM promoted
        );
      IF promoted THEN current_level := next_level; END IF;
    END LOOP;

    UPDATE public.colaboradores_perfis SET
      senioridade_atual = current_level,
      progresso_meta3 = current_progress,
      updated_at = now()
    WHERE id = affected_id
      AND (
        senioridade_atual IS DISTINCT FROM current_level
        OR progresso_meta3 IS DISTINCT FROM current_progress
      );
    recalculated := recalculated + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'ok',true,'origem',trim(p_origem),
    'perfis_recebidos',profiles_received,'perfis_inseridos',profiles_inserted,
    'perfis_atualizados',profiles_updated,
    'resultados_recebidos',results_received,'resultados_inseridos',results_inserted,
    'resultados_corrigidos',results_corrected,'resultados_ignorados',results_ignored,
    'colaboradores_recalculados',recalculated
  );
END
$$;
