-- Terminal leadership behavior through the same public RPC used by Apps Script.
-- All fixtures are rolled back.
BEGIN;

DO $test$
DECLARE
  sdr_name text := 'ZZ LIDERANCA SDR';
  closer_name text := 'ZZ LIDERANCA CLOSER';
  bonus_name text := 'ZZ LIDERANCA BONUS';
  sdr_id uuid;
  closer_id uuid;
  bonus_id uuid;
  snapshot_one jsonb;
  snapshot_two jsonb;
  profile_updated_at timestamptz;
  event_created_at timestamptz;
  response jsonb;
BEGIN
  response:=public.sincronizar_progressao_planilha(
    jsonb_build_array(jsonb_build_object(
      'nome_colaborador',sdr_name,'posicao','Liderança de SDRs',
      'squad','Águia','jornada','Ativo','ativo',true
    )),
    jsonb_build_array(
      jsonb_build_object('nome_colaborador',sdr_name,'posicao','SDR','squad','Águia','competencia','2026-06-01','meta_alcancada','Meta 3','senioridade_informada','Júnior 1'),
      jsonb_build_object('nome_colaborador',sdr_name,'posicao','SDR','squad','Águia','competencia','2026-07-01','meta_alcancada','Meta 3','senioridade_informada','Júnior 1'),
      jsonb_build_object('nome_colaborador',sdr_name,'posicao','Liderança de SDRs','squad','Águia','competencia','2026-08-01','meta_alcancada','Meta 3 (Liderança de SDRs)','senioridade_informada','Júnior 1'),
      jsonb_build_object('nome_colaborador',sdr_name,'posicao','Liderança de SDRs','squad','Sem squad','competencia','2026-09-01','meta_alcancada','Meta 2 (Liderança de SDRs)','senioridade_informada','Júnior 3')
    ),'leadership_test'
  );
  IF coalesce((response->>'ok')::boolean,false) IS NOT TRUE THEN
    RAISE EXCEPTION 'leadership SDR RPC failed: %',response;
  END IF;
  SELECT id INTO STRICT sdr_id FROM public.colaboradores_perfis
  WHERE nome_normalizado=public.normalize_career_name(sdr_name);
  IF NOT EXISTS(
    SELECT 1 FROM public.colaboradores_perfis WHERE id=sdr_id
      AND posicao_atual='Liderança de SDRs' AND senioridade_atual='Júnior 1'
      AND progresso_meta3=0 AND progresso_meta2=0 AND progresso_ciclo=0
      AND bonificacao_sdr=0 AND streak_meta3_bonificacao=0
  ) THEN RAISE EXCEPTION 'SDR leadership terminal state is incorrect'; END IF;
  IF (SELECT count(*) FROM public.career_progression_events
      WHERE colaborador_id=sdr_id AND event_type='role_promotion' AND competencia='2026-08-01')<>1 THEN
    RAISE EXCEPTION 'SDR leadership role event is missing or duplicated';
  END IF;
  IF EXISTS(SELECT 1 FROM public.colaboradores WHERE colaborador_id=sdr_id AND competencia>='2026-08-01' AND recebeu_promocao) THEN
    RAISE EXCEPTION 'leadership goal caused a seniority promotion';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM public.colaboradores WHERE colaborador_id=sdr_id AND competencia='2026-08-01'
      AND posicao='Liderança de SDRs' AND meta_alcancada='Meta 3' AND senioridade='Júnior 1') THEN
    RAISE EXCEPTION 'leadership historical result was not preserved canonically';
  END IF;

  response:=public.sincronizar_progressao_planilha(
    jsonb_build_array(jsonb_build_object('nome_colaborador',closer_name,'posicao','Liderança de Closers','squad','Gorila','jornada','Ativo','ativo',true)),
    jsonb_build_array(
      jsonb_build_object('nome_colaborador',closer_name,'posicao','Closer','squad','Gorila','competencia','2026-06-01','meta_alcancada','Meta 3','senioridade_informada','Pleno 2'),
      jsonb_build_object('nome_colaborador',closer_name,'posicao','Closer','squad','Gorila','competencia','2026-07-01','meta_alcancada','Meta 3','senioridade_informada','Pleno 2'),
      jsonb_build_object('nome_colaborador',closer_name,'posicao','Liderança de Closers','squad','Gorila','competencia','2026-08-01','meta_alcancada','Meta 2 (Liderança de Closers)','senioridade_informada','Pleno 2'),
      jsonb_build_object('nome_colaborador',closer_name,'posicao','Liderança de Closers','squad','Gorila','competencia','2026-09-01','meta_alcancada','Meta não definida','senioridade_informada','Pleno 2')
    ),'leadership_test'
  );
  SELECT id INTO STRICT closer_id FROM public.colaboradores_perfis
  WHERE nome_normalizado=public.normalize_career_name(closer_name);
  IF NOT EXISTS(SELECT 1 FROM public.colaboradores_perfis WHERE id=closer_id
      AND senioridade_atual='Pleno 2' AND progresso_ciclo=0 AND progresso_meta3=0 AND progresso_meta2=0) THEN
    RAISE EXCEPTION 'Closer leadership terminal state is incorrect';
  END IF;
  IF (SELECT count(*) FROM public.career_progression_events
      WHERE colaborador_id=closer_id AND event_type='role_promotion' AND competencia='2026-08-01')<>1 THEN
    RAISE EXCEPTION 'Closer leadership role event is missing or duplicated';
  END IF;
  IF EXISTS(SELECT 1 FROM public.career_progression_events
      WHERE colaborador_id=closer_id AND event_type='role_promotion' AND competencia='2026-09-01') THEN
    RAISE EXCEPTION 'continued leadership created a duplicate role event';
  END IF;

  response:=public.sincronizar_progressao_planilha(
    jsonb_build_array(jsonb_build_object('nome_colaborador',bonus_name,'posicao','Liderança de SDRs','squad','Lobo','jornada','Ativo','ativo',true)),
    jsonb_build_array(
      jsonb_build_object('nome_colaborador',bonus_name,'posicao','SDR','squad','Lobo','competencia','2026-06-01','meta_alcancada','Meta 3','senioridade_informada','Júnior 1'),
      jsonb_build_object('nome_colaborador',bonus_name,'posicao','SDR','squad','Lobo','competencia','2026-07-01','meta_alcancada','Meta 3','senioridade_informada','Júnior 1'),
      jsonb_build_object('nome_colaborador',bonus_name,'posicao','SDR','squad','Lobo','competencia','2026-08-01','meta_alcancada','Meta 3','senioridade_informada','Júnior 1'),
      jsonb_build_object('nome_colaborador',bonus_name,'posicao','Liderança de SDRs','squad','Lobo','competencia','2026-09-01','meta_alcancada','Meta 1 (Liderança de SDRs)','senioridade_informada','Júnior 2')
    ),'leadership_test'
  );
  SELECT id INTO STRICT bonus_id FROM public.colaboradores_perfis
  WHERE nome_normalizado=public.normalize_career_name(bonus_name);
  IF NOT EXISTS(SELECT 1 FROM public.colaboradores_perfis WHERE id=bonus_id
      AND senioridade_atual='Júnior 2' AND progresso_ciclo=0
      AND bonificacao_sdr=0 AND streak_meta3_bonificacao=0) THEN
    RAISE EXCEPTION 'leadership did not terminate the existing SDR bonus state';
  END IF;

  -- Exact replay must not duplicate events or touch timestamps.
  SELECT updated_at INTO profile_updated_at FROM public.colaboradores_perfis WHERE id=sdr_id;
  SELECT created_at INTO event_created_at FROM public.career_progression_events
  WHERE colaborador_id=sdr_id AND competencia='2026-08-01' AND event_type='role_promotion';
  SELECT jsonb_build_object(
    'profile',(SELECT to_jsonb(p) FROM (SELECT senioridade_atual,progresso_meta3,progresso_meta2,progresso_ciclo,bonificacao_sdr,streak_meta3_bonificacao FROM public.colaboradores_perfis WHERE id=sdr_id) p),
    'results',(SELECT jsonb_agg(to_jsonb(r) ORDER BY competencia) FROM (SELECT competencia,posicao,meta_alcancada,senioridade,recebeu_promocao FROM public.colaboradores WHERE colaborador_id=sdr_id) r),
    'events',(SELECT jsonb_agg(to_jsonb(e) ORDER BY competencia,event_type) FROM (SELECT competencia,event_type,senioridade,recebeu_promocao FROM public.career_progression_events WHERE colaborador_id=sdr_id) e)
  ) INTO snapshot_one;
  PERFORM public.recalcular_progressao_colaborador(sdr_id);
  SELECT jsonb_build_object(
    'profile',(SELECT to_jsonb(p) FROM (SELECT senioridade_atual,progresso_meta3,progresso_meta2,progresso_ciclo,bonificacao_sdr,streak_meta3_bonificacao FROM public.colaboradores_perfis WHERE id=sdr_id) p),
    'results',(SELECT jsonb_agg(to_jsonb(r) ORDER BY competencia) FROM (SELECT competencia,posicao,meta_alcancada,senioridade,recebeu_promocao FROM public.colaboradores WHERE colaborador_id=sdr_id) r),
    'events',(SELECT jsonb_agg(to_jsonb(e) ORDER BY competencia,event_type) FROM (SELECT competencia,event_type,senioridade,recebeu_promocao FROM public.career_progression_events WHERE colaborador_id=sdr_id) e)
  ) INTO snapshot_two;
  IF snapshot_one IS DISTINCT FROM snapshot_two THEN RAISE EXCEPTION 'leadership replay is not functionally idempotent'; END IF;
  IF profile_updated_at IS DISTINCT FROM (SELECT updated_at FROM public.colaboradores_perfis WHERE id=sdr_id)
     OR event_created_at IS DISTINCT FROM (SELECT created_at FROM public.career_progression_events WHERE colaborador_id=sdr_id AND competencia='2026-08-01' AND event_type='role_promotion') THEN
    RAISE EXCEPTION 'leadership replay changed timestamps without a functional change';
  END IF;

  -- A leadership suffix cannot be detached from its matching position.
  BEGIN
    PERFORM public.sincronizar_progressao_planilha(
      jsonb_build_array(jsonb_build_object('nome_colaborador','ZZ SUFFIX INVALIDO','posicao','SDR','squad','Lobo','jornada','Ativo','ativo',true)),
      jsonb_build_array(jsonb_build_object('nome_colaborador','ZZ SUFFIX INVALIDO','posicao','SDR','squad','Lobo','competencia','2026-08-01','meta_alcancada','Meta 3 (Liderança de SDRs)','senioridade_informada','Júnior 1')),
      'leadership_test'
    );
    RAISE EXCEPTION 'mismatched leadership suffix was accepted';
  EXCEPTION WHEN sqlstate '22023' THEN NULL;
  END;

END
$test$;

ROLLBACK;
