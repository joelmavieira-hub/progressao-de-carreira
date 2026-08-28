import { describe, expect, it } from "vitest";
import {
  SENIORITIES, computeProgression, formatarCompetencia, formatarComposicaoCiclo,
  getCurrentPosition, getCurrentSquad, getNextSeniority, normalizeGoal, normalizeName,
  normalizeSeniority, parseLegacyCompetence, processCareerGoal, projectNextCloserPromotion, recordsThrough,
  type CareerRuleState, type GoalLevel, type MonthRecord, type Seniority,
} from "./progression";

const month = (offset: number) => {
  const date = new Date(Date.UTC(2026, 5 + offset, 1));
  return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, "0")}-01`;
};
const record = (competence: string, goal: GoalLevel, position = "SDR", seniority: Seniority = "Júnior 1"): MonthRecord => ({
  competence, month: competence, goal, position, seniority, informedSeniority: seniority,
});
const history = (goals: GoalLevel[], position = "SDR") => goals.map((goal, index) => record(month(index), goal, position));
const replay = (goals: GoalLevel[], position = "SDR") => computeProgression(history(goals, position), "Júnior 1");

describe("normalização e utilitários", () => {
  it("mantém senioridades e normaliza aliases oficiais", () => {
    expect(SENIORITIES.map(getNextSeniority)).toEqual([
      "Júnior 2", "Júnior 3", "Pleno 1", "Pleno 2", "Pleno 3", "Sênior 1", "Sênior 2", "Sênior 3", null,
    ]);
    expect(normalizeSeniority("SDR Pleno III")).toBe("Pleno 3");
    expect(normalizeSeniority("SDR IV")).toBeNull();
  });
  it("normaliza metas, nomes e competências sem ambiguidades", () => {
    expect(normalizeGoal(" meta   3 ")).toBe("meta3");
    expect(normalizeGoal("Nenhuma Meta")).toBe("below");
    expect(normalizeGoal("Sem presença")).toBe("absent");
    expect(normalizeGoal("Meta não definida")).toBe("absent");
    expect(normalizeGoal("Mega meta")).toBeNull();
    expect(normalizeName(" Gabriel   Barbosa ")).toBe("gabriel barbosa");
    expect(parseLegacyCompetence(" Abril ")).toBe("2026-04-01");
    expect(formatarCompetencia("2026-08-01")).toBe("Ago/2026");
    expect(formatarComposicaoCiclo(1, 1)).toBe("1 Meta 3 + 1 Meta 2");
    expect(formatarComposicaoCiclo(1, 1, "Closer")).toBe("1 Meta 3");
  });
});

describe("máquina de progressão desde junho/2026", () => {
  it.each([
    [["meta3", "meta3", "meta3"], "2026-08-01"],
    [["meta3", "meta3", "meta2"], "2026-08-01"],
    [["meta3", "meta2", "meta3"], "2026-08-01"],
    [["meta2", "meta3", "meta3"], "2026-08-01"],
    [["meta2", "meta2", "meta3", "meta3"], "2026-09-01"],
    [["meta3", "meta2", "meta2", "meta3", "meta3"], "2026-10-01"],
    [["meta2", "meta2", "meta2", "meta3", "meta3"], "2026-10-01"],
  ] as Array<[GoalLevel[], string]>)('%j promove na competência correta', (goals, competence) => {
    const state = replay(goals);
    expect(state.seniorityAtPeriod).toBe("Júnior 2");
    expect(state.promotionCompetences).toEqual([competence]);
    expect(state.cycleProgress).toBe(0);
  });

  it.each([
    [["meta3", "meta2", "meta2"], 0, 1],
    [["meta2", "meta3", "meta2"], 0, 1],
    [["meta2", "meta2", "meta2"], 0, 1],
  ] as Array<[GoalLevel[], number, number]>)('%j mantém somente a Meta 2 mais recente', (goals, meta3, meta2) => {
    expect(replay(goals)).toMatchObject({ meta3Streak: meta3, meta2Count: meta2, cycleProgress: 1 });
  });

  it("Meta 1 reseta e não inicia outro ciclo", () => {
    expect(replay(["meta3", "meta1"])).toMatchObject({ meta3Streak: 0, meta2Count: 0 });
    expect(replay(["meta3", "meta2", "meta1", "meta3"])).toMatchObject({ meta3Streak: 1, meta2Count: 0 });
  });
  it.each([
    [["meta3", "below", "meta3", "meta3"]],
    [["meta3", "absent", "meta3", "meta2"]],
  ] as Array<[GoalLevel[]]>)('%j ignora vazios e promove', (goals) => {
    expect(replay(goals).seniorityAtPeriod).toBe("Júnior 2");
  });
  it.each(["below", "absent"] as GoalLevel[])('%s isolado é neutro', (goal) => {
    expect(replay([goal])).toMatchObject({ meta3Streak: 0, meta2Count: 0, cycleProgress: 0 });
  });
  it("ignora maio, conta junho e promove em agosto", () => {
    const rows = [record("2026-05-01", "meta3"), ...history(["meta2", "meta3", "meta3"])];
    expect(computeProgression(rows)).toMatchObject({ seniorityAtPeriod: "Júnior 2", promotionCompetences: ["2026-08-01"] });
  });
  it("não carrega progresso antigo para a primeira Meta 3 de junho", () => {
    expect(computeProgression([record("2026-05-01", "meta3"), record("2026-06-01", "meta3")]))
      .toMatchObject({ meta3Streak: 1, meta2Count: 0, seniorityAtPeriod: "Júnior 1" });
  });
  it("correção histórica altera deterministicamente os meses posteriores", () => {
    const rows = history(["meta3", "meta2", "meta3"]);
    expect(computeProgression(rows).seniorityAtPeriod).toBe("Júnior 2");
    rows[1] = record("2026-07-01", "meta1");
    const first = computeProgression(rows);
    expect(first).toEqual(computeProgression(rows));
    expect(first).toMatchObject({ seniorityAtPeriod: "Júnior 1", meta3Streak: 1 });
  });
  it("deduplica competência escolhendo deterministicamente a linha mais recente", () => {
    const rows = [
      { ...record("2026-06-01", "meta2"), id: "a", collaboratorId: "p" },
      { ...record("2026-06-01", "meta3"), id: "b", collaboratorId: "p" },
    ];
    expect(computeProgression(rows)).toMatchObject({ meta3Streak: 1, meta2Count: 0 });
  });
});

describe("SDR para Closer", () => {
  it("reseta as duas máquinas, ignora a meta da transição e só conta o mês seguinte", () => {
    const rows = [record("2026-06-01", "meta3", "SDR"), record("2026-07-01", "meta3", "Closer"), record("2026-08-01", "meta3", "Closer")];
    expect(computeProgression(rows)).toMatchObject({
      meta3Streak: 1, meta2Count: 0, sdrBonus: 0, sdrBonusStreak: 0,
      resetCompetence: "2026-07-01", sdrToCloserCompetences: ["2026-07-01"],
    });
    expect(getCurrentPosition(rows)).toBe("Closer");
  });
  it("preserva squad e posição históricos", () => {
    const rows = [{ ...record("2026-06-01", "meta3", "SDR"), squad: "Lobo" }, { ...record("2026-07-01", "absent", "Closer"), squad: "Águia" }];
    expect(getCurrentSquad(rows, "2026-06-01")).toBe("Lobo");
    expect(getCurrentSquad(rows)).toBe("Águia");
    expect(recordsThrough(rows).map((row) => row.position)).toEqual(["SDR", "Closer"]);
  });
});

describe("máquina exclusiva de Closer", () => {
  const closerReplay = (goals: GoalLevel[]) => computeProgression([
    record("2026-05-01", "meta3", "Closer"),
    ...history(goals, "Closer"),
  ], "Júnior 1");

  it("promove somente com três Meta 3 consecutivas", () => {
    expect(closerReplay(["meta3", "meta3", "meta3"])).toMatchObject({
      seniorityAtPeriod: "Júnior 2", promotionCompetences: ["2026-08-01"],
      meta3Streak: 0, meta2Count: 0, cycleProgress: 0,
    });
  });

  it.each([
    [["meta3", "meta2", "meta3"], 1],
    [["meta3", "meta3", "meta2"], 0],
    [["meta2", "meta3", "meta3"], 2],
    [["meta3", "meta1", "meta3"], 1],
  ] as Array<[GoalLevel[], number]>)('%j termina com %i Meta 3 consecutiva(s)', (goals, expected) => {
    expect(closerReplay(goals)).toMatchObject({ meta3Streak: expected, meta2Count: 0, cycleProgress: expected });
  });

  it.each([
    [["meta3", "absent", "meta3", "meta3"]],
    [["meta3", "below", "meta3", "meta3"]],
  ] as Array<[GoalLevel[]]>)('%j preserva a sequência nos vazios e promove', (goals) => {
    expect(closerReplay(goals)).toMatchObject({ seniorityAtPeriod: "Júnior 2", promotionCompetences: ["2026-09-01"] });
  });

  it.each(["meta3", "meta2", "meta1"] as GoalLevel[])('ignora %s no primeiro mês como Closer', (goal) => {
    expect(replay([goal], "Closer")).toMatchObject({
      meta3Streak: 0, meta2Count: 0, cycleProgress: 0,
      firstCloserCompetence: "2026-06-01", rampingIgnoredCompetence: "2026-06-01",
    });
  });

  it("espera a primeira meta efetiva para consumir o ramping", () => {
    expect(replay(["absent", "meta3"], "Closer")).toMatchObject({
      meta3Streak: 0, closerRampingMetaConsumed: true, rampingIgnoredCompetence: "2026-07-01",
    });
    expect(replay(["absent", "below", "meta3"], "Closer")).toMatchObject({
      meta3Streak: 0, closerRampingMetaConsumed: true, rampingIgnoredCompetence: "2026-08-01",
    });
  });

  it("promove somente na terceira Meta 3 posterior ao ramping", () => {
    const state = replay(["meta3", "meta3", "meta3", "meta3"], "Closer");
    expect(state).toMatchObject({
      seniorityAtPeriod: "Júnior 2", promotionCompetences: ["2026-09-01"], meta3Streak: 0,
      rampingIgnoredCompetence: "2026-06-01",
    });
  });
});

describe("projeção de Closer separada do replay", () => {
  const withConsumedRamping = (goals: GoalLevel[]) => [
    record("2026-05-01", "meta3", "Closer"),
    ...goals.map((goal, index) => record(month(index), goal, "Closer")),
  ];

  it("usa agosto vazio como primeiro slot quando há streak 1 em julho", () => {
    const rows = withConsumedRamping(["absent", "meta3", "absent"]);
    expect(computeProgression(rows)).toMatchObject({ meta3Streak: 1 });
    expect(projectNextCloserPromotion(rows)).toEqual({
      promotionCompetence: "2026-09-01",
      projectedMeta3Competences: ["2026-08-01", "2026-09-01"],
      rampingMetaCompetence: null,
    });
  });

  it("projeta outubro com streak zero e agosto vazio", () => {
    const rows = withConsumedRamping(["absent", "meta2", "absent"]);
    expect(projectNextCloserPromotion(rows).promotionCompetence).toBe("2026-10-01");
  });

  it("consome o ramping em agosto e projeta três M3 válidas até novembro", () => {
    const rows = history(["absent", "absent", "absent"], "Closer");
    expect(computeProgression(rows)).toMatchObject({ closerRampingMetaConsumed: false, meta3Streak: 0 });
    expect(projectNextCloserPromotion(rows)).toEqual({
      promotionCompetence: "2026-11-01",
      projectedMeta3Competences: ["2026-09-01", "2026-10-01", "2026-11-01"],
      rampingMetaCompetence: "2026-08-01",
    });
  });
});

describe("bonificação SDR independente", () => {
  const bonus = (goals: GoalLevel[]) => replay(goals).sdrBonus;
  it.each([
    [["meta3", "meta3", "meta3"], 40], [["meta3", "meta3", "meta3", "meta3"], 40],
    [["meta3", "meta3", "meta3", "meta2"], 30], [["meta3", "meta3", "meta3", "meta2", "meta2"], 30],
    [["meta3", "meta3", "meta3", "meta2", "meta3"], 40], [["meta3", "meta3", "meta3", "meta1"], 0],
    [["meta3", "meta3", "meta2", "meta3", "meta3"], 0], [["meta3", "meta3", "meta2", "meta3", "meta3", "meta3"], 40],
    [["meta3", "meta3", "absent", "meta3"], 40], [["meta3", "below", "meta3", "meta3"], 40],
    [["meta3", "meta3", "meta3", "absent"], 40], [["meta3", "meta3", "meta3", "meta2", "below"], 30],
  ] as Array<[GoalLevel[], number]>)('%j resulta em %i%%', (goals, expected) => expect(bonus(goals)).toBe(expected));
  it("após Meta 1 exige novamente três Meta 3", () => {
    expect(bonus(["meta3", "meta3", "meta3", "meta1", "meta3", "meta3"])).toBe(0);
    expect(bonus(["meta3", "meta3", "meta3", "meta1", "meta3", "meta3", "meta3"])).toBe(40);
  });
  it("Closer nunca recebe bonificação", () => {
    expect(computeProgression(history(["meta3", "meta3", "meta3"], "Closer"))).toMatchObject({ sdrBonus: 0, sdrBonusStreak: 0 });
  });
  it("a transição mensal mantém 40/30/0 conforme a regra", () => {
    const base: CareerRuleState = { seniority: "Júnior 1", meta3: 0, meta2: 0, bonus: 40, bonusStreak: 0 };
    expect(processCareerGoal(base, "meta2", true).bonus).toBe(30);
    expect(processCareerGoal({ ...base, bonus: 30 }, "meta3", true).bonus).toBe(40);
    expect(processCareerGoal({ ...base, bonus: 30 }, "meta1", true).bonus).toBe(0);
  });
});
