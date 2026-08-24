-- Run after migrations. Fully transactional; creates no lasting data.
BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.seed_career_case(
  case_name text,
  goals text[],
  positions text[] DEFAULT NULL
) RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE person uuid := gen_random_uuid(); i integer; position_value text;
BEGIN
  INSERT INTO public.colaboradores_perfis(
    id,nome_colaborador,nome_normalizado,posicao_atual,squad_atual,senioridade_atual
  ) VALUES (
    person,case_name,public.normalize_career_name(case_name),
    coalesce(positions[array_length(goals,1)],'SDR'),'Teste','Júnior 1'
  );
  FOR i IN 1..array_length(goals,1) LOOP
    position_value:=coalesce(positions[i],'SDR');
    INSERT INTO public.colaboradores(
      colaborador_id,competencia,mes_referencia,nome_colaborador,posicao,squad,
      meta_alcancada,senioridade_informada,senioridade,recebeu_promocao,origem
    ) VALUES (
      person,(date '2026-06-01'+((i-1)||' months')::interval)::date,
      to_char(date '2026-06-01'+((i-1)||' months')::interval,'YYYY-MM'),
      case_name,position_value,'Teste',goals[i],'Júnior 1','Júnior 1',false,'test_v2'
    );
  END LOOP;
  PERFORM public.recalcular_progressao_colaborador(person);
  RETURN person;
END $$;

