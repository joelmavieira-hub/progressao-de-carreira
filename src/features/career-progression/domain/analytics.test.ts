import { describe, expect, it } from "vitest";
import { relacionarPerfisEResultados } from "../domain";
import type { ColaboradorPerfil, ColaboradorResultado, PerfilComHistorico } from "../types";
import {
  buildCareerPromotions, buildCycleColumns, calculateCoverage, countUniqueCareerPromoted, countUniquePromoted,
  distributeCycle, distributeSeniority, filterHistoricalResults, filterProfiles, filterProfilesByHistoricalSquad, listSquadsByCompetence,
  findNearPromotion, findRecentPromotions, groupCareerPromotionsByCompetence, groupGoalsByCompetence,
  groupProgressBySquad, groupPromotionsByCompetence, listCompetences, nextSeniority, normalizeSearch, type AnalyticsFilters,
} from "./analytics";

const profile = (id: string, overrides: Partial<ColaboradorPerfil> = {}): ColaboradorPerfil => ({
  id, nome_colaborador: `Pessoa ${id}`, nome_normalizado: `pessoa ${id}`, posicao_atual: "SDR", squad_atual: "Lobo",
  senioridade_atual: "Júnior 1", progresso_meta3: 0, ativo: true, created_at: "2026-01-01T00:00:00Z", updated_at: "2026-08-01T00:00:00Z", ...overrides,
});
const result = (id: string, collaboratorId: string, competence: string, goal = "Meta 1", promoted = false, overrides: Partial<ColaboradorResultado> = {}): ColaboradorResultado => ({
  id, colaborador_id: collaboratorId, nome_colaborador: `Pessoa ${collaboratorId}`, posicao: "SDR", squad: "Lobo", competencia: competence,
  meta_alcancada: goal, senioridade: "Júnior 1", senioridade_informada: "Júnior 1", recebeu_promocao: promoted,
  origem: "google_sheets_progressao", mes_referencia: competence, created_at: competence, updated_at: competence, ...overrides,
});
const related = (profiles: ColaboradorPerfil[], results: ColaboradorResultado[] = []): PerfilComHistorico[] => relacionarPerfisEResultados(profiles, results);
const filters = (overrides: Partial<AnalyticsFilters> = {}): AnalyticsFilters => ({ competence: "2026-08-01", status: "todos", squad: "todos", position: "todos", seniority: "todos", search: "", ...overrides });

