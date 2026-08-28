export type GoalLevel = "below" | "meta1" | "meta2" | "meta3" | "absent";

export const SENIORITIES = [
  "Júnior 1", "Júnior 2", "Júnior 3",
  "Pleno 1", "Pleno 2", "Pleno 3",
  "Sênior 1", "Sênior 2", "Sênior 3",
] as const;

export type Seniority = (typeof SENIORITIES)[number];
export type Level = Seniority;
export type PromotionBand = "promoted" | "one_away" | "two_away" | "starting" | "top";

export interface MonthRecord {
  id?: string;
  collaboratorId?: string | null;
  competence?: string | null;
  month: string;
  goal: GoalLevel;
  seniority?: Seniority | null;
  informedSeniority?: Seniority | null;
  squad?: string | null;
  position?: string | null;
  receivedPromotion?: boolean;
}

export interface SDR {
  id: string;
  name: string;
  avatarColor: string;
  level: Seniority;
  squad: string;
  position?: string | null;
  currentProgress?: number;
  active?: boolean;
  history: MonthRecord[];
}

export interface ProgressionState {
  meta3Streak: number;
  meta2Count: 0 | 1;
  cycleProgress: number;
  sdrBonus: 0 | 30 | 40;
  sdrBonusStreak: number;
  tier: 1 | 2;
  wasReset: boolean;
  readyForLevelUp: boolean;
  isCareerTop: boolean;
  lastGoal: GoalLevel | null;
  seniorityAtPeriod: Seniority | null;
  resetCompetence: string | null;
  cycleCompletionCompetences: string[];
  currentCycleMeta3Competences: string[];
  promotionCompetences: string[];
  sdrToCloserCompetences: string[];
  firstCloserCompetence: string | null;
  rampingIgnoredCompetence: string | null;
  closerRampingMetaConsumed: boolean;
}

export interface MonthlyProgressionResult {
  seniority: Seniority;
  progress: number;
  receivedPromotion: boolean;
  cycleCompleted: boolean;
}

export interface CareerRuleState {
  seniority: Seniority;
  meta3: number;
  meta2: 0 | 1;
  bonus: 0 | 30 | 40;
  bonusStreak: number;
}

export interface PromotionClassification {
  sdr: SDR;
  band: PromotionBand;
  progress: number;
  seniorityAtPeriod: Seniority;
  promotedInPeriod: boolean;
}

export const GOAL_LABEL: Record<GoalLevel, string> = {
  below: "Nenhuma meta",
  meta1: "Meta 1",
  meta2: "Meta 2",
  meta3: "Meta 3",
  absent: "Sem presença",
};

const OFFICIAL_NORMALIZED = [
  "JUNIOR 1", "JUNIOR 2", "JUNIOR 3",
  "PLENO 1", "PLENO 2", "PLENO 3",
  "SENIOR 1", "SENIOR 2", "SENIOR 3",
] as const;
const ROMAN_TO_NUMBER: Record<string, string> = { I: "1", II: "2", III: "3" };

function fold(value: string): string {
  return value.normalize("NFD").replace(/[\u0300-\u036f]/g, "").trim().toUpperCase().replace(/\s+/g, " ");
}

/** Operational identity: trims/collapses whitespace and ignores case, while preserving accents. */
export function normalizeName(value: string): string {
  return value.trim().replace(/\s+/g, " ").toLocaleLowerCase("pt-BR");
}

/** Empty is the explicit neutral "Sem presença" state; unknown non-empty values are rejected. */
export function normalizeGoal(value: string | null | undefined): GoalLevel | null {
  if (value == null || value.trim() === "") return "absent";
  const normalized = fold(value);
  if (normalized === "META 1") return "meta1";
  if (normalized === "META 2") return "meta2";
  if (normalized === "META 3") return "meta3";
  if (normalized === "NENHUMA META" || normalized === "SEM META" || normalized === "SEM REGISTRO") return "below";
  if (normalized === "SEM PRESENCA" || normalized === "AUSENTE" || normalized === "META NAO DEFINIDA") return "absent";
  return null;
}

