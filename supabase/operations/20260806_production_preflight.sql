-- Production preflight: SELECT-only inventory. No state changes.
SELECT current_database() AS database_name, current_user AS execution_role;

SELECT n.nspname AS schema_name, c.relname AS object_name, c.relkind,
       c.relrowsecurity AS rls_enabled
FROM pg_catalog.pg_class c
JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname IN ('public', 'archive')
  AND c.relkind IN ('r', 'p', 'v', 'm')
ORDER BY n.nspname, c.relname;

SELECT
  (SELECT count(*) FROM public.colaboradores_perfis) AS profiles_count,
  (SELECT count(*) FROM public.colaboradores) AS results_count,
  (SELECT count(*) FROM public.colaboradores_perfis WHERE ativo) AS active_profiles_count,
  (SELECT count(*) FROM public.colaboradores_perfis WHERE NOT ativo) AS inactive_profiles_count,
  (SELECT count(*) FROM public.colaboradores c
     WHERE c.colaborador_id IS NULL OR NOT EXISTS (
       SELECT 1 FROM public.colaboradores_perfis p WHERE p.id = c.colaborador_id
     )) AS orphans_count,
  (SELECT count(*) FROM (
     SELECT colaborador_id, competencia FROM public.colaboradores
     GROUP BY colaborador_id, competencia HAVING count(*) > 1
   ) duplicates) AS duplicates_count,
  (SELECT count(*) FROM public.colaboradores_perfis
     WHERE progresso_meta3 NOT BETWEEN 0 AND 2) AS invalid_progress_count,
  (SELECT count(*) FROM public.colaboradores_perfis
     WHERE upper(trim(coalesce(posicao_atual, ''))) NOT IN ('SDR', 'CLOSER')) AS invalid_positions_count,
  (SELECT count(*) FROM public.colaboradores_perfis
     WHERE public.normalize_career_seniority(senioridade_atual) IS NULL) AS invalid_seniorities_count;

SELECT p.nome_colaborador, p.id, p.ativo, p.posicao_atual, p.senioridade_atual,
       p.progresso_meta3, c.competencia, c.posicao, c.senioridade,
       c.senioridade_informada, c.meta_alcancada, c.recebeu_promocao
FROM public.colaboradores_perfis p
JOIN public.colaboradores c ON c.colaborador_id = p.id
WHERE p.nome_normalizado IN (
  public.normalize_career_name('Miguel Carneiro Nunes'),
  public.normalize_career_name('Tatyanna Lima de Freitas'),
  public.normalize_career_name('Adrilene Azevedo da Silva'),
  public.normalize_career_name('Luiz Fernando de Medeiros Paiva Moura')
)
ORDER BY p.nome_normalizado, c.competencia, c.id;

SELECT schemaname, tablename, policyname, permissive, roles, cmd
FROM pg_catalog.pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('career_progression_events', 'colaboradores', 'colaboradores_perfis', 'promocoes')
ORDER BY tablename, policyname;

SELECT c.relname AS table_name, c.relrowsecurity AS rls_enabled,
       has_table_privilege('anon', c.oid, 'SELECT') AS anon_select,
       has_table_privilege('anon', c.oid, 'INSERT') AS anon_insert,
       has_table_privilege('anon', c.oid, 'UPDATE') AS anon_update,
       has_table_privilege('anon', c.oid, 'DELETE') AS anon_delete
FROM pg_catalog.pg_class c
JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname IN ('career_progression_events', 'colaboradores', 'colaboradores_perfis', 'promocoes')
ORDER BY c.relname;

SELECT p.proname,
       pg_catalog.pg_get_function_identity_arguments(p.oid) AS arguments,
       md5(pg_catalog.pg_get_functiondef(p.oid)) AS definition_hash,
       has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_execute,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') AS authenticated_execute,
       has_function_privilege('service_role', p.oid, 'EXECUTE') AS service_role_execute
FROM pg_catalog.pg_proc p
JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('sincronizar_progressao_planilha', 'recalcular_progressao_colaborador')
ORDER BY p.proname, arguments;

SELECT version FROM supabase_migrations.schema_migrations ORDER BY version;

SELECT to_regclass('public.sdrs') IS NOT NULL AS public_sdrs_exists;

