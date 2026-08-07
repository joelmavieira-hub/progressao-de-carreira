-- SELECT-only evidence for historical transition and dashboard reconciliation.
WITH legacy_ranked AS (
  SELECT s.*,
    row_number() OVER (PARTITION BY public.normalize_career_name(s.nome_colaborador),s.mes_referencia ORDER BY s.updated_at DESC,s.id DESC) AS rn
  FROM archive.colaboradores_legacy_20260805 s
  WHERE to_jsonb(s)::text ILIKE ANY (ARRAY[
    '%Crisostomo%', '%João Paulo%', '%Joao Paulo%', '%Gustavo Duarte%',
    '%Leandro Dos Santos%', '%Gabrielly%', '%Miguel Carneiro%', '%Tatyanna%'
  ])
), legacy_named AS (
  SELECT jsonb_build_object(
    'name',nome_colaborador,'month',mes_referencia,'position',posicao,
    'goal',meta_alcancada,'seniority',senioridade,'squad',squad,
    'source_suffix',CASE
      WHEN meta_alcancada ~* '\(SDR\)' THEN 'SDR'
      WHEN meta_alcancada ~* '\(Closer\)' THEN 'Closer'
      ELSE NULL END
  ) AS row_data
  FROM legacy_ranked WHERE rn=1
), operational AS (
  SELECT p.*
  FROM public.colaboradores_perfis p
  WHERE upper(trim(coalesce(p.posicao_atual, ''))) IN ('SDR', 'CLOSER')
    AND coalesce(public.normalize_career_name(p.squad_atual), '') <> 'saiu'
    AND coalesce(public.normalize_career_name(p.jornada_atual), '') <> 'saiu'
), operational_results AS (
  SELECT c.* FROM public.colaboradores c JOIN operational p ON p.id = c.colaborador_id
)
SELECT jsonb_build_object(
  'legacy_columns', (
    SELECT jsonb_agg(column_name ORDER BY ordinal_position)
    FROM information_schema.columns WHERE table_schema='archive' AND table_name='colaboradores_legacy_20260805'
  ),
  'legacy_named', (SELECT jsonb_agg(row_data) FROM legacy_named),
  'named_sequences', (
    SELECT jsonb_agg(jsonb_build_object(
      'name',p.nome_colaborador,'current_position',p.posicao_atual,
      'current_seniority',p.senioridade_atual,'current_progress',p.progresso_meta3,
      'sequence',(SELECT jsonb_agg(jsonb_build_object(
        'competence',c.competencia,'position',c.posicao,'goal',c.meta_alcancada,
        'seniority',c.senioridade,'informed',c.senioridade_informada,
        'promotion',c.recebeu_promocao
      ) ORDER BY c.competencia) FROM public.colaboradores c WHERE c.colaborador_id=p.id)
    ) ORDER BY p.nome_normalizado)
    FROM public.colaboradores_perfis p
    WHERE p.nome_normalizado IN (
      public.normalize_career_name('Luan Nicolas Sinesio Crisostomo'),
      public.normalize_career_name('João Paulo Maciel Sousa'),
      public.normalize_career_name('Gustavo Duarte Pinheiro Silva'),
      public.normalize_career_name('Leandro Dos Santos Pereira'),
      public.normalize_career_name('Gabrielly de Oliveira Medeiros')
    )
  ),
  'matrix_before', jsonb_build_object(
    'historical_profiles',(SELECT count(*) FROM public.colaboradores_perfis),
    'historical_results',(SELECT count(*) FROM public.colaboradores),
    'operational_active',(SELECT count(*) FROM operational WHERE ativo),
    'operational_inactive',(SELECT count(*) FROM operational WHERE NOT ativo),
    'positions',(SELECT jsonb_object_agg(posicao_atual,n) FROM (SELECT posicao_atual,count(*) n FROM operational GROUP BY posicao_atual ORDER BY posicao_atual) x),
    'seniorities',(SELECT jsonb_object_agg(senioridade_atual,n) FROM (SELECT senioridade_atual,count(*) n FROM operational GROUP BY senioridade_atual ORDER BY senioridade_atual) x),
    'squads',(SELECT jsonb_object_agg(coalesce(squad_atual,'Não informado'),n) FROM (SELECT squad_atual,count(*) n FROM operational GROUP BY squad_atual ORDER BY squad_atual) x),
    'progress',(SELECT jsonb_object_agg(progresso_meta3::text,n) FROM (SELECT progresso_meta3,count(*) n FROM operational GROUP BY progresso_meta3 ORDER BY progresso_meta3) x),
    'promotions',(SELECT count(*) FROM operational_results WHERE recebeu_promocao),
    'results_by_competence',(SELECT jsonb_object_agg(competencia::text,n) FROM (SELECT competencia,count(*) n FROM operational_results GROUP BY competencia ORDER BY competencia) x),
    'kanban_active',(SELECT count(*) FROM operational WHERE ativo)
  ),
  'excluded_profiles', (
    SELECT jsonb_agg(jsonb_build_object('name',nome_colaborador,'active',ativo,'position',posicao_atual,'squad',squad_atual,'journey',jornada_atual) ORDER BY nome_normalizado)
    FROM public.colaboradores_perfis p
    WHERE NOT (
      upper(trim(coalesce(p.posicao_atual, ''))) IN ('SDR', 'CLOSER')
      AND coalesce(public.normalize_career_name(p.squad_atual), '') <> 'saiu'
      AND coalesce(public.normalize_career_name(p.jornada_atual), '') <> 'saiu'
    )
  )
) AS evidence;
