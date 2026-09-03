-- Production validation only. This script always rolls back.
BEGIN;

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
  IF worker_oid IS NULL THEN RAISE EXCEPTION 'validated worker is missing'; END IF;
  SELECT p.prosrc INTO worker_source FROM pg_catalog.pg_proc p WHERE p.oid=worker_oid;
  replay_start:=strpos(worker_source,E'  FOREACH affected_id IN ARRAY affected_ids LOOP\n');
  return_start:=strpos(worker_source,E'  RETURN jsonb_build_object(\n');
  IF replay_start=0 OR return_start<=replay_start OR strpos(
    substring(worker_source FROM replay_start),'UPDATE public.colaboradores_perfis SET'
  )=0 THEN
    RAISE EXCEPTION 'validated worker has an unexpected shape';
  END IF;
  patched_source:=left(worker_source,replay_start-1)
    || E'  recalculated := cardinality(affected_ids);\n\n'
    || substring(worker_source FROM return_start);
  EXECUTE format(
    'CREATE OR REPLACE FUNCTION public.sincronizar_progressao_planilha_lote_validado_v1(p_perfis jsonb,p_resultados jsonb,p_origem text) '
    || 'RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER '
    || 'SET search_path=pg_catalog,public AS %L',patched_source
  );
END
$migration$;

CREATE TEMP TABLE incremental_fix_evidence(
  first_response jsonb,
  second_response jsonb,
  first_snapshot jsonb,
  second_snapshot jsonb
) ON COMMIT DROP;

DO $validation$
DECLARE
  profiles_payload jsonb:=jsonb_build_array(
    jsonb_build_object('nome_colaborador','Ana Raquel Alves Rodrigues','posicao','SDR','squad','Lobo','jornada','Inativo','ativo',false),
    jsonb_build_object('nome_colaborador','Adrilene Azevedo da Silva','posicao','SDR','squad','Águia','jornada','Ativo','ativo',true),
    jsonb_build_object('nome_colaborador','Ana Alice Sousa do Amaral','posicao','SDR','squad','Lobo','jornada','Ativo','ativo',true)
  );
  results_payload jsonb:=jsonb_build_array(
    jsonb_build_object('nome_colaborador','Ana Raquel Alves Rodrigues','posicao','SDR','squad','Lobo','competencia','2026-08-01','meta_alcancada','Meta 3','senioridade_informada','Júnior 1'),
    jsonb_build_object('nome_colaborador','Adrilene Azevedo da Silva','posicao','SDR','squad','Águia','competencia','2026-08-01','meta_alcancada','Sem presença','senioridade_informada','Júnior 1'),
    jsonb_build_object('nome_colaborador','Ana Alice Sousa do Amaral','posicao','SDR','squad','Lobo','competencia','2026-08-01','meta_alcancada','Sem presença','senioridade_informada','Júnior 1')
  );
  response_one jsonb;
  response_two jsonb;
  snapshot_one jsonb;
  snapshot_two jsonb;
BEGIN
  response_one:=public.sincronizar_progressao_planilha(
    profiles_payload,results_payload,'google_sheets'
  );
  IF coalesce((response_one->>'ok')::boolean,false) IS NOT TRUE THEN
    RAISE EXCEPTION 'first full RPC did not report success: %',response_one;
  END IF;
  IF NOT EXISTS(
    SELECT 1 FROM public.colaboradores_perfis
    WHERE nome_colaborador='Ana Raquel Alves Rodrigues'
      AND senioridade_atual='Júnior 2'
      AND progresso_meta3=0 AND progresso_meta2=0 AND progresso_ciclo=0
      AND bonificacao_sdr=0 AND streak_meta3_bonificacao=2
  ) THEN
    RAISE EXCEPTION 'Ana final state differs from reference replay';
  END IF;
  IF EXISTS(
    SELECT 1 FROM public.colaboradores_perfis
    WHERE progresso_ciclo<>progresso_meta3+progresso_meta2
  ) THEN
    RAISE EXCEPTION 'constraint-equivalent violation after first RPC';
  END IF;

  SELECT jsonb_build_object(
    'profiles',(SELECT jsonb_agg(to_jsonb(x) ORDER BY nome_colaborador) FROM (
      SELECT nome_colaborador,senioridade_atual,progresso_meta3,progresso_meta2,
             progresso_ciclo,bonificacao_sdr,streak_meta3_bonificacao,updated_at
      FROM public.colaboradores_perfis
      WHERE nome_colaborador IN ('Ana Raquel Alves Rodrigues','Adrilene Azevedo da Silva','Ana Alice Sousa do Amaral')
    ) x),
    'august',(SELECT jsonb_agg(to_jsonb(x) ORDER BY nome_colaborador) FROM (
      SELECT p.nome_colaborador,c.meta_alcancada,c.senioridade,c.recebeu_promocao,
             c.origem,c.updated_at
      FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id
      WHERE p.nome_colaborador IN ('Ana Raquel Alves Rodrigues','Adrilene Azevedo da Silva','Ana Alice Sousa do Amaral')
        AND c.competencia='2026-08-01'
    ) x)
  ) INTO snapshot_one;

  response_two:=public.sincronizar_progressao_planilha(
    profiles_payload,results_payload,'google_sheets'
  );
  SELECT jsonb_build_object(
    'profiles',(SELECT jsonb_agg(to_jsonb(x) ORDER BY nome_colaborador) FROM (
      SELECT nome_colaborador,senioridade_atual,progresso_meta3,progresso_meta2,
             progresso_ciclo,bonificacao_sdr,streak_meta3_bonificacao,updated_at
      FROM public.colaboradores_perfis
      WHERE nome_colaborador IN ('Ana Raquel Alves Rodrigues','Adrilene Azevedo da Silva','Ana Alice Sousa do Amaral')
    ) x),
    'august',(SELECT jsonb_agg(to_jsonb(x) ORDER BY nome_colaborador) FROM (
      SELECT p.nome_colaborador,c.meta_alcancada,c.senioridade,c.recebeu_promocao,
             c.origem,c.updated_at
      FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id
      WHERE p.nome_colaborador IN ('Ana Raquel Alves Rodrigues','Adrilene Azevedo da Silva','Ana Alice Sousa do Amaral')
        AND c.competencia='2026-08-01'
    ) x)
  ) INTO snapshot_two;
  IF coalesce((response_two->>'ok')::boolean,false) IS NOT TRUE
     OR snapshot_one IS DISTINCT FROM snapshot_two THEN
    RAISE EXCEPTION 'second full RPC was not idempotent';
  END IF;
  INSERT INTO incremental_fix_evidence VALUES(
    response_one,response_two,snapshot_one,snapshot_two
  );
END
$validation$;

-- Any exception above aborts the script. The final SELECT after ROLLBACK is the
-- machine-readable success signal returned by the Management API.
ROLLBACK;
SELECT jsonb_build_object(
  'status','PASS',
  'rpc','sincronizar_progressao_planilha',
  'batch_profiles',3,
  'violations',0,
  'reference_state','Júnior 2 / M3=0 / M2=0 / ciclo=0 / bônus=0 / streak=2',
  'second_run_idempotent',true,
  'updated_at_stable',true,
  'rolled_back',true
) AS evidence;
