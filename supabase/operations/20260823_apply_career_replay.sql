-- Run only after reviewing the dry-run report. Transactional and idempotent.
BEGIN;
DO $$ DECLARE person uuid; BEGIN
  FOR person IN SELECT id FROM public.colaboradores_perfis ORDER BY id LOOP
    PERFORM public.recalcular_progressao_colaborador(person);
  END LOOP;
END $$;
COMMIT;