export function normalizeSeniority(value: string | null | undefined): Seniority | null {
  if (!value) return null;
  let normalized = fold(value).replace(/[._-]+/g, " ").replace(/\s+/g, " ");
  normalized = normalized.replace(/^SDR\s+/, "").replace(/^JR\s+/, "JUNIOR ").replace(/^SR\s+/, "SENIOR ");
  const roman = normalized.match(/^(JUNIOR|PLENO|SENIOR)\s+(I|II|III)$/);
  if (roman) normalized = `${roman[1]} ${ROMAN_TO_NUMBER[roman[2]]}`;
  const index = OFFICIAL_NORMALIZED.indexOf(normalized as (typeof OFFICIAL_NORMALIZED)[number]);
  return index < 0 ? null : SENIORITIES[index];
}

export function getNextSeniority(value: string | null | undefined): Seniority | null {
  const seniority = normalizeSeniority(value);
  if (!seniority) return null;
  const index = SENIORITIES.indexOf(seniority);
  return index === SENIORITIES.length - 1 ? null : SENIORITIES[index + 1];
}

export function processMonthlyGoal(currentSeniority: string, currentProgress: number, goal: GoalLevel): MonthlyProgressionResult {
  const seniority = normalizeSeniority(currentSeniority);
  if (!seniority) throw new Error(`Senioridade inválida: ${currentSeniority}`);
  let progress = Math.max(0, Math.min(Math.trunc(currentProgress), 2));
  if (goal === "meta3") {
    const next = getNextSeniority(seniority);
    if (progress === 2) return {
      seniority: next ?? seniority,
      progress: 0,
      receivedPromotion: next !== null,
      cycleCompleted: true,
    };
    progress = Math.min(progress + 1, 2);
  }
  return { seniority, progress, receivedPromotion: false, cycleCompleted: false };
}

export function processCareerGoal(state: CareerRuleState, goal: GoalLevel, isSdr: boolean): CareerRuleState & { receivedPromotion: boolean; cycleCompleted: boolean } {
  let { seniority, meta3, meta2, bonus, bonusStreak } = state;
  let receivedPromotion = false;
  let cycleCompleted = false;
  if (isSdr) {
    if (goal === "meta1") { meta3 = 0; meta2 = 0; }
    if (goal === "meta2") { if (meta2 === 1) meta3 = 0; meta2 = 1; }
    if (goal === "meta3") meta3 += 1;
  } else {
    meta2 = 0;
    if (goal === "meta1" || goal === "meta2") meta3 = 0;
    if (goal === "meta3") meta3 += 1;
  }
  if (meta3 >= 3 || (isSdr && meta3 >= 2 && meta2 === 1)) {
    const next = getNextSeniority(seniority);
    meta3 = 0; meta2 = 0; cycleCompleted = true;
    if (next) { seniority = next; receivedPromotion = true; }
  }
  if (!isSdr) { bonus = 0; bonusStreak = 0; }
  else if (goal === "meta1") { bonus = 0; bonusStreak = 0; }
  else if (goal === "meta2") { bonusStreak = 0; if (bonus === 40) bonus = 30; }
  else if (goal === "meta3") {
    if (bonus === 30) { bonus = 40; bonusStreak = 0; }
    else if (bonus === 0) { bonusStreak += 1; if (bonusStreak >= 3) { bonus = 40; bonusStreak = 0; } }
  }
  return { seniority, meta3, meta2, bonus, bonusStreak, receivedPromotion, cycleCompleted };
}

export function compareCompetence(a: MonthRecord, b: MonthRecord): number {
  const byDate = (a.competence ?? "9999-12-31").localeCompare(b.competence ?? "9999-12-31");
  return byDate || (a.id ?? "").localeCompare(b.id ?? "");
}

export function recordsThrough(history: readonly MonthRecord[], throughCompetence?: string | null): MonthRecord[] {
  return history.filter((record) => record.competence != null)
    .filter((record) => !throughCompetence || (record.competence as string) <= throughCompetence)
    .sort(compareCompetence);
}

/**
 * Keeps one deterministic result per collaborator/competence. The database has the
 * same unique key; this guard prevents legacy duplicates from incrementing twice.
 */
