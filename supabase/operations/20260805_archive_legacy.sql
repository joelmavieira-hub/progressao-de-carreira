-- FASE A: script preparado, ainda não executado remotamente.
-- Projeto permitido na futura execução: ygyiygqfiupadgnaaxlz.
-- O project ref deve ser validado externamente antes deste SQL, porque o PostgreSQL
-- não expõe de forma confiável o project ref do Supabase à sessão SQL.

BEGIN ISOLATION LEVEL REPEATABLE READ;

-- Evita dois arquivamentos concorrentes com o mesmo identificador lógico.
SELECT pg_advisory_xact_lock(hashtextextended('career-archive-legacy-20260805', 0));

CREATE SCHEMA IF NOT EXISTS archive;

DO $archive_precheck$
DECLARE
  archive_table text;
BEGIN
  FOREACH archive_table IN ARRAY ARRAY[
    'archive_manifest_20260805',
    'colaboradores_legacy_20260805',
    'colaboradores_perfis_legacy_20260805',
    'career_migration_issues_legacy_20260805',
    'sdrs_legacy_20260805'
  ]
  LOOP
    IF to_regclass(format('archive.%I', archive_table)) IS NOT NULL THEN
      RAISE EXCEPTION 'Arquivamento recusado: archive.% já existe.', archive_table
        USING ERRCODE = '42P07';
    END IF;
  END LOOP;

  IF to_regclass('public.colaboradores') IS NULL THEN
    RAISE EXCEPTION 'Arquivamento recusado: public.colaboradores não existe.'
      USING ERRCODE = '42P01';
  END IF;
END
$archive_precheck$;

CREATE TABLE archive.archive_manifest_20260805 (
  source_schema text NOT NULL,
  source_table text NOT NULL,
  archive_schema text NOT NULL,
  archive_table text NOT NULL,
  archived_at timestamptz NOT NULL,
  archived_by text NOT NULL,
  source_row_count bigint NOT NULL,
  PRIMARY KEY (source_schema, source_table),
  UNIQUE (archive_schema, archive_table)
);

DO $archive_copy$
DECLARE
  item record;
  source_count bigint;
BEGIN
  FOR item IN
    SELECT *
    FROM (VALUES
      ('colaboradores', 'colaboradores_legacy_20260805'),
      ('colaboradores_perfis', 'colaboradores_perfis_legacy_20260805'),
      ('career_migration_issues', 'career_migration_issues_legacy_20260805'),
      ('sdrs', 'sdrs_legacy_20260805')
    ) AS targets(source_table, archive_table)
  LOOP
    IF to_regclass(format('public.%I', item.source_table)) IS NOT NULL THEN
      -- SHARE impede INSERT/UPDATE/DELETE durante a cópia e é liberado no COMMIT.
      EXECUTE format('LOCK TABLE public.%I IN SHARE MODE', item.source_table);
      EXECUTE format(
        'CREATE TABLE archive.%I AS TABLE public.%I WITH DATA',
        item.archive_table,
        item.source_table
      );
      EXECUTE format('SELECT count(*) FROM public.%I', item.source_table)
        INTO source_count;

      INSERT INTO archive.archive_manifest_20260805 (
        source_schema,
        source_table,
        archive_schema,
        archive_table,
        archived_at,
        archived_by,
        source_row_count
      )
      VALUES (
        'public',
        item.source_table,
        'archive',
        item.archive_table,
        transaction_timestamp(),
        session_user,
        source_count
      );
    END IF;
  END LOOP;
END
$archive_copy$;

COMMIT;

SELECT
  source_schema,
  source_table,
  archive_schema,
  archive_table,
  archived_at,
  archived_by,
  source_row_count
FROM archive.archive_manifest_20260805
ORDER BY source_table;
