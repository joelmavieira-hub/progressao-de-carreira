SELECT jsonb_build_object(
  'migration_registered',EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20260828120000'),
  'replay_function',to_regprocedure('public.recalcular_progressao_colaborador(uuid)') IS NOT NULL,
  'sync_rpc',to_regprocedure('public.sincronizar_progressao_planilha(jsonb,jsonb,text)') IS NOT NULL,
  'normalize_meta_nao_definida',public.normalize_career_goal('Meta não definida'),
  'service_role_can_replay',has_function_privilege('service_role','public.recalcular_progressao_colaborador(uuid)','EXECUTE'),
  'anon_can_replay',has_function_privilege('anon','public.recalcular_progressao_colaborador(uuid)','EXECUTE'),
  'authenticated_can_replay',has_function_privilege('authenticated','public.recalcular_progressao_colaborador(uuid)','EXECUTE'),
  'profile_constraints',(SELECT count(*) FROM pg_constraint WHERE conrelid='public.colaboradores_perfis'::regclass),
  'result_constraints',(SELECT count(*) FROM pg_constraint WHERE conrelid='public.colaboradores'::regclass),
  'event_constraints',(SELECT count(*) FROM pg_constraint WHERE conrelid='public.career_progression_events'::regclass),
  'closer_with_meta2_before_replay',(SELECT count(*) FROM public.colaboradores_perfis WHERE upper(trim(coalesce(posicao_atual,'')))='CLOSER' AND progresso_meta2<>0)
) AS migration_validation;
