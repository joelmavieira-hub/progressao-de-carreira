-- REVIEW ONLY: the active statements are SELECTs. The proposed UPDATE statements
-- remain commented until spreadsheet owners confirm the source data and approve a
-- controlled transaction. Names are correction targets, never business rules.

SELECT p.nome_colaborador,p.posicao_atual,p.senioridade_atual,p.progresso_meta3,
  c.competencia,c.posicao,c.meta_alcancada,c.senioridade_informada,c.recebeu_promocao
FROM public.colaboradores_perfis p
JOIN public.colaboradores c ON c.colaborador_id=p.id
WHERE p.nome_normalizado IN (
  public.normalize_career_name('Tatyanna Lima de Freitas'),
  public.normalize_career_name('Miguel Carneiro Nunes'),
  public.normalize_career_name('Luan Nicolas Sinesio Crisostomo'),
  public.normalize_career_name('Gustavo Duarte Pinheiro Silva'),
  public.normalize_career_name('Leandro Dos Santos Pereira'),
  public.normalize_career_name('João Paulo Maciel Sousa')
)
ORDER BY p.nome_normalizado,c.competencia;

-- Proposed historical corrections explicitly supplied by the business request:
-- UPDATE public.colaboradores c SET posicao='SDR'
-- FROM public.colaboradores_perfis p WHERE c.colaborador_id=p.id
--   AND p.nome_normalizado=public.normalize_career_name('Tatyanna Lima de Freitas')
--   AND c.competencia BETWEEN date '2026-01-01' AND date '2026-06-01';
-- UPDATE public.colaboradores c SET senioridade_informada='Júnior 3'
-- FROM public.colaboradores_perfis p WHERE c.colaborador_id=p.id
--   AND p.nome_normalizado=public.normalize_career_name('Tatyanna Lima de Freitas')
--   AND c.competencia BETWEEN date '2026-04-01' AND date '2026-06-01';
-- UPDATE public.colaboradores c SET posicao='Closer',senioridade_informada='Júnior 2'
-- FROM public.colaboradores_perfis p WHERE c.colaborador_id=p.id
--   AND p.nome_normalizado=public.normalize_career_name('Tatyanna Lima de Freitas')
--   AND c.competencia>=date '2026-07-01';
-- UPDATE public.colaboradores c SET posicao=CASE WHEN c.competencia<date '2026-07-01' THEN 'SDR' ELSE 'Closer' END
-- FROM public.colaboradores_perfis p WHERE c.colaborador_id=p.id
--   AND p.nome_normalizado=public.normalize_career_name('Miguel Carneiro Nunes');
-- UPDATE public.colaboradores c SET meta_alcancada='Sem presença',senioridade_informada='Júnior 1'
-- FROM public.colaboradores_perfis p WHERE c.colaborador_id=p.id
--   AND p.nome_normalizado=public.normalize_career_name('Miguel Carneiro Nunes')
--   AND c.competencia IN (date '2026-07-01',date '2026-08-01');
-- UPDATE public.colaboradores_perfis SET posicao_atual='Closer',senioridade_atual='Júnior 1'
--   WHERE nome_normalizado=public.normalize_career_name('Miguel Carneiro Nunes');
--
-- UPDATE public.colaboradores_perfis SET senioridade_atual='Júnior 3' WHERE nome_normalizado IN (
--   public.normalize_career_name('Luan Nicolas Sinesio Crisostomo'),
--   public.normalize_career_name('Gustavo Duarte Pinheiro Silva'));
-- UPDATE public.colaboradores_perfis SET senioridade_atual='Pleno 1'
--   WHERE nome_normalizado=public.normalize_career_name('Leandro Dos Santos Pereira');
-- UPDATE public.colaboradores_perfis SET senioridade_atual='Júnior 1'
--   WHERE nome_normalizado=public.normalize_career_name('João Paulo Maciel Sousa');

-- Controlled sequence after review: backup; BEGIN; apply approved corrections;
-- call recalcular_progressao_colaborador for only affected IDs; compare before/after;
-- COMMIT on approval or ROLLBACK on any mismatch.
