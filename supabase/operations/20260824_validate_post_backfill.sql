-- Production post-backfill validation and second replay idempotence proof.
BEGIN;

CREATE TEMP TABLE career_profiles_snapshot ON COMMIT DROP AS
SELECT id, to_jsonb(p) AS row_data FROM public.colaboradores_perfis p;
CREATE TEMP TABLE career_results_snapshot ON COMMIT DROP AS
SELECT id, to_jsonb(r) AS row_data FROM public.colaboradores r;
CREATE TEMP TABLE career_events_snapshot ON COMMIT DROP AS
SELECT id, to_jsonb(e) AS row_data FROM public.career_progression_events e;

DO $$
DECLARE person uuid;
BEGIN
  FOR person IN SELECT id FROM public.colaboradores_perfis ORDER BY id LOOP
    PERFORM public.recalcular_progressao_colaborador(person);
  END LOOP;
END $$;

SELECT jsonb_build_object(
  'profiles', (SELECT count(*) FROM public.colaboradores_perfis),
  'results', (SELECT count(*) FROM public.colaboradores),
  'events', (SELECT count(*) FROM public.career_progression_events),
  'duplicate_profiles', (
    SELECT count(*) FROM (
      SELECT nome_normalizado FROM public.colaboradores_perfis
      GROUP BY nome_normalizado HAVING count(*)>1
    ) d
  ),
  'duplicate_results', (
    SELECT count(*) FROM (
      SELECT colaborador_id,competencia FROM public.colaboradores
      GROUP BY colaborador_id,competencia HAVING count(*)>1
    ) d
  ),
  'duplicate_events', (
    SELECT count(*) FROM (
      SELECT colaborador_id,competencia,event_type FROM public.career_progression_events
      GROUP BY colaborador_id,competencia,event_type HAVING count(*)>1
    ) d
  ),
  'orphan_results', (
    SELECT count(*) FROM public.colaboradores r
    LEFT JOIN public.colaboradores_perfis p ON p.id=r.colaborador_id
    WHERE p.id IS NULL
  ),
  'historical_squad_differences', (
    SELECT count(*) FROM public.colaboradores r
    JOIN archive.colaboradores_20260824t024900z b USING(id)
    WHERE r.squad IS DISTINCT FROM b.squad
  ),
  'historical_position_differences', (
    SELECT count(*) FROM public.colaboradores r
    JOIN archive.colaboradores_20260824t024900z b USING(id)
    WHERE r.posicao IS DISTINCT FROM b.posicao
  ),
  'pre_june_results_changed', (
    SELECT count(*) FROM public.colaboradores r
    JOIN archive.colaboradores_20260824t024900z b USING(id)
    WHERE r.competencia<date '2026-06-01' AND to_jsonb(r) IS DISTINCT FROM to_jsonb(b)
  ),
  'bonus_30', (SELECT count(*) FROM public.colaboradores_perfis WHERE bonificacao_sdr=30),
  'bonus_40', (SELECT count(*) FROM public.colaboradores_perfis WHERE bonificacao_sdr=40),
  'non_sdr_with_bonus', (
    SELECT count(*) FROM public.colaboradores_perfis
    WHERE coalesce(posicao_atual,'')<>'SDR' AND bonificacao_sdr<>0
  ),
  'closer_with_bonus', (
    SELECT count(*) FROM public.colaboradores_perfis
    WHERE posicao_atual='Closer' AND bonificacao_sdr<>0
  ),
  'role_promotion_events', (
    SELECT count(*) FROM public.career_progression_events WHERE event_type='role_promotion'
  ),
  'seniority_promotion_events', (
    SELECT count(*) FROM public.career_progression_events WHERE event_type='seniority_promotion'
  ),
  'events_before_june', (
    SELECT count(*) FROM public.career_progression_events WHERE competencia<date '2026-06-01'
  ),
  'second_replay_profile_differences', (
    SELECT count(*) FROM (
      (SELECT id,row_data FROM career_profiles_snapshot
       EXCEPT SELECT id,to_jsonb(p) FROM public.colaboradores_perfis p)
      UNION ALL
      (SELECT id,to_jsonb(p) FROM public.colaboradores_perfis p
       EXCEPT SELECT id,row_data FROM career_profiles_snapshot)
    ) d
  ),
  'second_replay_result_differences', (
    SELECT count(*) FROM (
      (SELECT id,row_data FROM career_results_snapshot
       EXCEPT SELECT id,to_jsonb(r) FROM public.colaboradores r)
      UNION ALL
      (SELECT id,to_jsonb(r) FROM public.colaboradores r
       EXCEPT SELECT id,row_data FROM career_results_snapshot)
    ) d
  ),
  'second_replay_event_differences', (
    SELECT count(*) FROM (
      (SELECT id,row_data FROM career_events_snapshot
       EXCEPT SELECT id,to_jsonb(e) FROM public.career_progression_events e)
      UNION ALL
      (SELECT id,to_jsonb(e) FROM public.career_progression_events e
       EXCEPT SELECT id,row_data FROM career_events_snapshot)
    ) d
  )
) AS post_backfill_validation;

COMMIT;
