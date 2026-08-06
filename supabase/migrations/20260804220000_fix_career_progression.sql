-- Career progression, stage 1. This migration is intentionally not applied remotely.
CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

CREATE TABLE IF NOT EXISTS public.colaboradores (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nome_colaborador text,
  posicao text,
  squad text,
  meta_alcancada text,
  senioridade text,
  recebeu_promocao text,
  mes_referencia text
);

DO $$
DECLARE invalid_values text;
BEGIN
  SELECT string_agg(format('%L (%s)', raw_value, occurrences), ', ' ORDER BY raw_value)
  INTO invalid_values
  FROM (
    SELECT trim(recebeu_promocao::text) raw_value, count(*) occurrences
    FROM public.colaboradores
    WHERE recebeu_promocao IS NOT NULL
      AND lower(trim(recebeu_promocao::text)) NOT IN
        ('true','t','1','sim','yes','false','f','0','não','nao','no','')
    GROUP BY trim(recebeu_promocao::text)
  ) invalid;
  IF invalid_values IS NOT NULL THEN
    RAISE EXCEPTION 'recebeu_promocao contém valores inválidos: %', invalid_values;
  END IF;
END $$;

ALTER TABLE public.colaboradores ALTER COLUMN recebeu_promocao DROP DEFAULT;
ALTER TABLE public.colaboradores ALTER COLUMN recebeu_promocao TYPE boolean USING CASE
  WHEN recebeu_promocao IS NULL THEN false
  WHEN lower(trim(recebeu_promocao::text)) IN ('true','t','1','sim','yes') THEN true
  ELSE false END;
ALTER TABLE public.colaboradores
  ALTER COLUMN recebeu_promocao SET DEFAULT false,
  ALTER COLUMN recebeu_promocao SET NOT NULL,
  ALTER COLUMN id SET DEFAULT gen_random_uuid(),
  ALTER COLUMN id SET NOT NULL,
  ADD COLUMN IF NOT EXISTS colaborador_id uuid,
  ADD COLUMN IF NOT EXISTS competencia date,
  ADD COLUMN IF NOT EXISTS senioridade_informada text,
  ADD COLUMN IF NOT EXISTS origem text,
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
CREATE UNIQUE INDEX IF NOT EXISTS colaboradores_id_official_key ON public.colaboradores(id);

CREATE OR REPLACE FUNCTION public.normalize_career_name(raw_value text)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path = pg_catalog, public AS $$
  SELECT nullif(lower(regexp_replace(trim(coalesce(raw_value, '')), '[[:space:]]+', ' ', 'g')), '')
$$;

