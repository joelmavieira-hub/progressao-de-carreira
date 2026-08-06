-- READ ONLY. Self-contained diagnostics before applying the migration and enabling
-- sincronizar_progressao_planilha. It intentionally has no dependency on new RPC helpers.
-- Blank goals are valid and mean "Sem presença".
WITH raw AS (
  SELECT c.*,
    nullif(lower(regexp_replace(trim(coalesce(nome_colaborador,'')),'[[:space:]]+',' ','g')),'') nome_normalizado,
    regexp_replace(upper(translate(trim(coalesce(meta_alcancada,'')),'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','AAAAAEEEEIIIIOOOOOUUUUC')),'[[:space:]]+',' ','g') meta_key,
    regexp_replace(upper(translate(trim(coalesce(senioridade,'')),'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','AAAAAEEEEIIIIOOOOOUUUUC')),'[._ -]+',' ','g') senioridade_key,
    lower(translate(regexp_replace(trim(coalesce(mes_referencia,'')),'[[:space:]]+',' ','g'),'áàâãäéèêëíìîïóòôõöúùûüç','aaaaaeeeeiiiiooooouuuuc')) mes_key
  FROM public.colaboradores c
), normalized AS (
  SELECT *,CASE mes_key WHEN 'janeiro' THEN date '2026-01-01' WHEN 'fevereiro' THEN date '2026-02-01'
    WHEN 'marco' THEN date '2026-03-01' WHEN 'abril' THEN date '2026-04-01' WHEN 'maio' THEN date '2026-05-01'
    WHEN 'junho' THEN date '2026-06-01' WHEN 'julho' THEN date '2026-07-01' WHEN 'agosto' THEN date '2026-08-01'
    WHEN 'setembro' THEN date '2026-09-01' WHEN 'outubro' THEN date '2026-10-01' WHEN 'novembro' THEN date '2026-11-01'
    WHEN 'dezembro' THEN date '2026-12-01' ELSE NULL END competencia_normalizada
  FROM raw
)
SELECT 'nomes_vazios' check_name,jsonb_agg(jsonb_build_object('id',id,'valor',nome_colaborador)) details FROM normalized WHERE nome_normalizado IS NULL
UNION ALL SELECT 'ids_nulos',jsonb_agg(jsonb_build_object('nome',nome_colaborador)) FROM normalized WHERE id IS NULL
UNION ALL SELECT 'metas_invalidas',jsonb_agg(jsonb_build_object('id',id,'valor',meta_alcancada)) FROM normalized
  WHERE meta_key NOT IN ('','SEM PRESENCA','AUSENTE','META 1','META 2','META 3','NENHUMA META','SEM META')
UNION ALL SELECT 'senioridades_invalidas',jsonb_agg(jsonb_build_object('id',id,'valor',senioridade)) FROM normalized
  WHERE senioridade_key NOT IN ('JUNIOR 1','JUNIOR I','JR 1','JR I','SDR I','SDR JUNIOR 1','SDR JUNIOR I','SDR JR 1','SDR JR I',
    'JUNIOR 2','JUNIOR II','JR 2','JR II','SDR JUNIOR 2','SDR JUNIOR II','SDR JR 2','SDR JR II',
    'JUNIOR 3','JUNIOR III','JR 3','JR III','SDR JUNIOR 3','SDR JUNIOR III','SDR JR 3','SDR JR III',
    'PLENO 1','PLENO I','SDR PLENO 1','SDR PLENO I','PLENO 2','PLENO II','SDR PLENO 2','SDR PLENO II','PLENO 3','PLENO III','SDR PLENO 3','SDR PLENO III',
    'SENIOR 1','SENIOR I','SR 1','SR I','SDR SENIOR 1','SDR SENIOR I','SENIOR 2','SENIOR II','SR 2','SR II','SDR SENIOR 2','SDR SENIOR II','SENIOR 3','SENIOR III','SR 3','SR III','SDR SENIOR 3','SDR SENIOR III')
    AND NOT (senioridade_key='' AND meta_key IN ('','SEM PRESENCA','AUSENTE'))
UNION ALL SELECT 'meses_invalidos',jsonb_agg(jsonb_build_object('id',id,'valor',mes_referencia)) FROM normalized WHERE competencia_normalizada IS NULL;

