-- READ-ONLY DRY-RUN. This script does not call the recalculation function and
-- performs no INSERT/UPDATE/DELETE. Run first in a controlled SQL session.
-- Confirmed correction simulated by scripts/recalculate-career-progress.ts:
-- Miguel: SDR through 2026-06; Closer/Júnior 1/Sem presença at 2026-07 and 2026-08.
WITH deduplicated AS (
  SELECT DISTINCT ON (c.colaborador_id,c.competencia)
    c.*
  FROM public.colaboradores c
  WHERE c.colaborador_id IS NOT NULL AND c.competencia IS NOT NULL
  ORDER BY c.colaborador_id,c.competencia,c.id DESC
), ordered AS (
  SELECT d.*, lag(upper(trim(d.posicao))) OVER (
      PARTITION BY d.colaborador_id ORDER BY d.competencia,d.id
    ) AS previous_position
  FROM deduplicated d
), last_reset AS (
  SELECT colaborador_id,max(competencia) AS reset_competence
  FROM ordered
  WHERE previous_position='SDR' AND upper(trim(posicao))='CLOSER'
  GROUP BY colaborador_id
), counted AS (
  SELECT p.id,p.nome_colaborador,p.progresso_meta3 AS before_progress,
    r.reset_competence,
    count(*) FILTER (
      WHERE public.normalize_career_goal(o.meta_alcancada)='Meta 3'
        AND (r.reset_competence IS NULL OR o.competencia>=r.reset_competence)
    ) AS meta3_after_reset
  FROM public.colaboradores_perfis p
  LEFT JOIN ordered o ON o.colaborador_id=p.id
  LEFT JOIN last_reset r ON r.colaborador_id=p.id
  GROUP BY p.id,p.nome_colaborador,p.progresso_meta3,r.reset_competence
)
SELECT nome_colaborador,before_progress,reset_competence,meta3_after_reset,
  'inventário; use npm run recalculate:dry-run para simular promoções e senioridade' AS action
FROM counted
ORDER BY nome_colaborador;

-- After reviewing/exporting the result and taking a backup, execute the following
-- manually in a transaction in the controlled maintenance window:
-- BEGIN;
-- SELECT public.recalcular_progressao_colaborador(id)
-- FROM public.colaboradores_perfis ORDER BY nome_normalizado;
-- Re-run npm run recalculate:dry-run and validate named cases; COMMIT or ROLLBACK explicitly.
