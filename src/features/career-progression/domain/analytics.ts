import { isSquadSaiu, progressoDeSenioridade } from "../domain";
import type { ColaboradorPerfil, ColaboradorResultado, PerfilComHistorico, ProfileStatusFilter } from "../types";
import { detectRoleTransitionPromotions, isLeadershipPosition, type CareerPromotionType } from "./promotions";

export const SENIORITY_ORDER = [
  "Júnior 1", "Júnior 2", "Júnior 3", "Pleno 1", "Pleno 2", "Pleno 3", "Sênior 1", "Sênior 2", "Sênior 3",
] as const;

export type GoalCategory = "Meta 1" | "Meta 2" | "Meta 3" | "Nenhuma meta" | "Sem presença" | "Sem registro";

export interface AnalyticsFilters {
  competence: string;
  status: ProfileStatusFilter;
  squad: string;
  position: string;
  seniority: string;
  search: string;
}

export interface CoverageSummary {
  present: number;
  absent: number;
  total: number;
  presentPercentage: number;
  absentPercentage: number;
}

export interface PromotionView {
  promotionType: CareerPromotionType;
  profile: PerfilComHistorico;
  result: ColaboradorResultado;
  previousSeniority: string;
  nextSeniority: string;
  fromPosition: string | null;
  toPosition: string | null;
}

export interface CareerPromotionByCompetence {
  competence: string;
  total: number;
  seniority: number;
  roleTransition: number;
}

export interface MonthlyGoalEvolution {
  competence: string;
  "Atingiram meta": number;
  "Meta 1": number;
  "Meta 2": number;
  "Meta 3": number;
  "Nenhuma meta": number;
  "Sem presença": number;
  "Sem registro": number;
}

export function normalizeSearch(value: string | null | undefined): string {
  return (value ?? "").normalize("NFD").replace(/[\u0300-\u036f]/g, "")
    .trim().replace(/\s+/g, " ").toLocaleLowerCase("pt-BR");
}

export function listCompetences(results: readonly ColaboradorResultado[]): string[] {
  return [...new Set(results.map((row) => row.competencia).filter((value): value is string => Boolean(value)))].sort();
}

export function filterProfiles(profiles: readonly PerfilComHistorico[], filters: AnalyticsFilters): PerfilComHistorico[] {
  const search = normalizeSearch(filters.search);
  return profiles.filter(({ perfil }) => {
    if (filters.status === "ativos" && !perfil.ativo) return false;
    if (filters.status === "inativos" && perfil.ativo) return false;
    if (filters.squad !== "todos" && perfil.squad_atual !== filters.squad) return false;
    if (filters.position !== "todos" && perfil.posicao_atual !== filters.position) return false;
    if (filters.seniority !== "todos" && perfil.senioridade_atual !== filters.seniority) return false;
    if (search && !normalizeSearch(perfil.nome_colaborador).includes(search)) return false;
    return true;
  }).sort((a, b) => Number(b.perfil.ativo) - Number(a.perfil.ativo)
    || a.perfil.nome_normalizado.localeCompare(b.perfil.nome_normalizado, "pt-BR")
    || a.perfil.id.localeCompare(b.perfil.id));
}

export function filterResultsByProfiles(results: readonly ColaboradorResultado[], profiles: readonly PerfilComHistorico[]): ColaboradorResultado[] {
  const ids = new Set(profiles.map(({ perfil }) => perfil.id));
  return results.filter((row) => row.colaborador_id !== null && ids.has(row.colaborador_id));
}

/**
 * Filters monthly facts using the values that were true in each competence.
 * Status and search remain profile-level filters; position, squad and seniority
 * are evaluated from the historical result instead of the current profile.
 */
/**
 * Retorna o squad registrado para o colaborador na competência.
 *
 * Não usa squad_atual como fallback para impedir que uma alteração
 * presente reescreva visualmente competências passadas.
 */
export function squadForCompetence(
  profile: PerfilComHistorico,
  competence: string,
): string | null {
  return profile.resultados.find(
    (row) => row.competencia === competence,
  )?.squad ?? null;
}

