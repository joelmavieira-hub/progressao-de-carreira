BEGIN;

DO $$
DECLARE person uuid;
BEGIN
  FOR person IN SELECT id FROM public.colaboradores_perfis ORDER BY id LOOP
    PERFORM public.recalcular_progressao_colaborador(person);
  END LOOP;
END $$;

DO $$
BEGIN
  IF EXISTS(
    SELECT 1 FROM public.colaboradores_perfis p
    JOIN archive.colaboradores_perfis_20260828t101500z b USING(id)
    WHERE p.senioridade_atual IS DISTINCT FROM b.senioridade_atual
  ) THEN RAISE EXCEPTION 'Replay alterou senioridade inesperadamente'; END IF;
  IF EXISTS(
    SELECT 1 FROM public.colaboradores r
    JOIN archive.colaboradores_20260828t101500z b USING(id)
    WHERE r.squad IS DISTINCT FROM b.squad
  ) THEN RAISE EXCEPTION 'Replay alterou squad histórico'; END IF;
  IF EXISTS(
    SELECT 1 FROM public.colaboradores r
    JOIN archive.colaboradores_20260828t101500z b USING(id)
    WHERE r.posicao IS DISTINCT FROM b.posicao
  ) THEN RAISE EXCEPTION 'Replay alterou posição histórica'; END IF;
  IF EXISTS(
    SELECT 1 FROM public.colaboradores r
    JOIN archive.colaboradores_20260828t101500z b USING(id)
    WHERE r.recebeu_promocao IS DISTINCT FROM b.recebeu_promocao
  ) THEN RAISE EXCEPTION 'Replay criou/removeu promoção histórica inesperadamente'; END IF;
END $$;

COMMIT;

WITH profile_changes AS (
  SELECT p.id,p.nome_colaborador,p.senioridade_atual,
    b.progresso_meta3 AS meta3_before,p.progresso_meta3 AS meta3_after,
    b.progresso_meta2 AS meta2_before,p.progresso_meta2 AS meta2_after,
    b.progresso_ciclo AS cycle_before,p.progresso_ciclo AS cycle_after,
    b.bonificacao_sdr AS bonus_before,p.bonificacao_sdr AS bonus_after,
    b.streak_meta3_bonificacao AS bonus_streak_before,p.streak_meta3_bonificacao AS bonus_streak_after
  FROM public.colaboradores_perfis p
  JOIN archive.colaboradores_perfis_20260828t101500z b USING(id)
  WHERE (p.senioridade_atual,p.progresso_meta3,p.progresso_meta2,p.progresso_ciclo,p.bonificacao_sdr,p.streak_meta3_bonificacao)
    IS DISTINCT FROM
    (b.senioridade_atual,b.progresso_meta3,b.progresso_meta2,b.progresso_ciclo,b.bonificacao_sdr,b.streak_meta3_bonificacao)
)
SELECT jsonb_build_object(
  'profiles',(SELECT count(*) FROM public.colaboradores_perfis),
  'results',(SELECT count(*) FROM public.colaboradores),
  'events',(SELECT count(*) FROM public.career_progression_events),
  'functional_profile_changes',(SELECT count(*) FROM profile_changes),
  'profile_changes',(SELECT coalesce(jsonb_agg(to_jsonb(pc) ORDER BY nome_colaborador),'[]'::jsonb) FROM profile_changes pc),
  'seniority_changes',(SELECT count(*) FROM public.colaboradores_perfis p JOIN archive.colaboradores_perfis_20260828t101500z b USING(id) WHERE p.senioridade_atual IS DISTINCT FROM b.senioridade_atual),
  'result_functional_changes',(SELECT count(*) FROM public.colaboradores r JOIN archive.colaboradores_20260828t101500z b USING(id) WHERE (r.meta_alcancada,r.senioridade,r.recebeu_promocao,r.squad,r.posicao) IS DISTINCT FROM (b.meta_alcancada,b.senioridade,b.recebeu_promocao,b.squad,b.posicao)),
  'historical_squad_changes',(SELECT count(*) FROM public.colaboradores r JOIN archive.colaboradores_20260828t101500z b USING(id) WHERE r.squad IS DISTINCT FROM b.squad),
  'historical_position_changes',(SELECT count(*) FROM public.colaboradores r JOIN archive.colaboradores_20260828t101500z b USING(id) WHERE r.posicao IS DISTINCT FROM b.posicao),
  'historical_promotion_changes',(SELECT count(*) FROM public.colaboradores r JOIN archive.colaboradores_20260828t101500z b USING(id) WHERE r.recebeu_promocao IS DISTINCT FROM b.recebeu_promocao),
  'profile_id_changes',abs((SELECT count(*) FROM public.colaboradores_perfis)-(SELECT count(*) FROM archive.colaboradores_perfis_20260828t101500z)),
  'result_id_changes',abs((SELECT count(*) FROM public.colaboradores)-(SELECT count(*) FROM archive.colaboradores_20260828t101500z)),
  'duplicate_results',(SELECT count(*) FROM (SELECT colaborador_id,competencia FROM public.colaboradores GROUP BY colaborador_id,competencia HAVING count(*)>1) d),
  'orphan_results',(SELECT count(*) FROM public.colaboradores r LEFT JOIN public.colaboradores_perfis p ON p.id=r.colaborador_id WHERE p.id IS NULL),
  'closer_with_meta2',(SELECT count(*) FROM public.colaboradores_perfis WHERE upper(trim(coalesce(posicao_atual,'')))='CLOSER' AND progresso_meta2<>0),
  'closer_with_bonus',(SELECT count(*) FROM public.colaboradores_perfis WHERE upper(trim(coalesce(posicao_atual,'')))='CLOSER' AND (bonificacao_sdr<>0 OR streak_meta3_bonificacao<>0))
) AS replay_result;
