-- Read the final result set, then ROLLBACK. No production change survives.
BEGIN;
CREATE TEMP TABLE career_profiles_before ON COMMIT DROP AS
SELECT id,nome_colaborador,senioridade_atual,progresso_meta3,
       progresso_meta2,progresso_ciclo,bonificacao_sdr,streak_meta3_bonificacao
FROM public.colaboradores_perfis;
CREATE TEMP TABLE career_results_before ON COMMIT DROP AS
SELECT id,competencia,senioridade,recebeu_promocao FROM public.colaboradores
WHERE competencia>=date '2026-06-01';

DO $$ DECLARE person uuid; BEGIN
  FOR person IN SELECT id FROM public.colaboradores_perfis ORDER BY id LOOP
    PERFORM public.recalcular_progressao_colaborador(person);
  END LOOP;
END $$;

CREATE TEMP TABLE career_profiles_after_first ON COMMIT DROP AS
SELECT id,senioridade_atual,progresso_meta3,progresso_meta2,progresso_ciclo,
       bonificacao_sdr,streak_meta3_bonificacao,updated_at
FROM public.colaboradores_perfis;
CREATE TEMP TABLE career_results_after_first ON COMMIT DROP AS
SELECT id,meta_alcancada,senioridade,recebeu_promocao,squad,posicao,updated_at
FROM public.colaboradores WHERE competencia>=date '2026-06-01';
CREATE TEMP TABLE career_events_after_first ON COMMIT DROP AS
SELECT id,colaborador_id,competencia,event_type,senioridade,recebeu_promocao,created_at
FROM public.career_progression_events WHERE competencia>=date '2026-06-01';

-- Second replay must be observationally identical.
DO $$ DECLARE person uuid; BEGIN
  FOR person IN SELECT id FROM public.colaboradores_perfis ORDER BY id LOOP
    PERFORM public.recalcular_progressao_colaborador(person);
  END LOOP;
END $$;

CREATE TEMP TABLE career_idempotence ON COMMIT DROP AS
SELECT
  (SELECT count(*) FROM (
    (SELECT * FROM career_profiles_after_first EXCEPT SELECT id,senioridade_atual,progresso_meta3,progresso_meta2,progresso_ciclo,bonificacao_sdr,streak_meta3_bonificacao,updated_at FROM public.colaboradores_perfis)
    UNION ALL
    (SELECT id,senioridade_atual,progresso_meta3,progresso_meta2,progresso_ciclo,bonificacao_sdr,streak_meta3_bonificacao,updated_at FROM public.colaboradores_perfis EXCEPT SELECT * FROM career_profiles_after_first)
  ) d) AS diferencas_perfis_segundo_replay,
  (SELECT count(*) FROM (
    (SELECT * FROM career_results_after_first EXCEPT SELECT id,meta_alcancada,senioridade,recebeu_promocao,squad,posicao,updated_at FROM public.colaboradores WHERE competencia>=date '2026-06-01')
    UNION ALL
    (SELECT id,meta_alcancada,senioridade,recebeu_promocao,squad,posicao,updated_at FROM public.colaboradores WHERE competencia>=date '2026-06-01' EXCEPT SELECT * FROM career_results_after_first)
  ) d) AS diferencas_resultados_segundo_replay,
  (SELECT count(*) FROM (
    (SELECT * FROM career_events_after_first EXCEPT SELECT id,colaborador_id,competencia,event_type,senioridade,recebeu_promocao,created_at FROM public.career_progression_events WHERE competencia>=date '2026-06-01')
    UNION ALL
    (SELECT id,colaborador_id,competencia,event_type,senioridade,recebeu_promocao,created_at FROM public.career_progression_events WHERE competencia>=date '2026-06-01' EXCEPT SELECT * FROM career_events_after_first)
  ) d) AS diferencas_eventos_segundo_replay;

CREATE TEMP TABLE career_projected_changes ON COMMIT DROP AS
SELECT b.id,b.nome_colaborador,
  b.senioridade_atual AS senioridade_anterior,p.senioridade_atual AS senioridade_nova,
  b.progresso_meta3 AS meta3_anterior,p.progresso_meta3 AS meta3_nova,
  b.progresso_meta2 AS meta2_anterior,p.progresso_meta2 AS meta2_nova,
  b.progresso_ciclo AS ciclo_anterior,p.progresso_ciclo AS ciclo_novo,
  b.bonificacao_sdr AS bonus_anterior,p.bonificacao_sdr AS bonus_novo,
  b.streak_meta3_bonificacao AS streak_anterior,p.streak_meta3_bonificacao AS streak_novo,
  (SELECT jsonb_agg(jsonb_build_object('competencia',r.competencia,'tipo',r.event_type) ORDER BY r.competencia,r.event_type)
   FROM public.career_progression_events r WHERE r.colaborador_id=p.id AND r.competencia>=date '2026-06-01') AS eventos_novos
FROM career_profiles_before b JOIN public.colaboradores_perfis p USING(id)
WHERE (b.senioridade_atual,b.progresso_meta3,b.progresso_meta2,b.progresso_ciclo,b.bonificacao_sdr,b.streak_meta3_bonificacao)
  IS DISTINCT FROM
      (p.senioridade_atual,p.progresso_meta3,p.progresso_meta2,p.progresso_ciclo,p.bonificacao_sdr,p.streak_meta3_bonificacao)
ORDER BY b.nome_colaborador;

SELECT jsonb_build_object(
  'perfis_analisados', (SELECT count(*) FROM public.colaboradores_perfis),
  'resultados', (SELECT count(*) FROM public.colaboradores),
  'competencias_duplicadas', (
    SELECT count(*) FROM (
      SELECT colaborador_id,competencia FROM public.colaboradores
      GROUP BY colaborador_id,competencia HAVING count(*)>1
    ) d
  ),
  'perfis_alterados', (SELECT count(*) FROM career_projected_changes),
  'senioridades_alteradas', (
    SELECT count(*) FROM career_projected_changes
    WHERE senioridade_anterior IS DISTINCT FROM senioridade_nova
  ),
  'bonus_30', (SELECT count(*) FROM public.colaboradores_perfis WHERE bonificacao_sdr=30),
  'bonus_40', (SELECT count(*) FROM public.colaboradores_perfis WHERE bonificacao_sdr=40),
  'eventos_promocao_senioridade', (
    SELECT count(*) FROM public.career_progression_events
    WHERE competencia>=date '2026-06-01' AND event_type='seniority_promotion'
  ),
  'eventos_promocao_funcao', (
    SELECT count(*) FROM public.career_progression_events
    WHERE competencia>=date '2026-06-01' AND event_type='role_promotion'
  ),
  'segunda_passagem', (SELECT to_jsonb(i) FROM career_idempotence i),
  'alteracoes', coalesce(
    (SELECT jsonb_agg(to_jsonb(c) ORDER BY c.nome_colaborador) FROM career_projected_changes c),
    '[]'::jsonb
  )
) AS dry_run;
ROLLBACK;
