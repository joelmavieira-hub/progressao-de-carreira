BEGIN ISOLATION LEVEL REPEATABLE READ, READ ONLY;

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
), internal_acl AS (
  SELECT
    f.signature,
    has_function_privilege('anon', f.signature, 'EXECUTE') AS anon_execute,
    has_function_privilege('authenticated', f.signature, 'EXECUTE') AS authenticated_execute,
    EXISTS (
      SELECT 1
      FROM pg_proc p
      CROSS JOIN LATERAL aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
      WHERE p.oid = to_regprocedure(f.signature)
        AND acl.grantee = 0
        AND acl.privilege_type = 'EXECUTE'
    ) AS public_execute
  FROM internal_functions f
), rpc_acl AS (
  SELECT
    has_function_privilege('anon',
      'public.sincronizar_progressao_planilha(jsonb,jsonb,text)', 'EXECUTE') AS anon_execute,
    has_function_privilege('authenticated',
      'public.sincronizar_progressao_planilha(jsonb,jsonb,text)', 'EXECUTE') AS authenticated_execute,
    has_function_privilege('service_role',
      'public.sincronizar_progressao_planilha(jsonb,jsonb,text)', 'EXECUTE') AS service_role_execute,
    EXISTS (
      SELECT 1
      FROM pg_proc p
      CROSS JOIN LATERAL aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
      WHERE p.oid = to_regprocedure('public.sincronizar_progressao_planilha(jsonb,jsonb,text)')
        AND acl.grantee = 0
        AND acl.privilege_type = 'EXECUTE'
    ) AS public_execute,
    coalesce((SELECT p.prosecdef FROM pg_proc p
      WHERE p.oid=to_regprocedure('public.sincronizar_progressao_planilha(jsonb,jsonb,text)')),false) AS security_definer,
    coalesce((SELECT EXISTS (
      SELECT 1 FROM unnest(coalesce(p.proconfig,ARRAY[]::text[])) setting
      WHERE replace(setting,' ','')='search_path=pg_catalog,public')
      FROM pg_proc p
      WHERE p.oid=to_regprocedure('public.sincronizar_progressao_planilha(jsonb,jsonb,text)')),false) AS safe_search_path
)
SELECT
  r.public_execute AS public_pode_executar,
  r.anon_execute AS anon_pode_executar,
  r.authenticated_execute AS authenticated_pode_executar,
  r.service_role_execute AS service_role_pode_executar,
  r.security_definer,
  r.safe_search_path,
  (SELECT jsonb_agg(to_jsonb(i) ORDER BY i.signature) FROM internal_acl i) AS funcoes_internas,
  NOT r.public_execute
    AND NOT r.anon_execute
    AND NOT r.authenticated_execute
    AND r.service_role_execute
    AND r.security_definer
    AND r.safe_search_path
    AND NOT EXISTS (SELECT 1 FROM internal_acl
      WHERE anon_execute OR authenticated_execute OR public_execute) AS ok
FROM rpc_acl r;

COMMIT;
