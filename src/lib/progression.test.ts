import { describe, expect, it } from "vitest";
import {
  SENIORITIES, classifyPromotionBands, computeProgression, getCurrentPosition, getCurrentSquad, getNextSeniority,
  formatarCompetencia, formatarEtapaProgresso, normalizeGoal, normalizeName, normalizeSeniority, parseLegacyCompetence, processMonthlyGoal, recordsThrough,
  type GoalLevel, type MonthRecord, type SDR, type Seniority,
} from "./progression";

const record = (
  competence: string,
  goal: GoalLevel,
  seniority: Seniority = "Júnior 1",
  receivedPromotion = false,
): MonthRecord => ({ competence, month: competence, goal, seniority, receivedPromotion });

const progress = (goals: GoalLevel[]) => computeProgression(
  goals.map((goal, index) => record(`2026-${String(index + 1).padStart(2, "0")}-01`, goal)),
  "Júnior 1",
).meta3Streak;

function runMonthly(seniority: Seniority, goals: GoalLevel[]) {
  return goals.reduce(
    (state, goal) => processMonthlyGoal(state.seniority, state.progress, goal),
    { seniority, progress: 0, receivedPromotion: false, cycleCompleted: false },
  );
}

const sdr = (id: string, name: string, history: MonthRecord[], level: Seniority = "Júnior 1"): SDR => ({
  id, name, history, level, squad: "LOBO", avatarColor: "0 0% 0%",
});

describe("normalização estrita", () => {
  it("formata competências e exibe a quantidade real de Meta 3", () => {
    expect(formatarCompetencia("2026-01-01")).toBe("Jan/2026");
    expect(formatarCompetencia("2026-08-01")).toBe("Ago/2026");
    expect([0, 1, 2].map(formatarEtapaProgresso)).toEqual(["0/3", "1/3", "2/3"]);
  });
  it("mantém a ordem oficial e os saltos entre famílias", () => {
    expect(SENIORITIES.map(getNextSeniority)).toEqual([
      "Júnior 2", "Júnior 3", "Pleno 1", "Pleno 2", "Pleno 3",
      "Sênior 1", "Sênior 2", "Sênior 3", null,
    ]);
  });

  it("normaliza aliases conhecidos e rejeita senioridades desconhecidas", () => {
    expect(normalizeSeniority("Júnior I")).toBe("Júnior 1");
    expect(normalizeSeniority("SDR Pleno III")).toBe("Pleno 3");
    expect(normalizeSeniority("SDR Sênior III")).toBe("Sênior 3");
    expect(normalizeSeniority("SDR IV")).toBeNull();
    expect(() => processMonthlyGoal("SDR IV", 0, "meta3")).toThrow("Senioridade inválida");
  });

  it("aceita apenas as quatro metas oficiais, ignorando caixa e espaços", () => {
    expect(normalizeGoal("  meta   3 ")).toBe("meta3");
    expect(normalizeGoal("NENHUMA META")).toBe("below");
    expect(normalizeGoal("Sem registro")).toBe("below");
    expect(normalizeGoal("Mega meta")).toBeNull();
    expect(normalizeGoal(null)).toBe("absent");
    expect(normalizeGoal(" Sem presença ")).toBe("absent");
  });
});