export function uniqueRecordsByCompetence(history: readonly MonthRecord[], throughCompetence?: string | null): MonthRecord[] {
  const unique = new Map<string, MonthRecord>();
  for (const record of recordsThrough(history, throughCompetence)) {
    const key = `${record.collaboratorId ?? "profile"}|${record.competence}`;
    unique.set(key, record);
  }
  return [...unique.values()].sort(compareCompetence);
}

function normalizedPosition(value: string | null | undefined): string {
  return fold(value ?? "");
}

export function isEffectiveGoal(goal: GoalLevel): boolean {
  return goal === "meta1" || goal === "meta2" || goal === "meta3";
}

export function getCurrentSquad(history: readonly MonthRecord[], throughCompetence?: string | null): string | null {
  return [...recordsThrough(history, throughCompetence)].reverse().find((record) => record.squad?.trim())?.squad?.trim() ?? null;
}

export function getCurrentPosition(history: readonly MonthRecord[], throughCompetence?: string | null): string | null {
  return [...recordsThrough(history, throughCompetence)].reverse().find((record) => record.position?.trim())?.position?.trim() ?? null;
}

export function parseLegacyCompetence(value: string | null | undefined, baseYear = 2026): string | null {
  if (!value) return null;
  const months: Record<string, number> = { janeiro: 1, fevereiro: 2, marco: 3, abril: 4, maio: 5, junho: 6, julho: 7, agosto: 8, setembro: 9, outubro: 10, novembro: 11, dezembro: 12 };
  const normalized = fold(value).toLocaleLowerCase("pt-BR");
  const month = months[normalized];
  return month ? `${baseYear}-${String(month).padStart(2, "0")}-01` : null;
}

