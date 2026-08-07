BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SELECT plan(131);

CREATE TEMP TABLE pgtap_finish_output (
  line text NOT NULL
) ON COMMIT DROP;

CREATE TEMP TABLE pgtap_assertion_output (
  sequence bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  line text NOT NULL
) ON COMMIT DROP;

INSERT INTO pgtap_assertion_output(line) SELECT is(public.normalize_career_name(' Alice   RPC '),public.normalize_career_name('alice rpc'),'normalized name ignores case and repeated spaces');
INSERT INTO pgtap_assertion_output(line) SELECT is(public.normalize_career_goal('Sem presença'),'Sem presença','goal normalizer accepts canonical lowercase accent');
INSERT INTO pgtap_assertion_output(line) SELECT is(public.normalize_career_goal('SEM PRESENÇA'),'Sem presença','goal normalizer accepts uppercase accent');
INSERT INTO pgtap_assertion_output(line) SELECT is(public.normalize_career_goal('sem presença'),'Sem presença','goal normalizer accepts lowercase accented input');
INSERT INTO pgtap_assertion_output(line) SELECT is(public.normalize_career_goal('Sem presenca'),'Sem presença','goal normalizer accepts unaccented input');
INSERT INTO pgtap_assertion_output(line) SELECT is(public.normalize_career_goal('Sem registro'),'Nenhuma meta','goal normalizer accepts explicit missing-record label');
INSERT INTO pgtap_assertion_output(line) SELECT is(public.normalize_career_seniority('Júnior 1'),'Júnior 1','seniority normalizer accepts canonical lowercase accent');
INSERT INTO pgtap_assertion_output(line) SELECT is(public.normalize_career_seniority('JÚNIOR 1'),'Júnior 1','seniority normalizer accepts uppercase accent');
INSERT INTO pgtap_assertion_output(line) SELECT is(public.normalize_career_seniority('júnior 1'),'Júnior 1','seniority normalizer accepts lowercase accented input');
INSERT INTO pgtap_assertion_output(line) SELECT is(public.normalize_career_seniority('Junior 1'),'Júnior 1','seniority normalizer accepts unaccented input');
INSERT INTO pgtap_assertion_output(line) SELECT is(public.parse_legacy_competencia('MARÇO'),date '2026-03-01','legacy month normalizer accepts uppercase accent');
INSERT INTO pgtap_assertion_output(line) SELECT is(public.parse_legacy_competencia('março'),date '2026-03-01','legacy month normalizer accepts lowercase accent');
INSERT INTO pgtap_assertion_output(line) SELECT is(public.parse_legacy_competencia('2026-01-01'),date '2026-01-01','legacy competence preserves January ISO fallback');
INSERT INTO pgtap_assertion_output(line) SELECT is(public.parse_legacy_competencia('2026-08-01'),date '2026-08-01','legacy competence preserves August ISO fallback');
INSERT INTO pgtap_assertion_output(line) SELECT throws_ok($$INSERT INTO public.colaboradores_perfis(nome_colaborador,nome_normalizado,senioridade_atual)
 VALUES('ZZ TESTE RPC Pessoa Única','zz teste rpc pessoa única','Júnior 1'),('ZZ TESTE RPC PESSOA ÚNICA','zz teste rpc pessoa única','Júnior 1')$$,'23505',NULL,'nome_normalizado is unique');
INSERT INTO pgtap_assertion_output(line) SELECT is(public.parse_legacy_competencia(' Abril '),date '2026-04-01','legacy month uses 2026 base year');

CREATE TEMP TABLE sync_response(payload jsonb);
INSERT INTO sync_response SELECT public.sincronizar_progressao_planilha(
  jsonb_build_array(jsonb_build_object('nome_colaborador',' ZZ TESTE RPC Alice   RPC ','posicao','SDR','squad','Lobo','ativo',true)),
  jsonb_build_array(
    jsonb_build_object('nome_colaborador','ZZ TESTE RPC Alice RPC','posicao','SDR','squad','Lobo','competencia','2026-01-01','meta_alcancada','Meta 3','senioridade_informada','Júnior 1'),
    jsonb_build_object('nome_colaborador','ZZ TESTE RPC Alice RPC','posicao','SDR','squad','Lobo','competencia','2026-02-01','meta_alcancada','Meta 1','senioridade_informada','Júnior 1'),
    jsonb_build_object('nome_colaborador','ZZ TESTE RPC Alice RPC','posicao','SDR','squad','Lobo','competencia','2026-03-01','meta_alcancada','Meta 2','senioridade_informada','Júnior 1'),
    jsonb_build_object('nome_colaborador','ZZ TESTE RPC Alice RPC','posicao','SDR','squad','Lobo','competencia','2026-04-01','meta_alcancada','Sem presença','senioridade_informada',NULL),
    jsonb_build_object('nome_colaborador','ZZ TESTE RPC Alice RPC','posicao','SDR','squad','Lobo','competencia','2026-05-01','meta_alcancada','Meta 3','senioridade_informada','Júnior 1'),
    jsonb_build_object('nome_colaborador','ZZ TESTE RPC Alice RPC','posicao','SDR','squad','Lobo','competencia','2026-06-01','meta_alcancada','Meta 3','senioridade_informada','Júnior 1')
  ),'zz_teste_rpc_pgtap');

