-- Run only after loading the leadership migration in the same transaction.
-- The caller owns BEGIN/ROLLBACK. This script projects the real source facts.

SELECT public.sincronizar_progressao_planilha(
  jsonb_build_array(jsonb_build_object(
    'nome_colaborador','Marcos Vinicius Teles da Silva',
    'posicao','Liderança de SDRs','squad','Sem squad','ativo',true
  )),
  jsonb_build_array(
    jsonb_build_object('nome_colaborador','Marcos Vinicius Teles da Silva','posicao','SDR','squad','Águia','competencia','2026-06-01','meta_alcancada','Meta 2','senioridade_informada','Júnior 2'),
    jsonb_build_object('nome_colaborador','Marcos Vinicius Teles da Silva','posicao','SDR','squad','Águia','competencia','2026-07-01','meta_alcancada','Meta 3','senioridade_informada','Júnior 2'),
    jsonb_build_object('nome_colaborador','Marcos Vinicius Teles da Silva','posicao','Liderança de SDRs','squad','Águia','competencia','2026-08-01','meta_alcancada','Meta 3 (Liderança de SDRs)','senioridade_informada','Júnior 2'),
    jsonb_build_object('nome_colaborador','Marcos Vinicius Teles da Silva','posicao','Liderança de SDRs','squad','Sem squad','competencia','2026-09-01','meta_alcancada','','senioridade_informada','Júnior 3')
  ),'leadership_real_projection'
);

SELECT public.sincronizar_progressao_planilha(
  jsonb_build_array(jsonb_build_object(
    'nome_colaborador','Gregory Lavor Brito Amora',
    'posicao','Liderança de Closers','squad','Gorila','ativo',true
  )),
  jsonb_build_array(
    jsonb_build_object('nome_colaborador','Gregory Lavor Brito Amora','posicao','Closer','squad','Whenna','competencia','2026-05-01','meta_alcancada','Meta 3','senioridade_informada','Pleno 2'),
    jsonb_build_object('nome_colaborador','Gregory Lavor Brito Amora','posicao','Closer','squad','Gorila','competencia','2026-06-01','meta_alcancada','Meta 3','senioridade_informada','Pleno 2'),
    jsonb_build_object('nome_colaborador','Gregory Lavor Brito Amora','posicao','Closer','squad','Gorila','competencia','2026-07-01','meta_alcancada','Meta não definida','senioridade_informada','Pleno 2'),
    jsonb_build_object('nome_colaborador','Gregory Lavor Brito Amora','posicao','Liderança de Closers','squad','Gorila','competencia','2026-08-01','meta_alcancada','Meta não definida','senioridade_informada','Pleno 2'),
    jsonb_build_object('nome_colaborador','Gregory Lavor Brito Amora','posicao','Liderança de Closers','squad','Gorila','competencia','2026-09-01','meta_alcancada','Meta não definida','senioridade_informada','Pleno 2')
  ),'leadership_real_projection'
);

SELECT p.nome_colaborador,p.posicao_atual,p.senioridade_atual,
       p.progresso_meta3,p.progresso_meta2,p.progresso_ciclo,
       p.bonificacao_sdr,p.streak_meta3_bonificacao,
       e.competencia AS evento_competencia,e.event_type
FROM public.colaboradores_perfis p
LEFT JOIN public.career_progression_events e ON e.colaborador_id=p.id AND e.event_type='role_promotion'
WHERE p.nome_normalizado IN (
  public.normalize_career_name('Marcos Vinicius Teles da Silva'),
  public.normalize_career_name('Gregory Lavor Brito Amora')
)
ORDER BY p.nome_normalizado,e.competencia;