describe("regra mensal", () => {
  it.each([
    ["nenhum histórico", [], 0],
    ["Meta 1", ["meta1"], 0],
    ["Meta 2", ["meta2"], 0],
    ["Meta 3", ["meta3"], 1],
    ["Meta 3, Meta 1", ["meta3", "meta1"], 1],
    ["Meta 3, Meta 2", ["meta3", "meta2"], 1],
    ["duas Meta 3 com Meta 2", ["meta3", "meta2", "meta3"], 2],
    ["Meta 3 e sem registro", ["meta3", "below"], 1],
    ["sem registro é neutro", ["meta3", "meta3", "below", "meta1"], 2],
  ] as Array<[string, GoalLevel[], number]>)("%s resulta em progresso %s", (_name, goals, expected) => {
    expect(progress(goals)).toBe(expected);
  });

  it("Meta 1 e Meta 2 nunca zeram progresso conquistado", () => {
    expect(processMonthlyGoal("Pleno 1", 2, "meta1").progress).toBe(2);
    expect(processMonthlyGoal("Pleno 1", 2, "meta2").progress).toBe(2);
  });

  it("promove na terceira Meta 3 e reinicia o ciclo", () => {
    expect(runMonthly("Júnior 1", ["meta3", "meta1", "meta3", "meta2", "meta3"])).toEqual({
      seniority: "Júnior 2", progress: 0, receivedPromotion: true, cycleCompleted: true,
    });
  });

  it.each([
    ["Júnior 1", "Júnior 2"], ["Júnior 3", "Pleno 1"],
    ["Pleno 3", "Sênior 1"], ["Sênior 2", "Sênior 3"],
  ] as Array<[Seniority, Seniority]>)("%s promove para %s", (from, to) => {
    expect(runMonthly(from, ["meta3", "meta3", "meta3"]).seniority).toBe(to);
  });

  it("Sênior 3 conclui o terceiro ciclo sem promoção e reinicia", () => {
    expect(runMonthly("Sênior 3", ["meta3", "meta3"])).toMatchObject({ seniority: "Sênior 3", progress: 2, receivedPromotion: false, cycleCompleted: false });
    expect(runMonthly("Sênior 3", ["meta3", "meta3", "meta3"])).toEqual({ seniority: "Sênior 3", progress: 0, receivedPromotion: false, cycleCompleted: true });
    expect(runMonthly("Sênior 3", ["meta3", "meta3", "meta3", "meta3"])).toEqual({ seniority: "Sênior 3", progress: 1, receivedPromotion: false, cycleCompleted: false });
  });

  it.each(["meta1", "meta2", "absent", "below"] as GoalLevel[])("Sênior 3 mantém 2/3 com %s", (goal) => {
    expect(processMonthlyGoal("Sênior 3", 2, goal)).toEqual({ seniority: "Sênior 3", progress: 2, receivedPromotion: false, cycleCompleted: false });
  });

  it("registro promovido encerra o ciclo e a próxima Meta 3 inicia em 1", () => {
    const history = [
      record("2026-01-01", "meta3"), record("2026-02-01", "meta3"),
      record("2026-03-01", "meta3", "Júnior 1", true),
      record("2026-04-01", "meta3", "Júnior 2"),
    ];
    expect(computeProgression(history, "Júnior 2")).toMatchObject({ meta3Streak: 1, seniorityAtPeriod: "Júnior 2" });
  });
});

describe("identidade e mobilidade", () => {
  it("normaliza caixa e espaços sem remover acentos ou sobrenomes", () => {
    expect(normalizeName(" Gabriel   Barbosa ")).toBe(normalizeName("gabriel barbosa"));
    expect(normalizeName("Álvaro Silva")).toBe("álvaro silva");
    expect(normalizeName("Gabriel de Barbosa")).not.toBe(normalizeName("Gabriel Barbosa"));
    expect(normalizeName("Gabriel Barbosa Silva")).not.toBe(normalizeName("Gabriel Barbosa"));
  });

  it("troca de SDR para Closer reinicia antes de avaliar a primeira competência", () => {
    const history = [
      { ...record("2026-01-01", "meta3"), squad: "LOBO", position: "SDR" },
      { ...record("2026-02-01", "meta2"), squad: "LOBO", position: "SDR" },
      { ...record("2026-03-01", "meta3"), squad: "ÁGUIA", position: "Closer" },
    ];
    expect(computeProgression(history)).toMatchObject({ meta3Streak: 1, resetCompetence: "2026-03-01" });
    expect(getCurrentSquad(history)).toBe("ÁGUIA");
    expect(getCurrentSquad(history, "2026-02-01")).toBe("LOBO");
    expect(getCurrentPosition(history)).toBe("Closer");
    expect(history[0].squad).toBe("LOBO");
  });
});