INSERT INTO pgtap_assertion_output(line) SELECT ok((SELECT (payload->>'ok')::boolean FROM sync_response),'RPC reports success');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT (payload->>'perfis_recebidos')::integer FROM sync_response),1,'reports received profiles');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT (payload->>'perfis_inseridos')::integer FROM sync_response),1,'inserts a new profile');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT (payload->>'resultados_inseridos')::integer FROM sync_response),6,'inserts monthly results');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT count(*) FROM public.colaboradores_perfis WHERE nome_normalizado='zz teste rpc alice rpc'),1::bigint,'one Alice profile exists');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT count(*) FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id WHERE p.nome_normalizado='zz teste rpc alice rpc'),6::bigint,'six Alice history rows exist');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT senioridade_atual FROM public.colaboradores_perfis WHERE nome_normalizado='zz teste rpc alice rpc'),'Júnior 2','current profile advances');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT progresso_meta3 FROM public.colaboradores_perfis WHERE nome_normalizado='zz teste rpc alice rpc'),0,'promotion resets progress');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT count(*) FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id WHERE p.nome_normalizado='zz teste rpc alice rpc' AND c.recebeu_promocao),1::bigint,'only one month is promoter');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT c.competencia FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id WHERE p.nome_normalizado='zz teste rpc alice rpc' AND c.recebeu_promocao),date '2026-06-01','third Meta 3 is promoter month');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT c.senioridade FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id WHERE p.nome_normalizado='zz teste rpc alice rpc' AND c.recebeu_promocao),'Júnior 1','promoter month keeps previous seniority');
INSERT INTO pgtap_assertion_output(line) SELECT ok((SELECT bool_and(c.origem='zz_teste_rpc_pgtap') FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id WHERE p.nome_normalizado='zz teste rpc alice rpc'),'new results record origin');

-- Operational idempotency: an identical resend must create no row version or timestamp churn.
CREATE TEMP TABLE operational_idempotency_snapshot AS
SELECT
  p.id AS profile_id,
  p.created_at AS profile_created_at,
  p.updated_at AS profile_updated_at,
  p.ctid::text AS profile_ctid,
  jsonb_build_object(
    'nome_colaborador',p.nome_colaborador,'nome_normalizado',p.nome_normalizado,
    'posicao_atual',p.posicao_atual,'squad_atual',p.squad_atual,
    'senioridade_atual',p.senioridade_atual,'progresso_meta3',p.progresso_meta3,'ativo',p.ativo
  ) AS profile_functional,
  (SELECT jsonb_agg(c.id ORDER BY c.competencia,c.id) FROM public.colaboradores c WHERE c.colaborador_id=p.id) AS result_ids,
  (SELECT jsonb_agg(c.created_at ORDER BY c.competencia,c.id) FROM public.colaboradores c WHERE c.colaborador_id=p.id) AS result_created_ats,
  (SELECT jsonb_agg(c.updated_at ORDER BY c.competencia,c.id) FROM public.colaboradores c WHERE c.colaborador_id=p.id) AS result_updated_ats,
  (SELECT jsonb_agg(c.ctid::text ORDER BY c.competencia,c.id) FROM public.colaboradores c WHERE c.colaborador_id=p.id) AS result_ctids,
  (SELECT jsonb_agg(jsonb_build_object(
      'nome_colaborador',c.nome_colaborador,'posicao',c.posicao,'squad',c.squad,
      'competencia',c.competencia,'meta_alcancada',c.meta_alcancada,
      'senioridade',c.senioridade,'senioridade_informada',c.senioridade_informada,
      'recebeu_promocao',c.recebeu_promocao,'origem',c.origem
    ) ORDER BY c.competencia,c.id)
   FROM public.colaboradores c WHERE c.colaborador_id=p.id) AS result_functional
FROM public.colaboradores_perfis p
WHERE p.nome_normalizado='zz teste rpc alice rpc';