-- Blocking bootstrap gap: neutral absences may be null, but each person needs at least one informed level.
WITH n AS (
  SELECT id,nullif(lower(regexp_replace(trim(coalesce(nome_colaborador,'')),'[[:space:]]+',' ','g')),'') nome_normalizado,
    nullif(trim(coalesce(senioridade,'')),'') senioridade_preenchida
  FROM public.colaboradores
)
SELECT nome_normalizado,array_agg(id ORDER BY id) ids
FROM n WHERE nome_normalizado IS NOT NULL
GROUP BY nome_normalizado HAVING count(senioridade_preenchida)=0;

SELECT id,count(*) ocorrencias FROM public.colaboradores GROUP BY id HAVING count(*)>1;

WITH n AS (SELECT id,nome_colaborador,nullif(lower(regexp_replace(trim(coalesce(nome_colaborador,'')),'[[:space:]]+',' ','g')),'') nome_normalizado FROM public.colaboradores)
SELECT nome_normalizado,array_agg(DISTINCT nome_colaborador ORDER BY nome_colaborador) variantes,array_agg(id ORDER BY id) ids
FROM n WHERE nome_normalizado IS NOT NULL GROUP BY nome_normalizado HAVING count(DISTINCT nome_colaborador)>1;

WITH n AS (
 SELECT id,nome_colaborador,nullif(lower(regexp_replace(trim(coalesce(nome_colaborador,'')),'[[:space:]]+',' ','g')),'') nome_normalizado,
  CASE lower(translate(trim(coalesce(mes_referencia,'')),'áàâãäéèêëíìîïóòôõöúùûüç','aaaaaeeeeiiiiooooouuuuc'))
    WHEN 'janeiro' THEN date '2026-01-01' WHEN 'fevereiro' THEN date '2026-02-01' WHEN 'marco' THEN date '2026-03-01'
    WHEN 'abril' THEN date '2026-04-01' WHEN 'maio' THEN date '2026-05-01' WHEN 'junho' THEN date '2026-06-01'
    WHEN 'julho' THEN date '2026-07-01' WHEN 'agosto' THEN date '2026-08-01' WHEN 'setembro' THEN date '2026-09-01'
    WHEN 'outubro' THEN date '2026-10-01' WHEN 'novembro' THEN date '2026-11-01' WHEN 'dezembro' THEN date '2026-12-01' ELSE NULL END competencia
 FROM public.colaboradores
)
SELECT nome_normalizado,competencia,array_agg(id ORDER BY id) ids FROM n
WHERE nome_normalizado IS NOT NULL AND competencia IS NOT NULL GROUP BY nome_normalizado,competencia HAVING count(*)>1;

-- Informational mobility (not errors).
WITH n AS (SELECT *,lower(regexp_replace(trim(nome_colaborador),'[[:space:]]+',' ','g')) nome_normalizado FROM public.colaboradores WHERE nullif(trim(nome_colaborador),'') IS NOT NULL)
SELECT 'mudanca_squad' tipo,nome_normalizado,array_agg(DISTINCT squad ORDER BY squad) valores FROM n GROUP BY nome_normalizado HAVING count(DISTINCT squad)>1
UNION ALL SELECT 'mudanca_posicao',nome_normalizado,array_agg(DISTINCT posicao ORDER BY posicao) FROM n GROUP BY nome_normalizado HAVING count(DISTINCT posicao)>1;

-- Potential informed-seniority divergences and rows that cannot be associated safely.
WITH n AS (
 SELECT id,nome_colaborador,senioridade,lower(regexp_replace(trim(coalesce(nome_colaborador,'')),'[[:space:]]+',' ','g')) nome_normalizado,
   first_value(senioridade) OVER (PARTITION BY lower(regexp_replace(trim(coalesce(nome_colaborador,'')),'[[:space:]]+',' ','g')) ORDER BY mes_referencia,id) inicial
 FROM public.colaboradores
)
SELECT id,nome_colaborador,senioridade,inicial FROM n WHERE senioridade IS DISTINCT FROM inicial;

SELECT id,nome_colaborador,mes_referencia FROM public.colaboradores
WHERE nullif(trim(nome_colaborador),'') IS NULL OR nullif(trim(mes_referencia),'') IS NULL;
