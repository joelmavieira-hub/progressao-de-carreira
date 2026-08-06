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
}

export interface MonthlyProgressionResult {
  seniority: Seniority;
  progress: number;
  receivedPromotion: boolean;
  cycleCompleted: boolean;
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
  if (normalized === "SEM PRESENCA" || normalized === "AUSENTE") return "absent";
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

/** Pure chronological reconstruction using the competence-level seniority priority. */
export function computeProgression(history: readonly MonthRecord[], currentSeniority?: string | null, throughCompetence?: string | null): ProgressionState {
  const ordered = uniqueRecordsByCompetence(history, throughCompetence);
  let seniority: Seniority | null = null;
  let progress = 0;
  let wasReset = false;
  let resetCompetence: string | null = null;
  let lastGoal: GoalLevel | null = null;
  let previousPosition: string | null = null;
  const cycleCompletionCompetences: string[] = [];
  let currentCycleMeta3Competences: string[] = [];
  const promotionCompetences: string[] = [];
  const sdrToCloserCompetences: string[] = [];
  for (const record of ordered) {
    const historicalPosition = normalizedPosition(record.position);
    if (previousPosition === "SDR" && historicalPosition === "CLOSER") {
      progress = 0;
      currentCycleMeta3Competences = [];
      wasReset = true;
      resetCompetence = record.competence ?? null;
      if (record.competence) sdrToCloserCompetences.push(record.competence);
    }
    if (historicalPosition) previousPosition = historicalPosition;

    // Competence-level information wins without changing already processed months.
    seniority = normalizeSeniority(record.informedSeniority)
      ?? seniority
      ?? normalizeSeniority(record.seniority)
      ?? normalizeSeniority(currentSeniority);
    if (!seniority) continue;
    lastGoal = record.goal;
    const result = processMonthlyGoal(seniority, progress, record.goal);
    if (result.cycleCompleted) {
      wasReset = true;
      resetCompetence = record.competence ?? null;
      if (record.competence) cycleCompletionCompetences.push(record.competence);
      currentCycleMeta3Competences = [];
    } else if (record.goal === "meta3" && record.competence) {
      currentCycleMeta3Competences.push(record.competence);
    }
    if (result.receivedPromotion && record.competence) promotionCompetences.push(record.competence);
    seniority = result.seniority;
    progress = result.progress;
  }
  const isCareerTop = seniority === "Sênior 3";
  return { meta3Streak: progress, tier: progress >= 2 ? 2 : 1, wasReset, readyForLevelUp: progress === 2 && !isCareerTop, isCareerTop, lastGoal, seniorityAtPeriod: seniority, resetCompetence, cycleCompletionCompetences, currentCycleMeta3Competences, promotionCompetences, sdrToCloserCompetences };
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
      return { sdr: historicalSquad ? { ...sdr, squad: historicalSquad } : sdr, progress: state.meta3Streak, promotedInPeriod, seniorityAtPeriod, band: getPromotionBand(seniorityAtPeriod, state.meta3Streak, promotedInPeriod) };
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

export function goalTone(goal: GoalLevel): "success" | "warning" | "danger" | "muted" {
  if (goal === "meta3") return "success";
  if (goal === "meta1" || goal === "meta2") return "warning";
  if (goal === "below") return "danger";
  return "muted";
}