DELETE FROM sync_response;
INSERT INTO sync_response SELECT public.sincronizar_progressao_planilha(
  jsonb_build_array(jsonb_build_object('nome_colaborador','ZZ TESTE RPC Alice RPC','posicao','SDR','squad','Lobo','ativo',true)),
  (SELECT jsonb_agg(jsonb_build_object('nome_colaborador',c.nome_colaborador,'posicao',c.posicao,'squad',c.squad,'competencia',c.competencia,'meta_alcancada',c.meta_alcancada,'senioridade_informada',c.senioridade_informada) ORDER BY c.competencia)
   FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id WHERE p.nome_normalizado='zz teste rpc alice rpc'),
  'zz_teste_rpc_pgtap');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT (payload->>'resultados_ignorados')::integer FROM sync_response),6,'identical resend is ignored');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT count(*) FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id WHERE p.nome_normalizado='zz teste rpc alice rpc'),6::bigint,'identical resend does not duplicate history');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT count(*) FROM public.colaboradores_perfis WHERE nome_normalizado='zz teste rpc alice rpc'),1::bigint,'identical resend does not duplicate profile');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT (payload->>'perfis_inseridos')::integer FROM sync_response),0,'identical resend inserts no profile');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT (payload->>'perfis_atualizados')::integer FROM sync_response),0,'identical resend updates no profile');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT (payload->>'resultados_inseridos')::integer FROM sync_response),0,'identical resend inserts no result');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT (payload->>'resultados_corrigidos')::integer FROM sync_response),0,'identical resend corrects no result, including NULL informed seniority');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT (payload->>'colaboradores_recalculados')::integer FROM sync_response),0,'identical resend recalculates no collaborator');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT id FROM public.colaboradores_perfis WHERE nome_normalizado='zz teste rpc alice rpc'),(SELECT profile_id FROM operational_idempotency_snapshot),'identical resend preserves profile id');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT created_at FROM public.colaboradores_perfis WHERE nome_normalizado='zz teste rpc alice rpc'),(SELECT profile_created_at FROM operational_idempotency_snapshot),'identical resend preserves profile created_at');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT updated_at FROM public.colaboradores_perfis WHERE nome_normalizado='zz teste rpc alice rpc'),(SELECT profile_updated_at FROM operational_idempotency_snapshot),'identical resend preserves profile updated_at');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT ctid::text FROM public.colaboradores_perfis WHERE nome_normalizado='zz teste rpc alice rpc'),(SELECT profile_ctid FROM operational_idempotency_snapshot),'identical resend creates no profile row version');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT jsonb_agg(c.id ORDER BY c.competencia,c.id) FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id WHERE p.nome_normalizado='zz teste rpc alice rpc'),(SELECT result_ids FROM operational_idempotency_snapshot),'identical resend preserves result ids');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT jsonb_agg(c.created_at ORDER BY c.competencia,c.id) FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id WHERE p.nome_normalizado='zz teste rpc alice rpc'),(SELECT result_created_ats FROM operational_idempotency_snapshot),'identical resend preserves result created_at');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT jsonb_agg(c.updated_at ORDER BY c.competencia,c.id) FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id WHERE p.nome_normalizado='zz teste rpc alice rpc'),(SELECT result_updated_ats FROM operational_idempotency_snapshot),'identical resend preserves result updated_at');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT jsonb_agg(c.ctid::text ORDER BY c.competencia,c.id) FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id WHERE p.nome_normalizado='zz teste rpc alice rpc'),(SELECT result_ctids FROM operational_idempotency_snapshot),'identical resend creates no result row version');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT jsonb_build_object('nome_colaborador',p.nome_colaborador,'nome_normalizado',p.nome_normalizado,'posicao_atual',p.posicao_atual,'squad_atual',p.squad_atual,'senioridade_atual',p.senioridade_atual,'progresso_meta3',p.progresso_meta3,'ativo',p.ativo) FROM public.colaboradores_perfis p WHERE p.nome_normalizado='zz teste rpc alice rpc'),(SELECT profile_functional FROM operational_idempotency_snapshot),'identical resend preserves profile functional content');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT jsonb_agg(jsonb_build_object('nome_colaborador',c.nome_colaborador,'posicao',c.posicao,'squad',c.squad,'competencia',c.competencia,'meta_alcancada',c.meta_alcancada,'senioridade',c.senioridade,'senioridade_informada',c.senioridade_informada,'recebeu_promocao',c.recebeu_promocao,'origem',c.origem) ORDER BY c.competencia,c.id) FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id WHERE p.nome_normalizado='zz teste rpc alice rpc'),(SELECT result_functional FROM operational_idempotency_snapshot),'identical resend preserves result functional content');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT count(*) FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id WHERE p.nome_normalizado='zz teste rpc alice rpc' AND c.meta_alcancada='Sem presença' AND c.senioridade_informada IS NULL),1::bigint,'NULL informed seniority remains NULL and is ignored');

SELECT public.sincronizar_progressao_planilha(
  jsonb_build_array(jsonb_build_object('nome_colaborador','ZZ TESTE RPC ALICE RPC','posicao','Closer','squad','Águia','ativo',true)),
  '[]'::jsonb,'zz_teste_rpc_pgtap');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT squad_atual FROM public.colaboradores_perfis WHERE nome_normalizado='zz teste rpc alice rpc'),'Águia','profile current squad updates');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT posicao_atual FROM public.colaboradores_perfis WHERE nome_normalizado='zz teste rpc alice rpc'),'Closer','profile current position updates');
INSERT INTO pgtap_assertion_output(line) SELECT ok((SELECT bool_and(c.squad='Lobo') FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id WHERE p.nome_normalizado='zz teste rpc alice rpc'),'historical squad is preserved');
INSERT INTO pgtap_assertion_output(line) SELECT ok((SELECT bool_and(c.posicao='SDR') FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id WHERE p.nome_normalizado='zz teste rpc alice rpc'),'historical position is preserved');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT count(*) FROM public.colaboradores_perfis WHERE nome_normalizado='zz teste rpc alice rpc'),1::bigint,'squad change creates no profile');

-- Goal semantics through the batch RPC.
SELECT public.sincronizar_progressao_planilha(
  jsonb_build_array(jsonb_build_object('nome_colaborador','ZZ TESTE RPC Bob Regras','posicao','SDR','squad','Lobo','ativo',true)),
  jsonb_build_array(jsonb_build_object('nome_colaborador','ZZ TESTE RPC Bob Regras','posicao','SDR','squad','Lobo','competencia','2026-01-01','meta_alcancada','Meta 3','senioridade_informada','Pleno 1')),
  'zz_teste_rpc_pgtap');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT progresso_meta3 FROM public.colaboradores_perfis WHERE nome_normalizado='zz teste rpc bob regras'),1,'Meta 3 increments zero to one');
