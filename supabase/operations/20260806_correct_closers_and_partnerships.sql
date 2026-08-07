-- Auditable, scoped production correction. Requires migration 20260806131000.
BEGIN;

CREATE TEMP TABLE emergency_targets AS
SELECT id,nome_normalizado FROM public.colaboradores_perfis
WHERE nome_normalizado IN (
  public.normalize_career_name('Luan Nicolas Sinesio Crisostomo'),
  public.normalize_career_name('João Paulo Maciel Sousa'),
  public.normalize_career_name('Gustavo Duarte Pinheiro Silva'),
  public.normalize_career_name('Leandro Dos Santos Pereira'),
  public.normalize_career_name('Gabrielly de Oliveira Medeiros')
);

DO $$ BEGIN
  IF (SELECT count(*) FROM emergency_targets)<>5 THEN
    RAISE EXCEPTION 'Escopo nominal incompleto';
  END IF;
END $$;

CREATE TEMP TABLE emergency_untouched AS
SELECT
  (SELECT md5(coalesce(string_agg(md5(to_jsonb(p)::text),'' ORDER BY p.id),''))
   FROM public.colaboradores_perfis p WHERE NOT EXISTS(SELECT 1 FROM emergency_targets t WHERE t.id=p.id)) AS profiles_hash,
  (SELECT md5(coalesce(string_agg(md5(to_jsonb(c)::text),'' ORDER BY c.id),''))
   FROM public.colaboradores c WHERE NOT EXISTS(SELECT 1 FROM emergency_targets t WHERE t.id=c.colaborador_id)) AS results_hash,
  (SELECT md5(coalesce(string_agg(md5(to_jsonb(e)::text),'' ORDER BY e.id),''))
   FROM public.career_progression_events e WHERE NOT EXISTS(SELECT 1 FROM emergency_targets t WHERE t.id=e.colaborador_id)) AS events_hash;

-- The archived source suffixes identify João as SDR through May and Closer in June.
UPDATE public.colaboradores c SET
  posicao=CASE WHEN c.competencia<date '2026-06-01' THEN 'SDR' ELSE 'Closer' END,
  updated_at=now()
FROM public.colaboradores_perfis p
WHERE p.id=c.colaborador_id
  AND p.nome_normalizado=public.normalize_career_name('João Paulo Maciel Sousa')
  AND c.posicao IS DISTINCT FROM CASE WHEN c.competencia<date '2026-06-01' THEN 'SDR' ELSE 'Closer' END;

-- Current role correction only; all eight historical SDR results stay untouched.
UPDATE public.colaboradores_perfis SET posicao_atual='Parcerias',updated_at=now()
WHERE nome_normalizado=public.normalize_career_name('Gabrielly de Oliveira Medeiros')
  AND posicao_atual IS DISTINCT FROM 'Parcerias';

SELECT public.recalcular_progressao_colaborador(p.id)
FROM public.colaboradores_perfis p
WHERE p.nome_normalizado IN (
  public.normalize_career_name('Luan Nicolas Sinesio Crisostomo'),
  public.normalize_career_name('João Paulo Maciel Sousa'),
  public.normalize_career_name('Gustavo Duarte Pinheiro Silva'),
  public.normalize_career_name('Leandro Dos Santos Pereira')
)
ORDER BY p.nome_normalizado;

