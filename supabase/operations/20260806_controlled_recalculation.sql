BEGIN;

LOCK TABLE public.colaboradores_perfis IN SHARE ROW EXCLUSIVE MODE;
LOCK TABLE public.colaboradores IN SHARE ROW EXCLUSIVE MODE;

CREATE TEMP TABLE deployment_snapshot AS
SELECT
  (SELECT count(*) FROM public.colaboradores_perfis) AS profiles_count,
  (SELECT count(*) FROM public.colaboradores) AS results_count,
  (SELECT count(*) FROM public.colaboradores_perfis WHERE ativo) AS active_count,
  (SELECT count(*) FROM public.colaboradores_perfis WHERE NOT ativo) AS inactive_count,
  to_regclass('public.sdrs') IS NOT NULL AS public_sdrs_exists;

CREATE TEMP TABLE profile_before AS
SELECT id,senioridade_atual,progresso_meta3,posicao_atual,squad_atual,ativo
FROM public.colaboradores_perfis;

CREATE TEMP TABLE result_before AS
SELECT id,posicao,senioridade,senioridade_informada,meta_alcancada,recebeu_promocao
FROM public.colaboradores;

-- Authorized historical source-data corrections. Names identify data rows only;
-- the progression functions remain generic and contain no person-specific rules.
UPDATE public.colaboradores c SET
  posicao=CASE WHEN c.competencia<=date '2026-06-01' THEN 'SDR' ELSE 'Closer' END,
  senioridade_informada='Júnior 1',
  meta_alcancada=CASE WHEN c.competencia>=date '2026-07-01' THEN 'Sem presença' ELSE c.meta_alcancada END,
  updated_at=now()
FROM public.colaboradores_perfis p
WHERE c.colaborador_id=p.id
  AND p.nome_normalizado=public.normalize_career_name('Miguel Carneiro Nunes')
  AND (
    c.posicao IS DISTINCT FROM CASE WHEN c.competencia<=date '2026-06-01' THEN 'SDR' ELSE 'Closer' END
    OR c.senioridade_informada IS DISTINCT FROM 'Júnior 1'
    OR c.meta_alcancada IS DISTINCT FROM CASE WHEN c.competencia>=date '2026-07-01' THEN 'Sem presença' ELSE c.meta_alcancada END
  );

UPDATE public.colaboradores c SET
  posicao=CASE WHEN c.competencia<=date '2026-06-01' THEN 'SDR' ELSE 'Closer' END,
  senioridade_informada=CASE
    WHEN c.competencia>=date '2026-07-01' THEN 'Júnior 2'
    WHEN c.competencia>=date '2026-04-01' THEN 'Júnior 3'
    ELSE NULL
  END,
  updated_at=now()
FROM public.colaboradores_perfis p
WHERE c.colaborador_id=p.id
  AND p.nome_normalizado=public.normalize_career_name('Tatyanna Lima de Freitas')
  AND (
    c.posicao IS DISTINCT FROM CASE WHEN c.competencia<=date '2026-06-01' THEN 'SDR' ELSE 'Closer' END
    OR c.senioridade_informada IS DISTINCT FROM CASE
      WHEN c.competencia>=date '2026-07-01' THEN 'Júnior 2'
      WHEN c.competencia>=date '2026-04-01' THEN 'Júnior 3'
      ELSE NULL
    END
  );

SELECT public.recalcular_progressao_colaborador(id)
FROM public.colaboradores_perfis
ORDER BY nome_normalizado;

DO $validate$
DECLARE
  snap deployment_snapshot%ROWTYPE;