SELECT public.sincronizar_progressao_planilha(jsonb_build_array(jsonb_build_object('nome_colaborador','ZZ TESTE RPC Bob Regras','posicao','SDR','squad','Lobo','ativo',true)),jsonb_build_array(jsonb_build_object('nome_colaborador','ZZ TESTE RPC Bob Regras','posicao','SDR','squad','Lobo','competencia','2026-02-01','meta_alcancada','Meta 1','senioridade_informada','Pleno 1')),'zz_teste_rpc_pgtap');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT progresso_meta3 FROM public.colaboradores_perfis WHERE nome_normalizado='zz teste rpc bob regras'),1,'Meta 1 preserves progress');
SELECT public.sincronizar_progressao_planilha(jsonb_build_array(jsonb_build_object('nome_colaborador','ZZ TESTE RPC Bob Regras','posicao','SDR','squad','Lobo','ativo',true)),jsonb_build_array(jsonb_build_object('nome_colaborador','ZZ TESTE RPC Bob Regras','posicao','SDR','squad','Lobo','competencia','2026-03-01','meta_alcancada','Meta 2','senioridade_informada','Pleno 1')),'zz_teste_rpc_pgtap');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT progresso_meta3 FROM public.colaboradores_perfis WHERE nome_normalizado='zz teste rpc bob regras'),1,'Meta 2 preserves progress');
SELECT public.sincronizar_progressao_planilha(jsonb_build_array(jsonb_build_object('nome_colaborador','ZZ TESTE RPC Bob Regras','posicao','SDR','squad','Lobo','ativo',true)),jsonb_build_array(jsonb_build_object('nome_colaborador','ZZ TESTE RPC Bob Regras','posicao','SDR','squad','Lobo','competencia','2026-04-01','meta_alcancada','Sem presença','senioridade_informada','Pleno 1')),'zz_teste_rpc_pgtap');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT progresso_meta3 FROM public.colaboradores_perfis WHERE nome_normalizado='zz teste rpc bob regras'),1,'Sem presença is neutral');
SELECT public.sincronizar_progressao_planilha(jsonb_build_array(jsonb_build_object('nome_colaborador','ZZ TESTE RPC Bob Regras','posicao','SDR','squad','Lobo','ativo',true)),jsonb_build_array(jsonb_build_object('nome_colaborador','ZZ TESTE RPC Bob Regras','posicao','SDR','squad','Lobo','competencia','2026-05-01','meta_alcancada','Nenhuma meta','senioridade_informada','Pleno 1')),'zz_teste_rpc_pgtap');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT progresso_meta3 FROM public.colaboradores_perfis WHERE nome_normalizado='zz teste rpc bob regras'),1,'Nenhuma meta is neutral');
SELECT public.sincronizar_progressao_planilha(jsonb_build_array(jsonb_build_object('nome_colaborador','ZZ TESTE RPC Bob Regras','posicao','Closer','squad','Lobo','ativo',true)),jsonb_build_array(jsonb_build_object('nome_colaborador','ZZ TESTE RPC Bob Regras','posicao','Closer','squad','Lobo','competencia','2026-06-01','meta_alcancada','Meta 3','senioridade_informada','Pleno 1')),'zz_teste_rpc_pgtap');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT progresso_meta3 FROM public.colaboradores_perfis WHERE nome_normalizado='zz teste rpc bob regras'),1,'SDR to Closer resets before first Closer Meta 3');
SELECT public.sincronizar_progressao_planilha(jsonb_build_array(jsonb_build_object('nome_colaborador',' zz teste rpc bob   regras ','posicao','SDR','squad','Lobo','ativo',true)),'[]'::jsonb,'zz_teste_rpc_pgtap');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT count(*) FROM public.colaboradores_perfis WHERE nome_normalizado='zz teste rpc bob regras'),1::bigint,'equivalent names identify one person');

-- Historical correction removes and then recreates a promotion, recomputing later months.
UPDATE public.colaboradores c SET updated_at = x.synthetic_updated_at
FROM (
  SELECT c2.id,timestamptz '2000-01-01 00:00:00+00'
    + row_number() OVER (ORDER BY c2.competencia,c2.id) * interval '1 day' AS synthetic_updated_at
  FROM public.colaboradores c2
  JOIN public.colaboradores_perfis p2 ON p2.id=c2.colaborador_id
  WHERE p2.nome_normalizado='zz teste rpc alice rpc'
) x
WHERE c.id=x.id;
CREATE TEMP TABLE correction_snapshot AS
SELECT p.ctid::text AS profile_ctid
FROM public.colaboradores_perfis p
WHERE p.nome_normalizado='zz teste rpc alice rpc';

DELETE FROM sync_response;
INSERT INTO sync_response SELECT public.sincronizar_progressao_planilha(
  jsonb_build_array(jsonb_build_object('nome_colaborador','ZZ TESTE RPC Alice RPC','posicao','Closer','squad','Águia','ativo',true)),
  jsonb_build_array(jsonb_build_object('nome_colaborador','ZZ TESTE RPC Alice RPC','posicao','Closer','squad','Águia','competencia','2026-01-01','meta_alcancada','Meta 2','senioridade_informada','Júnior 1')),
  'zz_teste_rpc_pgtap');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT (payload->>'resultados_corrigidos')::integer FROM sync_response),1,'old month is counted as correction');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT count(*) FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id WHERE p.nome_normalizado='zz teste rpc alice rpc' AND c.recebeu_promocao),0::bigint,'correction removes obsolete promotion');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT senioridade_atual FROM public.colaboradores_perfis WHERE nome_normalizado='zz teste rpc alice rpc'),'Júnior 1','old correction recomputes later seniority');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT progresso_meta3 FROM public.colaboradores_perfis WHERE nome_normalizado='zz teste rpc alice rpc'),2,'old correction recomputes later progress');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT count(*) FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id WHERE p.nome_normalizado='zz teste rpc alice rpc'),6::bigint,'correction never deletes history');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT c.squad FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id WHERE p.nome_normalizado='zz teste rpc alice rpc' AND c.competencia=date '2026-01-01'),'Águia','correction accepts authoritative historical squad');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT c.posicao FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id WHERE p.nome_normalizado='zz teste rpc alice rpc' AND c.competencia=date '2026-01-01'),'Closer','correction accepts authoritative historical position');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT (payload->>'colaboradores_recalculados')::integer FROM sync_response),1,'real Meta 3 to Meta 2 correction selectively recalculates one collaborator');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT count(*) FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id WHERE p.nome_normalizado='zz teste rpc alice rpc' AND c.updated_at>timestamptz '2020-01-01'),2::bigint,'real correction updates timestamps only on functionally changed history rows');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT count(*) FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id WHERE p.nome_normalizado='zz teste rpc alice rpc' AND c.updated_at<timestamptz '2020-01-01'),4::bigint,'real correction preserves timestamps on unchanged history rows');
