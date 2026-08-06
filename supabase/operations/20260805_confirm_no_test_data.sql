BEGIN ISOLATION LEVEL REPEATABLE READ, READ ONLY;

WITH state AS (
  SELECT
    (SELECT count(*) FROM public.colaboradores_perfis
      WHERE nome_normalizado LIKE 'zz teste rpc%') AS test_profiles,
    (SELECT count(*) FROM public.colaboradores
      WHERE public.normalize_career_name(nome_colaborador) LIKE 'zz teste rpc%'
         OR origem IN ('smoke_test','zz_teste_rpc_pgtap','zz_teste_rpc_reduzida')) AS test_results,
    (SELECT count(*) FROM public.colaboradores) AS total_results,
    (SELECT count(*) FROM public.colaboradores_perfis) AS total_profiles,
    (SELECT count(*) FROM public.career_migration_issues) AS migration_issues,
    (SELECT count(*) FROM archive.colaboradores_legacy_20260805) AS archive_rows,
    (SELECT source_row_count FROM archive.archive_manifest_20260805
      WHERE source_schema='public' AND source_table='colaboradores') AS manifest_rows
)
SELECT *,
  test_profiles=0 AND test_results=0 AND total_results=0 AND total_profiles=0
    AND migration_issues=0
    AND archive_rows=6040 AND manifest_rows=6040 AS ok
FROM state;

COMMIT;
