-- FASE A: script preparado, ainda não executado remotamente.
-- Executar somente após uma futura autorização e após a limpeza controlada.

-- A validação usa tabela TEMP para consolidar resultados; por isso a transação
-- não pode ser declarada READ ONLY, embora não grave nada persistente.
BEGIN ISOLATION LEVEL REPEATABLE READ;

CREATE TEMP TABLE clean_state_validation (
  section text NOT NULL,
  object_name text NOT NULL,
  row_count bigint,
  expected_rows bigint,
  ok boolean NOT NULL,
  details text
) ON COMMIT DROP;

DO $validate_clean_state$
DECLARE
  item record;
  relation regclass;
  current_rows bigint;
  archive_rows bigint;
  source_rows bigint;
  exact_row_match boolean;
BEGIN
  IF to_regclass('archive.archive_manifest_20260805') IS NULL THEN
    RAISE EXCEPTION 'Validação impossível: archive.archive_manifest_20260805 não existe.';
  END IF;

  -- Tabelas operacionais: colaboradores é obrigatória; as outras podem ainda não
  -- existir antes da migration. Quando existirem, devem estar vazias.
  FOR item IN
    SELECT *
    FROM (VALUES
      ('colaboradores', true),
      ('colaboradores_perfis', false),
      ('career_migration_issues', false)
    ) AS targets(table_name, required)
  LOOP
    relation := to_regclass(format('public.%I', item.table_name));
    current_rows := NULL;
    IF relation IS NOT NULL THEN
      EXECUTE format('SELECT count(*) FROM public.%I', item.table_name)
        INTO current_rows;
    END IF;

    INSERT INTO clean_state_validation
    VALUES (
      'operational',
      'public.' || item.table_name,
      current_rows,
      0,
      CASE
        WHEN relation IS NULL THEN NOT item.required
        ELSE current_rows = 0
      END,
      CASE
        WHEN relation IS NULL AND item.required THEN 'tabela obrigatória ausente'
        WHEN relation IS NULL THEN 'tabela opcional ainda não criada pela migration'
        ELSE 'tabela existente'
      END
    );
  END LOOP;

  -- Toda cópia registrada deve continuar presente e com a contagem do manifest.
  FOR item IN
    SELECT source_table, archive_table, source_row_count
    FROM archive.archive_manifest_20260805
  LOOP
    relation := to_regclass(format('archive.%I', item.archive_table));
    archive_rows := NULL;
    IF relation IS NOT NULL THEN
      EXECUTE format('SELECT count(*) FROM archive.%I', item.archive_table)
        INTO archive_rows;
    END IF;

    INSERT INTO clean_state_validation
    VALUES (
      'archive',
      'archive.' || item.archive_table,
      archive_rows,
      item.source_row_count,
      relation IS NOT NULL AND archive_rows = item.source_row_count,
      'origem: public.' || item.source_table
    );
  END LOOP;

  -- sdrs não faz parte da limpeza: além da cópia, sua origem deve permanecer idêntica.
  IF EXISTS (
    SELECT 1
    FROM archive.archive_manifest_20260805
    WHERE source_table = 'sdrs' AND archive_table = 'sdrs_legacy_20260805'
  ) THEN
    IF to_regclass('public.sdrs') IS NULL
      OR to_regclass('archive.sdrs_legacy_20260805') IS NULL THEN
      INSERT INTO clean_state_validation
      VALUES ('preserved_source', 'public.sdrs', NULL, NULL, false,
              'origem ou arquivo ausente');
    ELSE
      SELECT source_row_count INTO source_rows
      FROM archive.archive_manifest_20260805
      WHERE source_table = 'sdrs' AND archive_table = 'sdrs_legacy_20260805';

      EXECUTE $sql$
        SELECT NOT EXISTS (
          SELECT 1
          FROM (
            (SELECT to_jsonb(source_row) AS row_data FROM public.sdrs source_row
             EXCEPT ALL
             SELECT to_jsonb(archive_row) FROM archive.sdrs_legacy_20260805 archive_row)
            UNION ALL
            (SELECT to_jsonb(archive_row) FROM archive.sdrs_legacy_20260805 archive_row
             EXCEPT ALL
             SELECT to_jsonb(source_row) FROM public.sdrs source_row)
          ) differences
        )
      $sql$ INTO exact_row_match;

      SELECT count(*) INTO current_rows FROM public.sdrs;
      INSERT INTO clean_state_validation
      VALUES ('preserved_source', 'public.sdrs', current_rows, source_rows,
              current_rows = source_rows AND exact_row_match,
              'sdrs foi arquivada, mas não deve ser limpa');
    END IF;
  END IF;
END
$validate_clean_state$;

TABLE clean_state_validation;

SELECT
  bool_and(ok)
    AND EXISTS (
      SELECT 1
      FROM clean_state_validation
      WHERE object_name = 'archive.colaboradores_legacy_20260805'
        AND row_count = 6040
        AND expected_rows = 6040
        AND ok
    ) AS ok,
  'A migration só pode avançar quando ok=true.'::text AS decision
FROM clean_state_validation;

COMMIT;
