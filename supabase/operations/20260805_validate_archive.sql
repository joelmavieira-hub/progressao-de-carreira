-- FASE A: script preparado, ainda não executado remotamente.
-- Somente validação; não altera tabelas persistentes.

-- A validação usa tabelas TEMP para consolidar resultados; por isso a transação
-- não pode ser declarada READ ONLY no PostgreSQL, embora não grave nada persistente.
BEGIN ISOLATION LEVEL REPEATABLE READ;

CREATE TEMP TABLE archive_table_validation (
  source_table text PRIMARY KEY,
  source_exists boolean NOT NULL,
  archive_exists boolean NOT NULL,
  source_rows bigint,
  archive_rows bigint,
  source_distinct_ids bigint,
  archive_distinct_ids bigint,
  source_null_ids bigint,
  archive_null_ids bigint,
  exact_row_match boolean,
  manifest_row_count bigint,
  ok boolean NOT NULL
) ON COMMIT DROP;

DO $validate_tables$
DECLARE
  item record;
  source_relation regclass;
  archive_relation regclass;
  source_rows bigint;
  archive_rows bigint;
  source_distinct_ids bigint;
  archive_distinct_ids bigint;
  source_null_ids bigint;
  archive_null_ids bigint;
  exact_row_match boolean;
  manifest_row_count bigint;
BEGIN
  IF to_regclass('archive.archive_manifest_20260805') IS NULL THEN
    RAISE EXCEPTION 'Validação impossível: archive.archive_manifest_20260805 não existe.';
  END IF;

  FOR item IN
    SELECT *
    FROM (VALUES
      ('colaboradores', 'colaboradores_legacy_20260805'),
      ('colaboradores_perfis', 'colaboradores_perfis_legacy_20260805'),
      ('career_migration_issues', 'career_migration_issues_legacy_20260805'),
      ('sdrs', 'sdrs_legacy_20260805')
    ) AS targets(source_table, archive_table)
  LOOP
    source_relation := to_regclass(format('public.%I', item.source_table));
    archive_relation := to_regclass(format('archive.%I', item.archive_table));
    source_rows := NULL;
    archive_rows := NULL;
    source_distinct_ids := NULL;
    archive_distinct_ids := NULL;
    source_null_ids := NULL;
    archive_null_ids := NULL;
    exact_row_match := NULL;

    SELECT m.source_row_count
      INTO manifest_row_count
    FROM archive.archive_manifest_20260805 m
    WHERE m.source_schema = 'public'
      AND m.source_table = item.source_table
      AND m.archive_schema = 'archive'
      AND m.archive_table = item.archive_table;

    IF source_relation IS NOT NULL AND archive_relation IS NOT NULL THEN
      EXECUTE format(
        'SELECT count(*), count(DISTINCT id), count(*) FILTER (WHERE id IS NULL) FROM public.%I',
        item.source_table
      ) INTO source_rows, source_distinct_ids, source_null_ids;

      EXECUTE format(
        'SELECT count(*), count(DISTINCT id), count(*) FILTER (WHERE id IS NULL) FROM archive.%I',
        item.archive_table
      ) INTO archive_rows, archive_distinct_ids, archive_null_ids;

      EXECUTE format($sql$
        SELECT NOT EXISTS (
          SELECT 1
          FROM (
            (SELECT to_jsonb(source_row) AS row_data FROM public.%I source_row
             EXCEPT ALL
             SELECT to_jsonb(archive_row) FROM archive.%I archive_row)
            UNION ALL
            (SELECT to_jsonb(archive_row) FROM archive.%I archive_row
             EXCEPT ALL
             SELECT to_jsonb(source_row) FROM public.%I source_row)
          ) differences
        )
      $sql$, item.source_table, item.archive_table, item.archive_table, item.source_table)
      INTO exact_row_match;
    END IF;

    INSERT INTO archive_table_validation
    VALUES (
      item.source_table,
      source_relation IS NOT NULL,
      archive_relation IS NOT NULL,
      source_rows,
      archive_rows,
      source_distinct_ids,
      archive_distinct_ids,
      source_null_ids,
      archive_null_ids,
      exact_row_match,
      manifest_row_count,
      CASE
        WHEN source_relation IS NULL AND archive_relation IS NULL
          THEN manifest_row_count IS NULL
        WHEN source_relation IS NOT NULL AND archive_relation IS NOT NULL
          THEN source_rows = archive_rows
           AND source_distinct_ids = archive_distinct_ids
           AND source_null_ids = archive_null_ids
           AND exact_row_match
           AND manifest_row_count = source_rows
        ELSE false
      END
    );
  END LOOP;
END
$validate_tables$;

