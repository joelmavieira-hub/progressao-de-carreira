-- Emergency investigation: SELECT-only evidence for backup, scope and named cases.
SELECT jsonb_build_object(
  'backup', (
    SELECT jsonb_build_object(
      'rows', count(*),
      'valid', bool_and(source_count=backup_count AND source_hash=backup_hash),
      'entries', jsonb_agg(jsonb_build_object(
        'source', source_schema||'.'||source_table,
        'backup', backup_schema||'.'||backup_table,
        'source_count', source_count,
        'backup_count', backup_count,
        'hashes_match', source_hash=backup_hash
      ) ORDER BY source_table)
    )
    FROM archive.progression_backup_manifest
    WHERE backup_id='progression_20260806t121500z'
  ),
  'current_counts', jsonb_build_object(
    'profiles', (SELECT count(*) FROM public.colaboradores_perfis),
    'results', (SELECT count(*) FROM public.colaboradores),
    'events', (SELECT count(*) FROM public.career_progression_events)
  ),
  'domains', jsonb_build_object(
    'positions', (SELECT jsonb_agg(x ORDER BY x) FROM (SELECT DISTINCT posicao_atual AS x FROM public.colaboradores_perfis WHERE posicao_atual IS NOT NULL) q),
    'squads', (SELECT jsonb_agg(x ORDER BY x) FROM (SELECT DISTINCT squad_atual AS x FROM public.colaboradores_perfis WHERE squad_atual IS NOT NULL) q),
    'journeys', (SELECT jsonb_agg(x ORDER BY x) FROM (SELECT DISTINCT jornada_atual AS x FROM public.colaboradores_perfis WHERE jornada_atual IS NOT NULL) q)
  ),
  'named', (
    SELECT jsonb_agg(jsonb_build_object(
      'id',p.id,'name',p.nome_colaborador,'normalized',p.nome_normalizado,
      'active',p.ativo,'journey',p.jornada_atual,'current_position',p.posicao_atual,
      'current_squad',p.squad_atual,'current_seniority',p.senioridade_atual,
      'progress',p.progresso_meta3,
      'history',(
        SELECT jsonb_agg(jsonb_build_object(
          'id',c.id,'competence',c.competencia,'name',c.nome_colaborador,
          'position',c.posicao,'squad',c.squad,'goal',c.meta_alcancada,
          'seniority',c.senioridade,'informed_seniority',c.senioridade_informada,
          'promotion',c.recebeu_promocao,'origin',c.origem
        ) ORDER BY c.competencia,c.id)
        FROM public.colaboradores c WHERE c.colaborador_id=p.id
      )
    ) ORDER BY p.nome_normalizado)
    FROM public.colaboradores_perfis p
    WHERE p.nome_normalizado IN (
      public.normalize_career_name('Luan Nicolas Sinesio Crisostomo'),
      public.normalize_career_name('João Paulo Maciel Sousa'),
      public.normalize_career_name('Gustavo Duarte Pinheiro Silva'),
      public.normalize_career_name('Leandro Dos Santos Pereira'),
      public.normalize_career_name('Miguel Carneiro Nunes'),
      public.normalize_career_name('Tatyanna Lima de Freitas'),
      public.normalize_career_name('Adrilene Azevedo da Silva'),
      public.normalize_career_name('Luiz Fernando de Medeiros Paiva Moura'),
      public.normalize_career_name('Cleber Rodrigues Souza'),
      public.normalize_career_name('Gabrielly de Oliveira Medeiros')
    )
  )
) AS investigation;