/**
 * Aplica o filtro de Squad usando o registro da competência
 * selecionada. Os demais filtros mantêm o comportamento existente.
 */
export function filterProfilesByHistoricalSquad(
  profiles: readonly PerfilComHistorico[],
  filters: AnalyticsFilters,
): PerfilComHistorico[] {
  const profileScope = filterProfiles(
    profiles,
    {
      ...filters,
      squad: "todos",
    },
  );

  if (filters.squad === "todos") {
    return profileScope;
  }

  return profileScope.filter(
    (profile) =>
      squadForCompetence(
        profile,
        filters.competence,
      ) === filters.squad,
  );
}

/**
 * Opções de Squad válidas para a competência selecionada.
 */
export function listSquadsByCompetence(
  profiles: readonly PerfilComHistorico[],
  competence: string,
): string[] {
  return [
    ...new Set(
      profiles
        .map((profile) =>
          squadForCompetence(
            profile,
            competence,
          ),
        )
        .filter(
          (squad): squad is string =>
            Boolean(squad) &&
            normalizeSearch(squad) !== "saiu",
        ),
    ),
  ].sort((a, b) =>
    a.localeCompare(
      b,
      "pt-BR",
    ),
  );
}
export function filterHistoricalResults(
  results: readonly ColaboradorResultado[],
  profileScope: readonly PerfilComHistorico[],
  filters: AnalyticsFilters,
): ColaboradorResultado[] {
  const ids = new Set(profileScope.map(({ perfil }) => perfil.id));
  return results.filter((row) => {
    if (!row.colaborador_id || !ids.has(row.colaborador_id)) return false;
    if (filters.squad !== "todos" && row.squad !== filters.squad) return false;
    if (filters.position !== "todos" && normalizeSearch(row.posicao) !== normalizeSearch(filters.position)) return false;
    const historicalSeniority = row.senioridade_informada ?? row.senioridade;
    if (filters.seniority !== "todos" && historicalSeniority !== filters.seniority) return false;
    return true;
  });
}

export function calculateCoverage(profiles: readonly PerfilComHistorico[], competence: string): CoverageSummary {
  const rows = profiles.map(({ resultados }) => resultados.find((row) => row.competencia === competence)).filter(Boolean) as ColaboradorResultado[];
  const absent = rows.filter((row) => row.meta_alcancada === "Sem presença").length;
  const present = rows.length - absent;
  const total = rows.length;
  return {
    present, absent, total,
    presentPercentage: total ? Math.round((present / total) * 100) : 0,
    absentPercentage: total ? Math.round((absent / total) * 100) : 0,
  };
}

export function distributeCycle(profiles: readonly PerfilComHistorico[]) {
  return [0, 1, 2].map((progress) => ({ progress, total: profiles.filter(({ perfil }) => progressoDeSenioridade(perfil) === progress).length }));
}

export function distributeSeniority(profiles: readonly PerfilComHistorico[]) {
  return SENIORITY_ORDER.map((seniority) => ({ seniority, total: profiles.filter(({ perfil }) => perfil.senioridade_atual === seniority).length }));
}

function goalCategory(value: string | null): GoalCategory {
  if (value === "Meta 1" || value === "Meta 2" || value === "Meta 3" || value === "Nenhuma meta" || value === "Sem presença" || value === "Sem registro") return value;
  return value === null ? "Sem registro" : "Nenhuma meta";
}

function latestDistinctResults(rows: readonly ColaboradorResultado[]): ColaboradorResultado[] {
  const byPerson = new Map<string, ColaboradorResultado>();
  for (const row of rows) {
    if (!row.colaborador_id) continue;
    const current = byPerson.get(row.colaborador_id);
    if (!current || `${row.updated_at}|${row.id}` > `${current.updated_at}|${current.id}`) {
      byPerson.set(row.colaborador_id, row);
    }
  }
  return [...byPerson.values()];
}

