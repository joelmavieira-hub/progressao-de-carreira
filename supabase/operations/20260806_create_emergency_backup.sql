BEGIN;

LOCK TABLE public.colaboradores_perfis, public.colaboradores, public.career_progression_events IN SHARE MODE;

CREATE TABLE archive.colaboradores_perfis_20260806t130602z
  (LIKE public.colaboradores_perfis INCLUDING ALL);
INSERT INTO archive.colaboradores_perfis_20260806t130602z SELECT * FROM public.colaboradores_perfis;

CREATE TABLE archive.colaboradores_20260806t130602z
  (LIKE public.colaboradores INCLUDING ALL);
INSERT INTO archive.colaboradores_20260806t130602z SELECT * FROM public.colaboradores;

CREATE TABLE archive.career_progression_events_20260806t130602z
  (LIKE public.career_progression_events INCLUDING ALL);
INSERT INTO archive.career_progression_events_20260806t130602z SELECT * FROM public.career_progression_events;

DO $$
DECLARE
  source_table text;
  backup_table text;
  source_count bigint;
  backup_count bigint;
  source_hash text;
  backup_hash text;
BEGIN
  FOR source_table, backup_table IN VALUES
    ('colaboradores_perfis','colaboradores_perfis_20260806t130602z'),
    ('colaboradores','colaboradores_20260806t130602z'),
    ('career_progression_events','career_progression_events_20260806t130602z')
  LOOP
    EXECUTE format('SELECT count(*),md5(coalesce(string_agg(md5(to_jsonb(t)::text),'''' ORDER BY t.id),'''')) FROM public.%I t',source_table)
      INTO source_count,source_hash;
    EXECUTE format('SELECT count(*),md5(coalesce(string_agg(md5(to_jsonb(t)::text),'''' ORDER BY t.id),'''')) FROM archive.%I t',backup_table)
      INTO backup_count,backup_hash;
    IF source_count<>backup_count OR source_hash<>backup_hash THEN
      RAISE EXCEPTION 'Backup divergente: %',source_table;
    END IF;
    INSERT INTO archive.progression_backup_manifest(
      backup_id,project_ref,source_schema,source_table,backup_schema,backup_table,
      source_count,backup_count,source_hash,backup_hash,restore_notes
    ) VALUES (
      'progression_20260806t130602z','ygyiygqfiupadgnaaxlz','public',source_table,'archive',backup_table,
      source_count,backup_count,source_hash,backup_hash,
      'Restauração somente em transação controlada, preservando IDs, FKs e registros fora do escopo.'
    );
  END LOOP;
END $$;

COMMIT;

SELECT jsonb_build_object(
  'backup_id',backup_id,'project_ref',min(project_ref),
  'tables',jsonb_agg(jsonb_build_object(
    'source',source_schema||'.'||source_table,'backup',backup_schema||'.'||backup_table,
    'source_count',source_count,'backup_count',backup_count,
    'source_hash',source_hash,'backup_hash',backup_hash,'hashes_match',source_hash=backup_hash
  ) ORDER BY source_table),
  'valid',bool_and(source_count=backup_count AND source_hash=backup_hash)
) AS backup_manifest
FROM archive.progression_backup_manifest
WHERE backup_id='progression_20260806t130602z'
GROUP BY backup_id;