/** Deterministic mirror used by tests/simulation. Supabase remains the source of truth. */
export function computeProgression(history: readonly MonthRecord[], currentSeniority?: string | null, throughCompetence?: string | null): ProgressionState {
  const ordered = uniqueRecordsByCompetence(history, throughCompetence);
  const epoch = "2026-06-01";
  const firstCloserCompetence = ordered.find((record) => normalizedPosition(record.position) === "CLOSER")?.competence ?? null;
  const beforeEpoch = ordered.filter((record) => (record.competence as string) < epoch);
  const eligible = ordered.filter((record) => (record.competence as string) >= epoch);
  const baseline = beforeEpoch.at(-1);
  let seniority: Seniority | null = normalizeSeniority(baseline?.informedSeniority)
    ?? normalizeSeniority(baseline?.seniority)
    ?? eligible.map((record) => normalizeSeniority(record.informedSeniority)).find((value): value is Seniority => value !== null)
    ?? eligible.map((record) => normalizeSeniority(record.seniority)).find((value): value is Seniority => value !== null)
    ?? normalizeSeniority(currentSeniority);
  if (baseline?.receivedPromotion && seniority) seniority = getNextSeniority(seniority) ?? seniority;
  let meta3 = 0;
  let meta2: 0 | 1 = 0;
  let bonus: 0 | 30 | 40 = 0;
  let bonusStreak = 0;
  let wasReset = false;
  let resetCompetence: string | null = null;
  let lastGoal: GoalLevel | null = null;
  let previousPosition: string | null = baseline ? normalizedPosition(baseline.position) : null;
  let closerRampingMetaConsumed = false;
  let rampingIgnoredCompetence: string | null = null;
  let positionDuringRampingScan: string | null = null;
  for (const record of beforeEpoch) {
    const position = normalizedPosition(record.position);
    if (position === "CLOSER" && positionDuringRampingScan !== "CLOSER") {
      closerRampingMetaConsumed = false;
      rampingIgnoredCompetence = null;
    }
    if (position === "CLOSER" && !closerRampingMetaConsumed && isEffectiveGoal(record.goal)) {
      closerRampingMetaConsumed = true;
      rampingIgnoredCompetence = record.competence ?? null;
    }
    if (position) positionDuringRampingScan = position;
  }
  const cycleCompletionCompetences: string[] = [];
  let currentCycleMeta3Competences: string[] = [];
  const promotionCompetences: string[] = [];
  const sdrToCloserCompetences: string[] = [];
  for (const record of eligible) {
    const historicalPosition = normalizedPosition(record.position);
    const informedSeniority = normalizeSeniority(record.informedSeniority);
    const roleChanged = previousPosition === "SDR" && historicalPosition === "CLOSER";
    const enteredCloser = historicalPosition === "CLOSER" && previousPosition !== "CLOSER";
    if (enteredCloser) {
      closerRampingMetaConsumed = false;
      rampingIgnoredCompetence = null;
    }
    if (roleChanged) {
      meta3 = 0; meta2 = 0; bonus = 0; bonusStreak = 0;
      seniority = informedSeniority ?? seniority;
      currentCycleMeta3Competences = [];
      wasReset = true; resetCompetence = record.competence ?? null; lastGoal = record.goal;
      if (roleChanged && record.competence) sdrToCloserCompetences.push(record.competence);
    } else if (informedSeniority && informedSeniority !== seniority) {
      seniority = informedSeniority; meta3 = 0; meta2 = 0; currentCycleMeta3Competences = [];
      wasReset = true; resetCompetence = record.competence ?? null;
    }
    if (historicalPosition === "CLOSER" && !closerRampingMetaConsumed && isEffectiveGoal(record.goal)) {
      closerRampingMetaConsumed = true;
      rampingIgnoredCompetence = record.competence ?? null;
      lastGoal = record.goal;
      if (historicalPosition) previousPosition = historicalPosition;
      continue;
    }
    if (historicalPosition) previousPosition = historicalPosition;
    if (!seniority) continue;
    lastGoal = record.goal;
    const isSdr = historicalPosition === "SDR";
    const previousMeta2 = meta2;
    const result = processCareerGoal({ seniority, meta3, meta2, bonus, bonusStreak }, record.goal, isSdr);
    if (result.cycleCompleted) {
      wasReset = true; resetCompetence = record.competence ?? null;
      if (record.competence) cycleCompletionCompetences.push(record.competence);
      currentCycleMeta3Competences = [];
    } else if (record.goal === "meta1" || (record.goal === "meta2" && (!isSdr || previousMeta2 === 1))) {
      currentCycleMeta3Competences = [];
    } else if (record.goal === "meta3" && record.competence) currentCycleMeta3Competences.push(record.competence);
    if (result.receivedPromotion && record.competence) promotionCompetences.push(record.competence);
    seniority = result.seniority; meta3 = result.meta3; meta2 = result.meta2;
    bonus = result.bonus; bonusStreak = result.bonusStreak;
  }
  const isCareerTop = seniority === "Sênior 3";
  const cycleProgress = previousPosition === "CLOSER" ? meta3 : meta3 + meta2;
  return { meta3Streak: meta3, meta2Count: meta2, cycleProgress, sdrBonus: bonus, sdrBonusStreak: bonusStreak,
    tier: cycleProgress >= 2 ? 2 : 1, wasReset, readyForLevelUp: cycleProgress === 2 && !isCareerTop,
    isCareerTop, lastGoal, seniorityAtPeriod: seniority, resetCompetence, cycleCompletionCompetences,
    currentCycleMeta3Competences, promotionCompetences, sdrToCloserCompetences,
    firstCloserCompetence, rampingIgnoredCompetence, closerRampingMetaConsumed };
}

export interface CloserPromotionProjection {
  promotionCompetence: string | null;
  projectedMeta3Competences: string[];
  rampingMetaCompetence: string | null;
}