-- The Management API returns the final result set, so consolidate the evidence.
SELECT jsonb_build_object(
  'objects', (
    SELECT jsonb_agg(jsonb_build_object(
      'schema', n.nspname, 'name', c.relname, 'kind', c.relkind,
      'rls', c.relrowsecurity
    ) ORDER BY n.nspname, c.relname)
    FROM pg_catalog.pg_class c
    JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname IN ('public', 'archive') AND c.relkind IN ('r', 'p', 'v', 'm')
  ),
  'counts', jsonb_build_object(
    'profiles', (SELECT count(*) FROM public.colaboradores_perfis),
    'results', (SELECT count(*) FROM public.colaboradores),
    'active', (SELECT count(*) FROM public.colaboradores_perfis WHERE ativo),
    'inactive', (SELECT count(*) FROM public.colaboradores_perfis WHERE NOT ativo),
    'orphans', (SELECT count(*) FROM public.colaboradores c WHERE c.colaborador_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.colaboradores_perfis p WHERE p.id=c.colaborador_id)),
    'duplicates', (SELECT count(*) FROM (SELECT colaborador_id,competencia FROM public.colaboradores GROUP BY colaborador_id,competencia HAVING count(*)>1) d),
    'invalid_progress', (SELECT count(*) FROM public.colaboradores_perfis WHERE progresso_meta3 NOT BETWEEN 0 AND 2),
    'invalid_positions', (SELECT count(*) FROM public.colaboradores_perfis WHERE upper(trim(coalesce(posicao_atual,''))) NOT IN ('SDR','CLOSER')),
    'invalid_seniorities', (SELECT count(*) FROM public.colaboradores_perfis WHERE public.normalize_career_seniority(senioridade_atual) IS NULL)
  ),
  'named_cases', (
    SELECT jsonb_agg(jsonb_build_object(
      'name', p.nome_colaborador, 'id', p.id, 'active', p.ativo,
      'current_position', p.posicao_atual, 'current_seniority', p.senioridade_atual,
      'progress', p.progresso_meta3,
      'history', (SELECT jsonb_agg(jsonb_build_object(
        'competence', c.competencia, 'position', c.posicao, 'seniority', c.senioridade,
        'informed_seniority', c.senioridade_informada, 'goal', c.meta_alcancada,
        'promotion', c.recebeu_promocao
      ) ORDER BY c.competencia,c.id) FROM public.colaboradores c WHERE c.colaborador_id=p.id)
    ) ORDER BY p.nome_normalizado)
    FROM public.colaboradores_perfis p
    WHERE p.nome_normalizado IN (
      public.normalize_career_name('Miguel Carneiro Nunes'),
      public.normalize_career_name('Tatyanna Lima de Freitas'),
      public.normalize_career_name('Adrilene Azevedo da Silva'),
      public.normalize_career_name('Luiz Fernando de Medeiros Paiva Moura')
    )
  ),
  'table_permissions', (
    SELECT jsonb_agg(jsonb_build_object(
      'table', c.relname, 'rls', c.relrowsecurity,
      'anon_select', has_table_privilege('anon',c.oid,'SELECT'),
      'anon_insert', has_table_privilege('anon',c.oid,'INSERT'),
      'anon_update', has_table_privilege('anon',c.oid,'UPDATE'),
      'anon_delete', has_table_privilege('anon',c.oid,'DELETE')
    ) ORDER BY c.relname)
    FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relname IN ('career_progression_events','colaboradores','colaboradores_perfis','promocoes')
  ),
  'function_permissions', (
    SELECT jsonb_agg(jsonb_build_object(
      'function', p.proname, 'arguments', pg_catalog.pg_get_function_identity_arguments(p.oid),
      'hash', md5(pg_catalog.pg_get_functiondef(p.oid)),
      'anon_execute', has_function_privilege('anon',p.oid,'EXECUTE'),
      'authenticated_execute', has_function_privilege('authenticated',p.oid,'EXECUTE'),
      'service_role_execute', has_function_privilege('service_role',p.oid,'EXECUTE')
    ) ORDER BY p.proname, pg_catalog.pg_get_function_identity_arguments(p.oid))
    FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.proname IN ('sincronizar_progressao_planilha','recalcular_progressao_colaborador')
  ),
  'migrations', (SELECT jsonb_agg(version ORDER BY version) FROM supabase_migrations.schema_migrations),
  'public_sdrs_exists', to_regclass('public.sdrs') IS NOT NULL
) AS preflight;