INSERT INTO pgtap_assertion_output(line) SELECT ok((SELECT bool_and(c.competencia IN (date '2026-01-01',date '2026-06-01')) FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id WHERE p.nome_normalizado='zz teste rpc alice rpc' AND c.updated_at>timestamptz '2020-01-01'),'only corrected month and changed promotion month receive new timestamps');
INSERT INTO pgtap_assertion_output(line) SELECT isnt((SELECT ctid::text FROM public.colaboradores_perfis WHERE nome_normalizado='zz teste rpc alice rpc'),(SELECT profile_ctid FROM correction_snapshot),'real correction creates a new profile row version when calculated state changes');

SELECT public.sincronizar_progressao_planilha(
  jsonb_build_array(jsonb_build_object('nome_colaborador','ZZ TESTE RPC Alice RPC','posicao','Closer','squad','Águia','ativo',true)),
  jsonb_build_array(jsonb_build_object('nome_colaborador','ZZ TESTE RPC Alice RPC','posicao','Closer','squad','Águia','competencia','2026-01-01','meta_alcancada','Meta 3','senioridade_informada','Júnior 1')),
  'zz_teste_rpc_pgtap');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT count(*) FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id WHERE p.nome_normalizado='zz teste rpc alice rpc' AND c.recebeu_promocao),1::bigint,'restored Meta 3 recreates promotion');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT senioridade_atual FROM public.colaboradores_perfis WHERE nome_normalizado='zz teste rpc alice rpc'),'Júnior 2','restored promotion advances profile');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT progresso_meta3 FROM public.colaboradores_perfis WHERE nome_normalizado='zz teste rpc alice rpc'),0,'restored promotion resets progress');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT c.competencia FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id WHERE p.nome_normalizado='zz teste rpc alice rpc' AND c.recebeu_promocao),date '2026-06-01','only causal month is re-marked');

SELECT public.sincronizar_progressao_planilha(jsonb_build_array(jsonb_build_object('nome_colaborador','ZZ TESTE RPC Alice RPC','posicao','Closer','squad','Águia','ativo',false)),'[]'::jsonb,'zz_teste_rpc_pgtap');
INSERT INTO pgtap_assertion_output(line) SELECT isnt((SELECT ativo FROM public.colaboradores_perfis WHERE nome_normalizado='zz teste rpc alice rpc'),true,'profile can become inactive');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT count(*) FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id WHERE p.nome_normalizado='zz teste rpc alice rpc'),6::bigint,'inactive profile retains history');

SELECT public.sincronizar_progressao_planilha(
 jsonb_build_array(jsonb_build_object('nome_colaborador','ZZ TESTE RPC Senior Topo','posicao','SDR','squad','Lobo','ativo',true)),
 jsonb_build_array(
  jsonb_build_object('nome_colaborador','ZZ TESTE RPC Senior Topo','posicao','SDR','squad','Lobo','competencia','2026-01-01','meta_alcancada','Meta 3','senioridade_informada','Sênior 3'),
  jsonb_build_object('nome_colaborador','ZZ TESTE RPC Senior Topo','posicao','SDR','squad','Lobo','competencia','2026-02-01','meta_alcancada','Meta 3','senioridade_informada','Sênior 3'),
  jsonb_build_object('nome_colaborador','ZZ TESTE RPC Senior Topo','posicao','SDR','squad','Lobo','competencia','2026-03-01','meta_alcancada','Meta 3','senioridade_informada','Sênior 3')),
 'zz_teste_rpc_pgtap');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT senioridade_atual FROM public.colaboradores_perfis WHERE nome_normalizado='zz teste rpc senior topo'),'Sênior 3','career top never advances');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT count(*) FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id WHERE p.nome_normalizado='zz teste rpc senior topo' AND c.recebeu_promocao),0::bigint,'career top has no fictitious promotion');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT progresso_meta3 FROM public.colaboradores_perfis WHERE nome_normalizado='zz teste rpc senior topo'),0,'third career-top Meta 3 completes and resets cycle');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT count(*) FROM public.career_progression_events e JOIN public.colaboradores_perfis p ON p.id=e.colaborador_id WHERE p.nome_normalizado='zz teste rpc senior topo' AND e.event_type='career_cycle_completed' AND e.competencia=date '2026-03-01' AND e.senioridade='Sênior 3' AND NOT e.recebeu_promocao),1::bigint,'third career-top Meta 3 persists a non-promotional cycle completion event');
SELECT public.sincronizar_progressao_planilha(
 jsonb_build_array(jsonb_build_object('nome_colaborador','ZZ TESTE RPC Senior Topo','posicao','SDR','squad','Lobo','ativo',true)),
 jsonb_build_array(jsonb_build_object('nome_colaborador','ZZ TESTE RPC Senior Topo','posicao','SDR','squad','Lobo','competencia','2026-04-01','meta_alcancada','Meta 3','senioridade_informada','Sênior 3')),
 'zz_teste_rpc_pgtap');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT progresso_meta3 FROM public.colaboradores_perfis WHERE nome_normalizado='zz teste rpc senior topo'),1,'next career-top Meta 3 starts new cycle at one');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT count(*) FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id WHERE p.nome_normalizado='zz teste rpc senior topo' AND c.recebeu_promocao),0::bigint,'career-top cycle completion remains non-promotional after new cycle starts');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT count(*) FROM public.career_progression_events e JOIN public.colaboradores_perfis p ON p.id=e.colaborador_id WHERE p.nome_normalizado='zz teste rpc senior topo' AND e.event_type='career_cycle_completed'),1::bigint,'starting the next career-top cycle preserves the prior completion event');