DO $$
DECLARE untouched emergency_untouched%ROWTYPE;
BEGIN
  SELECT * INTO STRICT untouched FROM emergency_untouched;
  IF untouched.profiles_hash IS DISTINCT FROM (
    SELECT md5(coalesce(string_agg(md5(to_jsonb(p)::text),'' ORDER BY p.id),''))
    FROM public.colaboradores_perfis p WHERE NOT EXISTS(SELECT 1 FROM emergency_targets t WHERE t.id=p.id)
  ) OR untouched.results_hash IS DISTINCT FROM (
    SELECT md5(coalesce(string_agg(md5(to_jsonb(c)::text),'' ORDER BY c.id),''))
    FROM public.colaboradores c WHERE NOT EXISTS(SELECT 1 FROM emergency_targets t WHERE t.id=c.colaborador_id)
  ) OR untouched.events_hash IS DISTINCT FROM (
    SELECT md5(coalesce(string_agg(md5(to_jsonb(e)::text),'' ORDER BY e.id),''))
    FROM public.career_progression_events e WHERE NOT EXISTS(SELECT 1 FROM emergency_targets t WHERE t.id=e.colaborador_id)
  ) THEN RAISE EXCEPTION 'Registro fora do escopo foi alterado'; END IF;

  IF NOT EXISTS(SELECT 1 FROM public.colaboradores_perfis WHERE nome_normalizado=public.normalize_career_name('Luan Nicolas Sinesio Crisostomo') AND posicao_atual='Closer' AND senioridade_atual='Júnior 3' AND progresso_meta3=1) THEN RAISE EXCEPTION 'Luan divergente'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.colaboradores_perfis WHERE nome_normalizado=public.normalize_career_name('João Paulo Maciel Sousa') AND posicao_atual='Closer' AND senioridade_atual='Júnior 1' AND progresso_meta3=0) THEN RAISE EXCEPTION 'João Paulo divergente'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.colaboradores_perfis WHERE nome_normalizado=public.normalize_career_name('Gustavo Duarte Pinheiro Silva') AND posicao_atual='Closer' AND senioridade_atual='Júnior 3' AND progresso_meta3=1) THEN RAISE EXCEPTION 'Gustavo divergente'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.colaboradores_perfis WHERE nome_normalizado=public.normalize_career_name('Leandro Dos Santos Pereira') AND posicao_atual='Closer' AND senioridade_atual='Pleno 1' AND progresso_meta3=1) THEN RAISE EXCEPTION 'Leandro divergente'; END IF;
  IF EXISTS(SELECT 1 FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id WHERE p.nome_normalizado=public.normalize_career_name('João Paulo Maciel Sousa') AND ((c.competencia<date '2026-06-01' AND c.posicao<>'SDR') OR (c.competencia>=date '2026-06-01' AND c.posicao<>'Closer'))) THEN RAISE EXCEPTION 'Transição de João divergente'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.colaboradores_perfis WHERE nome_normalizado=public.normalize_career_name('Gabrielly de Oliveira Medeiros') AND posicao_atual='Parcerias') THEN RAISE EXCEPTION 'Gabrielly ainda operacional'; END IF;
  IF (SELECT count(*) FROM public.colaboradores c JOIN public.colaboradores_perfis p ON p.id=c.colaborador_id WHERE p.nome_normalizado=public.normalize_career_name('Gabrielly de Oliveira Medeiros'))<>8 THEN RAISE EXCEPTION 'Histórico de Gabrielly alterado'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.colaboradores_perfis WHERE nome_normalizado=public.normalize_career_name('Cleber Rodrigues Souza') AND ativo AND posicao_atual IN ('SDR','Closer') AND coalesce(public.normalize_career_name(squad_atual),'')<>'saiu') THEN RAISE EXCEPTION 'Cleber fora do escopo'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.colaboradores_perfis WHERE nome_normalizado=public.normalize_career_name('Miguel Carneiro Nunes') AND posicao_atual='Closer' AND senioridade_atual='Júnior 1' AND progresso_meta3=0) THEN RAISE EXCEPTION 'Regressão de Miguel'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.colaboradores_perfis WHERE nome_normalizado=public.normalize_career_name('Tatyanna Lima de Freitas') AND posicao_atual='Closer' AND senioridade_atual='Júnior 2' AND progresso_meta3=0) THEN RAISE EXCEPTION 'Regressão de Taty'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.colaboradores_perfis WHERE nome_normalizado=public.normalize_career_name('Adrilene Azevedo da Silva') AND progresso_meta3=0) THEN RAISE EXCEPTION 'Regressão de Adrilene'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.colaboradores_perfis WHERE nome_normalizado=public.normalize_career_name('Luiz Fernando de Medeiros Paiva Moura') AND progresso_meta3=1) THEN RAISE EXCEPTION 'Regressão de Luiz'; END IF;
  IF EXISTS(SELECT 1 FROM public.colaboradores_perfis WHERE progresso_meta3 NOT BETWEEN 0 AND 2) THEN RAISE EXCEPTION 'Progresso inválido'; END IF;
  IF EXISTS(SELECT 1 FROM public.colaboradores c WHERE c.colaborador_id IS NULL OR NOT EXISTS(SELECT 1 FROM public.colaboradores_perfis p WHERE p.id=c.colaborador_id)) THEN RAISE EXCEPTION 'Órfão criado'; END IF;
  IF EXISTS(SELECT 1 FROM public.colaboradores GROUP BY colaborador_id,competencia HAVING count(*)>1) THEN RAISE EXCEPTION 'Duplicidade criada'; END IF;
  IF (SELECT count(*) FROM public.colaboradores_perfis)<>73 OR (SELECT count(*) FROM public.colaboradores)<>584 THEN RAISE EXCEPTION 'Cardinalidade histórica alterada'; END IF;
END $$;

COMMIT;

SELECT jsonb_build_object(
  'profiles',(SELECT jsonb_agg(jsonb_build_object('name',p.nome_colaborador,'position',p.posicao_atual,'seniority',p.senioridade_atual,'progress',p.progresso_meta3) ORDER BY p.nome_normalizado) FROM public.colaboradores_perfis p JOIN emergency_targets t ON t.id=p.id),
  'profile_rows_changed',(SELECT count(*) FROM archive.colaboradores_perfis_20260806t130602z b JOIN public.colaboradores_perfis p USING(id) WHERE to_jsonb(b)-'updated_at' IS DISTINCT FROM to_jsonb(p)-'updated_at'),
  'result_rows_changed',(SELECT count(*) FROM archive.colaboradores_20260806t130602z b JOIN public.colaboradores c USING(id) WHERE to_jsonb(b)-'updated_at' IS DISTINCT FROM to_jsonb(c)-'updated_at'),
  'events',(SELECT count(*) FROM public.career_progression_events)
) AS correction_result;