CREATE OR REPLACE FUNCTION public.normalize_career_seniority(raw_value text)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path = pg_catalog, public AS $$
  WITH cleaned AS (
    SELECT regexp_replace(upper(translate(trim(coalesce(raw_value, '')),
      'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ', 'AAAAAEEEEIIIIOOOOOUUUUC')), '[._ -]+', ' ', 'g') value
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
  SELECT CASE regexp_replace(upper(translate(trim(coalesce(raw_value, '')), 'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ', 'AAAAAEEEEIIIIOOOOOUUUUC')), '[[:space:]]+', ' ', 'g')
    WHEN '' THEN 'Sem presença' WHEN 'SEM PRESENCA' THEN 'Sem presença' WHEN 'AUSENTE' THEN 'Sem presença'
    WHEN 'META 1' THEN 'Meta 1' WHEN 'META 2' THEN 'Meta 2' WHEN 'META 3' THEN 'Meta 3'
    WHEN 'NENHUMA META' THEN 'Nenhuma meta' WHEN 'SEM META' THEN 'Nenhuma meta'
    ELSE NULL END
$$;

CREATE OR REPLACE FUNCTION public.next_career_seniority(raw_value text)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path = pg_catalog, public AS $$
  SELECT CASE public.normalize_career_seniority(raw_value)
    WHEN 'Júnior 1' THEN 'Júnior 2' WHEN 'Júnior 2' THEN 'Júnior 3'
    WHEN 'Júnior 3' THEN 'Pleno 1' WHEN 'Pleno 1' THEN 'Pleno 2'
    WHEN 'Pleno 2' THEN 'Pleno 3' WHEN 'Pleno 3' THEN 'Sênior 1'
    WHEN 'Sênior 1' THEN 'Sênior 2' WHEN 'Sênior 2' THEN 'Sênior 3'
    ELSE NULL END
$$;

CREATE OR REPLACE FUNCTION public.parse_legacy_competencia(raw_value text)
RETURNS date LANGUAGE sql IMMUTABLE SET search_path = pg_catalog, public AS $$
  WITH cleaned AS (
    SELECT lower(translate(regexp_replace(trim(coalesce(raw_value, '')), '[[:space:]]+', ' ', 'g'),
      'áàâãäéèêëíìîïóòôõöúùûüç', 'aaaaaeeeeiiiiooooouuuuc')) value
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

UPDATE public.colaboradores
SET senioridade_informada = senioridade
WHERE senioridade_informada IS NULL;
UPDATE public.colaboradores
SET competencia = public.parse_legacy_competencia(mes_referencia)
WHERE competencia IS NULL AND public.parse_legacy_competencia(mes_referencia) IS NOT NULL;

ALTER TABLE public.colaboradores DROP CONSTRAINT IF EXISTS colaboradores_competencia_primeiro_dia;
ALTER TABLE public.colaboradores ADD CONSTRAINT colaboradores_competencia_primeiro_dia
  CHECK (competencia IS NULL OR competencia = date_trunc('month', competencia)::date);

CREATE TABLE IF NOT EXISTS public.colaboradores_perfis (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nome_colaborador text NOT NULL,
  nome_normalizado text NOT NULL UNIQUE,
  posicao_atual text,
  squad_atual text,
  senioridade_atual text NOT NULL,
  progresso_meta3 integer NOT NULL DEFAULT 0 CHECK (progresso_meta3 BETWEEN 0 AND 2),
  ativo boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT colaboradores_perfis_nome_normalizado_canonico CHECK (nome_normalizado = public.normalize_career_name(nome_colaborador)),
  CONSTRAINT colaboradores_perfis_senioridade_valida CHECK (public.normalize_career_seniority(senioridade_atual) = senioridade_atual)
);

CREATE TABLE IF NOT EXISTS public.career_migration_issues (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  issue_type text NOT NULL,
  colaboradores_id uuid REFERENCES public.colaboradores(id),
  raw_value text,
  details text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.career_migration_issues) THEN
    RAISE EXCEPTION
      'Migration interrompida: public.career_migration_issues contém registros inesperados; revise-os sem exclusão automática.';
  END IF;
END $$;

INSERT INTO public.career_migration_issues(issue_type,colaboradores_id,raw_value,details)
SELECT 'nome_invalido',id,nome_colaborador,'Nome vazio não permite associação segura.' FROM public.colaboradores WHERE public.normalize_career_name(nome_colaborador) IS NULL
UNION ALL
SELECT 'competencia_invalida',id,mes_referencia,'Mês legado não corresponde inequivocamente a uma competência.' FROM public.colaboradores WHERE competencia IS NULL
UNION ALL
SELECT 'meta_invalida',id,meta_alcancada,'Meta desconhecida; não foi convertida para ausência ou reinício.' FROM public.colaboradores WHERE public.normalize_career_goal(meta_alcancada) IS NULL
UNION ALL
SELECT 'senioridade_invalida',id,senioridade_informada,'Senioridade de bootstrap fora da lista oficial.'
FROM public.colaboradores
WHERE public.normalize_career_seniority(senioridade_informada) IS NULL
  AND NOT (
    public.normalize_career_goal(meta_alcancada)='Sem presença'
    AND nullif(trim(coalesce(senioridade_informada,'')),'') IS NULL
  );

-- A null informed level is allowed only for neutral absence; another chronological row must bootstrap the person.

INSERT INTO public.career_migration_issues(issue_type,colaboradores_id,raw_value,details)
SELECT 'senioridade_bootstrap_ausente',(array_agg(id ORDER BY id::text))[1],public.normalize_career_name(nome_colaborador),
  'Colaborador não possui nenhum resultado com senioridade_informada válida para bootstrap.'
FROM public.colaboradores
WHERE public.normalize_career_name(nome_colaborador) IS NOT NULL
GROUP BY public.normalize_career_name(nome_colaborador)
HAVING count(*) FILTER (WHERE public.normalize_career_seniority(senioridade_informada) IS NOT NULL)=0;

INSERT INTO public.career_migration_issues(issue_type,colaboradores_id,raw_value,details)
SELECT 'resultado_duplicado', (array_agg(id ORDER BY id::text))[1], public.normalize_career_name(nome_colaborador) || '|' || competencia,
       'IDs: ' || string_agg(id::text, ', ' ORDER BY id)
FROM public.colaboradores
WHERE public.normalize_career_name(nome_colaborador) IS NOT NULL AND competencia IS NOT NULL
GROUP BY public.normalize_career_name(nome_colaborador), competencia HAVING count(*) > 1;

DO $$
DECLARE diagnostics text;
BEGIN
  SELECT string_agg(issue_type || ': ' || coalesce(raw_value,'NULL') || ' (' || details || ')', E'\n' ORDER BY id)
  INTO diagnostics FROM public.career_migration_issues
  WHERE issue_type IN ('nome_invalido','competencia_invalida','meta_invalida','senioridade_invalida','senioridade_bootstrap_ausente','resultado_duplicado');
  IF diagnostics IS NOT NULL THEN
    RAISE EXCEPTION USING MESSAGE = 'Backfill interrompido por dados ambíguos', DETAIL = diagnostics,
      HINT = 'Execute supabase/preflight/legacy_data.sql, resolva explicitamente cada registro e reaplique.';
  END IF;
END $$;

-- One profile per normalized full name. Latest row determines display name, squad and position.
INSERT INTO public.colaboradores_perfis(nome_colaborador,nome_normalizado,posicao_atual,squad_atual,senioridade_atual)
SELECT DISTINCT ON (public.normalize_career_name(latest.nome_colaborador))
  latest.nome_colaborador,
  public.normalize_career_name(latest.nome_colaborador),
  latest.posicao,
  latest.squad,
  (
    SELECT public.normalize_career_seniority(first_valid.senioridade_informada)
    FROM public.colaboradores first_valid
    WHERE public.normalize_career_name(first_valid.nome_colaborador)=public.normalize_career_name(latest.nome_colaborador)
      AND public.normalize_career_seniority(first_valid.senioridade_informada) IS NOT NULL
    ORDER BY first_valid.competencia,first_valid.id LIMIT 1
  )
FROM public.colaboradores latest
ORDER BY public.normalize_career_name(latest.nome_colaborador), latest.competencia DESC, latest.id DESC
ON CONFLICT (nome_normalizado) DO UPDATE SET
  nome_colaborador=excluded.nome_colaborador, posicao_atual=excluded.posicao_atual,
  squad_atual=excluded.squad_atual, updated_at=now();

UPDATE public.colaboradores c SET colaborador_id=p.id
FROM public.colaboradores_perfis p
WHERE p.nome_normalizado=public.normalize_career_name(c.nome_colaborador)
  AND (c.colaborador_id IS NULL OR c.colaborador_id<>p.id);

ALTER TABLE public.colaboradores DROP CONSTRAINT IF EXISTS colaboradores_colaborador_id_fkey;
ALTER TABLE public.colaboradores ADD CONSTRAINT colaboradores_colaborador_id_fkey
  FOREIGN KEY(colaborador_id) REFERENCES public.colaboradores_perfis(id) NOT VALID;
ALTER TABLE public.colaboradores VALIDATE CONSTRAINT colaboradores_colaborador_id_fkey;
CREATE UNIQUE INDEX IF NOT EXISTS colaboradores_colaborador_competencia_key
  ON public.colaboradores(colaborador_id,competencia);

CREATE OR REPLACE FUNCTION public.recalcular_progressao_colaborador(p_colaborador_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE
  profile public.colaboradores_perfis%ROWTYPE;
  item public.colaboradores%ROWTYPE;
  current_level text;
  next_level text;
  current_progress integer := 0;
  promoted boolean;
  normalized_goal text;
  latest_name text;
  latest_squad text;
  latest_position text;
BEGIN
  SELECT * INTO STRICT profile FROM public.colaboradores_perfis WHERE id=p_colaborador_id FOR UPDATE;
  SELECT public.normalize_career_seniority(senioridade_informada) INTO current_level
  FROM public.colaboradores
  WHERE colaborador_id=p_colaborador_id
    AND public.normalize_career_seniority(senioridade_informada) IS NOT NULL
  ORDER BY competencia,id LIMIT 1;
  IF current_level IS NULL THEN
    SELECT public.normalize_career_seniority(senioridade) INTO current_level
    FROM public.colaboradores WHERE colaborador_id=p_colaborador_id
    ORDER BY competencia,id LIMIT 1;
  END IF;
  IF current_level IS NULL THEN RAISE EXCEPTION 'Sem senioridade inicial válida para %',p_colaborador_id USING ERRCODE='22023'; END IF;

  FOR item IN SELECT * FROM public.colaboradores WHERE colaborador_id=p_colaborador_id ORDER BY competencia,id FOR UPDATE LOOP
    normalized_goal := public.normalize_career_goal(item.meta_alcancada);
    IF normalized_goal IS NULL THEN RAISE EXCEPTION 'Meta inválida no resultado %',item.id USING ERRCODE='22023'; END IF;
    promoted := false;
    IF normalized_goal='Meta 3' THEN
      IF current_progress=2 AND public.next_career_seniority(current_level) IS NOT NULL THEN
        next_level:=public.next_career_seniority(current_level); promoted:=true; current_progress:=0;
      ELSE current_progress:=least(current_progress+1,2); END IF;
    ELSIF normalized_goal='Nenhuma meta' THEN current_progress:=0;
    END IF; -- Meta 1, Meta 2 and Sem presença preserve exactly.

    UPDATE public.colaboradores SET meta_alcancada=normalized_goal, senioridade=current_level,
      recebeu_promocao=promoted, updated_at=now() WHERE id=item.id;
    IF promoted THEN current_level:=next_level; END IF;
  END LOOP;

  SELECT nome_colaborador,squad,posicao INTO latest_name,latest_squad,latest_position
  FROM public.colaboradores WHERE colaborador_id=p_colaborador_id ORDER BY competencia DESC,id DESC LIMIT 1;
  UPDATE public.colaboradores_perfis SET nome_colaborador=latest_name,
    nome_normalizado=public.normalize_career_name(latest_name), squad_atual=latest_squad,
    posicao_atual=latest_position, senioridade_atual=current_level,
    progresso_meta3=current_progress, updated_at=now() WHERE id=p_colaborador_id;
END $$;

DO $$ DECLARE person uuid; BEGIN
  FOR person IN SELECT id FROM public.colaboradores_perfis LOOP
    PERFORM public.recalcular_progressao_colaborador(person);
  END LOOP;
END $$;

INSERT INTO public.career_migration_issues(issue_type,colaboradores_id,raw_value,details)
SELECT 'senioridade_informada_divergente',c.id,c.senioridade_informada,
  'Valor informado preservado para auditoria; senioridade calculada aplicada: '||c.senioridade
FROM public.colaboradores c
WHERE public.normalize_career_seniority(c.senioridade_informada) IS DISTINCT FROM c.senioridade;

CREATE OR REPLACE FUNCTION public.registrar_resultado_mensal(p_colaborador_id uuid,p_competencia date,p_meta text)
RETURNS public.colaboradores LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE profile public.colaboradores_perfis%ROWTYPE; existing public.colaboradores%ROWTYPE;
  inserted public.colaboradores%ROWTYPE; normalized_goal text;
BEGIN
  IF p_colaborador_id IS NULL THEN RAISE EXCEPTION 'colaborador_id é obrigatório' USING ERRCODE='22023'; END IF;
  IF p_competencia IS NULL OR p_competencia<>date_trunc('month',p_competencia)::date THEN
    RAISE EXCEPTION 'competencia deve ser o primeiro dia do mês' USING ERRCODE='22023'; END IF;
  normalized_goal:=public.normalize_career_goal(p_meta);
  IF normalized_goal IS NULL THEN RAISE EXCEPTION 'meta inválida: %',p_meta USING ERRCODE='22023'; END IF;
  SELECT * INTO profile FROM public.colaboradores_perfis WHERE id=p_colaborador_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'colaborador não encontrado: %',p_colaborador_id USING ERRCODE='P0002'; END IF;
  SELECT * INTO existing FROM public.colaboradores WHERE colaborador_id=p_colaborador_id AND competencia=p_competencia;
  IF FOUND THEN
    IF public.normalize_career_goal(existing.meta_alcancada)=normalized_goal THEN RETURN existing; END IF;
    RAISE EXCEPTION 'já existe resultado para este colaborador e competência' USING ERRCODE='23505';
  END IF;
  INSERT INTO public.colaboradores(colaborador_id,competencia,mes_referencia,nome_colaborador,posicao,squad,
    meta_alcancada,senioridade_informada,senioridade,recebeu_promocao)
  VALUES(profile.id,p_competencia,to_char(p_competencia,'YYYY-MM'),profile.nome_colaborador,profile.posicao_atual,
    profile.squad_atual,normalized_goal,profile.senioridade_atual,profile.senioridade_atual,false) RETURNING * INTO inserted;
  PERFORM public.recalcular_progressao_colaborador(profile.id);
  SELECT * INTO inserted FROM public.colaboradores WHERE id=inserted.id;
  RETURN inserted;
END $$;

CREATE OR REPLACE FUNCTION public.sincronizar_progressao_planilha(
  p_perfis jsonb,
  p_resultados jsonb,
  p_origem text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  item jsonb;
  profile public.colaboradores_perfis%ROWTYPE;
  existing public.colaboradores%ROWTYPE;
  normalized_name text;
  normalized_goal text;
  normalized_seniority text;
  parsed_competence date;
  bootstrap_seniority text;
  affected_ids uuid[] := ARRAY[]::uuid[];
  affected_id uuid;
  profiles_received integer := 0;
  profiles_inserted integer := 0;
  profiles_updated integer := 0;
  results_received integer := 0;
  results_inserted integer := 0;
  results_corrected integer := 0;
  results_ignored integer := 0;
  recalculated integer := 0;
BEGIN
  IF p_perfis IS NULL OR jsonb_typeof(p_perfis) <> 'array' THEN
    RAISE EXCEPTION 'p_perfis deve ser um array JSON' USING ERRCODE = '22023';
  END IF;
  IF p_resultados IS NULL OR jsonb_typeof(p_resultados) <> 'array' THEN
    RAISE EXCEPTION 'p_resultados deve ser um array JSON' USING ERRCODE = '22023';
  END IF;
  IF nullif(trim(p_origem), '') IS NULL THEN
    RAISE EXCEPTION 'p_origem é obrigatório' USING ERRCODE = '22023';
  END IF;
  profiles_received := jsonb_array_length(p_perfis);
  results_received := jsonb_array_length(p_resultados);

  -- Validate the complete batch before the first write, so domain failures are all-or-nothing.
  FOR item IN SELECT value FROM jsonb_array_elements(p_perfis) LOOP
    IF jsonb_typeof(item) <> 'object' THEN
      RAISE EXCEPTION 'cada item de p_perfis deve ser um objeto JSON' USING ERRCODE = '22023';
    END IF;
    normalized_name := public.normalize_career_name(item->>'nome_colaborador');
    IF normalized_name IS NULL THEN
      RAISE EXCEPTION 'perfil com nome_colaborador vazio' USING ERRCODE = '22023';
    END IF;
    IF NOT item ? 'ativo' OR jsonb_typeof(item->'ativo') <> 'boolean' THEN
      RAISE EXCEPTION 'ativo deve ser boolean para %', item->>'nome_colaborador' USING ERRCODE = '22023';
    END IF;
    -- "Saiu" is an explicit, valid operational squad for inactive profiles; no closed squad enum is used.
    IF NOT item ? 'squad' OR jsonb_typeof(item->'squad') <> 'string' OR nullif(trim(item->>'squad'), '') IS NULL THEN
      RAISE EXCEPTION 'squad deve ser texto não vazio para %', item->>'nome_colaborador' USING ERRCODE = '22023';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.colaboradores_perfis p WHERE p.nome_normalizado = normalized_name)
      AND NOT EXISTS (
        SELECT 1 FROM jsonb_array_elements(p_resultados) r
        WHERE public.normalize_career_name(r->>'nome_colaborador') = normalized_name
      ) THEN
      RAISE EXCEPTION 'perfil novo sem resultado para bootstrap de senioridade: %', item->>'nome_colaborador' USING ERRCODE = '22023';
    END IF;
  END LOOP;

  IF EXISTS (
    SELECT 1 FROM jsonb_array_elements(p_perfis) value
    GROUP BY public.normalize_career_name(value->>'nome_colaborador') HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION 'p_perfis contém nomes equivalentes duplicados' USING ERRCODE = '22023';
  END IF;

  FOR item IN SELECT value FROM jsonb_array_elements(p_resultados) LOOP
    IF jsonb_typeof(item) <> 'object' THEN
      RAISE EXCEPTION 'cada item de p_resultados deve ser um objeto JSON' USING ERRCODE = '22023';
    END IF;
    normalized_name := public.normalize_career_name(item->>'nome_colaborador');
    IF normalized_name IS NULL THEN
      RAISE EXCEPTION 'resultado com nome_colaborador vazio' USING ERRCODE = '22023';
    END IF;
    IF coalesce(item->>'competencia', '') !~ '^\d{4}-(0[1-9]|1[0-2])-01$' THEN
      RAISE EXCEPTION 'competencia inválida para %: %', item->>'nome_colaborador', item->>'competencia' USING ERRCODE = '22023';
    END IF;
    parsed_competence := (item->>'competencia')::date;
    normalized_goal := public.normalize_career_goal(item->>'meta_alcancada');
    IF normalized_goal IS NULL THEN
      RAISE EXCEPTION 'meta inválida para %: %', item->>'nome_colaborador', item->>'meta_alcancada' USING ERRCODE = '22023';
    END IF;
    normalized_seniority := public.normalize_career_seniority(item->>'senioridade_informada');
    IF normalized_seniority IS NULL AND NOT (
      normalized_goal = 'Sem presença'
      AND nullif(trim(coalesce(item->>'senioridade_informada', '')), '') IS NULL
    ) THEN
      RAISE EXCEPTION 'senioridade inválida para %: %', item->>'nome_colaborador', item->>'senioridade_informada' USING ERRCODE = '22023';
    END IF;
    IF NOT item ? 'squad' OR jsonb_typeof(item->'squad') <> 'string' OR nullif(trim(item->>'squad'), '') IS NULL THEN
      RAISE EXCEPTION 'squad deve ser texto não vazio para %', item->>'nome_colaborador' USING ERRCODE = '22023';
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM jsonb_array_elements(p_perfis) p
      WHERE public.normalize_career_name(p->>'nome_colaborador') = normalized_name
    ) AND NOT EXISTS (
      SELECT 1 FROM public.colaboradores_perfis p WHERE p.nome_normalizado = normalized_name
    ) THEN
      RAISE EXCEPTION 'resultado sem perfil conhecido no lote ou banco: %', item->>'nome_colaborador' USING ERRCODE = '22023';
    END IF;
  END LOOP;

  IF EXISTS (
    SELECT 1 FROM jsonb_array_elements(p_resultados) value
    GROUP BY public.normalize_career_name(value->>'nome_colaborador'), value->>'competencia'
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION 'p_resultados contém colaborador/competência duplicado' USING ERRCODE = '22023';
  END IF;

  FOR item IN SELECT value FROM jsonb_array_elements(p_perfis) LOOP
    normalized_name := public.normalize_career_name(item->>'nome_colaborador');
    -- Serializes concurrent upserts for the same operational identity, including the not-yet-existing row.
    PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(normalized_name, 0));
    SELECT * INTO profile FROM public.colaboradores_perfis
    WHERE nome_normalizado = normalized_name FOR UPDATE;
    IF FOUND THEN
      UPDATE public.colaboradores_perfis SET
        nome_colaborador = trim(regexp_replace(item->>'nome_colaborador', '[[:space:]]+', ' ', 'g')),
        posicao_atual = nullif(trim(item->>'posicao'), ''),
        squad_atual = nullif(trim(item->>'squad'), ''),
        ativo = (item->>'ativo')::boolean,
        updated_at = now()
      WHERE id = profile.id;
      profiles_updated := profiles_updated + 1;
    ELSE
      SELECT public.normalize_career_seniority(r->>'senioridade_informada') INTO bootstrap_seniority
      FROM jsonb_array_elements(p_resultados) r
      WHERE public.normalize_career_name(r->>'nome_colaborador') = normalized_name
        AND public.normalize_career_seniority(r->>'senioridade_informada') IS NOT NULL
      ORDER BY (r->>'competencia')::date LIMIT 1;
      IF bootstrap_seniority IS NULL THEN
        RAISE EXCEPTION 'perfil novo sem resultado para bootstrap de senioridade: %', item->>'nome_colaborador' USING ERRCODE = '22023';
      END IF;
      INSERT INTO public.colaboradores_perfis(
        nome_colaborador,nome_normalizado,posicao_atual,squad_atual,senioridade_atual,progresso_meta3,ativo
      ) VALUES (
        trim(regexp_replace(item->>'nome_colaborador', '[[:space:]]+', ' ', 'g')),
        normalized_name,nullif(trim(item->>'posicao'),''),nullif(trim(item->>'squad'),''),
        bootstrap_seniority,0,(item->>'ativo')::boolean
      );
      profiles_inserted := profiles_inserted + 1;
    END IF;
  END LOOP;

  FOR item IN
    SELECT value FROM jsonb_array_elements(p_resultados)
    ORDER BY (value->>'competencia')::date, public.normalize_career_name(value->>'nome_colaborador')
  LOOP
    normalized_name := public.normalize_career_name(item->>'nome_colaborador');
    normalized_goal := public.normalize_career_goal(item->>'meta_alcancada');
    normalized_seniority := public.normalize_career_seniority(item->>'senioridade_informada');
    parsed_competence := (item->>'competencia')::date;
    SELECT * INTO STRICT profile FROM public.colaboradores_perfis WHERE nome_normalizado = normalized_name FOR UPDATE;
    IF NOT profile.id = ANY(affected_ids) THEN affected_ids := array_append(affected_ids, profile.id); END IF;

    SELECT * INTO existing FROM public.colaboradores
    WHERE colaborador_id = profile.id AND competencia = parsed_competence FOR UPDATE;
    IF FOUND THEN
      IF public.normalize_career_goal(existing.meta_alcancada) = normalized_goal
        AND public.normalize_career_seniority(existing.senioridade_informada) = normalized_seniority THEN
        results_ignored := results_ignored + 1;
      ELSE
        UPDATE public.colaboradores SET
          meta_alcancada = normalized_goal,
          senioridade_informada = normalized_seniority,
          origem = trim(p_origem),
          updated_at = now()
        WHERE id = existing.id;
        results_corrected := results_corrected + 1;
      END IF;
    ELSE
      INSERT INTO public.colaboradores(
        colaborador_id,nome_colaborador,competencia,mes_referencia,posicao,squad,
        senioridade,senioridade_informada,meta_alcancada,recebeu_promocao,origem
      ) VALUES (
        profile.id,trim(regexp_replace(item->>'nome_colaborador','[[:space:]]+',' ','g')),
        parsed_competence,to_char(parsed_competence,'YYYY-MM'),nullif(trim(item->>'posicao'),''),
        nullif(trim(item->>'squad'),''),profile.senioridade_atual,normalized_seniority,
        normalized_goal,false,trim(p_origem)
      );
      results_inserted := results_inserted + 1;
    END IF;
  END LOOP;

  FOREACH affected_id IN ARRAY affected_ids LOOP
    PERFORM public.recalcular_progressao_colaborador(affected_id);
    recalculated := recalculated + 1;
  END LOOP;

  -- The profile payload represents current operational data and wins over old historical squad/position.
  FOR item IN SELECT value FROM jsonb_array_elements(p_perfis) LOOP
    UPDATE public.colaboradores_perfis SET
      nome_colaborador = trim(regexp_replace(item->>'nome_colaborador', '[[:space:]]+', ' ', 'g')),
      posicao_atual = nullif(trim(item->>'posicao'), ''),
      squad_atual = nullif(trim(item->>'squad'), ''),
      ativo = (item->>'ativo')::boolean,
      updated_at = now()
    WHERE nome_normalizado = public.normalize_career_name(item->>'nome_colaborador');
  END LOOP;

  RETURN jsonb_build_object(
    'ok',true,'origem',trim(p_origem),
    'perfis_recebidos',profiles_received,'perfis_inseridos',profiles_inserted,'perfis_atualizados',profiles_updated,
    'resultados_recebidos',results_received,'resultados_inseridos',results_inserted,
    'resultados_corrigidos',results_corrected,'resultados_ignorados',results_ignored,
    'colaboradores_recalculados',recalculated
  );
END $$;

CREATE OR REPLACE FUNCTION public.set_career_updated_at() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog,public AS $$
BEGIN NEW.updated_at:=now(); RETURN NEW; END $$;
DROP TRIGGER IF EXISTS set_colaboradores_perfis_updated_at ON public.colaboradores_perfis;
CREATE TRIGGER set_colaboradores_perfis_updated_at BEFORE UPDATE ON public.colaboradores_perfis
FOR EACH ROW EXECUTE FUNCTION public.set_career_updated_at();

DO $optional_sdrs$
BEGIN
  IF to_regclass('public.sdrs') IS NOT NULL THEN
    EXECUTE $sql$COMMENT ON TABLE public.sdrs IS 'LEGACY: não é fonte de estado atual; mantida nesta etapa.'$sql$;
    EXECUTE $sql$DROP POLICY IF EXISTS "Public insert sdrs" ON public.sdrs$sql$;
    EXECUTE $sql$DROP POLICY IF EXISTS "Public update sdrs" ON public.sdrs$sql$;
    EXECUTE $sql$DROP POLICY IF EXISTS "Public delete sdrs" ON public.sdrs$sql$;
  END IF;
END
$optional_sdrs$;
COMMENT ON COLUMN public.colaboradores.senioridade_informada IS 'Valor original da planilha, somente auditoria/bootstrap.';
COMMENT ON COLUMN public.colaboradores.senioridade IS 'Senioridade histórica calculada antes do resultado mensal.';
COMMENT ON COLUMN public.colaboradores.origem IS 'Origem da criação ou última correção dos campos de entrada do resultado.';

ALTER TABLE public.colaboradores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.colaboradores_perfis ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.career_migration_issues ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Career results are readable" ON public.colaboradores FOR SELECT TO anon,authenticated USING(true);
CREATE POLICY "Career profiles are readable" ON public.colaboradores_perfis FOR SELECT TO anon,authenticated USING(true);
CREATE POLICY "Migration issues are authenticated-readable" ON public.career_migration_issues FOR SELECT TO authenticated USING(true);
REVOKE ALL ON FUNCTION public.registrar_resultado_mensal(uuid,date,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.registrar_resultado_mensal(uuid,date,text) TO service_role;
REVOKE ALL ON FUNCTION public.recalcular_progressao_colaborador(uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.sincronizar_progressao_planilha(jsonb,jsonb,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sincronizar_progressao_planilha(jsonb,jsonb,text) TO service_role;
REVOKE ALL ON FUNCTION public.normalize_career_name(text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.normalize_career_goal(text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.normalize_career_seniority(text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.next_career_seniority(text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.parse_legacy_competencia(text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.set_career_updated_at() FROM PUBLIC,anon,authenticated;
REVOKE INSERT,UPDATE,DELETE ON public.colaboradores,public.colaboradores_perfis FROM anon,authenticated;
GRANT SELECT ON public.colaboradores,public.colaboradores_perfis TO anon,authenticated;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='colaboradores') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.colaboradores; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='colaboradores_perfis') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.colaboradores_perfis; END IF;
END $$;