INSERT INTO pgtap_assertion_output(line) SELECT throws_ok($call$SELECT public.sincronizar_progressao_planilha(
 jsonb_build_array(jsonb_build_object('nome_colaborador','ZZ TESTE RPC Rollback Teste','posicao','SDR','squad','Lobo','ativo',true)),
 jsonb_build_array(jsonb_build_object('nome_colaborador','ZZ TESTE RPC Rollback Teste','posicao','SDR','squad','Lobo','competencia','2026-01-01','meta_alcancada','Meta inválida','senioridade_informada','Júnior 1')),
 'zz_teste_rpc_pgtap')$call$,'22023','meta inválida para ZZ TESTE RPC Rollback Teste: Meta inválida','invalid goal rejects complete batch');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT count(*) FROM public.colaboradores_perfis WHERE nome_normalizado='zz teste rpc rollback teste'),0::bigint,'invalid batch rolls back profile insertion');
INSERT INTO pgtap_assertion_output(line) SELECT throws_ok($call$SELECT public.sincronizar_progressao_planilha(
 jsonb_build_array(jsonb_build_object('nome_colaborador','ZZ TESTE RPC Senioridade Ruim','posicao','SDR','squad','Lobo','ativo',true)),
 jsonb_build_array(jsonb_build_object('nome_colaborador','ZZ TESTE RPC Senioridade Ruim','posicao','SDR','squad','Lobo','competencia','2026-01-01','meta_alcancada','Meta 3','senioridade_informada','SDR IV')),
 'zz_teste_rpc_pgtap')$call$,'22023','senioridade inválida para ZZ TESTE RPC Senioridade Ruim: SDR IV','invalid seniority rejects batch');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT count(*) FROM public.colaboradores_perfis WHERE nome_normalizado='zz teste rpc senioridade ruim'),0::bigint,'invalid seniority batch writes nothing');
INSERT INTO pgtap_assertion_output(line) SELECT throws_ok($$SELECT public.sincronizar_progressao_planilha('{}'::jsonb,'[]'::jsonb,'zz_teste_rpc_pgtap')$$,'22023','p_perfis deve ser um array JSON','non-array profiles are rejected');
INSERT INTO pgtap_assertion_output(line) SELECT throws_ok($call$SELECT public.sincronizar_progressao_planilha(
 jsonb_build_array(jsonb_build_object('nome_colaborador','ZZ TESTE RPC Duplicado Lote','posicao','SDR','squad','Lobo','ativo',true)),
 jsonb_build_array(
  jsonb_build_object('nome_colaborador','ZZ TESTE RPC Duplicado Lote','posicao','SDR','squad','Lobo','competencia','2026-01-01','meta_alcancada','Meta 1','senioridade_informada','Júnior 1'),
  jsonb_build_object('nome_colaborador',' zz teste rpc duplicado  lote ','posicao','SDR','squad','Lobo','competencia','2026-01-01','meta_alcancada','Meta 2','senioridade_informada','Júnior 1')),
 'zz_teste_rpc_pgtap')$call$,'22023','p_resultados contém colaborador/competência duplicado','ambiguous duplicate result batch is rejected');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT count(*) FROM public.colaboradores_perfis WHERE nome_normalizado='zz teste rpc duplicado lote'),0::bigint,'divergent duplicate results roll back the whole batch');

-- Apps Script sends squad "Saiu" for inactive people; it is a valid explicit value.
DELETE FROM sync_response;
INSERT INTO sync_response SELECT public.sincronizar_progressao_planilha(
  jsonb_build_array(jsonb_build_object('nome_colaborador','ZZ TESTE RPC Perfil Saiu','posicao','SDR','squad','Saiu','ativo',false)),
  jsonb_build_array(jsonb_build_object('nome_colaborador','ZZ TESTE RPC Perfil Saiu','posicao','SDR','squad','Saiu','competencia','2026-01-01','meta_alcancada','Meta 1','senioridade_informada','Júnior 1')),
  'zz_teste_rpc_pgtap');
INSERT INTO pgtap_assertion_output(line) SELECT ok((SELECT (payload->>'ok')::boolean FROM sync_response),'squad Saiu is accepted by RPC');
INSERT INTO pgtap_assertion_output(line) SELECT isnt((SELECT ativo FROM public.colaboradores_perfis WHERE nome_normalizado='zz teste rpc perfil saiu'),true,'squad Saiu profile remains inactive');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT squad_atual FROM public.colaboradores_perfis WHERE nome_normalizado='zz teste rpc perfil saiu'),'Saiu','current squad stores Saiu explicitly');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT c.squad FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id WHERE p.nome_normalizado='zz teste rpc perfil saiu'),'Saiu','new history stores squad Saiu');

-- Neutral absence may precede the first valid informed seniority.
SELECT public.sincronizar_progressao_planilha(
  jsonb_build_array(jsonb_build_object('nome_colaborador','ZZ TESTE RPC Ausência Bootstrap','posicao','SDR','squad','Lobo','ativo',true)),
  jsonb_build_array(
    jsonb_build_object('nome_colaborador','ZZ TESTE RPC Ausência Bootstrap','posicao','SDR','squad','Lobo','competencia','2026-01-01','meta_alcancada','Sem presença','senioridade_informada',NULL),
    jsonb_build_object('nome_colaborador','ZZ TESTE RPC Ausência Bootstrap','posicao','SDR','squad','Lobo','competencia','2026-02-01','meta_alcancada','Meta 3','senioridade_informada','Júnior 1'),
    jsonb_build_object('nome_colaborador','ZZ TESTE RPC Ausência Bootstrap','posicao','SDR','squad','Lobo','competencia','2026-03-01','meta_alcancada','Sem presença','senioridade_informada',NULL)),
  'zz_teste_rpc_pgtap');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT c.senioridade_informada FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id WHERE p.nome_normalizado='zz teste rpc ausência bootstrap' AND c.competencia=date '2026-01-01'),NULL,'Sem presença preserves null informed seniority');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT c.senioridade FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id WHERE p.nome_normalizado='zz teste rpc ausência bootstrap' AND c.competencia=date '2026-01-01'),'Júnior 1','neutral month uses first later valid bootstrap level');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT senioridade_atual FROM public.colaboradores_perfis WHERE nome_normalizado='zz teste rpc ausência bootstrap'),'Júnior 1','Sem presença does not change seniority');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT progresso_meta3 FROM public.colaboradores_perfis WHERE nome_normalizado='zz teste rpc ausência bootstrap'),1,'Sem presença preserves progress before later Meta 3');

