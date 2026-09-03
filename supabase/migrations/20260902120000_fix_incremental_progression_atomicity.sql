-- The incremental RPC still delegates input validation/upserts to the original
-- validated-batch worker. That worker also retained its pre-cycle replay, which
-- writes only progresso_meta3 and can violate the newer atomic cycle constraint
-- before the current replay runs. Keep its validated CRUD path, but delegate all
-- derived-state materialization to recalcular_progressao_colaborador in the
-- public wrapper.
DO $migration$
DECLARE
  worker_oid regprocedure := to_regprocedure(
    'public.sincronizar_progressao_planilha_lote_validado_v1(jsonb,jsonb,text)'
  );
  worker_source text;
  replay_start integer;
  return_start integer;
  patched_source text;
BEGIN
  IF worker_oid IS NULL THEN
    RAISE EXCEPTION 'validated incremental worker is missing';
  END IF;

  SELECT p.prosrc
  INTO worker_source
  FROM pg_catalog.pg_proc p
  WHERE p.oid=worker_oid;

  replay_start := strpos(
    worker_source,
    E'  FOREACH affected_id IN ARRAY affected_ids LOOP\n'
  );
  return_start := strpos(
    worker_source,
    E'  RETURN jsonb_build_object(\n'
  );

  IF replay_start=0 OR return_start=0 OR return_start<=replay_start THEN
    RAISE EXCEPTION 'validated worker no longer has the expected legacy replay shape';
  END IF;
  IF strpos(
    substring(worker_source FROM replay_start),
    'UPDATE public.colaboradores_perfis SET'
  )=0 THEN
    RAISE EXCEPTION 'expected partial profile update was not found in legacy replay';
  END IF;

  patched_source :=
    left(worker_source,replay_start-1)
    || E'  -- The public wrapper performs the current replay after all input and\n'
    || E'  -- historical position/squad fields have been written. No derived\n'
    || E'  -- profile field is materialized by this legacy worker.\n'
    || E'  recalculated := cardinality(affected_ids);\n\n'
    || substring(worker_source FROM return_start);

  EXECUTE format(
    'CREATE OR REPLACE FUNCTION public.sincronizar_progressao_planilha_lote_validado_v1(p_perfis jsonb,p_resultados jsonb,p_origem text) '
    || 'RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER '
    || 'SET search_path=pg_catalog,public AS %L',
    patched_source
  );
END
$migration$;

COMMENT ON FUNCTION public.sincronizar_progressao_planilha_lote_validado_v1(jsonb,jsonb,text)
IS 'Validated input/upsert worker. Derived career state is materialized only by the current replay in the public wrapper.';

REVOKE ALL ON FUNCTION public.sincronizar_progressao_planilha_lote_validado_v1(jsonb,jsonb,text)
  FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.sincronizar_progressao_planilha(jsonb,jsonb,text)
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sincronizar_progressao_planilha(jsonb,jsonb,text)
  TO service_role;
