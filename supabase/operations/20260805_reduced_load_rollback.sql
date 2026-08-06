BEGIN;

CREATE TEMP TABLE reduced_rpc_responses (
  step text PRIMARY KEY,
  payload jsonb NOT NULL
) ON COMMIT DROP;

CREATE TEMP TABLE reduced_observations (
  scenario text NOT NULL,
  stage text NOT NULL,
  senioridade_atual text NOT NULL,
  progresso integer NOT NULL,
  promotions bigint NOT NULL,
  PRIMARY KEY (scenario, stage)
) ON COMMIT DROP;

GRANT SELECT, INSERT ON reduced_rpc_responses, reduced_observations TO service_role;
SET LOCAL ROLE service_role;

-- Cenário A: terceira Meta 3 promove e zera o progresso.
INSERT INTO reduced_rpc_responses
SELECT 'A_promocao', public.sincronizar_progressao_planilha(
  jsonb_build_array(jsonb_build_object(
    'nome_colaborador','ZZ TESTE RPC PROMOCAO','posicao','SDR','squad','Lobo','ativo',true)),
  jsonb_build_array(
    jsonb_build_object('nome_colaborador','ZZ TESTE RPC PROMOCAO','posicao','SDR','squad','Lobo',
      'competencia','2026-01-01','meta_alcancada','Meta 3','senioridade_informada','Júnior 1'),
    jsonb_build_object('nome_colaborador','ZZ TESTE RPC PROMOCAO','posicao','SDR','squad','Lobo',
      'competencia','2026-02-01','meta_alcancada','Meta 3','senioridade_informada','Júnior 1'),
    jsonb_build_object('nome_colaborador','ZZ TESTE RPC PROMOCAO','posicao','SDR','squad','Lobo',
      'competencia','2026-03-01','meta_alcancada','Meta 3','senioridade_informada','Júnior 1')),
  'zz_teste_rpc_reduzida');

-- Cenário B: observação incremental do progresso após cada competência.
INSERT INTO reduced_rpc_responses
SELECT 'B_janeiro', public.sincronizar_progressao_planilha(
  jsonb_build_array(jsonb_build_object(
    'nome_colaborador','ZZ TESTE RPC NEUTRALIDADE','posicao','SDR','squad','Águia','ativo',true)),
  jsonb_build_array(jsonb_build_object(
    'nome_colaborador','ZZ TESTE RPC NEUTRALIDADE','posicao','SDR','squad','Águia',
    'competencia','2026-01-01','meta_alcancada','Meta 3','senioridade_informada','Júnior 1')),
  'zz_teste_rpc_reduzida');
INSERT INTO reduced_observations
SELECT 'B','apos_janeiro',p.senioridade_atual,p.progresso_meta3,
  (SELECT count(*) FROM public.colaboradores c WHERE c.colaborador_id=p.id AND c.recebeu_promocao)
FROM public.colaboradores_perfis p WHERE p.nome_normalizado='zz teste rpc neutralidade';

INSERT INTO reduced_rpc_responses
SELECT 'B_sem_presenca', public.sincronizar_progressao_planilha(
  jsonb_build_array(jsonb_build_object(
    'nome_colaborador','ZZ TESTE RPC NEUTRALIDADE','posicao','SDR','squad','Águia','ativo',true)),
  jsonb_build_array(jsonb_build_object(
    'nome_colaborador','ZZ TESTE RPC NEUTRALIDADE','posicao','SDR','squad','Águia',
    'competencia','2026-02-01','meta_alcancada','Sem presença','senioridade_informada',NULL)),
  'zz_teste_rpc_reduzida');
INSERT INTO reduced_observations
SELECT 'B','apos_sem_presenca',p.senioridade_atual,p.progresso_meta3,
  (SELECT count(*) FROM public.colaboradores c WHERE c.colaborador_id=p.id AND c.recebeu_promocao)
FROM public.colaboradores_perfis p WHERE p.nome_normalizado='zz teste rpc neutralidade';

INSERT INTO reduced_rpc_responses
SELECT 'B_meta2', public.sincronizar_progressao_planilha(
  jsonb_build_array(jsonb_build_object(
    'nome_colaborador','ZZ TESTE RPC NEUTRALIDADE','posicao','SDR','squad','Águia','ativo',true)),
  jsonb_build_array(jsonb_build_object(
    'nome_colaborador','ZZ TESTE RPC NEUTRALIDADE','posicao','SDR','squad','Águia',
    'competencia','2026-03-01','meta_alcancada','Meta 2','senioridade_informada','Júnior 1')),
  'zz_teste_rpc_reduzida');
INSERT INTO reduced_observations
SELECT 'B','apos_meta2',p.senioridade_atual,p.progresso_meta3,
  (SELECT count(*) FROM public.colaboradores c WHERE c.colaborador_id=p.id AND c.recebeu_promocao)
