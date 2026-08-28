BEGIN;

LOCK TABLE public.colaboradores_perfis,
           public.colaboradores,
           public.career_progression_events IN SHARE MODE;

CREATE SCHEMA IF NOT EXISTS archive;

CREATE TABLE IF NOT EXISTS archive.progression_backup_manifest (
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
  PRIMARY KEY (backup_id,source_schema,source_table)
);

CREATE TABLE archive.colaboradores_perfis_20260828t101500z (LIKE public.colaboradores_perfis INCLUDING ALL);
INSERT INTO archive.colaboradores_perfis_20260828t101500z SELECT * FROM public.colaboradores_perfis;

CREATE TABLE archive.colaboradores_20260828t101500z (LIKE public.colaboradores INCLUDING ALL);
INSERT INTO archive.colaboradores_20260828t101500z SELECT * FROM public.colaboradores;

CREATE TABLE archive.career_progression_events_20260828t101500z (LIKE public.career_progression_events INCLUDING ALL);
INSERT INTO archive.career_progression_events_20260828t101500z SELECT * FROM public.career_progression_events;

DO $$
DECLARE source_table text; backup_table text; source_count bigint; backup_count bigint; source_hash text; backup_hash text;
BEGIN
  FOR source_table,backup_table IN VALUES
    ('colaboradores_perfis','colaboradores_perfis_20260828t101500z'),
    ('colaboradores','colaboradores_20260828t101500z'),
    ('career_progression_events','career_progression_events_20260828t101500z')
  LOOP
    EXECUTE format('SELECT count(*),md5(coalesce(string_agg(md5(to_jsonb(t)::text),'''' ORDER BY t.id),'''')) FROM public.%I t',source_table)
      INTO source_count,source_hash;
    EXECUTE format('SELECT count(*),md5(coalesce(string_agg(md5(to_jsonb(t)::text),'''' ORDER BY t.id),'''')) FROM archive.%I t',backup_table)
      INTO backup_count,backup_hash;
    IF source_count<>backup_count OR source_hash<>backup_hash THEN RAISE EXCEPTION 'Backup divergente: %',source_table; END IF;
    INSERT INTO archive.progression_backup_manifest(
      backup_id,project_ref,source_schema,source_table,backup_schema,backup_table,
      source_count,backup_count,source_hash,backup_hash,restore_notes
    ) VALUES (
      'progression_closer_20260828t101500z','ygyiygqfiupadgnaaxlz','public',source_table,'archive',backup_table,
      source_count,backup_count,source_hash,backup_hash,
      'Checkpoint imediatamente anterior à migration 20260828120000. Restaurar somente em transação controlada.'
    );
  END LOOP;
END $$;

COMMIT;

SELECT jsonb_build_object(
  'backup_id',backup_id,
  'created_at',min(created_at),
  'tables',jsonb_agg(jsonb_build_object(
    'source',source_schema||'.'||source_table,
    'backup',backup_schema||'.'||backup_table,
    'source_count',source_count,
    'backup_count',backup_count,
    'hashes_match',source_hash=backup_hash
  ) ORDER BY source_table),
  'valid',bool_and(source_count=backup_count AND source_hash=backup_hash)
) AS backup_manifest
FROM archive.progression_backup_manifest
WHERE backup_id='progression_closer_20260828t101500z'
GROUP BY backup_id;