-- Later informed levels are authoritative and begin a new level cycle.
SELECT public.sincronizar_progressao_planilha(
  jsonb_build_array(jsonb_build_object('nome_colaborador','ZZ TESTE RPC Bootstrap Cronológico','posicao','SDR','squad','Lobo','ativo',true)),
  jsonb_build_array(
    jsonb_build_object('nome_colaborador','ZZ TESTE RPC Bootstrap Cronológico','posicao','SDR','squad','Lobo','competencia','2026-01-01','meta_alcancada','Meta 3','senioridade_informada','Júnior 1'),
    jsonb_build_object('nome_colaborador','ZZ TESTE RPC Bootstrap Cronológico','posicao','SDR','squad','Lobo','competencia','2026-02-01','meta_alcancada','Meta 3','senioridade_informada','Sênior 3'),
    jsonb_build_object('nome_colaborador','ZZ TESTE RPC Bootstrap Cronológico','posicao','SDR','squad','Lobo','competencia','2026-03-01','meta_alcancada','Meta 3','senioridade_informada','Sênior 3')),
  'zz_teste_rpc_pgtap');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT senioridade_atual FROM public.colaboradores_perfis WHERE nome_normalizado='zz teste rpc bootstrap cronológico'),'Sênior 3','latest informed seniority becomes current');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT c.senioridade FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id WHERE p.nome_normalizado='zz teste rpc bootstrap cronológico' AND c.competencia=date '2026-03-01'),'Sênior 3','competence stores its authoritative seniority');
INSERT INTO pgtap_assertion_output(line) SELECT isnt((SELECT c.recebeu_promocao FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id WHERE p.nome_normalizado='zz teste rpc bootstrap cronológico' AND c.competencia=date '2026-03-01'),true,'two Meta 3 in the new level do not promote');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT progresso_meta3 FROM public.colaboradores_perfis WHERE nome_normalizado='zz teste rpc bootstrap cronológico'),2,'level change resets before evaluating its first Meta 3');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT c.senioridade_informada FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id WHERE p.nome_normalizado='zz teste rpc bootstrap cronológico' AND c.competencia=date '2026-03-01'),'Sênior 3','authoritative informed seniority remains auditable');

INSERT INTO pgtap_assertion_output(line) SELECT throws_ok($call$SELECT public.sincronizar_progressao_planilha(
 jsonb_build_array(
  jsonb_build_object('nome_colaborador','ZZ TESTE RPC Perfil Duplicado','posicao','SDR','squad','Lobo','ativo',true),
  jsonb_build_object('nome_colaborador',' zz teste rpc perfil   duplicado ','posicao','SDR','squad','Lobo','ativo',true)),
 jsonb_build_array(jsonb_build_object('nome_colaborador','ZZ TESTE RPC Perfil Duplicado','posicao','SDR','squad','Lobo','competencia','2026-01-01','meta_alcancada','Meta 1','senioridade_informada','Júnior 1')),
 'zz_teste_rpc_pgtap')$call$,'22023','p_perfis contém nomes equivalentes duplicados','normalized duplicate profiles are rejected atomically');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT count(*) FROM public.colaboradores_perfis WHERE nome_normalizado='zz teste rpc perfil duplicado'),0::bigint,'duplicate profiles write nothing');

INSERT INTO pgtap_assertion_output(line) SELECT throws_ok($call$SELECT public.sincronizar_progressao_planilha(
 jsonb_build_array(jsonb_build_object('nome_colaborador','ZZ TESTE RPC Resultado Idêntico','posicao','SDR','squad','Lobo','ativo',true)),
 jsonb_build_array(
  jsonb_build_object('nome_colaborador','ZZ TESTE RPC Resultado Idêntico','posicao','SDR','squad','Lobo','competencia','2026-01-01','meta_alcancada','Meta 1','senioridade_informada','Júnior 1'),
  jsonb_build_object('nome_colaborador',' zz teste rpc resultado  idêntico ','posicao','SDR','squad','Lobo','competencia','2026-01-01','meta_alcancada','Meta 1','senioridade_informada','Júnior 1')),
 'zz_teste_rpc_pgtap')$call$,'22023','p_resultados contém colaborador/competência duplicado','identical duplicate results are rejected atomically');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT count(*) FROM public.colaboradores_perfis WHERE nome_normalizado='zz teste rpc resultado idêntico'),0::bigint,'identical duplicate results write nothing');

INSERT INTO pgtap_assertion_output(line) SELECT isnt(has_function_privilege('anon','public.sincronizar_progressao_planilha(jsonb,jsonb,text)','EXECUTE'),true,'anon cannot execute sync RPC');
INSERT INTO pgtap_assertion_output(line) SELECT isnt(has_function_privilege('authenticated','public.sincronizar_progressao_planilha(jsonb,jsonb,text)','EXECUTE'),true,'authenticated cannot execute sync RPC');
INSERT INTO pgtap_assertion_output(line) SELECT ok(has_function_privilege('service_role','public.sincronizar_progressao_planilha(jsonb,jsonb,text)','EXECUTE'),'service_role can execute sync RPC');