describe("analytics", () => {
  it("calcula cobertura com e sem presença sem misturar categorias", () => {
    const data = related([profile("1"), profile("2")], [result("r1", "1", "2026-08-01", "Meta 2"), result("r2", "2", "2026-08-01", "Sem presença")]);
    expect(calculateCoverage(data, "2026-08-01")).toEqual({ present: 1, absent: 1, total: 2, presentPercentage: 50, absentPercentage: 50 });
  });
  it("não conta Sem presença como Nenhuma meta", () => {
    const grouped = groupGoalsByCompetence([result("r1", "1", "2026-08-01", "Sem presença"), result("r2", "2", "2026-08-01", "Nenhuma meta")]);
    expect(grouped[0]).toMatchObject({ "Sem presença": 1, "Nenhuma meta": 1 });
  });
  it("distribui as três etapas do ciclo", () => {
    expect(distributeCycle(related([profile("1"), profile("2", { progresso_meta3: 1 }), profile("3", { progresso_meta3: 2 })])).map((row) => row.total)).toEqual([1, 1, 1]);
  });
  it("distribui senioridade e preserva níveis com zero", () => {
    const rows = distributeSeniority(related([profile("1", { senioridade_atual: "Pleno 2" })]));
    expect(rows).toHaveLength(9); expect(rows.find((row) => row.seniority === "Pleno 2")?.total).toBe(1); expect(rows[0].total).toBe(0);
  });
  it("ordena competências cronologicamente", () => expect(listCompetences([result("r2", "1", "2026-08-01"), result("r1", "1", "2026-01-01")])).toEqual(["2026-01-01", "2026-08-01"]));
  it("agrupa metas por competência", () => expect(groupGoalsByCompetence([result("r1", "1", "2026-01-01", "Meta 3")])[0]["Meta 3"]).toBe(1));
  it("conta Meta 1, Meta 2 e Meta 3 como atingimento mensal", () => {
    const rows = [
      result("r1", "1", "2026-08-01", "Meta 1", false, { posicao: "Closer" }),
      result("r2", "2", "2026-08-01", "Meta 2", false, { posicao: "Closer" }),
      result("r3", "3", "2026-08-01", "Meta 3", false, { posicao: "Closer" }),
      result("r4", "4", "2026-08-01", "Meta 3", false, { posicao: "Closer" }),
      result("r5", "5", "2026-08-01", "Meta 2", false, { posicao: "Closer" }),
      result("r6", "6", "2026-08-01", "Meta 1", false, { posicao: "Closer" }),
      result("r7", "7", "2026-08-01", "Meta 3", false, { posicao: "Closer" }),
      result("r8", "8", "2026-08-01", "Nenhuma meta", false, { posicao: "Closer" }),
      result("r9", "9", "2026-08-01", "Sem presença", false, { posicao: "Closer" }),
    ];
    expect(groupGoalsByCompetence(rows)[0]).toMatchObject({
      "Atingiram meta": 7, "Meta 1": 2, "Meta 2": 2, "Meta 3": 3,
      "Nenhuma meta": 1, "Sem presença": 1,
    });
  });
  it("conta a mesma pessoa uma única vez por competência", () => {
    const rows = [
      result("r1", "1", "2026-08-01", "Meta 1", false, { updated_at: "2026-08-01T10:00:00Z" }),
      result("r2", "1", "2026-08-01", "Meta 3", false, { updated_at: "2026-08-01T11:00:00Z" }),
    ];
    expect(groupGoalsByCompetence(rows)[0]).toMatchObject({ "Atingiram meta": 1, "Meta 1": 0, "Meta 3": 1 });
  });
  it("usa a posição histórica da competência no filtro mensal", () => {
    const profiles = related([profile("1", { posicao_atual: "Closer" }), profile("2", { posicao_atual: "Closer" })]);
    const rows = [
      result("r1", "1", "2026-05-01", "Meta 3", false, { posicao: "SDR" }),
      result("r2", "2", "2026-05-01", "Meta 2", false, { posicao: "Closer" }),
    ];
    const filtered = filterHistoricalResults(rows, profiles, filters({ position: "Closer" }));
    expect(filtered.map((row) => row.id)).toEqual(["r2"]);
  });
  it("agrupa registros de promoção por competência", () => {
    const rows = groupPromotionsByCompetence([result("r1", "1", "2026-01-01", "Meta 3", true), result("r2", "2", "2026-01-01", "Meta 3", true)]);
    expect(rows[0].total).toBe(2);
  });
  it("conta pessoas promovidas de forma única", () => expect(countUniquePromoted([result("r1", "1", "2026-01-01", "Meta 3", true), result("r2", "1", "2026-02-01", "Meta 3", true)])).toBe(1));
  it("exclui squad Saiu da progressão por squad", () => {
    const rows = groupProgressBySquad(related([profile("1"), profile("2", { squad_atual: "Saiu", ativo: false })]));
    expect(rows.map((row) => row.squad)).toEqual(["Lobo"]);
  });
  it("localiza próximos da promoção", () => expect(findNearPromotion(related([profile("1"), profile("2", { progresso_meta3: 2 })])).map((row) => row.perfil.id)).toEqual(["2"]));
  it("ordena promoções recentes por competência", () => {
    const data = related([profile("1")], [result("r1", "1", "2026-01-01", "Meta 3", true), result("r2", "1", "2026-08-01", "Meta 3", true)]);
    expect(findRecentPromotions(data).map((row) => row.result.id)).toEqual(["r2", "r1"]);
  });
  it("monta 0/3, 1/3 e 2/3 sem duplicar o ciclo", () => {
    const columns = buildCycleColumns(related([profile("1"), profile("2", { progresso_meta3: 1 }), profile("3", { progresso_meta3: 2 })]));
    expect([columns.meta1.length, columns.meta2.length, columns.meta3.length]).toEqual([1, 1, 1]);
  });
  it("mantém promoção como coluna auxiliar além da coluna de ciclo", () => {
    const data = related([profile("1")], [result("r1", "1", "2026-08-01", "Meta 3", true)]);
    expect(buildCycleColumns(data).meta1).toHaveLength(1); expect(findRecentPromotions(data, "2026-08-01")).toHaveLength(1);
  });
  it("normaliza busca sem acentos e excesso de espaços", () => expect(normalizeSearch("  José   Álvaro ")).toBe("jose alvaro"));
  it("filtra por nome, status, squad, posição e senioridade", () => {
    const data = related([profile("1", { nome_colaborador: "José Álvaro", nome_normalizado: "jose alvaro", posicao_atual: "Closer", senioridade_atual: "Pleno 1" })]);
    expect(filterProfiles(data, filters({ search: " jose   alvaro ", status: "ativos", squad: "Lobo", position: "Closer", seniority: "Pleno 1" }))).toHaveLength(1);
  });
  it("calcula a transição visual pela escada oficial", () => { expect(nextSeniority("Júnior 3")).toBe("Pleno 1"); expect(nextSeniority("Sênior 3")).toBe("Sênior 3"); });

  it("considera SDR -> Closer uma promoção e evita dupla contagem na mesma competência", () => {
    const data = related([profile("miguel", { nome_colaborador: "Miguel", nome_normalizado: "miguel", posicao_atual: "Closer" })], [
      result("miguel-jun", "miguel", "2026-06-01", "Meta 1", false, { posicao: "SDR" }),
      result("miguel-jul", "miguel", "2026-07-01", "Meta 3", true, { posicao: "Closer" }),
    ]);

    const promotions = buildCareerPromotions(data);

    expect(promotions).toHaveLength(1);
    expect(promotions[0].promotionType).toBe("role_transition");
    expect(promotions[0].fromPosition).toBe("SDR");
    expect(promotions[0].toPosition).toBe("Closer");
    expect(countUniqueCareerPromoted(promotions)).toBe(1);
  });

  it("separa promoções de senioridade e para Closer no agrupamento mensal", () => {
    const profiles = [
      profile("miguel", { nome_colaborador: "Miguel", nome_normalizado: "miguel", posicao_atual: "Closer" }),
      profile("ana"),
    ];

    const results = [
      result("miguel-jun", "miguel", "2026-06-01", "Meta 1", false, { posicao: "SDR" }),
      result("miguel-jul", "miguel", "2026-07-01", "Meta 1", false, { posicao: "Closer" }),
      result("ana-jul", "ana", "2026-07-01", "Meta 3", true, { posicao: "SDR" }),
    ];

    const promotions = buildCareerPromotions(
      related(profiles, results),
    );

    const july = groupCareerPromotionsByCompetence(
      results,
      promotions,
    ).find((row) => row.competence === "2026-07-01");

    expect(july).toMatchObject({
      total: 2,
      seniority: 1,
      roleTransition: 1,
    });
  });
  it("usa o squad da competência em filtros e agrupamentos históricos", () => {
    const pessoa = profile(
      "historico-squad",
      {
        squad_atual: "Gorila",
        progresso_meta3: 1,
      },
    );

    const data = related(
      [pessoa],
      [
        result(
          "historico-jul",
          "historico-squad",
          "2026-07-01",
          "Meta 2",
          false,
          {
            squad: "Urso",
          },
        ),
        result(
          "historico-ago",
          "historico-squad",
          "2026-08-01",
          "Meta 2",
          false,
          {
            squad: "Gorila",
          },
        ),
      ],
    );

    expect(
      listSquadsByCompetence(
        data,
        "2026-07-01",
      ),
    ).toEqual(["Urso"]);

    expect(
      filterProfilesByHistoricalSquad(
        data,
        filters({
          competence: "2026-07-01",
          squad: "Urso",
        }),
      ),
    ).toHaveLength(1);

    expect(
      filterProfilesByHistoricalSquad(
        data,
        filters({
          competence: "2026-07-01",
          squad: "Gorila",
        }),
      ),
    ).toHaveLength(0);

    expect(
      groupProgressBySquad(
        data,
        "2026-07-01",
      ).map((row) => row.squad),
    ).toEqual(["Urso"]);
  });
});