describe("ausência, recomposição e competência legada", () => {
  it("Meta 3, Sem presença, Meta 3 resulta em dois", () => {
    expect(progress(["meta3", "absent", "meta3"])).toBe(2);
    expect(processMonthlyGoal("Júnior 1", 1, "absent").progress).toBe(1);
  });

  it("corrigir ausência para Meta 3 permite recompor a promoção", () => {
    const history = [record("2026-01-01", "meta3"), record("2026-02-01", "absent"), record("2026-03-01", "meta3")];
    expect(computeProgression(history).seniorityAtPeriod).toBe("Júnior 1");
    history[1] = record("2026-02-01", "meta3");
    expect(computeProgression(history).seniorityAtPeriod).toBe("Júnior 2");
  });

  it("usa 2026 para mês legado claro e rejeita valor ambíguo", () => {
    expect(parseLegacyCompetence(" Abril ")).toBe("2026-04-01");
    expect(parseLegacyCompetence("abril talvez")).toBeNull();
  });

  it("senioridade informada na competência tem prioridade sem reescrever meses anteriores", () => {
    const history = [
      record("2026-01-01", "meta3"), record("2026-02-01", "meta3"),
      record("2026-03-01", "meta3"),
      { ...record("2026-04-01", "meta1", "Júnior 2"), informedSeniority: "Júnior 1" as Seniority },
    ];
    expect(computeProgression(history).seniorityAtPeriod).toBe("Júnior 1");
  });
});

describe("ordenação temporal e corte", () => {
  it("ordena registros fora de ordem por competência", () => {
    const history = [record("2026-03-01", "meta3"), record("2026-01-01", "meta3"), record("2026-02-01", "below")];
    expect(recordsThrough(history).map((item) => item.competence)).toEqual(["2026-01-01", "2026-02-01", "2026-03-01"]);
    expect(computeProgression(history).meta3Streak).toBe(2);
  });

  it("dezembro vem antes de janeiro do ano seguinte", () => {
    expect(recordsThrough([record("2027-01-01", "meta3"), record("2026-12-01", "meta3")])[0].competence).toBe("2026-12-01");
  });

  it("filtro mensal não usa resultados futuros", () => {
    const history = [record("2026-01-01", "meta3"), record("2026-02-01", "meta3"), record("2026-03-01", "below")];
    expect(computeProgression(history, "Júnior 1", "2026-02-01").meta3Streak).toBe(2);
  });

  it("não deixa senioridade informada posterior criar um ciclo artificial", () => {
    const history = [record("2026-01-01", "meta3", "Júnior 1"), record("2026-02-01", "meta3", "Júnior 2")];
    expect(computeProgression(history).meta3Streak).toBe(2);
  });
});

