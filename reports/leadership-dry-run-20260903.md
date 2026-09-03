# Dry-run — posições terminais de liderança

Data da leitura: 2026-09-02 (America/Fortaleza).

Escopo lido: abas mensais Janeiro–Setembro de `[2026][LID][MENSAL] Pessoas do time` e estado atual do Supabase. Nenhuma célula ou linha de produção foi alterada.

## Pessoas encontradas

| Pessoa | Posição anterior | Transição | Senioridade anterior | Estado imediatamente anterior | Metas a partir da liderança | Evento/estado projetado |
| --- | --- | --- | --- | --- | --- | --- |
| Marcos Vinicius Teles da Silva | SDR (jul/2026) | 2026-08-01 → Liderança de SDRs | Júnior 2 | M3=1, M2=1, ciclo=2, bônus=0, streak=1 | ago: Meta 3 (Liderança de SDRs); set: vazio/sem presença, ainda em Liderança de SDRs | `role_promotion`, SDR → Liderança de SDRs; Júnior 2 preservado; todos os cinco derivados zerados |
| Gregory Lavor Brito Amora | Closer (jul/2026) | 2026-08-01 → Liderança de Closers | Pleno 2 | M3=1, M2=0, ciclo=1, bônus=0, streak=0 | ago e set: Meta não definida em Liderança de Closers | `role_promotion`, Closer → Liderança de Closers; Pleno 2 preservado; todos os cinco derivados zerados; setembro neutro e sem novo evento |

## Retornos à trilha comercial

A nova leitura das nove abas mensais encontrou zero casos `Liderança → SDR/Closer`. Gregory permanece em `Liderança de Closers` em setembro. Nenhuma regra de retorno foi adicionada ao escopo.

## Evidência técnica

- A migration e a suíte própria foram executadas juntas no banco vinculado dentro de `BEGIN ... ROLLBACK`: aprovação.
- A suíte transacional de não regressão SDR/Closer/bônus e o caso incremental de Ana também passaram com a migration carregada: aprovação.
- A projeção transacional com os nomes e fatos reais confirmou os dois eventos em 2026-08-01 e os estados finais condicionais da tabela; a tentativa de setembro de Gregory foi rejeitada pelo gate esperado.
- A migration foi aplicada em produção somente depois da aprovação deste dry-run e das suítes transacionais.
- Após a migration e antes da atualização manual do Apps Script, Gregory ainda não possui perfil no Supabase e Marcos continua materializado como SDR porque o adaptador atual ignora liderança.

## Gate

O bloqueio funcional foi removido pela correção da fonte. O dry-run atualizado está aprovado para implantação controlada.