DO $$
DECLARE p uuid; snapshot jsonb;
BEGIN
  FOREACH p IN ARRAY ARRAY[
    pg_temp.seed_career_case('ZZ V2 M333',ARRAY['Meta 3','Meta 3','Meta 3']),
    pg_temp.seed_career_case('ZZ V2 M332',ARRAY['Meta 3','Meta 3','Meta 2']),
    pg_temp.seed_career_case('ZZ V2 M323',ARRAY['Meta 3','Meta 2','Meta 3']),
    pg_temp.seed_career_case('ZZ V2 M233',ARRAY['Meta 2','Meta 3','Meta 3'])
  ] LOOP
    IF NOT EXISTS(SELECT 1 FROM public.colaboradores_perfis WHERE id=p AND senioridade_atual='Júnior 2' AND progresso_ciclo=0) THEN
      RAISE EXCEPTION 'combinação válida não promoveu: %',p;
    END IF;
    IF (SELECT count(*) FROM public.colaboradores WHERE colaborador_id=p AND recebeu_promocao)<>1 THEN
      RAISE EXCEPTION 'promoção não foi materializada exatamente uma vez: %',p;
    END IF;
  END LOOP;

  FOREACH p IN ARRAY ARRAY[
    pg_temp.seed_career_case('ZZ V2 Reset 322',ARRAY['Meta 3','Meta 2','Meta 2']),
    pg_temp.seed_career_case('ZZ V2 Reset 232',ARRAY['Meta 2','Meta 3','Meta 2']),
    pg_temp.seed_career_case('ZZ V2 Reset 222',ARRAY['Meta 2','Meta 2','Meta 2'])
  ] LOOP
    IF NOT EXISTS(SELECT 1 FROM public.colaboradores_perfis WHERE id=p AND progresso_meta3=0 AND progresso_meta2=1 AND progresso_ciclo=1) THEN
      RAISE EXCEPTION 'segunda Meta 2 não preservou somente a âncora: %',p;
    END IF;
  END LOOP;

  p:=pg_temp.seed_career_case('ZZ V2 Reset M1',ARRAY['Meta 3','Meta 2','Meta 1','Meta 3']);
  IF NOT EXISTS(SELECT 1 FROM public.colaboradores_perfis WHERE id=p AND progresso_meta3=1 AND progresso_meta2=0) THEN
    RAISE EXCEPTION 'Meta 1 não resetou o ciclo';
  END IF;

  p:=pg_temp.seed_career_case('ZZ V2 Vazios',ARRAY['Meta 3','Sem presença','Meta 3','Nenhuma meta','Meta 2']);
  IF NOT EXISTS(SELECT 1 FROM public.colaboradores_perfis WHERE id=p AND senioridade_atual='Júnior 2') THEN
    RAISE EXCEPTION 'vazios alteraram o ciclo';
  END IF;

  p:=pg_temp.seed_career_case('ZZ V2 Bonus',ARRAY['Meta 3','Meta 3','Meta 3','Meta 2','Meta 2','Meta 3']);
  IF NOT EXISTS(SELECT 1 FROM public.colaboradores_perfis WHERE id=p AND bonificacao_sdr=40 AND streak_meta3_bonificacao=0) THEN
    RAISE EXCEPTION 'máquina 40 -> 30 -> 30 -> 40 divergiu';
  END IF;

  p:=pg_temp.seed_career_case('ZZ V2 Bonus Reset',ARRAY['Meta 3','Meta 3','Meta 3','Meta 1','Meta 3','Meta 3']);
  IF NOT EXISTS(SELECT 1 FROM public.colaboradores_perfis WHERE id=p AND bonificacao_sdr=0 AND streak_meta3_bonificacao=2) THEN
    RAISE EXCEPTION 'recuperação após Meta 1 ocorreu antes de três Meta 3';
  END IF;

  p:=pg_temp.seed_career_case('ZZ V2 Bonus Vazio',ARRAY['Meta 3','Sem presença','Meta 3','Nenhuma meta','Meta 3']);
  IF NOT EXISTS(SELECT 1 FROM public.colaboradores_perfis WHERE id=p AND bonificacao_sdr=40) THEN
    RAISE EXCEPTION 'vazios quebraram streak de bonificação';
  END IF;

  p:=pg_temp.seed_career_case('ZZ V2 Bonus Consecutiva 333',ARRAY['Meta 3','Meta 3','Meta 3']);
  IF NOT EXISTS(SELECT 1 FROM public.colaboradores_perfis WHERE id=p AND bonificacao_sdr=40) THEN
    RAISE EXCEPTION 'M3 M3 M3 não liberou 40%%';
  END IF;
  p:=pg_temp.seed_career_case('ZZ V2 Bonus Quebrada 33233',ARRAY['Meta 3','Meta 3','Meta 2','Meta 3','Meta 3']);
  IF NOT EXISTS(SELECT 1 FROM public.colaboradores_perfis WHERE id=p AND bonificacao_sdr=0 AND streak_meta3_bonificacao=2) THEN
    RAISE EXCEPTION 'M3 M3 M2 M3 M3 liberou bonificação indevidamente';
  END IF;
  p:=pg_temp.seed_career_case('ZZ V2 Bonus Reiniciada 332333',ARRAY['Meta 3','Meta 3','Meta 2','Meta 3','Meta 3','Meta 3']);
  IF NOT EXISTS(SELECT 1 FROM public.colaboradores_perfis WHERE id=p AND bonificacao_sdr=40 AND streak_meta3_bonificacao=0) THEN
    RAISE EXCEPTION 'M3 M3 M2 M3 M3 M3 não liberou 40%% na última M3';
  END IF;

  p:=pg_temp.seed_career_case('ZZ V2 Squad Histórico',ARRAY['Meta 3','Meta 2','Meta 3']);
  UPDATE public.colaboradores SET squad=CASE competencia
    WHEN date '2026-06-01' THEN 'Lobo' WHEN date '2026-07-01' THEN 'Lobo' ELSE 'Águia' END
  WHERE colaborador_id=p;
  UPDATE public.colaboradores_perfis SET squad_atual='Águia' WHERE id=p;
  PERFORM public.recalcular_progressao_colaborador(p);
  IF NOT EXISTS(SELECT 1 FROM public.colaboradores WHERE colaborador_id=p AND competencia=date '2026-06-01' AND squad='Lobo')
     OR NOT EXISTS(SELECT 1 FROM public.colaboradores WHERE colaborador_id=p AND competencia=date '2026-07-01' AND squad='Lobo')
     OR NOT EXISTS(SELECT 1 FROM public.colaboradores WHERE colaborador_id=p AND competencia=date '2026-08-01' AND squad='Águia') THEN
    RAISE EXCEPTION 'replay reescreveu squad histórico';
  END IF;

  p:=pg_temp.seed_career_case('ZZ V2 Closer',ARRAY['Meta 3','Meta 3','Meta 3'],ARRAY['SDR','Closer','Closer']);
  IF NOT EXISTS(SELECT 1 FROM public.colaboradores_perfis WHERE id=p AND progresso_meta3=1 AND progresso_meta2=0 AND bonificacao_sdr=0 AND streak_meta3_bonificacao=0) THEN
    RAISE EXCEPTION 'SDR -> Closer não zerou/ignorou a competência da transição';
  END IF;
  IF (SELECT count(*) FROM public.career_progression_events WHERE colaborador_id=p AND event_type='role_promotion')<>1 THEN
    RAISE EXCEPTION 'promoção de função não foi deduplicada';
  END IF;

  -- Historical correction must replay the future and repeated replay must be identical.
  p:=pg_temp.seed_career_case('ZZ V2 Correção',ARRAY['Meta 3','Meta 2','Meta 3']);
  UPDATE public.colaboradores SET meta_alcancada='Meta 1'
  WHERE colaborador_id=p AND competencia=date '2026-07-01';
  PERFORM public.recalcular_progressao_colaborador(p);
  IF NOT EXISTS(SELECT 1 FROM public.colaboradores_perfis WHERE id=p AND senioridade_atual='Júnior 1' AND progresso_meta3=1) THEN
    RAISE EXCEPTION 'correção histórica não recalculou o futuro';
  END IF;
  SELECT jsonb_build_object(
    'perfil',(SELECT to_jsonb(x) FROM (SELECT senioridade_atual,progresso_meta3,progresso_meta2,progresso_ciclo,bonificacao_sdr,streak_meta3_bonificacao,updated_at FROM public.colaboradores_perfis WHERE id=p) x),
    'resultados',(SELECT jsonb_agg(to_jsonb(x) ORDER BY competencia,id) FROM (SELECT id,competencia,meta_alcancada,senioridade,recebeu_promocao,squad,posicao,updated_at FROM public.colaboradores WHERE colaborador_id=p) x),
    'eventos',(SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY competencia,event_type,id),'[]'::jsonb) FROM (SELECT id,competencia,event_type,senioridade,recebeu_promocao,created_at FROM public.career_progression_events WHERE colaborador_id=p) x)
  ) INTO snapshot;
  PERFORM public.recalcular_progressao_colaborador(p);
  IF snapshot IS DISTINCT FROM (SELECT jsonb_build_object(
    'perfil',(SELECT to_jsonb(x) FROM (SELECT senioridade_atual,progresso_meta3,progresso_meta2,progresso_ciclo,bonificacao_sdr,streak_meta3_bonificacao,updated_at FROM public.colaboradores_perfis WHERE id=p) x),
    'resultados',(SELECT jsonb_agg(to_jsonb(x) ORDER BY competencia,id) FROM (SELECT id,competencia,meta_alcancada,senioridade,recebeu_promocao,squad,posicao,updated_at FROM public.colaboradores WHERE colaborador_id=p) x),
    'eventos',(SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY competencia,event_type,id),'[]'::jsonb) FROM (SELECT id,competencia,event_type,senioridade,recebeu_promocao,created_at FROM public.career_progression_events WHERE colaborador_id=p) x)
  )) THEN RAISE EXCEPTION 'segunda execução do replay produziu diferenças'; END IF;
END $$;

ROLLBACK;
