BEGIN;

CREATE TEMP TABLE smoke_rpc_result (
  payload jsonb NOT NULL
) ON COMMIT DROP;

GRANT SELECT, INSERT ON smoke_rpc_result TO service_role;
SET LOCAL ROLE service_role;

INSERT INTO smoke_rpc_result
SELECT public.sincronizar_progressao_planilha(
  '[]'::jsonb,
  '[]'::jsonb,
  'smoke_test'
);

RESET ROLE;

DO $assertions$
DECLARE payload jsonb;
BEGIN
  SELECT s.payload INTO payload FROM smoke_rpc_result s;
  IF payload IS NULL
    OR coalesce((payload->>'ok')::boolean,false) IS NOT TRUE
    OR coalesce((payload->>'perfis_recebidos')::integer,-1) <> 0
    OR coalesce((payload->>'resultados_recebidos')::integer,-1) <> 0
    OR coalesce((payload->>'perfis_inseridos')::integer,-1) <> 0
    OR coalesce((payload->>'resultados_inseridos')::integer,-1) <> 0
    OR (SELECT count(*) FROM public.colaboradores_perfis) <> 0
    OR (SELECT count(*) FROM public.colaboradores) <> 0 THEN
    RAISE EXCEPTION 'Smoke RPC inválido: %',coalesce(payload,'null'::jsonb);
  END IF;
END
$assertions$;

SELECT payload AS smoke_response,
  true AS ok,
  (SELECT count(*) FROM public.colaboradores_perfis) AS profiles_rows,
  (SELECT count(*) FROM public.colaboradores) AS results_rows
FROM smoke_rpc_result;

ROLLBACK;
