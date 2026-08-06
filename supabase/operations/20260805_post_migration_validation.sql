-- Validação estrutural após a migration 20260804220000.
-- Usa apenas tabelas TEMP; nenhuma alteração persistente é realizada.
BEGIN ISOLATION LEVEL REPEATABLE READ;

CREATE TEMP TABLE post_migration_checks (
  check_name text PRIMARY KEY,
  ok boolean NOT NULL,
  details text NOT NULL
) ON COMMIT DROP;

INSERT INTO post_migration_checks
WITH internal_functions(signature) AS (
  VALUES
    ('public.normalize_career_name(text)'),
    ('public.normalize_career_goal(text)'),
    ('public.normalize_career_seniority(text)'),
    ('public.next_career_seniority(text)'),
    ('public.parse_legacy_competencia(text)'),
    ('public.recalcular_progressao_colaborador(uuid)'),
    ('public.registrar_resultado_mensal(uuid,date,text)'),
    ('public.set_career_updated_at()')
), internal_function_security AS (
  SELECT
    bool_and(to_regprocedure(f.signature) IS NOT NULL) AS all_exist,
    bool_and(
      NOT has_function_privilege('anon', f.signature, 'EXECUTE')
      AND NOT has_function_privilege('authenticated', f.signature, 'EXECUTE')
      AND NOT EXISTS (
        SELECT 1
        FROM pg_proc p
        CROSS JOIN LATERAL aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
        WHERE p.oid = to_regprocedure(f.signature)
          AND acl.grantee = 0
          AND acl.privilege_type = 'EXECUTE'
      )
    ) AS all_private
  FROM internal_functions f
), checks(check_name, ok, details) AS (
  VALUES
    ('archive_manifest_exists',
      to_regclass('archive.archive_manifest_20260805') IS NOT NULL,
      coalesce(to_regclass('archive.archive_manifest_20260805')::text, 'ausente')),
    ('archive_manifest_has_6040_rows',
      (SELECT source_row_count = 6040
       FROM archive.archive_manifest_20260805
       WHERE source_schema = 'public' AND source_table = 'colaboradores'
         AND archive_schema = 'archive'
         AND archive_table = 'colaboradores_legacy_20260805'),
      coalesce((SELECT source_row_count::text
        FROM archive.archive_manifest_20260805
        WHERE source_schema = 'public' AND source_table = 'colaboradores'), 'ausente')),
    ('archive_colaboradores_has_6040_rows',
      (SELECT count(*) = 6040 FROM archive.colaboradores_legacy_20260805),
      (SELECT count(*)::text FROM archive.colaboradores_legacy_20260805)),
    ('legacy_sdrs_remains_absent',
      to_regclass('public.sdrs') IS NULL
        AND to_regclass('archive.sdrs_legacy_20260805') IS NULL,
      format('public=%s archive=%s',
        coalesce(to_regclass('public.sdrs')::text, 'ausente'),
        coalesce(to_regclass('archive.sdrs_legacy_20260805')::text, 'ausente'))),
    ('operational_tables_exist',
      to_regclass('public.colaboradores') IS NOT NULL
        AND to_regclass('public.colaboradores_perfis') IS NOT NULL
        AND to_regclass('public.career_migration_issues') IS NOT NULL,
      'colaboradores, colaboradores_perfis, career_migration_issues'),
    ('operational_colaboradores_empty',
      (SELECT count(*) = 0 FROM public.colaboradores),
      (SELECT count(*)::text FROM public.colaboradores)),
    ('operational_profiles_empty',
      (SELECT count(*) = 0 FROM public.colaboradores_perfis),
      (SELECT count(*)::text FROM public.colaboradores_perfis)),
    ('migration_issues_empty',
      (SELECT count(*) = 0 FROM public.career_migration_issues),
      (SELECT count(*)::text FROM public.career_migration_issues)),
    ('new_result_columns_exist',
      (SELECT count(*) = 6 FROM information_schema.columns
       WHERE table_schema = 'public' AND table_name = 'colaboradores'
         AND column_name IN ('colaborador_id', 'competencia', 'senioridade_informada',
           'origem', 'created_at', 'updated_at')),
      'colaborador_id, competencia, senioridade_informada, origem, created_at, updated_at'),
    ('promotion_flag_is_boolean',
      EXISTS (SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'colaboradores'
          AND column_name = 'recebeu_promocao' AND data_type = 'boolean'
          AND is_nullable = 'NO'),
      'recebeu_promocao boolean NOT NULL'),
    ('results_profile_fk_validated',
      EXISTS (SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.colaboradores'::regclass
          AND conname = 'colaboradores_colaborador_id_fkey'
          AND contype = 'f' AND convalidated),
      'colaboradores_colaborador_id_fkey'),
    ('result_month_check_validated',
      EXISTS (SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.colaboradores'::regclass
          AND conname = 'colaboradores_competencia_primeiro_dia'
          AND contype = 'c' AND convalidated),
      'colaboradores_competencia_primeiro_dia'),
    ('result_month_unique_index_exists',
      to_regclass('public.colaboradores_colaborador_competencia_key') IS NOT NULL,
      coalesce(to_regclass('public.colaboradores_colaborador_competencia_key')::text, 'ausente')),
    ('normalized_name_unique_constraint_exists',
      EXISTS (SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.colaboradores_perfis'::regclass
          AND conname = 'colaboradores_perfis_nome_normalizado_key'
          AND contype = 'u' AND convalidated),
      'colaboradores_perfis_nome_normalizado_key'),
    ('normalized_name_check_exists',
      EXISTS (SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.colaboradores_perfis'::regclass
          AND conname = 'colaboradores_perfis_nome_normalizado_canonico'
          AND contype = 'c' AND convalidated),
      'colaboradores_perfis_nome_normalizado_canonico'),
    ('seniority_check_exists',
      EXISTS (SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.colaboradores_perfis'::regclass
          AND conname = 'colaboradores_perfis_senioridade_valida'
          AND contype = 'c' AND convalidated),
      'colaboradores_perfis_senioridade_valida'),
    ('progress_check_exists',
      EXISTS (SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.colaboradores_perfis'::regclass
          AND conname = 'colaboradores_perfis_progresso_meta3_check'
          AND contype = 'c' AND convalidated),
      'colaboradores_perfis_progresso_meta3_check'),
    ('goal_domain_validation_exists',
      coalesce(to_regprocedure('public.normalize_career_goal(text)') IS NOT NULL
        AND public.normalize_career_goal('Meta 1') = 'Meta 1'
        AND public.normalize_career_goal('Meta 2') = 'Meta 2'
        AND public.normalize_career_goal('Meta 3') = 'Meta 3'
        AND public.normalize_career_goal('Sem presença') = 'Sem presença'
        AND public.normalize_career_goal('SEM PRESENÇA') = 'Sem presença'
        AND public.normalize_career_goal('sem presença') = 'Sem presença'
        AND public.normalize_career_goal('Sem presenca') = 'Sem presença'
        AND public.normalize_career_goal('Nenhuma meta') = 'Nenhuma meta'
        AND public.normalize_career_goal('valor inválido') IS NULL, false),
      'normalize_career_goal valida o domínio usado pela RPC'),
    ('seniority_domain_validation_exists',
      coalesce(to_regprocedure('public.normalize_career_seniority(text)') IS NOT NULL
        AND public.normalize_career_seniority('Júnior 1') = 'Júnior 1'
        AND public.normalize_career_seniority('JÚNIOR 1') = 'Júnior 1'
        AND public.normalize_career_seniority('júnior 1') = 'Júnior 1'
        AND public.normalize_career_seniority('Junior 1') = 'Júnior 1'
        AND public.normalize_career_seniority('Pleno 2') = 'Pleno 2'
        AND public.normalize_career_seniority('Sênior 3') = 'Sênior 3'
        AND public.normalize_career_seniority('Senior 3') = 'Sênior 3'
        AND public.normalize_career_seniority('valor inválido') IS NULL, false),
      'normalize_career_seniority valida o domínio usado pela RPC'),
    ('sync_rpc_exists',
      to_regprocedure('public.sincronizar_progressao_planilha(jsonb,jsonb,text)') IS NOT NULL,
      coalesce(to_regprocedure('public.sincronizar_progressao_planilha(jsonb,jsonb,text)')::text, 'ausente')),
    ('sync_rpc_security_definer',
      coalesce((SELECT prosecdef FROM pg_proc
        WHERE oid = to_regprocedure('public.sincronizar_progressao_planilha(jsonb,jsonb,text)')), false),
      'SECURITY DEFINER esperado'),
    ('sync_rpc_safe_search_path',
      coalesce((SELECT EXISTS (
        SELECT 1 FROM unnest(coalesce(p.proconfig, ARRAY[]::text[])) setting
        WHERE replace(setting, ' ', '') = 'search_path=pg_catalog,public')
        FROM pg_proc p
        WHERE p.oid = to_regprocedure('public.sincronizar_progressao_planilha(jsonb,jsonb,text)')), false),
      'search_path=pg_catalog,public esperado'),
    ('sync_rpc_anon_denied',
      NOT has_function_privilege('anon',
        'public.sincronizar_progressao_planilha(jsonb,jsonb,text)', 'EXECUTE'),
      'anon=false esperado'),
    ('sync_rpc_authenticated_denied',
      NOT has_function_privilege('authenticated',
        'public.sincronizar_progressao_planilha(jsonb,jsonb,text)', 'EXECUTE'),
      'authenticated=false esperado'),
    ('sync_rpc_service_role_allowed',
      has_function_privilege('service_role',
        'public.sincronizar_progressao_planilha(jsonb,jsonb,text)', 'EXECUTE'),
      'service_role=true esperado'),
    ('internal_functions_exist',
      (SELECT all_exist FROM internal_function_security),
      '8 funções internas esperadas'),
    ('internal_functions_are_private',
      (SELECT all_private FROM internal_function_security),
      'PUBLIC, anon e authenticated sem EXECUTE'),
    ('results_rls_enabled',
      (SELECT relrowsecurity FROM pg_class WHERE oid = 'public.colaboradores'::regclass),
      'RLS esperado'),
    ('profiles_rls_enabled',
      (SELECT relrowsecurity FROM pg_class WHERE oid = 'public.colaboradores_perfis'::regclass),
      'RLS esperado'),
    ('migration_issues_rls_enabled',
      (SELECT relrowsecurity FROM pg_class WHERE oid = 'public.career_migration_issues'::regclass),
      'RLS esperado')
)
SELECT check_name, coalesce(ok, false), details FROM checks;

TABLE post_migration_checks;

SELECT bool_and(ok) AS ok,
       count(*) AS checks_executed,
       count(*) FILTER (WHERE NOT ok) AS checks_failed
FROM post_migration_checks;

COMMIT;
