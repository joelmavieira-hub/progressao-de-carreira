-- MANUAL, NOT EXECUTED. Non-destructive rollback for stage 1.
-- Historical rows and their audit/calculated columns are deliberately preserved.
BEGIN;
REVOKE ALL ON FUNCTION public.registrar_resultado_mensal(uuid,date,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.recalcular_progressao_colaborador(uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.sincronizar_progressao_planilha(jsonb,jsonb,text) FROM PUBLIC,anon,authenticated,service_role;
DROP POLICY IF EXISTS "Career results are readable" ON public.colaboradores;
DROP POLICY IF EXISTS "Career profiles are readable" ON public.colaboradores_perfis;
DROP POLICY IF EXISTS "Migration issues are authenticated-readable" ON public.career_migration_issues;
DROP TRIGGER IF EXISTS set_colaboradores_perfis_updated_at ON public.colaboradores_perfis;
DROP FUNCTION IF EXISTS public.registrar_resultado_mensal(uuid,date,text);
DROP FUNCTION IF EXISTS public.sincronizar_progressao_planilha(jsonb,jsonb,text);
DROP FUNCTION IF EXISTS public.recalcular_progressao_colaborador(uuid);
DROP FUNCTION IF EXISTS public.set_career_updated_at();
DROP INDEX IF EXISTS public.colaboradores_colaborador_competencia_key;
ALTER TABLE public.colaboradores DROP CONSTRAINT IF EXISTS colaboradores_colaborador_id_fkey;
ALTER TABLE public.colaboradores DROP CONSTRAINT IF EXISTS colaboradores_competencia_primeiro_dia;
ALTER TABLE public.colaboradores_perfis DROP CONSTRAINT IF EXISTS colaboradores_perfis_nome_normalizado_canonico;
ALTER TABLE public.colaboradores_perfis DROP CONSTRAINT IF EXISTS colaboradores_perfis_senioridade_valida;
ALTER TABLE public.colaboradores_perfis DROP CONSTRAINT IF EXISTS colaboradores_perfis_nome_normalizado_key;
ALTER TABLE public.colaboradores_perfis DROP CONSTRAINT IF EXISTS colaboradores_perfis_progresso_meta3_check;
DROP FUNCTION IF EXISTS public.next_career_seniority(text);
DROP FUNCTION IF EXISTS public.normalize_career_goal(text);
DROP FUNCTION IF EXISTS public.normalize_career_seniority(text);
DROP FUNCTION IF EXISTS public.normalize_career_name(text);
DROP FUNCTION IF EXISTS public.parse_legacy_competencia(text);
-- colaboradores_perfis and career_migration_issues are retained because dropping them loses state/audit.
-- colaborador_id, competencia, senioridade_informada and boolean recebeu_promocao are retained.
-- Restoring the old textual promotion type or legacy RLS requires a reviewed manual migration/backup restore.
COMMIT;
