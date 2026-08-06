# Certificação local pré-Gate 1 — 2026-08-06

Nenhum comando remoto, migration, sincronização, limpeza ou deploy foi executado.

## Estado local

- Diretório esperado: `progressão-de-carreira`.
- Git: indisponível; não existe `.git` nesta pasta nem no diretório pai. Branch, commit, status e diff não puderam ser certificados.
- Link local Supabase: `supabase/.temp/project-ref` contém `ygyiygqfiupadgnaaxlz`.
- `.env`: URL autorizada `https://ygyiygqfiupadgnaaxlz.supabase.co`; chave do tipo publicável; nenhuma referência ao projeto antigo e nenhum padrão `sb_secret_`/service role.
- Frontend: somente chamadas `select`; nenhuma operação `insert`, `update`, `upsert`, `delete` ou RPC do Supabase.
- Build: contém apenas a URL autorizada e a chave publicável exigida pelo cliente web; nenhum segredo privilegiado.

## Validações executadas

- `npm ci`: concluído; 500 pacotes instalados. Auditoria do npm informou 4 vulnerabilidades (3 moderadas, 1 alta), sem correção automática aplicada.
- `npm test`: 104/104 testes aprovados em 10 arquivos.
- `npm run lint`: 0 erros e 7 avisos preexistentes de React Fast Refresh.
- `npm run typecheck`: aprovado.
- `npm run build`: aprovado; avisos de bundle acima de 500 kB e Browserslist desatualizado.
- `npm run validate:supabase-read`: não executado nesta rodada, pois é remoto e o gate pré-remoto exige certificação Git e project ref remoto.

## Correções locais desta rodada

- Miguel: Jan–Jun SDR/Júnior 1; Jul–Ago Closer/Júnior 1/Sem presença; progresso esperado 0/3.
- Tatyanna: Jan–Jun SDR; Abr–Jun Júnior 3; Jul–Ago Closer/Júnior 2/Sem presença; progresso esperado 0/3.
- O dry-run agora apresenta posição antes/depois, Metas 3 consideradas, mudanças SDR→Closer, promoções, conclusões de ciclo e motivos.
- O relatório anterior foi marcado como desatualizado até nova leitura remota.

## Bloqueadores de segurança

1. **Ausência de Git:** impede cumprir a confirmação obrigatória de branch, commit, status, diff e alterações compreendidas antes de qualquer comando remoto.
2. **Contrato legado incompatível:** arquivamento/validação/limpeza exigem 6.040 linhas em `public.colaboradores`, mas o estado operacional confirmado possui 576 resultados. O arquivo criado a partir do estado atual não poderia satisfazer o `ok=true` exigido.
3. **Validação contraditória de `sdrs`:** `20260805_post_migration_validation.sql` exige ausência de `public.sdrs` e `archive.sdrs_legacy_20260805`, contrariando a obrigação de preservar a origem e a cópia arquivada.
4. **Ferramentas remotas não certificadas:** `supabase` e `psql` não estão disponíveis no PATH; uma tentativa local com `npx --no-install` não concluiu no prazo.

## Análise dos scripts

- O arquivamento usa transação `REPEATABLE READ`, lock de compartilhamento, cria somente o schema/tabelas de arquivo e manifest, sem DELETE/TRUNCATE/DROP.
- A limpeza é destrutiva e corretamente limitada às três tabelas previstas, mas contém guarda rígida de 6.040 linhas e não pode ser executada no estado operacional descrito.
- O preflight é somente leitura.
- A migration preparada mantém domínio 0–2, resultados neutros, reset SDR→Closer, Sênior 3 sem falsa promoção, RLS/privilégios públicos restritos e log `career_cycle_completed`. SHA-256: `ac9d530230508fcd099190713b3ec8ffa171bbbb8868789252a74333513e52d5`.
- Nenhum dado pessoal está hardcoded na migration; nomes aparecem somente nos scripts de revisão/dry-run.

## Próxima ação necessária

Antes do arquivamento remoto:

1. executar a operação a partir de uma cópia que contenha a metadata Git correta, ou fornecer o repositório/branch/commit certificados;
2. esclarecer onde está o conjunto legado de 6.040 linhas, pois ele não pode ser simultaneamente a tabela operacional confirmada com 576 resultados;
3. corrigir o check `legacy_sdrs_remains_absent` para validar preservação, não ausência;
4. disponibilizar um mecanismo remoto auditável (`supabase`/`psql`) e confirmar o vínculo com `ygyiygqfiupadgnaaxlz`.

O Gate 1 não foi alcançado e a autorização de limpeza não deve ser solicitada ainda.
