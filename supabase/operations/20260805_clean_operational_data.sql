-- FASE A: script destrutivo preparado, ainda NÃO autorizado nem executado.
-- Projeto permitido na futura execução: ygyiygqfiupadgnaaxlz.
-- Pré-condição externa obrigatória: Assert-MainProject deve mostrar exatamente
-- ygyiygqfiupadgnaaxlz antes de enviar este SQL ao banco.
-- Estratégia: DELETE controlado, sem CASCADE, dentro de uma única transação.

BEGIN ISOLATION LEVEL SERIALIZABLE;

SELECT pg_advisory_xact_lock(hashtextextended('career-clean-operational-20260805', 0));

DO $clean_precheck$
DECLARE
  item record;
  source_rows bigint;
  archive_rows bigint;
  manifest_rows bigint;
  exact_row_match boolean;
BEGIN
  IF to_regclass('archive.archive_manifest_20260805') IS NULL THEN
    RAISE EXCEPTION 'Limpeza recusada: manifest do arquivamento não existe.';
  END IF;

  FOR item IN
    SELECT *
    FROM (VALUES
      ('colaboradores', 'colaboradores_legacy_20260805'),
      ('colaboradores_perfis', 'colaboradores_perfis_legacy_20260805'),
      ('career_migration_issues', 'career_migration_issues_legacy_20260805')
    ) AS targets(source_table, archive_table)
  LOOP
    IF to_regclass(format('public.%I', item.source_table)) IS NOT NULL THEN
      IF to_regclass(format('archive.%I', item.archive_table)) IS NULL THEN
        RAISE EXCEPTION 'Limpeza recusada: archive.% não existe.', item.archive_table;
      END IF;

      EXECUTE format('LOCK TABLE public.%I IN SHARE ROW EXCLUSIVE MODE', item.source_table);
      EXECUTE format('SELECT count(*) FROM public.%I', item.source_table) INTO source_rows;
      EXECUTE format('SELECT count(*) FROM archive.%I', item.archive_table) INTO archive_rows;
      SELECT m.source_row_count INTO manifest_rows
      FROM archive.archive_manifest_20260805 m
      WHERE m.source_schema = 'public'
        AND m.source_table = item.source_table
        AND m.archive_schema = 'archive'
        AND m.archive_table = item.archive_table;

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

      IF source_rows IS DISTINCT FROM archive_rows
        OR source_rows IS DISTINCT FROM manifest_rows
        OR exact_row_match IS DISTINCT FROM true THEN
        RAISE EXCEPTION
          'Limpeza recusada: public.% diverge do arquivo (origem %, arquivo %, manifest %, conteúdo igual %).',
          item.source_table, source_rows, archive_rows, manifest_rows, exact_row_match;
      END IF;
    ELSIF to_regclass(format('archive.%I', item.archive_table)) IS NOT NULL THEN
      RAISE EXCEPTION 'Limpeza recusada: public.% não existe, mas o arquivo correspondente existe.',
        item.source_table;
    END IF;
  END LOOP;

  SELECT count(*) INTO source_rows FROM public.colaboradores;
  IF source_rows <> 6040 THEN
    RAISE EXCEPTION 'Limpeza recusada: esperadas 6040 linhas em public.colaboradores; encontradas %.',
      source_rows;
  END IF;
END
$clean_precheck$;

CREATE TEMP TABLE clean_operation_result (
  execution_order integer PRIMARY KEY,
  table_name text NOT NULL,
  deleted_rows bigint NOT NULL
) ON COMMIT DROP;

DO $controlled_delete$
DECLARE
  affected bigint;
BEGIN
  IF to_regclass('public.career_migration_issues') IS NOT NULL THEN
    DELETE FROM public.career_migration_issues;
    GET DIAGNOSTICS affected = ROW_COUNT;
    INSERT INTO clean_operation_result VALUES (1, 'public.career_migration_issues', affected);
  END IF;

  DELETE FROM public.colaboradores;
  GET DIAGNOSTICS affected = ROW_COUNT;
  INSERT INTO clean_operation_result VALUES (2, 'public.colaboradores', affected);

  IF to_regclass('public.colaboradores_perfis') IS NOT NULL THEN
    DELETE FROM public.colaboradores_perfis;
    GET DIAGNOSTICS affected = ROW_COUNT;
    INSERT INTO clean_operation_result VALUES (3, 'public.colaboradores_perfis', affected);
  END IF;
END
$controlled_delete$;

DO $clean_postcheck$
DECLARE
  remaining bigint;
BEGIN
  SELECT count(*) INTO remaining FROM public.colaboradores;
  IF remaining <> 0 THEN
    RAISE EXCEPTION 'Limpeza incompleta: public.colaboradores ainda possui % linhas.', remaining;
  END IF;

  IF to_regclass('public.colaboradores_perfis') IS NOT NULL THEN
    SELECT count(*) INTO remaining FROM public.colaboradores_perfis;
    IF remaining <> 0 THEN
      RAISE EXCEPTION 'Limpeza incompleta: public.colaboradores_perfis ainda possui % linhas.', remaining;
    END IF;
  END IF;

  IF to_regclass('public.career_migration_issues') IS NOT NULL THEN
    SELECT count(*) INTO remaining FROM public.career_migration_issues;
    IF remaining <> 0 THEN
      RAISE EXCEPTION 'Limpeza incompleta: public.career_migration_issues ainda possui % linhas.', remaining;
    END IF;
  END IF;
END
$clean_postcheck$;

TABLE clean_operation_result;

COMMIT;
