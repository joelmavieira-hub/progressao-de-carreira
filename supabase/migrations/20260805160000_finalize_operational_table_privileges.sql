REVOKE INSERT, UPDATE, DELETE, TRUNCATE
ON TABLE
  public.colaboradores,
  public.colaboradores_perfis,
  public.career_migration_issues
FROM PUBLIC, anon, authenticated;
