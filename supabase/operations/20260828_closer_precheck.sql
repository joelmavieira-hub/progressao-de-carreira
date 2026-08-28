SELECT jsonb_build_object(
  'profiles', (SELECT count(*) FROM public.colaboradores_perfis),
  'results', (SELECT count(*) FROM public.colaboradores),
  'events', (SELECT count(*) FROM public.career_progression_events),
  'duplicate_profiles', (SELECT count(*) FROM (SELECT nome_normalizado FROM public.colaboradores_perfis GROUP BY nome_normalizado HAVING count(*)>1) d),
  'duplicate_results', (SELECT count(*) FROM (SELECT colaborador_id,competencia FROM public.colaboradores GROUP BY colaborador_id,competencia HAVING count(*)>1) d),
  'duplicate_events', (SELECT count(*) FROM (SELECT colaborador_id,competencia,event_type FROM public.career_progression_events GROUP BY colaborador_id,competencia,event_type HAVING count(*)>1) d),
  'orphan_results', (SELECT count(*) FROM public.colaboradores r LEFT JOIN public.colaboradores_perfis p ON p.id=r.colaborador_id WHERE p.id IS NULL),
  'orphan_events', (SELECT count(*) FROM public.career_progression_events e LEFT JOIN public.colaboradores_perfis p ON p.id=e.colaborador_id WHERE p.id IS NULL),
  'null_competences', (SELECT count(*) FROM public.colaboradores WHERE competencia IS NULL),
  'invalid_profile_progress', (SELECT count(*) FROM public.colaboradores_perfis WHERE progresso_meta3 NOT BETWEEN 0 AND 2 OR progresso_meta2 NOT IN (0,1) OR progresso_ciclo<>progresso_meta3+progresso_meta2),
  'closer_with_bonus', (SELECT count(*) FROM public.colaboradores_perfis WHERE upper(trim(coalesce(posicao_atual,'')))='CLOSER' AND (bonificacao_sdr<>0 OR streak_meta3_bonificacao<>0)),
  'migration_applied', EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20260828120000'),
  'replay_function', to_regprocedure('public.recalcular_progressao_colaborador(uuid)') IS NOT NULL,
  'sync_rpc', to_regprocedure('public.sincronizar_progressao_planilha(jsonb,jsonb,text)') IS NOT NULL
) AS precheck;

SELECT conname, contype, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid IN ('public.colaboradores_perfis'::regclass,'public.colaboradores'::regclass,'public.career_progression_events'::regclass)
ORDER BY conrelid::regclass::text,conname;

SELECT table_name,column_name,data_type,is_nullable,column_default
FROM information_schema.columns
WHERE table_schema='public' AND table_name IN ('colaboradores_perfis','colaboradores','career_progression_events')
ORDER BY table_name,ordinal_position;

SELECT jsonb_build_object(
  'profiles',(SELECT count(*) FROM public.colaboradores_perfis),
  'results',(SELECT count(*) FROM public.colaboradores),
  'events',(SELECT count(*) FROM public.career_progression_events),
  'duplicate_profiles',(SELECT count(*) FROM (SELECT nome_normalizado FROM public.colaboradores_perfis GROUP BY nome_normalizado HAVING count(*)>1) d),
  'duplicate_results',(SELECT count(*) FROM (SELECT colaborador_id,competencia FROM public.colaboradores GROUP BY colaborador_id,competencia HAVING count(*)>1) d),
  'duplicate_events',(SELECT count(*) FROM (SELECT colaborador_id,competencia,event_type FROM public.career_progression_events GROUP BY colaborador_id,competencia,event_type HAVING count(*)>1) d),
  'orphan_results',(SELECT count(*) FROM public.colaboradores r LEFT JOIN public.colaboradores_perfis p ON p.id=r.colaborador_id WHERE p.id IS NULL),
  'orphan_events',(SELECT count(*) FROM public.career_progression_events e LEFT JOIN public.colaboradores_perfis p ON p.id=e.colaborador_id WHERE p.id IS NULL),
  'null_competences',(SELECT count(*) FROM public.colaboradores WHERE competencia IS NULL),
  'invalid_profile_progress',(SELECT count(*) FROM public.colaboradores_perfis WHERE progresso_meta3 NOT BETWEEN 0 AND 2 OR progresso_meta2 NOT IN (0,1) OR progresso_ciclo<>progresso_meta3+progresso_meta2),
  'closer_with_bonus',(SELECT count(*) FROM public.colaboradores_perfis WHERE upper(trim(coalesce(posicao_atual,'')))='CLOSER' AND (bonificacao_sdr<>0 OR streak_meta3_bonificacao<>0)),
  'migration_applied',EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20260828120000'),
  'replay_function',to_regprocedure('public.recalcular_progressao_colaborador(uuid)') IS NOT NULL,
  'sync_rpc',to_regprocedure('public.sincronizar_progressao_planilha(jsonb,jsonb,text)') IS NOT NULL
) AS precheck_summary;