BEGIN
  SELECT * INTO STRICT snap FROM deployment_snapshot;
  IF (SELECT count(*) FROM public.colaboradores_perfis)<>snap.profiles_count
    OR (SELECT count(*) FROM public.colaboradores)<>snap.results_count
    OR (SELECT count(*) FROM public.colaboradores_perfis WHERE ativo)<>snap.active_count
    OR (SELECT count(*) FROM public.colaboradores_perfis WHERE NOT ativo)<>snap.inactive_count THEN
    RAISE EXCEPTION 'Structural counts changed during recalculation';
  END IF;
  IF (to_regclass('public.sdrs') IS NOT NULL) IS DISTINCT FROM snap.public_sdrs_exists THEN
    RAISE EXCEPTION 'public.sdrs state changed';
  END IF;
  IF EXISTS(SELECT 1 FROM public.colaboradores_perfis WHERE progresso_meta3 NOT BETWEEN 0 AND 2) THEN
    RAISE EXCEPTION 'Progress outside 0..2';
  END IF;
  IF EXISTS(SELECT 1 FROM public.colaboradores c LEFT JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id WHERE p.id IS NULL) THEN
    RAISE EXCEPTION 'Orphan result detected';
  END IF;
  IF EXISTS(SELECT 1 FROM public.colaboradores GROUP BY colaborador_id,competencia HAVING count(*)>1) THEN
    RAISE EXCEPTION 'Duplicate collaborator/competence detected';
  END IF;
  IF EXISTS(SELECT 1 FROM public.colaboradores_perfis WHERE upper(trim(coalesce(posicao_atual,''))) NOT IN ('SDR','CLOSER')) THEN
    RAISE EXCEPTION 'Invalid current position';
  END IF;
  IF EXISTS(SELECT 1 FROM public.colaboradores_perfis WHERE public.normalize_career_seniority(senioridade_atual) IS NULL) THEN
    RAISE EXCEPTION 'Invalid current seniority';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM public.colaboradores_perfis WHERE nome_normalizado=public.normalize_career_name('Miguel Carneiro Nunes') AND posicao_atual='Closer' AND senioridade_atual='Júnior 1' AND progresso_meta3=0) THEN
    RAISE EXCEPTION 'Miguel acceptance failed';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM public.colaboradores_perfis WHERE nome_normalizado=public.normalize_career_name('Tatyanna Lima de Freitas') AND posicao_atual='Closer' AND senioridade_atual='Júnior 2' AND progresso_meta3=0) THEN
    RAISE EXCEPTION 'Tatyanna acceptance failed';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM public.colaboradores_perfis WHERE nome_normalizado=public.normalize_career_name('Adrilene Azevedo da Silva') AND progresso_meta3=0) THEN
    RAISE EXCEPTION 'Adrilene acceptance failed';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM public.colaboradores_perfis WHERE nome_normalizado=public.normalize_career_name('Luiz Fernando de Medeiros Paiva Moura') AND progresso_meta3=1) THEN
    RAISE EXCEPTION 'Luiz acceptance failed';
  END IF;
  IF EXISTS(
    SELECT 1 FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id
    WHERE p.nome_normalizado=public.normalize_career_name('Miguel Carneiro Nunes')
      AND ((c.competencia<=date '2026-06-01' AND c.posicao<>'SDR') OR (c.competencia>=date '2026-07-01' AND c.posicao<>'Closer'))
  ) THEN RAISE EXCEPTION 'Miguel historical position failed'; END IF;
  IF EXISTS(
    SELECT 1 FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id
    WHERE p.nome_normalizado=public.normalize_career_name('Tatyanna Lima de Freitas')
      AND ((c.competencia<=date '2026-06-01' AND c.posicao<>'SDR') OR (c.competencia>=date '2026-07-01' AND c.posicao<>'Closer'))
  ) THEN RAISE EXCEPTION 'Tatyanna historical position failed'; END IF;
  IF EXISTS(SELECT 1 FROM public.career_progression_events WHERE event_type='career_cycle_completed' AND (senioridade<>'Sênior 3' OR recebeu_promocao)) THEN
    RAISE EXCEPTION 'Invalid Sênior 3 cycle completion event';
  END IF;
  IF NOT EXISTS(
    SELECT 1 FROM archive.progression_backup_manifest
    WHERE backup_id='progression_20260806t121500z'
    GROUP BY backup_id HAVING count(*)=2 AND bool_and(source_count=backup_count AND source_hash=backup_hash)
  ) THEN RAISE EXCEPTION 'Validated remote backup is missing'; END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname='colaboradores' AND c.relrowsecurity) OR
     NOT EXISTS(SELECT 1 FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname='colaboradores_perfis' AND c.relrowsecurity) THEN
    RAISE EXCEPTION 'RLS disabled';
  END IF;
  IF has_table_privilege('anon','public.colaboradores','INSERT,UPDATE,DELETE') OR
     has_table_privilege('anon','public.colaboradores_perfis','INSERT,UPDATE,DELETE') OR
     has_function_privilege('anon','public.sincronizar_progressao_planilha(jsonb,jsonb,text)','EXECUTE') THEN
    RAISE EXCEPTION 'Anonymous write permission detected';
  END IF;
END $validate$;

COMMIT;

SELECT jsonb_build_object(
  'profiles_changed', (SELECT count(*) FROM profile_before b JOIN public.colaboradores_perfis p USING(id) WHERE (b.senioridade_atual,b.progresso_meta3,b.posicao_atual,b.squad_atual,b.ativo) IS DISTINCT FROM (p.senioridade_atual,p.progresso_meta3,p.posicao_atual,p.squad_atual,p.ativo)),
  'results_changed', (SELECT count(*) FROM result_before b JOIN public.colaboradores c USING(id) WHERE (b.posicao,b.senioridade,b.senioridade_informada,b.meta_alcancada,b.recebeu_promocao) IS DISTINCT FROM (c.posicao,c.senioridade,c.senioridade_informada,c.meta_alcancada,c.recebeu_promocao)),
  'profiles', (SELECT count(*) FROM public.colaboradores_perfis),
  'results', (SELECT count(*) FROM public.colaboradores),
  'active', (SELECT count(*) FROM public.colaboradores_perfis WHERE ativo),
  'inactive', (SELECT count(*) FROM public.colaboradores_perfis WHERE NOT ativo),
  'cycle_completion_events', (SELECT count(*) FROM public.career_progression_events)
) AS recalculation_result;
