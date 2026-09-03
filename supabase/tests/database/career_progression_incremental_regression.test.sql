-- Regression for the production failure reported for Ana Raquel Alves Rodrigues.
-- The production identity is not used: all rows are transactional fixtures.
BEGIN;

DO $test$
DECLARE
  ana_id uuid := gen_random_uuid();
  peer_id uuid := gen_random_uuid();
  response jsonb;
  first_profile_updated_at timestamptz;
  first_august_updated_at timestamptz;
  first_state jsonb;
  second_state jsonb;
  profiles_payload jsonb := jsonb_build_array(
    jsonb_build_object(
      'nome_colaborador','ZZ REGRESSAO Ana Incremental',
      'posicao','SDR','squad','Lobo','jornada','Ativo','ativo',true
    ),
    jsonb_build_object(
      'nome_colaborador','ZZ REGRESSAO Colega Lote',
      'posicao','SDR','squad','Águia','jornada','Ativo','ativo',true
    )
  );
  results_payload jsonb := jsonb_build_array(
    jsonb_build_object(
      'nome_colaborador','ZZ REGRESSAO Ana Incremental',
      'posicao','SDR','squad','Lobo','competencia','2026-08-01',
      'meta_alcancada','Meta 3','senioridade_informada','Júnior 1'
    ),
    jsonb_build_object(
      'nome_colaborador','ZZ REGRESSAO Colega Lote',
      'posicao','SDR','squad','Águia','competencia','2026-08-01',
      'meta_alcancada','Sem presença','senioridade_informada','Pleno 1'
    )
  );
