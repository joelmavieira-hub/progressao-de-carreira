# Dry-run da progressão de Closer — 2026-08-28

## Gate pré-escrita

- Modo: somente leitura; nenhuma escrita em produção.
- Base lida: 78 perfis, 624 resultados e 0 competências duplicadas.
- Casos de aceite: **12/12**.
- Mudanças inesperadas de senioridade: **0**.
- Diferenças na segunda execução da máquina de referência: **0**.
- Alterações projetadas em perfis: **4**.
- Gate técnico: **aprovado**, aguardando apresentação e autorização da etapa de escrita.

O replay histórico e a projeção são operações distintas. `Sem presença`, `Nenhuma meta`, `Meta não definida` e vazio não alteram o estado histórico. Na projeção, a competência mais recente vazia é reutilizada como primeiro slot hipotético; nenhuma meta fictícia é gravada.

## Comparação dos 12 casos de aceite

| Colaborador | Histórico desde junho | Ramping efetivo consumido em | Streak anterior → correto | Slots projetados | Próxima correta | Senioridade alterada | Aceite |
|---|---|---|---|---|---|---|---|
| Luan Nicolas Sinesio Crisostomo | Jun M2; Jul M3; Ago vazio | Fev/2026 | 1 M3 + 1 M2 → 1 M3 | Ago M3; Set M3 | Set/2026 | Não | Sim |
| João Paulo Maciel Sousa | Jun M3; Jul M3; Ago vazio | Jun/2026 | 1 M3 → 1 M3 | Ago M3; Set M3 | Set/2026 | Não | Sim |
| Miguel Carneiro Nunes | Jun SDR/M3; Jul Closer/M3; Ago vazio | Jul/2026 | 0 → 0 | Ago M3; Set M3; Out M3 | Out/2026 | Não | Sim |
| Tatyanna Lima de Freitas | Jun SDR/M3; Jul Closer/M3; Ago vazio | Jul/2026 | 0 → 0 | Ago M3; Set M3; Out M3 | Out/2026 | Não | Sim |
| Leandro Dos Santos Pereira | Jun vazio; Jul M1; Ago vazio | Jan/2026 | 0 → 0 | Ago M3; Set M3; Out M3 | Out/2026 | Não | Sim |
| Gustavo Duarte Pinheiro Silva | Jun NM; Jul M3; Ago vazio | Jan/2026 | 1 → 1 | Ago M3; Set M3 | Set/2026 | Não | Sim |
| Guilherme da Silva Gomes | Jun M2; Jul NM; Ago vazio | Abr/2026 | 1 M2 → 0 | Ago M3; Set M3; Out M3 | Out/2026 | Não | Sim |
| Letícia Wendy da Silva Alves | Jun NM; Jul M2; Ago vazio | Mai/2026 | 1 M2 → 0 | Ago M3; Set M3; Out M3 | Out/2026 | Não | Sim |
| Diego Nobre do Santos | Jun vazio; Jul meta não definida; Ago vazio | Pendente | 0 → 0 | Ago ramping; Set M3; Out M3; Nov M3 | Nov/2026 | Não | Sim |
| José Albesson Damasceno Silva | Jun vazio; Jul vazio; Ago vazio | Pendente | 0 → 0 | Nenhum progresso fabricado | Estado zerado | Não | Sim |
| Cleber Rodrigues Souza | Jun NM; Jul M1; Ago vazio | Jul/2026 | 0 → 0 | Ago M3; Set M3; Out M3 | Out/2026 | Não | Sim |
| Johnathan Ranier Brito de Oliveira | Jun M1; Jul M3; Ago vazio | Mai/2026 | 1 → 1 | Ago M3; Set M3 | Set/2026 | Não | Sim |

## Todos os Closers com alteração projetada

| Colaborador | Estado anterior | Estado correto | Senioridade | Motivo |
|---|---|---|---|---|
| Luan Nicolas Sinesio Crisostomo | 1 M3 + 1 M2; ciclo 2/3 | 1 M3; ciclo 1/3 | Júnior 3 → Júnior 3 | M2 não compõe progressão de Closer |
| Guilherme da Silva Gomes | 1 M2; ciclo 1/3 | 0/3 | Júnior 1 → Júnior 1 | M2 não é âncora de Closer |
| Letícia Wendy da Silva Alves | 1 M2; ciclo 1/3 | 0/3 | Júnior 1 → Júnior 1 | M2 não é âncora de Closer |
| Luiz Fernando de Medeiros Paiva Moura | 1 M3; ciclo 1/3 | 0/3 | Júnior 3 → Júnior 3 | M3 de julho é a primeira meta efetiva de Closer e consome o ramping |

Os demais Closers permanecem sem alteração persistida de progresso ou senioridade.

## Validações técnicas

- Testes Vitest: 126/126 aprovados.
- Typecheck: aprovado.
- Lint: 0 erros; 7 avisos preexistentes de Fast Refresh.
- Build de produção: aprovado.
- Testes SQL transacionais foram atualizados para ramping após um ou mais vazios; o ambiente local não possui `supabase`/`psql` para executá-los.

Nenhum replay, backfill, commit, push ou deploy foi executado nesta etapa.