-- Production acceptance: nominal corrections and operational cardinality.
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT posicao_atual FROM public.colaboradores_perfis WHERE nome_normalizado=public.normalize_career_name('Luan Nicolas Sinesio Crisostomo')),'Closer','Luan is Closer');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT senioridade_atual FROM public.colaboradores_perfis WHERE nome_normalizado=public.normalize_career_name('Luan Nicolas Sinesio Crisostomo')),'Júnior 3','Luan is Júnior 3');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT progresso_meta3 FROM public.colaboradores_perfis WHERE nome_normalizado=public.normalize_career_name('Luan Nicolas Sinesio Crisostomo')),1,'Luan uses only current authoritative cycle');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT posicao_atual FROM public.colaboradores_perfis WHERE nome_normalizado=public.normalize_career_name('João Paulo Maciel Sousa')),'Closer','João Paulo is Closer');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT senioridade_atual FROM public.colaboradores_perfis WHERE nome_normalizado=public.normalize_career_name('João Paulo Maciel Sousa')),'Júnior 1','João Paulo is Júnior 1');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT progresso_meta3 FROM public.colaboradores_perfis WHERE nome_normalizado=public.normalize_career_name('João Paulo Maciel Sousa')),0,'João Paulo current cycle is zero');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT posicao_atual FROM public.colaboradores_perfis WHERE nome_normalizado=public.normalize_career_name('Gustavo Duarte Pinheiro Silva')),'Closer','Gustavo is Closer');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT senioridade_atual FROM public.colaboradores_perfis WHERE nome_normalizado=public.normalize_career_name('Gustavo Duarte Pinheiro Silva')),'Júnior 3','Gustavo is Júnior 3');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT progresso_meta3 FROM public.colaboradores_perfis WHERE nome_normalizado=public.normalize_career_name('Gustavo Duarte Pinheiro Silva')),1,'Gustavo current cycle is one');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT posicao_atual FROM public.colaboradores_perfis WHERE nome_normalizado=public.normalize_career_name('Leandro Dos Santos Pereira')),'Closer','Leandro is Closer');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT senioridade_atual FROM public.colaboradores_perfis WHERE nome_normalizado=public.normalize_career_name('Leandro Dos Santos Pereira')),'Pleno 1','Leandro is Pleno 1');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT progresso_meta3 FROM public.colaboradores_perfis WHERE nome_normalizado=public.normalize_career_name('Leandro Dos Santos Pereira')),1,'Leandro current cycle is one');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT count(*) FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id WHERE p.nome_normalizado=public.normalize_career_name('João Paulo Maciel Sousa') AND c.competencia<date '2026-06-01' AND c.posicao='SDR'),5::bigint,'João preserves five SDR competencies');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT count(*) FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id WHERE p.nome_normalizado=public.normalize_career_name('João Paulo Maciel Sousa') AND c.competencia>=date '2026-06-01' AND c.posicao='Closer'),3::bigint,'João starts Closer in June');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT count(*) FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id WHERE p.nome_normalizado=public.normalize_career_name('Miguel Carneiro Nunes') AND c.competencia<=date '2026-06-01' AND c.posicao='SDR'),6::bigint,'Miguel SDR history remains preserved');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT count(*) FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id WHERE p.nome_normalizado=public.normalize_career_name('Tatyanna Lima de Freitas') AND c.competencia<=date '2026-06-01' AND c.posicao='SDR'),6::bigint,'Taty SDR history remains preserved');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT posicao_atual FROM public.colaboradores_perfis WHERE nome_normalizado=public.normalize_career_name('Gabrielly de Oliveira Medeiros')),'Parcerias','Gabrielly is outside SDR and Closer');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT count(*) FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id WHERE p.nome_normalizado=public.normalize_career_name('Gabrielly de Oliveira Medeiros')),8::bigint,'Gabrielly history is preserved');
INSERT INTO pgtap_assertion_output(line) SELECT ok((SELECT ativo AND posicao_atual IN ('SDR','Closer') AND coalesce(public.normalize_career_name(squad_atual),'')<>'saiu' FROM public.colaboradores_perfis WHERE nome_normalizado=public.normalize_career_name('Cleber Rodrigues Souza')),'Cleber remains operationally active');
INSERT INTO pgtap_assertion_output(line) SELECT is((SELECT count(DISTINCT p.id) FROM public.colaboradores_perfis p JOIN public.colaboradores c ON c.colaborador_id=p.id WHERE p.ativo AND p.posicao_atual IN ('SDR','Closer') AND coalesce(public.normalize_career_name(p.squad_atual),'')<>'saiu'),(SELECT count(*) FROM public.colaboradores_perfis p WHERE p.ativo AND p.posicao_atual IN ('SDR','Closer') AND coalesce(public.normalize_career_name(p.squad_atual),'')<>'saiu'),'monthly join does not multiply operational people');

INSERT INTO pgtap_finish_output SELECT * FROM finish(true);

SELECT
  format('1..%s',extensions._currtest()) AS plan,
  extensions._currtest() AS executed,
  extensions._currtest()-extensions.num_failed() AS passed,
  extensions.num_failed() AS failed,
  (SELECT jsonb_agg(line ORDER BY sequence) FROM pgtap_assertion_output
    WHERE line LIKE 'ok %') AS ok_lines,
  coalesce((SELECT jsonb_agg(line ORDER BY sequence) FROM pgtap_assertion_output
    WHERE line LIKE 'not ok %'),'[]'::jsonb) AS not_ok_lines,
  coalesce((SELECT jsonb_agg(line ORDER BY line) FROM pgtap_finish_output),'[]'::jsonb) AS diagnostics,
  extensions.num_failed()=0 AND extensions._currtest()=131 AS ok;
ROLLBACK;
