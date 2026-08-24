import { useMemo } from "react";
import { useCareerProgressionData } from "@/features/career-progression/hooks/useCareerProgressionData";
import {
  formatCompetence,
  normalizeGoal,
  normalizeSeniority,
  type MonthRecord,
  type SDR,
} from "@/lib/progression";
import type { Tables } from "@/integrations/supabase/types";
import type { ColaboradorPerfil } from "@/features/career-progression/types";

export type CareerResultRow = Tables<"colaboradores">;
export type CareerProfileRow = ColaboradorPerfil;

export interface CareerDataIssue {
  resultId: string;
  message: string;
}

export interface CareerData {
  sdrs: SDR[];
  results: CareerResultRow[];
  availableCompetences: string[];
  issues: CareerDataIssue[];
}

const ALLOWED_SQUADS = new Set(["lobo", "aguia", "sharks", "serpente", "gorila", "gorilla", "urso"]);

function fold(value: string | null): string {
  return (value ?? "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").trim().toLowerCase();
}

export function normalizeSquad(value: string | null): string {
  const normalized = fold(value);
  if (normalized === "aguia") return "ÁGUIA";
  if (normalized === "gorilla") return "GORILA";
  return normalized.toLocaleUpperCase("pt-BR");
}

function isEligible(row: Pick<CareerResultRow, "posicao" | "squad">): boolean {
  const position = fold(row.posicao);
  return (position.includes("sdr") || position.includes("closer")) && ALLOWED_SQUADS.has(fold(row.squad));
}

export function buildCareerData(
  rows: CareerResultRow[],
  profiles: CareerProfileRow[],
): CareerData {
  const issues: CareerDataIssue[] = [];
  const eligibleRows = rows.filter(isEligible);
  const historyById = new Map<string, MonthRecord[]>();

  for (const row of eligibleRows) {
    if (!row.colaborador_id) {
      issues.push({ resultId: row.id, message: "Resultado sem colaborador_id estável." });
      continue;
    }
    const goal = normalizeGoal(row.meta_alcancada);
    const seniority = normalizeSeniority(row.senioridade);
    if (!goal) {
      issues.push({ resultId: row.id, message: `Meta inválida: ${row.meta_alcancada ?? "null"}.` });
      continue;
    }
    if (!seniority) {
      issues.push({ resultId: row.id, message: `Senioridade inválida: ${row.senioridade ?? "null"}.` });
      continue;
    }
    if (!row.competencia) {
      issues.push({ resultId: row.id, message: "Competência ambígua; resultado fora do cálculo." });
      continue;
    }
    const history = historyById.get(row.colaborador_id) ?? [];
    history.push({
      id: row.id,
      collaboratorId: row.colaborador_id,
      competence: row.competencia,
      month: formatCompetence(row.competencia),
      goal,
      seniority,
      informedSeniority: normalizeSeniority(row.senioridade_informada),
      squad: row.squad,
      position: row.posicao,
      receivedPromotion: row.recebeu_promocao,
    });
    historyById.set(row.colaborador_id, history);
  }

  const sdrs: SDR[] = [];
  for (const profile of profiles) {
    const level = normalizeSeniority(profile.senioridade_atual);
    if (!level) {
      issues.push({ resultId: profile.id, message: `Perfil com senioridade atual inválida: ${profile.senioridade_atual ?? "null"}.` });
      continue;
    }
    const squad = normalizeSquad(profile.squad_atual);
    if (!ALLOWED_SQUADS.has(fold(squad))) continue;
    sdrs.push({
      id: profile.id,
      name: profile.nome_colaborador,
      level,
      position: profile.posicao_atual,
      squad,
      currentProgress: profile.progresso_ciclo ?? profile.progresso_meta3,
      avatarColor: "270 70% 60%",
      history: (historyById.get(profile.id) ?? []).sort((a, b) =>
        (a.competence as string).localeCompare(b.competence as string),
      ),
    });
  }

  sdrs.sort((a, b) => a.name.localeCompare(b.name, "pt-BR", { sensitivity: "base" }));
  const availableCompetences = Array.from(
    new Set(eligibleRows.map((row) => row.competencia).filter((value): value is string => Boolean(value))),
  ).sort((a, b) => b.localeCompare(a));

  return { sdrs, results: eligibleRows, availableCompetences, issues };
}

export function useColaboradoresSdrs() {
  const query = useCareerProgressionData();
  const data = useMemo(() => buildCareerData(query.resultadosOperacionais, query.perfisOperacionais), [query.perfisOperacionais, query.resultadosOperacionais]);
  return {
    ...data,
    loading: query.isLoading,
    error: query.error?.message ?? null,
    live: false,
    refetch: query.refetch,
    lastUpdated: query.lastUpdatedAt,
  };
}
