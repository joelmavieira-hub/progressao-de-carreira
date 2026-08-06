BEGIN;

CREATE SCHEMA IF NOT EXISTS archive;

CREATE TABLE archive.progression_backup_manifest (
  backup_id text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  project_ref text NOT NULL,
  source_schema text NOT NULL,
  source_table text NOT NULL,
  backup_schema text NOT NULL,
  backup_table text NOT NULL,
  source_count bigint NOT NULL,
  backup_count bigint NOT NULL,
  source_hash text NOT NULL,
  backup_hash text NOT NULL,
  restore_notes text NOT NULL,
  PRIMARY KEY (backup_id, source_schema, source_table)
);

CREATE TABLE archive.colaboradores_perfis_20260806t121500z
  (LIKE public.colaboradores_perfis INCLUDING ALL);
INSERT INTO archive.colaboradores_perfis_20260806t121500z
SELECT * FROM public.colaboradores_perfis;

CREATE TABLE archive.colaboradores_20260806t121500z
  (LIKE public.colaboradores INCLUDING ALL);
INSERT INTO archive.colaboradores_20260806t121500z
SELECT * FROM public.colaboradores;

DO $$
DECLARE
  profiles_source_count bigint;
  profiles_backup_count bigint;
  profiles_source_hash text;
  profiles_backup_hash text;
  results_source_count bigint;
  results_backup_count bigint;
  results_source_hash text;
  results_backup_hash text;
BEGIN
  SELECT count(*), md5(coalesce(string_agg(md5(to_jsonb(t)::text), '' ORDER BY t.id), ''))
    INTO profiles_source_count, profiles_source_hash
  FROM public.colaboradores_perfis t;
  SELECT count(*), md5(coalesce(string_agg(md5(to_jsonb(t)::text), '' ORDER BY t.id), ''))
    INTO profiles_backup_count, profiles_backup_hash
  FROM archive.colaboradores_perfis_20260806t121500z t;

  SELECT count(*), md5(coalesce(string_agg(md5(to_jsonb(t)::text), '' ORDER BY t.id), ''))
    INTO results_source_count, results_source_hash
  FROM public.colaboradores t;
  SELECT count(*), md5(coalesce(string_agg(md5(to_jsonb(t)::text), '' ORDER BY t.id), ''))
    INTO results_backup_count, results_backup_hash
  FROM archive.colaboradores_20260806t121500z t;

  IF profiles_source_count <> profiles_backup_count OR profiles_source_hash <> profiles_backup_hash THEN
    RAISE EXCEPTION 'Backup de colaboradores_perfis divergente';
  END IF;
  IF results_source_count <> results_backup_count OR results_source_hash <> results_backup_hash THEN
    RAISE EXCEPTION 'Backup de colaboradores divergente';
  END IF;

  INSERT INTO archive.progression_backup_manifest(
    backup_id,project_ref,source_schema,source_table,backup_schema,backup_table,
    source_count,backup_count,source_hash,backup_hash,restore_notes
  ) VALUES
  (
    'progression_20260806t121500z','ygyiygqfiupadgnaaxlz','public','colaboradores_perfis',
    'archive','colaboradores_perfis_20260806t121500z',profiles_source_count,profiles_backup_count,
    profiles_source_hash,profiles_backup_hash,
    'Restore only in a controlled transaction after validating IDs and counts; never truncate unrelated tables.'
  ),
  (
    'progression_20260806t121500z','ygyiygqfiupadgnaaxlz','public','colaboradores',
    'archive','colaboradores_20260806t121500z',results_source_count,results_backup_count,
    results_source_hash,results_backup_hash,
    'Restore only in a controlled transaction after validating collaborator foreign keys and counts.'
  );
END $$;

COMMIT;

SELECT jsonb_build_object(
  'backup_id', backup_id,
  'project_ref', min(project_ref),
  'tables', jsonb_agg(jsonb_build_object(
    'source', source_schema || '.' || source_table,
    'backup', backup_schema || '.' || backup_table,
    'source_count', source_count,
    'backup_count', backup_count,
    'hashes_match', source_hash = backup_hash
  ) ORDER BY source_table),
  'valid', bool_and(source_count = backup_count AND source_hash = backup_hash)
) AS backup_manifest
FROM archive.progression_backup_manifest
WHERE backup_id = 'progression_20260806t121500z'
GROUP BY backup_id;