function addCompetenceMonths(competence: string, months: number): string | null {
  const match = /^(\d{4})-(\d{2})-01$/.exec(competence);
  if (!match) return null;
  const date = new Date(Date.UTC(Number(match[1]), Number(match[2]) - 1 + months, 1));
  return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, "0")}-01`;
}

/** Projection is read-only: the latest neutral competence is an available slot, not historical progress. */
export function projectNextCloserPromotion(
  history: readonly MonthRecord[], currentSeniority?: string | null, throughCompetence?: string | null,
): CloserPromotionProjection {
  const ordered = uniqueRecordsByCompetence(history, throughCompetence);
  const latest = ordered.at(-1);
  if (!latest?.competence || normalizedPosition(latest.position) !== "CLOSER") {
    return { promotionCompetence: null, projectedMeta3Competences: [], rampingMetaCompetence: null };
  }
  const state = computeProgression(ordered, currentSeniority, throughCompetence);
  let competence = latest.competence;
  if (isEffectiveGoal(latest.goal)) {
    const next = addCompetenceMonths(competence, 1);
    if (!next) return { promotionCompetence: null, projectedMeta3Competences: [], rampingMetaCompetence: null };
    competence = next;
  }
  let rampingConsumed = state.closerRampingMetaConsumed;
  let rampingMetaCompetence: string | null = null;
  let streak = state.meta3Streak;
  const projectedMeta3Competences: string[] = [];
  while (streak < 3) {
    if (!rampingConsumed) {
      rampingConsumed = true;
      rampingMetaCompetence = competence;
    } else {
      streak += 1;
      projectedMeta3Competences.push(competence);
    }
    if (streak < 3) {
      const next = addCompetenceMonths(competence, 1);
      if (!next) return { promotionCompetence: null, projectedMeta3Competences, rampingMetaCompetence };
      competence = next;
    }
  }
  return { promotionCompetence: competence, projectedMeta3Competences, rampingMetaCompetence };
}

export function getPromotionBand(seniority: string, progress: number, promotedInPeriod = false): PromotionBand {
  if (promotedInPeriod) return "promoted";
  if (normalizeSeniority(seniority) === "Sênior 3") return "top";
  if (progress === 2) return "one_away";
  if (progress === 1) return "two_away";
  return "starting";
}

export function classifyPromotionBands(sdrs: readonly SDR[], period?: string | null): PromotionClassification[] {
  const seen = new Set<string>();
  return sdrs.filter((sdr) => !seen.has(sdr.id) && Boolean(seen.add(sdr.id)))
    .filter((sdr) => !period || sdr.history.length === 0 || recordsThrough(sdr.history, period).length > 0)
    .map((sdr) => {
      const through = recordsThrough(sdr.history, period);
      const promotedInPeriod = through.some((record) => record.competence === period && record.receivedPromotion);
      const state = computeProgression(through, sdr.level, period);
      const seniorityAtPeriod = state.seniorityAtPeriod ?? sdr.level;
      const historicalSquad = getCurrentSquad(through, period);
      return { sdr: historicalSquad ? { ...sdr, squad: historicalSquad } : sdr, progress: state.cycleProgress, promotedInPeriod, seniorityAtPeriod, band: getPromotionBand(seniorityAtPeriod, state.cycleProgress, promotedInPeriod) };
    })
    .sort((a, b) => a.sdr.name.localeCompare(b.sdr.name, "pt-BR", { sensitivity: "base" }));
}

export function formatCompetence(value: string): string {
  return formatarCompetencia(value);
}

const MONTH_LABELS = ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"] as const;

export function formatarCompetencia(competencia: string): string {
  const match = /^(\d{4})-(\d{2})(?:-\d{2})?$/.exec(competencia);
  if (!match) return competencia;
  const monthIndex = Number(match[2]) - 1;
  return MONTH_LABELS[monthIndex] ? `${MONTH_LABELS[monthIndex]}/${match[1]}` : competencia;
}

export function formatarEtapaProgresso(progresso: number): string {
  if (progresso === 0) return "0/3";
  if (progresso === 1) return "1/3";
  if (progresso === 2) return "2/3";
  return "Etapa não informada";
}

export function formatarComposicaoCiclo(meta3: number, meta2: number, position?: string | null): string {
  const effectiveMeta2 = normalizedPosition(position) === "CLOSER" ? 0 : meta2;
  const parts = [meta3 ? `${meta3} Meta 3` : null, effectiveMeta2 ? `${effectiveMeta2} Meta 2` : null].filter(Boolean);
  return parts.length ? parts.join(" + ") : "Ciclo sem metas válidas";
}

export function goalTone(goal: GoalLevel): "success" | "warning" | "danger" | "muted" {
  if (goal === "meta3") return "success";
  if (goal === "meta1" || goal === "meta2") return "warning";
  if (goal === "below") return "danger";
  return "muted";
}