BEGIN
  INSERT INTO public.colaboradores_perfis(
    id,nome_colaborador,nome_normalizado,posicao_atual,squad_atual,
    senioridade_atual,progresso_meta3,progresso_meta2,progresso_ciclo,
    bonificacao_sdr,streak_meta3_bonificacao,jornada_atual,ativo
  ) VALUES
    (ana_id,'ZZ REGRESSAO Ana Incremental',public.normalize_career_name('ZZ REGRESSAO Ana Incremental'),
     'SDR','Lobo','Júnior 1',1,1,2,0,1,'Ativo',true),
    (peer_id,'ZZ REGRESSAO Colega Lote',public.normalize_career_name('ZZ REGRESSAO Colega Lote'),
     'SDR','Águia','Pleno 1',0,0,0,0,0,'Ativo',true);

  -- Ana's real chronology: May M3 is outside the rule epoch; June M2 and July
  -- M3 produce the valid pre-incremental state 1 M3 + 1 M2 = cycle 2.
  INSERT INTO public.colaboradores(
    colaborador_id,nome_colaborador,competencia,mes_referencia,posicao,squad,
    senioridade,senioridade_informada,meta_alcancada,recebeu_promocao,origem
  ) VALUES
    (ana_id,'ZZ REGRESSAO Ana Incremental','2026-05-01','2026-05','SDR','Lobo','Júnior 1','Júnior 1','Meta 3',false,'fixture'),
    (ana_id,'ZZ REGRESSAO Ana Incremental','2026-06-01','2026-06','SDR','Lobo','Júnior 1','Júnior 1','Meta 2',false,'fixture'),
    (ana_id,'ZZ REGRESSAO Ana Incremental','2026-07-01','2026-07','SDR','Lobo','Júnior 1','Júnior 1','Meta 3',false,'fixture'),
    (ana_id,'ZZ REGRESSAO Ana Incremental','2026-08-01','2026-08','SDR','Lobo','Júnior 1','Júnior 1','Sem presença',false,'fixture'),
    (peer_id,'ZZ REGRESSAO Colega Lote','2026-06-01','2026-06','SDR','Águia','Pleno 1','Pleno 1','Sem presença',false,'fixture'),
    (peer_id,'ZZ REGRESSAO Colega Lote','2026-07-01','2026-07','SDR','Águia','Pleno 1','Pleno 1','Sem presença',false,'fixture'),
    (peer_id,'ZZ REGRESSAO Colega Lote','2026-08-01','2026-08','SDR','Águia','Pleno 1','Pleno 1','Sem presença',false,'google_sheets');

  response := public.sincronizar_progressao_planilha(
    profiles_payload,results_payload,'google_sheets'
  );
  IF coalesce((response->>'ok')::boolean,false) IS NOT TRUE THEN
    RAISE EXCEPTION 'full incremental RPC did not report success: %',response;
  END IF;
  IF NOT EXISTS(
    SELECT 1 FROM public.colaboradores_perfis
    WHERE id=ana_id
      AND senioridade_atual='Júnior 2'
      AND progresso_meta3=0 AND progresso_meta2=0 AND progresso_ciclo=0
      AND bonificacao_sdr=0 AND streak_meta3_bonificacao=2
      AND progresso_ciclo=progresso_meta3+progresso_meta2
  ) THEN
    RAISE EXCEPTION 'Ana-like final state differs from the reference machine';
  END IF;
  IF EXISTS(
    SELECT 1 FROM public.colaboradores_perfis
    WHERE progresso_ciclo<>progresso_meta3+progresso_meta2
  ) THEN
    RAISE EXCEPTION 'incremental batch left a cycle constraint violation';
  END IF;

  SELECT updated_at INTO first_profile_updated_at
  FROM public.colaboradores_perfis WHERE id=ana_id;
  SELECT updated_at INTO first_august_updated_at
  FROM public.colaboradores WHERE colaborador_id=ana_id AND competencia='2026-08-01';
  SELECT jsonb_build_object(
    'profile',(SELECT to_jsonb(x) FROM (
      SELECT senioridade_atual,progresso_meta3,progresso_meta2,progresso_ciclo,
             bonificacao_sdr,streak_meta3_bonificacao
      FROM public.colaboradores_perfis WHERE id=ana_id
    ) x),
    'results',(SELECT jsonb_agg(to_jsonb(x) ORDER BY competencia,id) FROM (
      SELECT id,competencia,posicao,meta_alcancada,senioridade,
             senioridade_informada,recebeu_promocao,origem
      FROM public.colaboradores WHERE colaborador_id=ana_id
    ) x)
  ) INTO first_state;

  response := public.sincronizar_progressao_planilha(
    profiles_payload,results_payload,'google_sheets'
  );
  IF coalesce((response->>'ok')::boolean,false) IS NOT TRUE THEN
    RAISE EXCEPTION 'second full incremental RPC did not report success: %',response;
  END IF;
  SELECT jsonb_build_object(
    'profile',(SELECT to_jsonb(x) FROM (
      SELECT senioridade_atual,progresso_meta3,progresso_meta2,progresso_ciclo,
             bonificacao_sdr,streak_meta3_bonificacao
      FROM public.colaboradores_perfis WHERE id=ana_id
    ) x),
    'results',(SELECT jsonb_agg(to_jsonb(x) ORDER BY competencia,id) FROM (
      SELECT id,competencia,posicao,meta_alcancada,senioridade,
             senioridade_informada,recebeu_promocao,origem
      FROM public.colaboradores WHERE colaborador_id=ana_id
    ) x)
  ) INTO second_state;

  IF first_state IS DISTINCT FROM second_state THEN
    RAISE EXCEPTION 'second full incremental RPC was not functionally idempotent';
  END IF;
  IF first_profile_updated_at IS DISTINCT FROM (
    SELECT updated_at FROM public.colaboradores_perfis WHERE id=ana_id
  ) OR first_august_updated_at IS DISTINCT FROM (
    SELECT updated_at FROM public.colaboradores
    WHERE colaborador_id=ana_id AND competencia='2026-08-01'
  ) THEN
    RAISE EXCEPTION 'second full incremental RPC changed updated_at without a functional change';
  END IF;
END
$test$;

ROLLBACK;