FROM public.colaboradores_perfis p WHERE p.nome_normalizado='zz teste rpc neutralidade';

INSERT INTO reduced_rpc_responses
SELECT 'B_nenhuma_meta', public.sincronizar_progressao_planilha(
  jsonb_build_array(jsonb_build_object(
    'nome_colaborador','ZZ TESTE RPC NEUTRALIDADE','posicao','SDR','squad','Águia','ativo',true)),
  jsonb_build_array(jsonb_build_object(
    'nome_colaborador','ZZ TESTE RPC NEUTRALIDADE','posicao','SDR','squad','Águia',
    'competencia','2026-04-01','meta_alcancada','Nenhuma meta','senioridade_informada','Júnior 1')),
  'zz_teste_rpc_reduzida');
INSERT INTO reduced_observations
SELECT 'B','apos_nenhuma_meta',p.senioridade_atual,p.progresso_meta3,
  (SELECT count(*) FROM public.colaboradores c WHERE c.colaborador_id=p.id AND c.recebeu_promocao)
FROM public.colaboradores_perfis p WHERE p.nome_normalizado='zz teste rpc neutralidade';

-- Cenário C: perfil inativo com squad operacional Saiu e histórico preservado.
INSERT INTO reduced_rpc_responses
SELECT 'C_inativo', public.sincronizar_progressao_planilha(
  jsonb_build_array(jsonb_build_object(
    'nome_colaborador','ZZ TESTE RPC INATIVO','posicao','Closer','squad','Saiu','ativo',false)),
  jsonb_build_array(jsonb_build_object(
    'nome_colaborador','ZZ TESTE RPC INATIVO','posicao','Closer','squad','Saiu',
    'competencia','2026-01-01','meta_alcancada','Meta 1','senioridade_informada','Júnior 1')),
  'zz_teste_rpc_reduzida');

-- Cenário D: cria promoção e depois corrige fevereiro, forçando recomposição.
INSERT INTO reduced_rpc_responses
SELECT 'D_promocao_inicial', public.sincronizar_progressao_planilha(
  jsonb_build_array(jsonb_build_object(
    'nome_colaborador','ZZ TESTE RPC CORRECAO','posicao','SDR','squad','Sharks','ativo',true)),
  jsonb_build_array(
    jsonb_build_object('nome_colaborador','ZZ TESTE RPC CORRECAO','posicao','SDR','squad','Sharks',
      'competencia','2026-01-01','meta_alcancada','Meta 3','senioridade_informada','Júnior 1'),
    jsonb_build_object('nome_colaborador','ZZ TESTE RPC CORRECAO','posicao','SDR','squad','Sharks',
      'competencia','2026-02-01','meta_alcancada','Meta 3','senioridade_informada','Júnior 1'),
    jsonb_build_object('nome_colaborador','ZZ TESTE RPC CORRECAO','posicao','SDR','squad','Sharks',
      'competencia','2026-03-01','meta_alcancada','Meta 3','senioridade_informada','Júnior 1')),
  'zz_teste_rpc_reduzida');
INSERT INTO reduced_observations
SELECT 'D','antes_correcao',p.senioridade_atual,p.progresso_meta3,
  (SELECT count(*) FROM public.colaboradores c WHERE c.colaborador_id=p.id AND c.recebeu_promocao)
FROM public.colaboradores_perfis p WHERE p.nome_normalizado='zz teste rpc correcao';

INSERT INTO reduced_rpc_responses
SELECT 'D_correcao_fevereiro', public.sincronizar_progressao_planilha(
  jsonb_build_array(jsonb_build_object(
    'nome_colaborador','ZZ TESTE RPC CORRECAO','posicao','SDR Atual','squad','Sharks Atual','ativo',true)),
  jsonb_build_array(jsonb_build_object(
    'nome_colaborador','ZZ TESTE RPC CORRECAO','posicao','POSICAO NAO SOBRESCREVER',
    'squad','SQUAD NAO SOBRESCREVER','competencia','2026-02-01',
    'meta_alcancada','Meta 2','senioridade_informada','Sênior 3')),
  'zz_teste_rpc_reduzida');
INSERT INTO reduced_observations
SELECT 'D','depois_correcao',p.senioridade_atual,p.progresso_meta3,
  (SELECT count(*) FROM public.colaboradores c WHERE c.colaborador_id=p.id AND c.recebeu_promocao)
FROM public.colaboradores_perfis p WHERE p.nome_normalizado='zz teste rpc correcao';

RESET ROLE;

DO $assertions$
DECLARE
  failed text;