CREATE TEMP TABLE colaboradores_domain_validation AS
WITH datasets AS (
  SELECT 'source'::text AS dataset, c.* FROM public.colaboradores c
  UNION ALL
  SELECT 'archive'::text AS dataset, c.* FROM archive.colaboradores_legacy_20260805 c
), normalized AS (
  SELECT
    dataset,
    id,
    nullif(lower(regexp_replace(trim(coalesce(nome_colaborador, '')), '[[:space:]]+', ' ', 'g')), '') AS nome_normalizado,
    regexp_replace(
      upper(translate(trim(coalesce(meta_alcancada, '')),
        'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ', 'AAAAAEEEEIIIIOOOOOUUUUC')),
      '[[:space:]]+', ' ', 'g'
    ) AS meta_normalizada,
    CASE lower(translate(trim(coalesce(mes_referencia, '')),
      'áàâãäéèêëíìîïóòôõöúùûüç', 'aaaaaeeeeiiiiooooouuuuc'))
      WHEN 'janeiro' THEN date '2026-01-01'
      WHEN 'fevereiro' THEN date '2026-02-01'
      WHEN 'marco' THEN date '2026-03-01'
      WHEN 'abril' THEN date '2026-04-01'
      WHEN 'maio' THEN date '2026-05-01'
      WHEN 'junho' THEN date '2026-06-01'
      WHEN 'julho' THEN date '2026-07-01'
      WHEN 'agosto' THEN date '2026-08-01'
      WHEN 'setembro' THEN date '2026-09-01'
      WHEN 'outubro' THEN date '2026-10-01'
      WHEN 'novembro' THEN date '2026-11-01'
      WHEN 'dezembro' THEN date '2026-12-01'
      ELSE NULL
    END AS competencia
  FROM datasets
), duplicates AS (
  SELECT dataset, nome_normalizado, competencia, count(*) AS occurrences
  FROM normalized
  WHERE nome_normalizado IS NOT NULL AND competencia IS NOT NULL
  GROUP BY dataset, nome_normalizado, competencia
  HAVING count(*) > 1
), metrics AS (
  SELECT
    n.dataset,
    count(*) AS row_count,
    count(DISTINCT n.id) AS distinct_ids,
    count(*) FILTER (WHERE n.id IS NULL) AS null_ids,
    count(DISTINCT n.nome_normalizado) AS distinct_normalized_names,
    count(*) FILTER (
      WHERE n.meta_normalizada NOT IN (
        '', 'SEM PRESENCA', 'AUSENTE', 'META 1', 'META 2', 'META 3',
        'NENHUMA META', 'SEM META'
      )
    ) AS invalid_goals,
    min(n.competencia) AS min_competencia,
    max(n.competencia) AS max_competencia
  FROM normalized n
  GROUP BY n.dataset
)
SELECT
  m.*,
  coalesce((SELECT count(*) FROM duplicates d WHERE d.dataset = m.dataset), 0) AS duplicate_groups,
  coalesce((SELECT sum(d.occurrences) FROM duplicates d WHERE d.dataset = m.dataset), 0) AS rows_in_duplicate_groups
FROM metrics m;

CREATE TEMP TABLE archived_date_ranges (
  dataset text NOT NULL,
  table_name text NOT NULL,
  min_created_at timestamptz,
  max_created_at timestamptz,
  min_updated_at timestamptz,
  max_updated_at timestamptz
) ON COMMIT DROP;

DO $validate_date_ranges$
BEGIN
  -- public.colaboradores legado não possui coluna temporal tipada; sua faixa de
  -- competência já é reportada em colaboradores_domain_validation.
  IF to_regclass('public.sdrs') IS NOT NULL
    AND to_regclass('archive.sdrs_legacy_20260805') IS NOT NULL THEN
    INSERT INTO archived_date_ranges
    SELECT 'source', 'public.sdrs', min(created_at), max(created_at),
           min(updated_at), max(updated_at)
    FROM public.sdrs
    UNION ALL
    SELECT 'archive', 'archive.sdrs_legacy_20260805', min(created_at), max(created_at),
           min(updated_at), max(updated_at)
    FROM archive.sdrs_legacy_20260805;
  END IF;
END
$validate_date_ranges$;

TABLE archive_table_validation;

SELECT *
FROM colaboradores_domain_validation
ORDER BY dataset;

SELECT *
FROM archived_date_ranges
ORDER BY dataset, table_name;

SELECT
  bool_and(t.ok)
    AND (SELECT row_count = 6040 FROM colaboradores_domain_validation WHERE dataset = 'source')
    AND (SELECT row_count = 6040 FROM colaboradores_domain_validation WHERE dataset = 'archive')
    AND (SELECT to_jsonb(s) - 'dataset' FROM colaboradores_domain_validation s WHERE dataset = 'source')
        = (SELECT to_jsonb(a) - 'dataset' FROM colaboradores_domain_validation a WHERE dataset = 'archive')
    AS ok,
  'A limpeza só pode ser autorizada quando ok=true.'::text AS decision
FROM archive_table_validation t;

COMMIT;
