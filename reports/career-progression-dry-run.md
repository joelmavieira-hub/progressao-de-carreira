# Relatório de inconsistências — dry-run

> Certificação pendente: este relatório precisa ser regenerado contra o estado remoto atual. A execução foi bloqueada porque esta cópia não contém metadata Git e os scripts da Fase A ainda esperam 6.040 linhas legadas, enquanto o estado operacional confirmado contém 576 resultados.

Gerado por leitura pública do Supabase em 2026-08-05 (America/Fortaleza). Nenhuma escrita foi executada.

- 72 perfis e 576 resultados lidos em 8 competências.
- 0 duplicidades por colaborador/competência e 0 órfãos.
- A execução anterior encontrou 12 perfis; essa quantidade não foi assumida como atual após a escrita posterior do Apps Script.
- Distribuição persistida: 0/3 = 53; 1/3 = 10; 2/3 = 9.

## Casos solicitados

- Adrilene: somente `Sem presença`; 0/3 persistido e 0/3 calculado.
- Luiz: 1/3 persistido e 1/3 calculado.
- Tatyanna: o banco marca todas as competências como Closer; abril–junho precisa ser corrigido para SDR/Júnior 3 e julho em diante para Closer/Júnior 2. O reset correto só será calculável após essa correção histórica.
- Miguel — estado persistido: posição histórica marcada como Closer em todos os meses e progresso 2/3.
- Miguel — depois das correções confirmadas simuladas: até Jun/2026 = SDR; Jul/2026 em diante = Closer/Júnior 1; julho e agosto = Sem presença; reset em `2026-07-01`; posição atual Closer; senioridade Júnior 1; progresso 0/3.
- Luan: perfil persistido em Pleno 3; referência solicitada é Júnior 3.
- Gustavo: perfil persistido em Júnior 2; referência solicitada é Júnior 3.
- Leandro Dos Santos Pereira: perfil persistido em Júnior 3; referência solicitada é Pleno 1.
- João Paulo: perfil persistido em Júnior 2; referência solicitada é Júnior 1.

## Outras divergências previstas

- Ana Karoline Rodrigues dos Santos: 0/3 → 1/3.
- Letícia Wendy da Silva Alves: 0/3 → 1/3.
- Maria Gabriele Xavier da Silva: 0/3 → 1/3.
- Miguel Carneiro Nunes: 2/3 → 0/3, com reset SDR → Closer em Jul/2026 e nenhum incremento posterior.
- Rebeca Garcez Cabral: 0/3 → 1/3.
- Lara Stefanny Barbosa de Carvalho Silva: 0/3 → 1/3 após reconstrução do ciclo histórico.
- Thais Giurizatto Cambraia Negreiros: 1/3 → 0/3 após reset SDR → Closer.

As mudanças acima são propostas para revisão. O script `npm run recalculate:dry-run` produz a comparação completa atualizada sem operações de escrita.

## Conclusão de ciclo em Sênior 3

- A terceira Meta 3 conclui o ciclo, mantém Sênior 3, grava progresso calculado 0/3 e não marca promoção.
- A Meta 3 seguinte inicia o novo ciclo em 1/3.
- Não foi criada migration adicional nem campo persistente: a migração já preparada emite `career_cycle_completed` no log do PostgreSQL e o dry-run lista `conclusoesDeCiclo`.
- Limitação documentada: o evento não possui coluna própria. Se auditoria persistente for exigida futuramente, a recomendação é um evento `conclusao_ciclo`/`ciclo_concluido`, sujeito a decisão de modelagem separada.

## Decisões finais

```text
MIGUEL_LAST_SDR_COMPETENCY=2026-06
MIGUEL_FIRST_CLOSER_COMPETENCY=2026-07
MIGUEL_CLOSER_PROGRESS_EXPECTED=0
SENIOR3_THIRD_META_COMPLETES_CYCLE=true
SENIOR3_RESETS_TO_ZERO=true
SENIOR3_RETAINS_SENIORITY=true
SENIOR3_CYCLE_COMPLETION_IS_NOT_PROMOTION=true
SENIOR3_RECEBEU_PROMOCAO_FALSE=true
```
