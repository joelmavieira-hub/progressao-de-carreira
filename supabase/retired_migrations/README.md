# Migrations aposentadas

## `20260421210832_e0427e69-8aaa-4fe0-ba31-289f03f5a044.sql`

- **Timestamp:** `20260421210832`
- **Finalidade original:** criar a tabela legada `public.sdrs`, suas quatro policies públicas, a função e o trigger de `updated_at`, configuração de RLS, replica identity e inclusão no Supabase Realtime.
- **Projeto relacionado:** `ygyiygqfiupadgnaaxlz`
- **Estado no projeto main:** o histórico consultado em 2026-08-05 confirmou que esta migration nunca foi registrada como aplicada.
- **Estado da tabela:** `public.sdrs` estava ausente na decisão de aposentadoria.
- **Motivo da aposentadoria:** a arquitetura operacional atual usa `public.colaboradores` e `public.colaboradores_perfis`; nenhuma rota ativa consulta `public.sdrs`. Manter o arquivo na cadeia ativa faria o Supabase CLI recriar uma tabela legada antes da migration principal.
- **Compatibilidade:** a migration principal `20260804220000_fix_career_progression.sql` trata `public.sdrs` como opcional e não depende de sua existência.
- **Data da decisão:** 2026-08-05.

O arquivo SQL foi preservado integralmente para auditoria histórica. Ele não deve voltar para `supabase/migrations/` sem revisão e autorização explícitas, incluindo nova análise de dependências e do histórico remoto.