/**
 * Builds the monthly goal evolution by distinct collaborator.
 * "Atingiram meta" includes Meta 1, Meta 2 and Meta 3, and excludes
 * Nenhuma meta, Sem presença and Sem registro.
 */
export function groupGoalsByCompetence(results: readonly ColaboradorResultado[]): MonthlyGoalEvolution[] {
  const categories: GoalCategory[] = ["Meta 1", "Meta 2", "Meta 3", "Nenhuma meta", "Sem presença", "Sem registro"];
  return listCompetences(results).map((competence) => {
    const rows = latestDistinctResults(results.filter((row) => row.competencia === competence));
    const grouped = Object.fromEntries(categories.map((category) => [
      category,
      rows.filter((row) => goalCategory(row.meta_alcancada) === category).length,
    ])) as Record<GoalCategory, number>;
    return {
      competence,
      "Atingiram meta": grouped["Meta 1"] + grouped["Meta 2"] + grouped["Meta 3"],
      ...grouped,
    };
  });
}

export function groupPromotionsByCompetence(results: readonly ColaboradorResultado[]) {
  return listCompetences(results).map((competence) => ({ competence, total: latestDistinctResults(results.filter((row) => row.competencia === competence && row.recebeu_promocao)).length }));
}

export function countUniquePromoted(results: readonly ColaboradorResultado[]): number {
  return new Set(results.filter((row) => row.recebeu_promocao && row.colaborador_id).map((row) => row.colaborador_id)).size;
}

function promotionEventKey(promotion: PromotionView): string {
  return [
    promotion.profile.perfil.id,
    promotion.result.competencia ?? promotion.result.id,
  ].join("|");
}

/**
 * Constrói a visão unificada de promoções.
 *
 * Regras:
 * - promoção de senioridade continua vindo de recebeu_promocao;
 * - SDR -> Closer é promoção de função;
 * - se os dois sinais ocorrerem para a mesma pessoa na mesma
 *   competência, a promoção de função prevalece e conta apenas uma vez.
 */
export function buildCareerPromotions(
  profiles: readonly PerfilComHistorico[],
  competence?: string,
): PromotionView[] {
  const seniorityPromotions: PromotionView[] = profiles.flatMap((profile) =>
    profile.resultados
      .filter(
        (row) =>
          row.recebeu_promocao &&
          (!competence || row.competencia === competence),
      )
      .map((result) => ({
        promotionType: "seniority" as const,
        profile,
        result,
        previousSeniority: result.senioridade ?? "Não informada",
        nextSeniority: nextSeniority(result.senioridade),
        fromPosition: result.posicao,
        toPosition: result.posicao,
      })),
  );

  const rolePromotions: PromotionView[] =
    detectRoleTransitionPromotions(profiles, competence).map(
      (promotion) => ({
        promotionType: "role_transition" as const,
        profile: promotion.profile,
        result: promotion.result,
        previousSeniority: promotion.previousSeniority ?? "Não informada",
        nextSeniority: promotion.nextSeniority ?? "Não informada",
        fromPosition: promotion.fromPosition,
        toPosition: promotion.toPosition,
      }),
    );

  const byPersonAndCompetence = new Map<string, PromotionView>();

  for (const promotion of seniorityPromotions) {
    byPersonAndCompetence.set(
      promotionEventKey(promotion),
      promotion,
    );
  }

  // A transição de função sobrescreve o sinal de senioridade
  // quando ambos aparecem na mesma competência.
  for (const promotion of rolePromotions) {
    byPersonAndCompetence.set(
      promotionEventKey(promotion),
      promotion,
    );
  }

  return [...byPersonAndCompetence.values()].sort(
    (a, b) =>
      (b.result.competencia ?? "").localeCompare(
        a.result.competencia ?? "",
      ) ||
      b.result.updated_at.localeCompare(a.result.updated_at) ||
      a.profile.perfil.nome_normalizado.localeCompare(
        b.profile.perfil.nome_normalizado,
        "pt-BR",
      ) ||
      a.result.id.localeCompare(b.result.id),
  );
}

