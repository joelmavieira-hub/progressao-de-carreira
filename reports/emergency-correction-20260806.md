# Correção emergencial — 2026-08-06

## Estado da execução

- Project ref: `ygyiygqfiupadgnaaxlz`.
- Backup incremental: `progression_20260806t130602z` (válido).
- Migration aplicada: `20260806131000_honor_competence_seniority.sql`.
- Correção transacional aplicada: 5 perfis e 29 resultados funcionais; 0 exclusões.
- Aplicação: 112/112 testes aprovados; typecheck aprovado; lint 0 erros/7 avisos preexistentes.
- Banco: 131/131 pgTAP aprovados.
- Build/deploy pendentes: a elevação necessária ao esbuild foi recusada porque a cota do serviço de aprovação foi atingida.

## Evidência e causa raiz

O arquivo `archive.colaboradores_legacy_20260805` preserva os sufixos da origem. João Paulo possui `Meta 3 (SDR)` em abril, `Meta 2 (SDR)` em maio e `Meta não definida (Closer)` em junho. Logo, a transição observável é `2026-06-01`; janeiro–maio foram preservados como SDR e junho–agosto como Closer.

Luan, Gustavo e Leandro já aparecem como Closers em todo o recorte retido (janeiro–agosto na base atual; abril–julho no legado) e não possuem evidência de SDR no recorte. A transição real é anterior a `2026-01-01`; nenhum mês SDR foi inventado.

A RPC inicializava o cálculo com a primeira `senioridade_informada` válida e tratava todas as mudanças posteriores apenas como auditoria. Isso aprisionava o estado no nível antigo. A correção genérica agora trata a senioridade informada por competência como autoritativa e reinicia o ciclo do novo nível antes de avaliar a meta daquele mês. O reset SDR→Closer continua independente e anterior à avaliação do primeiro mês como Closer.

## Casos nominais

| Pessoa | Antes | Evidência/transição | Depois | Meta 3 no ciclo atual |
|---|---|---|---|---|
| Luan | Closer, Pleno 3, 0/3 | Closer desde o início do recorte; Júnior 3 informado em jun/2026 | Closer, Júnior 3, 1/3 | jul/2026 |
| João Paulo | Closer, Júnior 2, 1/3; meses anteriores contaminados como Closer | SDR até mai/2026; Closer desde jun/2026 | Closer, Júnior 1, 0/3 | nenhuma após o reset vigente |
| Gustavo | Closer, Júnior 2, 2/3 | Closer desde o início do recorte; Júnior 3 informado em jun/2026 | Closer, Júnior 3, 1/3 | jul/2026 |
| Leandro | Closer, Júnior 3, 2/3 | Closer desde o início do recorte; Pleno 1 informado em mai/2026 | Closer, Pleno 1, 1/3 | mai/2026 |
| Miguel | Closer, Júnior 1, 0/3 | SDR até jun; Closer desde jul | sem alteração | nenhuma |
| Tatyanna | Closer, Júnior 2, 0/3 | SDR até jun; Closer desde jul | sem alteração | nenhuma |
| Adrilene | 0/3 | validado | sem alteração | nenhuma |
| Luiz | 1/3 | validado | sem alteração | jul/2026 |
| Cleber | ativo e operacional | validado | sem alteração | — |
| Gabrielly | ativa como SDR, 8 resultados | função atual informada pelo negócio: Parcerias | posição atual Parcerias; 8 resultados preservados | fora do escopo operacional |

## Matriz anterior

| Indicador | SQL bruto / escopo correto | Consulta frontend anterior | Dashboard anterior | Diferença/causa |
|---|---:|---:|---:|---|
| Perfis históricos | 73 | 73 | 73 | 0; rótulo anterior não distinguia escopo |
| Resultados históricos | 584 | 584 | não exibido como total | total histórico ausente |
| Ativos operacionais | 42 no estado armazenado; 41 pela função real de Gabrielly | 42 ativos entre 73 perfis | 42 | +1 nominal: Gabrielly classificada como SDR |
| Inativos operacionais | 3 | 31 inativos entre 73 perfis | 31 | +28: squad Saiu entrava em ciclo/senioridade/Kanban inativo |
| SDRs ativos | 30 armazenados; 29 pelo escopo real | 30 | 30 | +1 nominal: Gabrielly |
| Closers ativos | 12 | 12 | 12 | 0 |
| Senioridades ativas | J1 25; J2 13; J3 3; P3 1 | iguais ao estado incorreto | iguais | quatro níveis persistidos errados e Gabrielly no agrupamento |
| Squads ativos | Águia 12; Gorila 7; Lobo 11; Serpente 7; Urso 5 | iguais | iguais | Águia +1 por Gabrielly |
| Progresso ativo | 0/3 23; 1/3 10; 2/3 9 | iguais | iguais | quatro ciclos errados e Gabrielly no 2/3 |
| Promoções ativas | 9 | 9 | 9 | duas promoções indevidas no conjunto exibido (Luan e histórico de Gabrielly fora do escopo) |
| Resultados/competência ativos | 42 em cada mês | 42 | 42 | +1 por mês pelo escopo real de Gabrielly |
| Kanban visível padrão | 41 pelo escopo real | 42 | 42 | +1 por Gabrielly |