BEGIN
  SELECT string_agg(message, E'\n') INTO failed
  FROM (
    SELECT 'A: perfil não terminou em Júnior 2/progresso 0' AS message
      WHERE NOT EXISTS (SELECT 1 FROM public.colaboradores_perfis
        WHERE nome_normalizado='zz teste rpc promocao'
          AND senioridade_atual='Júnior 2' AND progresso_meta3=0 AND ativo)
    UNION ALL SELECT 'A: promoção não ficou somente em março'
      WHERE NOT EXISTS (SELECT 1 FROM public.colaboradores c
        JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id
        WHERE p.nome_normalizado='zz teste rpc promocao'
        GROUP BY p.id HAVING count(*)=3
          AND count(*) FILTER (WHERE c.recebeu_promocao)=1
          AND bool_and((c.competencia=date '2026-03-01') = c.recebeu_promocao))
    UNION ALL SELECT 'A: março não preservou senioridade histórica Júnior 1'
      WHERE NOT EXISTS (SELECT 1 FROM public.colaboradores c
        JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id
        WHERE p.nome_normalizado='zz teste rpc promocao'
          AND c.competencia=date '2026-03-01' AND c.senioridade='Júnior 1'
          AND c.recebeu_promocao)
    UNION ALL SELECT 'B: progresso observado não foi 1,1,1,0'
      WHERE (SELECT array_agg(progresso ORDER BY CASE stage
          WHEN 'apos_janeiro' THEN 1 WHEN 'apos_sem_presenca' THEN 2
          WHEN 'apos_meta2' THEN 3 ELSE 4 END)
        FROM reduced_observations WHERE scenario='B') IS DISTINCT FROM ARRAY[1,1,1,0]
    UNION ALL SELECT 'B: houve promoção inesperada'
      WHERE EXISTS (SELECT 1 FROM reduced_observations WHERE scenario='B' AND promotions<>0)
    UNION ALL SELECT 'C: perfil inativo/Saiu não foi preservado'
      WHERE NOT EXISTS (SELECT 1 FROM public.colaboradores_perfis
        WHERE nome_normalizado='zz teste rpc inativo' AND NOT ativo AND squad_atual='Saiu')
    UNION ALL SELECT 'C: histórico não foi criado/preservado'
      WHERE NOT EXISTS (SELECT 1 FROM public.colaboradores c
        JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id
        WHERE p.nome_normalizado='zz teste rpc inativo' AND c.squad='Saiu')
    UNION ALL SELECT 'D: promoção inicial não foi observada'
      WHERE NOT EXISTS (SELECT 1 FROM reduced_observations
        WHERE scenario='D' AND stage='antes_correcao'
          AND senioridade_atual='Júnior 2' AND progresso=0 AND promotions=1)
    UNION ALL SELECT 'D: recomposição após correção está incorreta'
      WHERE NOT EXISTS (SELECT 1 FROM reduced_observations
        WHERE scenario='D' AND stage='depois_correcao'
          AND senioridade_atual='Júnior 1' AND progresso=2 AND promotions=0)
    UNION ALL SELECT 'D: squad/posição históricos foram sobrescritos'
      WHERE NOT EXISTS (SELECT 1 FROM public.colaboradores c
        JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id
        WHERE p.nome_normalizado='zz teste rpc correcao'
          AND c.competencia=date '2026-02-01' AND c.squad='Sharks' AND c.posicao='SDR')
    UNION ALL SELECT 'D: senioridade histórica/auditoria incorretas após correção'
      WHERE NOT EXISTS (SELECT 1 FROM public.colaboradores c
        JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id
        WHERE p.nome_normalizado='zz teste rpc correcao'
          AND c.competencia=date '2026-02-01' AND c.senioridade='Júnior 1'
          AND c.senioridade_informada='Sênior 3' AND c.meta_alcancada='Meta 2'
          AND c.origem='zz_teste_rpc_reduzida')
  ) failures;

  IF failed IS NOT NULL THEN
    RAISE EXCEPTION 'Carga reduzida falhou:%', E'\n' || failed;
  END IF;
END
$assertions$;

SELECT jsonb_build_object(
  'ok', true,
  'responses', (SELECT jsonb_agg(to_jsonb(r) ORDER BY r.step) FROM reduced_rpc_responses r),
  'observations', (SELECT jsonb_agg(to_jsonb(o) ORDER BY o.scenario,o.stage) FROM reduced_observations o),
  'profiles', (SELECT jsonb_agg(to_jsonb(p) ORDER BY p.nome_normalizado)
    FROM public.colaboradores_perfis p WHERE p.nome_normalizado LIKE 'zz teste rpc%'),
  'history', (SELECT jsonb_agg(to_jsonb(c) ORDER BY c.nome_colaborador,c.competencia)
    FROM public.colaboradores c WHERE public.normalize_career_name(c.nome_colaborador) LIKE 'zz teste rpc%')
) AS reduced_load_report;

ROLLBACK;