describe("casos obrigatórios de ciclo", () => {
  it.each([
    ["nenhum resultado", [], 0],
    ["somente Sem presença", ["absent"], 0],
    ["somente Sem registro", ["below"], 0],
    ["Meta 1 e Meta 2", ["meta1", "meta2"], 0],
    ["Meta 3 seguida por Meta 1", ["meta3", "meta1"], 1],
    ["Meta 3 seguida por Meta 2", ["meta3", "meta2"], 1],
    ["Meta 3 seguida por Sem presença", ["meta3", "absent"], 1],
    ["Meta 3 seguida por Sem registro", ["meta3", "below"], 1],
    ["duas Meta 3 em competências distintas", ["meta3", "meta3"], 2],
  ] as Array<[string, GoalLevel[], number]>)('%s resulta em %i/3', (_name, goals, expected) => {
    expect(progress(goals)).toBe(expected);
  });

  it("duas linhas de Meta 3 na mesma competência incrementam uma vez", () => {
    const history = [
      { ...record("2026-01-01", "meta3"), id: "a", collaboratorId: "p" },
      { ...record("2026-01-01", "meta3"), id: "b", collaboratorId: "p" },
    ];
    expect(computeProgression(history).meta3Streak).toBe(1);
  });

  it("duas Meta 3 como SDR não passam para o ciclo de Closer", () => {
    const history = [
      { ...record("2026-04-01", "meta3"), position: "SDR" },
      { ...record("2026-05-01", "meta3"), position: "SDR" },
      { ...record("2026-07-01", "meta1"), position: "Closer" },
    ];
    expect(computeProgression(history)).toMatchObject({ meta3Streak: 0, resetCompetence: "2026-07-01" });
  });

  it.each([
    ["Adrilene", [{ ...record("2026-07-01", "absent"), position: "SDR" }], 0],
    ["Luiz", [{ ...record("2026-07-01", "meta3"), position: "SDR" }], 1],
  ] as Array<[string, MonthRecord[], number]>)('%s valida em %i/3 sem regra por nome', (_name, history, expected) => {
    expect(computeProgression(history).meta3Streak).toBe(expected);
  });

  it("Miguel encerra SDR em junho e permanece em 0/3 sem Meta 3 como Closer", () => {
    const history = [
      { ...record("2026-03-01", "meta3", "Júnior 1"), position: "SDR" },
      { ...record("2026-06-01", "meta3", "Júnior 1"), position: "SDR" },
      { ...record("2026-07-01", "absent", "Júnior 1"), position: "Closer", informedSeniority: "Júnior 1" as Seniority },
      { ...record("2026-08-01", "absent", "Júnior 1"), position: "Closer", informedSeniority: "Júnior 1" as Seniority },
    ];
    expect(getCurrentPosition(history)).toBe("Closer");
    expect(computeProgression(history)).toMatchObject({ meta3Streak: 0, seniorityAtPeriod: "Júnior 1", resetCompetence: "2026-07-01" });
  });

  it("Taty preserva SDR Júnior 3 e inicia Closer Júnior 2 em 0/3 sem Meta 3", () => {
    const history: MonthRecord[] = [
      { ...record("2026-04-01", "meta1", "Júnior 3"), position: "SDR", informedSeniority: "Júnior 3" },
      { ...record("2026-06-01", "meta2", "Júnior 3"), position: "SDR", informedSeniority: "Júnior 3" },
      { ...record("2026-07-01", "absent", "Júnior 2"), position: "Closer", informedSeniority: "Júnior 2" },
      { ...record("2026-08-01", "absent", "Júnior 2"), position: "Closer", informedSeniority: "Júnior 2" },
    ];
    expect(computeProgression(history)).toMatchObject({ meta3Streak: 0, seniorityAtPeriod: "Júnior 2", resetCompetence: "2026-07-01" });
  });
});

describe("classificação das faixas", () => {
  it("classifica promovido, progresso 2, 1 e 0 sem duplicidade", () => {
    const people = [
      sdr("p", "Promovida", [record("2026-01-01", "meta3"), record("2026-02-01", "meta3"), record("2026-03-01", "meta3", "Júnior 1", true)]),
      sdr("dois", "Duas", [record("2026-01-01", "meta3"), record("2026-03-01", "meta3")]),
      sdr("um", "Uma", [record("2026-03-01", "meta3")]),
      sdr("zero", "Zero", [record("2026-03-01", "meta1")]),
    ];
    const classified = classifyPromotionBands(people, "2026-03-01");
    expect(classified.map((item) => item.band)).toEqual(["one_away", "promoted", "two_away", "starting"]);
    expect(new Set(classified.map((item) => item.sdr.id)).size).toBe(classified.length);
  });

  it("nomes iguais com IDs diferentes não misturam históricos", () => {
    const classified = classifyPromotionBands([
      sdr("1", "Ana", [record("2026-01-01", "meta3")]),
      sdr("2", "Ana", [record("2026-01-01", "meta1")]),
    ], "2026-01-01");
    expect(classified.map((item) => [item.sdr.id, item.progress])).toEqual([["1", 1], ["2", 0]]);
  });

  it("ordena alfabeticamente com locale brasileiro e não usa futuro", () => {
    const classified = classifyPromotionBands([
      sdr("z", "Zélia", [record("2026-01-01", "meta1")]),
      sdr("a", "Álvaro", [record("2026-01-01", "meta1")]),
      sdr("future", "Futura", [record("2026-02-01", "meta3")]),
    ], "2026-01-01");
    expect(classified.map((item) => item.sdr.name)).toEqual(["Álvaro", "Zélia"]);
  });
});