export function filterCareerPromotions(
  promotions: readonly PromotionView[],
  filters: Pick<AnalyticsFilters, "squad" | "position" | "seniority">,
): PromotionView[] {
  return promotions.filter(({ result }) => {
    if (filters.squad !== "todos" && result.squad !== filters.squad) return false;
    if (filters.position !== "todos" && normalizeSearch(result.posicao) !== normalizeSearch(filters.position)) return false;
    const historicalSeniority =
      result.senioridade_informada ?? result.senioridade;
    if (filters.seniority !== "todos" && historicalSeniority !== filters.seniority) return false;
    return true;
  });
}

export function countUniqueCareerPromoted(
  promotions: readonly PromotionView[],
): number {
  return new Set(
    promotions.map(({ profile }) => profile.perfil.id),
  ).size;
}

export function groupCareerPromotionsByCompetence(
  results: readonly ColaboradorResultado[],
  promotions: readonly PromotionView[],
): CareerPromotionByCompetence[] {
  return listCompetences(results).map((competence) => {
    const events = promotions.filter(
      ({ result }) => result.competencia === competence,
    );

    const seniority = events.filter(
      ({ promotionType }) => promotionType === "seniority",
    ).length;

    const roleTransition = events.filter(
      ({ promotionType }) => promotionType === "role_transition",
    ).length;

    return {
      competence,
      total: events.length,
      seniority,
      roleTransition,
    };
  });
}

export function groupProgressBySquad(
  profiles: readonly PerfilComHistorico[],
  competence?: string,
) {
  const squadOf = (
    profile: PerfilComHistorico,
  ): string | null =>
    competence
      ? squadForCompetence(profile, competence)
      : profile.perfil.squad_atual;

  const squads = [
    ...new Set(
      profiles
        .map(squadOf)
        .filter(
          (squad): squad is string =>
            Boolean(squad) &&
            !isSquadSaiu(squad),
        ),
    ),
  ];

  return squads.map((squad) => {
    const people = profiles.filter(
      (profile) =>
        squadOf(profile) === squad,
    );

    return {
      squad,
      meta1: people.filter(
        ({ perfil }) =>
          progressoDeSenioridade(perfil) === 0,
      ).length,
      meta2: people.filter(
        ({ perfil }) =>
          progressoDeSenioridade(perfil) === 1,
      ).length,
      meta3: people.filter(
        ({ perfil }) =>
          progressoDeSenioridade(perfil) === 2,
      ).length,
      total: people.length,
    };
  }).sort(
    (a, b) =>
      b.total - a.total ||
      a.squad.localeCompare(
        b.squad,
        "pt-BR",
      ),
  );
}

export function findNearPromotion(profiles: readonly PerfilComHistorico[]): PerfilComHistorico[] {
  return profiles.filter(({ perfil }) => progressoDeSenioridade(perfil) === 2);
}

export function nextSeniority(current: string | null): string {
  const index = SENIORITY_ORDER.findIndex((level) => level === current);
  return index >= 0 && index < SENIORITY_ORDER.length - 1 ? SENIORITY_ORDER[index + 1] : current ?? "Não informada";
}

export function findRecentPromotions(profiles: readonly PerfilComHistorico[], competence?: string): PromotionView[] {
  return buildCareerPromotions(profiles, competence);
}

export function buildCycleColumns(profiles: readonly PerfilComHistorico[]) {
  const cycleProfiles = profiles.filter(({ perfil }) =>
    !isLeadershipPosition(perfil.posicao_atual));
  return {
    meta1: cycleProfiles.filter(({ perfil }) => progressoDeSenioridade(perfil) === 0),
    meta2: cycleProfiles.filter(({ perfil }) => progressoDeSenioridade(perfil) === 1),
    meta3: cycleProfiles.filter(({ perfil }) => progressoDeSenioridade(perfil) === 2),
  };
}

export function latestDatabaseUpdate(profiles: readonly ColaboradorPerfil[], results: readonly ColaboradorResultado[]): string | null {
  return [...profiles.map((row) => row.updated_at), ...results.map((row) => row.updated_at)].sort().at(-1) ?? null;
}
