-- Prepared migration only. Do not apply without the controlled dry-run described in
-- supabase/operations/20260805_recalculate_progress_dry_run.sql.

ALTER TABLE public.colaboradores_perfis
  ADD COLUMN IF NOT EXISTS jornada_atual text;

ALTER TABLE public.colaboradores_perfis
  DROP CONSTRAINT IF EXISTS colaboradores_perfis_jornada_atual_check;
ALTER TABLE public.colaboradores_perfis
  ADD CONSTRAINT colaboradores_perfis_jornada_atual_check
  CHECK (jornada_atual IS NULL OR jornada_atual IN ('Ativo','Inativo','Desligado','Saiu'));

CREATE OR REPLACE FUNCTION public.normalize_career_goal(raw_value text)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path = pg_catalog, public AS $$
  SELECT CASE regexp_replace(upper(translate(trim(coalesce(raw_value, '')),
    'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ', 'AAAAAEEEEIIIIOOOOOUUUUC')), '[[:space:]]+', ' ', 'g')
    WHEN '' THEN 'Sem presença' WHEN 'SEM PRESENCA' THEN 'Sem presença' WHEN 'AUSENTE' THEN 'Sem presença'
    WHEN 'META 1' THEN 'Meta 1' WHEN 'META 2' THEN 'Meta 2' WHEN 'META 3' THEN 'Meta 3'
    WHEN 'NENHUMA META' THEN 'Nenhuma meta' WHEN 'SEM META' THEN 'Nenhuma meta'
    WHEN 'SEM REGISTRO' THEN 'Nenhuma meta'
    ELSE NULL END
$$;

CREATE OR REPLACE FUNCTION public.recalcular_progressao_colaborador(p_colaborador_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE
  profile public.colaboradores_perfis%ROWTYPE;
  item public.colaboradores%ROWTYPE;
  current_level text := NULL;
  next_level text;
  current_progress integer := 0;
  promoted boolean;
  normalized_goal text;
  previous_position text := NULL;
  current_position text;
BEGIN
  SELECT * INTO STRICT profile FROM public.colaboradores_perfis
  WHERE id=p_colaborador_id FOR UPDATE;

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
    IF previous_position='SDR' AND current_position='CLOSER' THEN
      current_progress := 0;
    END IF;
    IF current_position<>'' THEN previous_position := current_position; END IF;

    -- Priority: informed in this competence; previous historical/resulting level;
    -- stored historical level; current profile only as last fallback.
    current_level := coalesce(
      public.normalize_career_seniority(item.senioridade_informada),
      current_level,
      public.normalize_career_seniority(item.senioridade),
      public.normalize_career_seniority(profile.senioridade_atual)
    );
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
          RAISE LOG 'career_cycle_completed collaborator_id=% competence=% seniority=Sênior 3 promotion=false',
            p_colaborador_id,item.competencia;
        END IF;
      ELSE
        current_progress := least(current_progress+1,2);
      END IF;
    END IF; -- Meta 1, Meta 2, Sem presença and Nenhuma meta are neutral.

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
    IF promoted THEN current_level := next_level; END IF;
  END LOOP;

  current_level := coalesce(current_level, public.normalize_career_seniority(profile.senioridade_atual));
  UPDATE public.colaboradores_perfis SET
    senioridade_atual=current_level,
    progresso_meta3=current_progress,
    updated_at=now()
  WHERE id=p_colaborador_id AND (
    senioridade_atual IS DISTINCT FROM current_level OR
    progresso_meta3 IS DISTINCT FROM current_progress
  );
END $$;

-- The Apps Script classifies isolated row errors before calling this RPC. The
-- original transactional implementation remains the validated-batch worker.
ALTER FUNCTION public.sincronizar_progressao_planilha(jsonb,jsonb,text)
  RENAME TO sincronizar_progressao_planilha_lote_validado_v1;

CREATE FUNCTION public.sincronizar_progressao_planilha(
  p_perfis jsonb,
  p_resultados jsonb,
  p_origem text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=pg_catalog,public
AS $$
DECLARE
  response jsonb;
  item jsonb;
  person_id uuid;
  journey text;
  affected_ids uuid[] := ARRAY[]::uuid[];
BEGIN
  response := public.sincronizar_progressao_planilha_lote_validado_v1(p_perfis,p_resultados,p_origem);

  FOR item IN SELECT value FROM jsonb_array_elements(p_perfis) LOOP
    SELECT id INTO person_id FROM public.colaboradores_perfis
    WHERE nome_normalizado=public.normalize_career_name(item->>'nome_colaborador');
    IF person_id IS NULL THEN CONTINUE; END IF;
    journey := nullif(trim(item->>'jornada'),'');
    IF journey IS NOT NULL AND journey NOT IN ('Ativo','Inativo','Desligado','Saiu') THEN
      RAISE EXCEPTION 'jornada inválida para %: %',item->>'nome_colaborador',journey USING ERRCODE='22023';
    END IF;
    IF journey IS NOT NULL THEN
      UPDATE public.colaboradores_perfis SET jornada_atual=journey,updated_at=now()
      WHERE id=person_id AND jornada_atual IS DISTINCT FROM journey;
    END IF;
    IF NOT person_id=ANY(affected_ids) THEN affected_ids:=array_append(affected_ids,person_id); END IF;
  END LOOP;

  FOR item IN SELECT value FROM jsonb_array_elements(p_resultados) LOOP
    SELECT id INTO person_id FROM public.colaboradores_perfis
    WHERE nome_normalizado=public.normalize_career_name(item->>'nome_colaborador');
    IF person_id IS NOT NULL AND NOT person_id=ANY(affected_ids) THEN
      affected_ids:=array_append(affected_ids,person_id);
    END IF;
  END LOOP;

  FOREACH person_id IN ARRAY affected_ids LOOP
    PERFORM public.recalcular_progressao_colaborador(person_id);
  END LOOP;
  RETURN response || jsonb_build_object('politica','linhas previamente validadas; lote válido transacional');
END $$;

REVOKE ALL ON FUNCTION public.sincronizar_progressao_planilha_lote_validado_v1(jsonb,jsonb,text) FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.sincronizar_progressao_planilha(jsonb,jsonb,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sincronizar_progressao_planilha(jsonb,jsonb,text) TO service_role;
REVOKE ALL ON FUNCTION public.recalcular_progressao_colaborador(uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.normalize_career_goal(text) FROM PUBLIC,anon,authenticated;
