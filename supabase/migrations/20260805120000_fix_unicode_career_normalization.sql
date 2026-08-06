-- Correct Unicode normalization order for career-domain values.
-- Convert case before translating accents so lowercase and uppercase accents
-- share the same canonical mapping. No table or operational data is changed.

CREATE OR REPLACE FUNCTION public.normalize_career_seniority(raw_value text)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path = pg_catalog, public AS $$
  WITH cleaned AS (
    SELECT regexp_replace(translate(upper(trim(coalesce(raw_value, ''))),
      'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ', 'AAAAAEEEEIIIIOOOOOUUUUC'), '[._ -]+', ' ', 'g') value
  )
  SELECT CASE value
    WHEN 'JUNIOR 1' THEN 'Júnior 1' WHEN 'JUNIOR I' THEN 'Júnior 1'
    WHEN 'JR 1' THEN 'Júnior 1' WHEN 'JR I' THEN 'Júnior 1'
    WHEN 'SDR I' THEN 'Júnior 1' WHEN 'SDR JUNIOR 1' THEN 'Júnior 1'
    WHEN 'SDR JUNIOR I' THEN 'Júnior 1' WHEN 'SDR JR 1' THEN 'Júnior 1' WHEN 'SDR JR I' THEN 'Júnior 1'
    WHEN 'JUNIOR 2' THEN 'Júnior 2' WHEN 'JUNIOR II' THEN 'Júnior 2'
    WHEN 'JR 2' THEN 'Júnior 2' WHEN 'JR II' THEN 'Júnior 2'
    WHEN 'SDR JUNIOR 2' THEN 'Júnior 2' WHEN 'SDR JUNIOR II' THEN 'Júnior 2'
    WHEN 'SDR JR 2' THEN 'Júnior 2' WHEN 'SDR JR II' THEN 'Júnior 2'
    WHEN 'JUNIOR 3' THEN 'Júnior 3' WHEN 'JUNIOR III' THEN 'Júnior 3'
    WHEN 'JR 3' THEN 'Júnior 3' WHEN 'JR III' THEN 'Júnior 3'
    WHEN 'SDR JUNIOR 3' THEN 'Júnior 3' WHEN 'SDR JUNIOR III' THEN 'Júnior 3'
    WHEN 'SDR JR 3' THEN 'Júnior 3' WHEN 'SDR JR III' THEN 'Júnior 3'
    WHEN 'PLENO 1' THEN 'Pleno 1' WHEN 'PLENO I' THEN 'Pleno 1'
    WHEN 'SDR PLENO 1' THEN 'Pleno 1' WHEN 'SDR PLENO I' THEN 'Pleno 1'
    WHEN 'PLENO 2' THEN 'Pleno 2' WHEN 'PLENO II' THEN 'Pleno 2'
    WHEN 'SDR PLENO 2' THEN 'Pleno 2' WHEN 'SDR PLENO II' THEN 'Pleno 2'
    WHEN 'PLENO 3' THEN 'Pleno 3' WHEN 'PLENO III' THEN 'Pleno 3'
    WHEN 'SDR PLENO 3' THEN 'Pleno 3' WHEN 'SDR PLENO III' THEN 'Pleno 3'
    WHEN 'SENIOR 1' THEN 'Sênior 1' WHEN 'SENIOR I' THEN 'Sênior 1'
    WHEN 'SR 1' THEN 'Sênior 1' WHEN 'SR I' THEN 'Sênior 1'
    WHEN 'SDR SENIOR 1' THEN 'Sênior 1' WHEN 'SDR SENIOR I' THEN 'Sênior 1'
    WHEN 'SENIOR 2' THEN 'Sênior 2' WHEN 'SENIOR II' THEN 'Sênior 2'
    WHEN 'SR 2' THEN 'Sênior 2' WHEN 'SR II' THEN 'Sênior 2'
    WHEN 'SDR SENIOR 2' THEN 'Sênior 2' WHEN 'SDR SENIOR II' THEN 'Sênior 2'
    WHEN 'SENIOR 3' THEN 'Sênior 3' WHEN 'SENIOR III' THEN 'Sênior 3'
    WHEN 'SR 3' THEN 'Sênior 3' WHEN 'SR III' THEN 'Sênior 3'
    WHEN 'SDR SENIOR 3' THEN 'Sênior 3' WHEN 'SDR SENIOR III' THEN 'Sênior 3'
    ELSE NULL END FROM cleaned
$$;

-- Canonical goal map: blank/AUSENTE => Sem presença; SEM META => Nenhuma meta.
CREATE OR REPLACE FUNCTION public.normalize_career_goal(raw_value text)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path = pg_catalog, public AS $$
  SELECT CASE regexp_replace(translate(upper(trim(coalesce(raw_value, ''))),
    'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ', 'AAAAAEEEEIIIIOOOOOUUUUC'), '[[:space:]]+', ' ', 'g')
    WHEN '' THEN 'Sem presença' WHEN 'SEM PRESENCA' THEN 'Sem presença' WHEN 'AUSENTE' THEN 'Sem presença'
    WHEN 'META 1' THEN 'Meta 1' WHEN 'META 2' THEN 'Meta 2' WHEN 'META 3' THEN 'Meta 3'
    WHEN 'NENHUMA META' THEN 'Nenhuma meta' WHEN 'SEM META' THEN 'Nenhuma meta'
    ELSE NULL END
$$;

CREATE OR REPLACE FUNCTION public.parse_legacy_competencia(raw_value text)
RETURNS date LANGUAGE sql IMMUTABLE SET search_path = pg_catalog, public AS $$
  WITH cleaned AS (
    SELECT translate(lower(regexp_replace(trim(coalesce(raw_value, '')), '[[:space:]]+', ' ', 'g')),
      'áàâãäéèêëíìîïóòôõöúùûüç', 'aaaaaeeeeiiiiooooouuuuc') value
  )
  SELECT CASE value
    WHEN 'janeiro' THEN date '2026-01-01' WHEN 'fevereiro' THEN date '2026-02-01'
    WHEN 'marco' THEN date '2026-03-01' WHEN 'abril' THEN date '2026-04-01'
    WHEN 'maio' THEN date '2026-05-01' WHEN 'junho' THEN date '2026-06-01'
    WHEN 'julho' THEN date '2026-07-01' WHEN 'agosto' THEN date '2026-08-01'
    WHEN 'setembro' THEN date '2026-09-01' WHEN 'outubro' THEN date '2026-10-01'
    WHEN 'novembro' THEN date '2026-11-01' WHEN 'dezembro' THEN date '2026-12-01'
    ELSE CASE WHEN value ~ '^\d{4}-(0[1-9]|1[0-2])-01$' THEN value::date ELSE NULL END END
  FROM cleaned
$$;

-- Preserve the private execution surface established by the principal migration.
REVOKE ALL ON FUNCTION public.normalize_career_goal(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.normalize_career_seniority(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.parse_legacy_competencia(text) FROM PUBLIC, anon, authenticated;
