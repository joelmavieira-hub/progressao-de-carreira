BEGIN;

CREATE TEMP TABLE closer_profiles_before AS SELECT id,to_jsonb(p) AS row_data FROM public.colaboradores_perfis p;
CREATE TEMP TABLE closer_results_before AS SELECT id,to_jsonb(r) AS row_data FROM public.colaboradores r;
CREATE TEMP TABLE closer_events_before AS SELECT id,to_jsonb(e) AS row_data FROM public.career_progression_events e;
CREATE TEMP TABLE closer_idempotence_result(
  profile_differences bigint,result_differences bigint,event_differences bigint,
  squad_differences bigint,position_differences bigint
);

DO $$
DECLARE person uuid;
BEGIN
  FOR person IN SELECT id FROM public.colaboradores_perfis ORDER BY id LOOP
    PERFORM public.recalcular_progressao_colaborador(person);
  END LOOP;
END $$;

INSERT INTO closer_idempotence_result
SELECT
  (SELECT count(*) FROM (
    (SELECT id,row_data FROM closer_profiles_before EXCEPT SELECT id,to_jsonb(p) FROM public.colaboradores_perfis p)
    UNION ALL
    (SELECT id,to_jsonb(p) FROM public.colaboradores_perfis p EXCEPT SELECT id,row_data FROM closer_profiles_before)
  ) d),
  (SELECT count(*) FROM (
    (SELECT id,row_data FROM closer_results_before EXCEPT SELECT id,to_jsonb(r) FROM public.colaboradores r)
    UNION ALL
    (SELECT id,to_jsonb(r) FROM public.colaboradores r EXCEPT SELECT id,row_data FROM closer_results_before)
  ) d),
  (SELECT count(*) FROM (
    (SELECT id,row_data FROM closer_events_before EXCEPT SELECT id,to_jsonb(e) FROM public.career_progression_events e)
    UNION ALL
    (SELECT id,to_jsonb(e) FROM public.career_progression_events e EXCEPT SELECT id,row_data FROM closer_events_before)
  ) d),
  (SELECT count(*) FROM public.colaboradores r JOIN archive.colaboradores_20260828t101500z b USING(id) WHERE r.squad IS DISTINCT FROM b.squad),
  (SELECT count(*) FROM public.colaboradores r JOIN archive.colaboradores_20260828t101500z b USING(id) WHERE r.posicao IS DISTINCT FROM b.posicao);

DO $$
BEGIN
  IF EXISTS(SELECT 1 FROM closer_idempotence_result WHERE profile_differences<>0 OR result_differences<>0 OR event_differences<>0 OR squad_differences<>0 OR position_differences<>0)
  THEN RAISE EXCEPTION 'Segunda passagem não foi idempotente'; END IF;
END $$;

COMMIT;

SELECT jsonb_build_object(
  'profile_differences',profile_differences,
  'result_differences',result_differences,
  'event_differences',event_differences,
  'squad_differences',squad_differences,
  'position_differences',position_differences,
  'all_fields_including_ids_created_at_updated_at_identical',profile_differences=0 AND result_differences=0 AND event_differences=0
) AS idempotence
FROM closer_idempotence_result;