Foram catalogadas 8 divergências de escopo/rótulo/agregação: base histórica, ativos, inativos, posição, senioridade, squad, progresso/Kanban e séries mensais/promoções.

## Matriz final

O frontend consulta a base histórica integral (73/584) e cria um read model operacional por ID distinto antes de filtros e agregações.

| Indicador equivalente | SQL | Read model frontend | Dashboard padrão | Diferença |
|---|---:|---:|---:|---:|
| Perfis históricos | 73 | 73 | 73 | 0 |
| Resultados históricos | 584 | 584 | 584 | 0 |
| Perfis operacionais (todos os status) | 44 | 44 | 44 no card de banco | 0 |
| Ativos operacionais | 41 | 41 | 41 | 0 |
| Inativos operacionais | 3 | 3 | 3 | 0 |
| SDRs ativos | 29 | 29 | 29 | 0 |
| Closers ativos | 12 | 12 | 12 | 0 |
| Júnior 1 ativos | 26 | 26 | 26 | 0 |
| Júnior 2 ativos | 10 | 10 | 10 | 0 |
| Júnior 3 ativos | 4 | 4 | 4 | 0 |
| Pleno 1 ativos | 1 | 1 | 1 | 0 |
| Águia ativos | 11 | 11 | 11 | 0 |
| Gorila ativos | 7 | 7 | 7 | 0 |
| Lobo ativos | 11 | 11 | 11 | 0 |
| Serpente ativos | 7 | 7 | 7 | 0 |
| Urso ativos | 5 | 5 | 5 | 0 |
| 0/3 ativos | 23 | 23 | 23 | 0 |
| 1/3 ativos | 12 | 12 | 12 | 0 |
| 2/3 ativos | 6 | 6 | 6 | 0 |
| Promoções históricas dos ativos operacionais | 7 | 7 | 7 | 0 |
| Resultados ativos por competência | 41 em cada mês | 41 em cada mês | 41 em cada mês | 0 |
| Pessoas no Kanban padrão | 41 | 41 | 41 | 0 |

Totais operacionais incluindo inativos: 31 SDR, 13 Closers; J1 29, J2 10, J3 4, Pleno 1 1; progresso 0/3 26, 1/3 12, 2/3 6; 44 resultados em cada competência.

## Backup

| Origem | Cópia | Linhas | Hash MD5 |
|---|---|---:|---|
| `public.colaboradores_perfis` | `archive.colaboradores_perfis_20260806t130602z` | 73 | `f3680b236e4d7ff9037be59fca9875c9` |
| `public.colaboradores` | `archive.colaboradores_20260806t130602z` | 584 | `34b3c85011b8fa12ff875da82e9197d2` |
| `public.career_progression_events` | `archive.career_progression_events_20260806t130602z` | 0 | `d41d8cd98f00b204e9800998ecf8427e` |

Todos os hashes coincidiram e as três entradas estão em `archive.progression_backup_manifest`.

## Retomada obrigatória

1. Executar `npm ci`.
2. Executar novamente `npm test`, `npm run lint`, `npm run typecheck`, `npm run build` e `npm run validate:supabase-read`.
3. Revisar status/diff e criar o commit local `fix: correct closer seniority and reconcile dashboard data`.
4. Executar `npx vercel --prod --force` e confirmar o domínio de produção.
5. Validar `/` e `/progressao` em desktop/mobile com Playwright/Chromium, console, Network e ausência de writes.
6. Só então reinstalar manualmente o gatilho do Apps Script.
