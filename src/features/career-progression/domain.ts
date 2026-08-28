import { formatCompetence, normalizeGoal, normalizeSeniority, type SDR } from "@/lib/progression";
import type {
  CareerProgressionData,
  CareerProgressionFilterOptions,
  CareerProgressionFilters,
  CareerProgressionSummary,
  CareerProgressionEvent,
  ColaboradorPerfil,
  ColaboradorResultado,
  PerfilComHistorico,
} from "./types";

export type CareerIntegrityIssueType = "duplicate_profile" | "duplicate_competence" | "orphan_result";

export interface CareerIntegrityIssue {
  type: CareerIntegrityIssueType;
  message: string;
}

export class CareerDataIntegrityError extends Error {
  constructor(readonly issues: CareerIntegrityIssue[]) {
    super(`Os dados de progressão possuem ${issues.length} inconsistência(s).`);
    this.name = "CareerDataIntegrityError";
  }
}

function foldForSearch(value: string | null | undefined): string {
  return (value ?? "").normalize("NFD").replace(/[\u0300-\u036f]/g, "")
    .trim().replace(/\s+/g, " ").toLocaleLowerCase("pt-BR");
}

function compareResults(a: ColaboradorResultado, b: ColaboradorResultado): number {
  return (a.competencia ?? "9999-12-31").localeCompare(b.competencia ?? "9999-12-31")
    || a.id.localeCompare(b.id);
}

export function relacionarPerfisEResultados(
  perfis: readonly ColaboradorPerfil[], resultados: readonly ColaboradorResultado[], eventos: readonly CareerProgressionEvent[] = [],
): PerfilComHistorico[] {
  const issues: CareerIntegrityIssue[] = [];
  const profilesById = new Map<string, ColaboradorPerfil>();
  const normalizedNames = new Set<string>();
  const histories = new Map<string, ColaboradorResultado[]>();
  const competenceKeys = new Set<string>();

  for (const perfil of perfis) {
    if (profilesById.has(perfil.id) || normalizedNames.has(perfil.nome_normalizado)) {
      issues.push({ type: "duplicate_profile", message: "Perfil duplicado detectado." });
      continue;
    }
    profilesById.set(perfil.id, perfil);
    normalizedNames.add(perfil.nome_normalizado);
  }

  for (const resultado of resultados) {
    if (!resultado.colaborador_id || !profilesById.has(resultado.colaborador_id)) {
      issues.push({ type: "orphan_result", message: "Resultado sem perfil associado." });
      continue;
    }
    const key = `${resultado.colaborador_id}|${resultado.competencia ?? "sem-competencia"}`;
    if (competenceKeys.has(key)) {
      issues.push({ type: "duplicate_competence", message: "Competência duplicada para o perfil." });
      continue;
    }
    competenceKeys.add(key);
    const history = histories.get(resultado.colaborador_id) ?? [];
    history.push(resultado);
    histories.set(resultado.colaborador_id, history);
  }

  if (issues.length > 0) throw new CareerDataIntegrityError(issues);

  return [...perfis]
    .sort((a, b) => a.nome_normalizado.localeCompare(b.nome_normalizado, "pt-BR") || a.id.localeCompare(b.id))
    .map((perfil) => {
      const history = [...(histories.get(perfil.id) ?? [])].sort(compareResults);
      return {
        perfil,
        resultados: history,
        totalMeta3: history.filter((item) => item.meta_alcancada === "Meta 3").length,
        totalPromocoes: history.filter((item) => item.recebeu_promocao).length,
        ultimaCompetencia: history.at(-1)?.competencia ?? null,
        eventos: eventos.filter((evento) => evento.colaborador_id === perfil.id)
          .sort((a, b) => a.competencia.localeCompare(b.competencia) || a.event_type.localeCompare(b.event_type)),
      };
    });
}

export function calcularResumo(
  perfis: readonly ColaboradorPerfil[], resultados: readonly ColaboradorResultado[],
): CareerProgressionSummary {
  const competencias = resultados.map((resultado) => resultado.competencia)
    .filter((value): value is string => value !== null).sort();
  return {
    totalPerfis: perfis.length,
    ativos: perfis.filter((perfil) => perfil.ativo).length,
    inativos: perfis.filter((perfil) => !perfil.ativo).length,
    totalResultados: resultados.length,
    progresso0: perfis.filter((perfil) => progressoDeSenioridade(perfil) === 0).length,
    progresso1: perfis.filter((perfil) => progressoDeSenioridade(perfil) === 1).length,
    progresso2: perfis.filter((perfil) => progressoDeSenioridade(perfil) === 2).length,
    promocoesRegistradas: resultados.filter((resultado) => resultado.recebeu_promocao).length,
    pessoasPromovidas: new Set(resultados.filter((resultado) => resultado.recebeu_promocao)
      .map((resultado) => resultado.colaborador_id)).size,
    competenciaMinima: competencias[0] ?? null,
    competenciaMaxima: competencias.at(-1) ?? null,
  };
}

export function montarDadosDeProgressao(
  perfis: ColaboradorPerfil[], resultados: ColaboradorResultado[], eventos: CareerProgressionEvent[] = [],
): CareerProgressionData {
  const perfisOperacionais = perfis.filter(isOperationalProfile);
  const idsOperacionais = new Set(perfisOperacionais.map((perfil) => perfil.id));
  const resultadosOperacionais = resultados.filter((resultado) => resultado.colaborador_id !== null && idsOperacionais.has(resultado.colaborador_id));
  return {
    perfis, resultados, eventos,
    perfisComHistorico: relacionarPerfisEResultados(perfis, resultados, eventos),
    resumo: calcularResumo(perfis, resultados),
    perfisOperacionais, resultadosOperacionais,
    perfisOperacionaisComHistorico: relacionarPerfisEResultados(perfisOperacionais, resultadosOperacionais, eventos),
    resumoOperacional: calcularResumo(perfisOperacionais, resultadosOperacionais),
  };
}

export function isOperationalProfile(perfil: ColaboradorPerfil): boolean {
  const position = foldForSearch(perfil.posicao_atual);
  return (position === "sdr" || position === "closer")
    && !isSquadSaiu(perfil.squad_atual)
    && foldForSearch(perfil.jornada_atual) !== "saiu";
}

export function progressoDeSenioridade(perfil: ColaboradorPerfil): number {
  return foldForSearch(perfil.posicao_atual) === "closer"
    ? perfil.progresso_meta3
    : (perfil.progresso_ciclo ?? perfil.progresso_meta3);
}

export function filtrarPerfis(
  perfis: readonly PerfilComHistorico[], filtros: CareerProgressionFilters,
): PerfilComHistorico[] {
  const busca = foldForSearch(filtros.busca);
  return perfis.filter(({ perfil }) => {
    if (busca && !foldForSearch(perfil.nome_colaborador).includes(busca)) return false;
    if (filtros.status === "ativos" && !perfil.ativo) return false;
    if (filtros.status === "inativos" && perfil.ativo) return false;
    if (filtros.squad !== "todos" && perfil.squad_atual !== filtros.squad) return false;
    if (filtros.posicao !== "todos" && perfil.posicao_atual !== filtros.posicao) return false;
    if (filtros.senioridade !== "todos" && perfil.senioridade_atual !== filtros.senioridade) return false;
    if (filtros.progresso !== "todos" && progressoDeSenioridade(perfil) !== Number(filtros.progresso)) return false;
    return true;
  });
}

function uniqueSorted(values: Array<string | null>): string[] {
  return [...new Set(values.filter((value): value is string => Boolean(value?.trim())))]
    .sort((a, b) => a.localeCompare(b, "pt-BR", { sensitivity: "base" }));
}

export function derivarOpcoesDeFiltro(perfis: readonly ColaboradorPerfil[]): CareerProgressionFilterOptions {
  return {
    squads: uniqueSorted(perfis.map((perfil) => perfil.squad_atual).filter((squad) => !isSquadSaiu(squad))),
    posicoes: uniqueSorted(perfis.map((perfil) => perfil.posicao_atual)),
    senioridades: uniqueSorted(perfis.map((perfil) => perfil.senioridade_atual)),
  };
}

export function isSquadSaiu(squad: string | null | undefined): boolean {
  return foldForSearch(squad) === "saiu";
}

export function formatarSquadAtual(squad: string | null | undefined): string {
  if (isSquadSaiu(squad)) return "Não se aplica";
  return squad?.trim() || "Não informado";
}

export function adaptarPerfisParaSdr(perfis: readonly PerfilComHistorico[]): SDR[] {
  return perfis.map(({ perfil, resultados }) => ({
    id: perfil.id,
    name: perfil.nome_colaborador,
    avatarColor: "270 70% 60%",
    level: normalizeSeniority(perfil.senioridade_atual) ?? "Júnior 1",
    squad: perfil.squad_atual ?? "Sem squad",
    position: perfil.posicao_atual,
    currentProgress: progressoDeSenioridade(perfil),
    active: perfil.ativo,
    history: resultados.map((resultado) => ({
      id: resultado.id,
      collaboratorId: resultado.colaborador_id,
      competence: resultado.competencia,
      month: resultado.competencia ? formatCompetence(resultado.competencia) : "Competência não informada",
      goal: normalizeGoal(resultado.meta_alcancada) ?? "absent",
      seniority: normalizeSeniority(resultado.senioridade),
      informedSeniority: normalizeSeniority(resultado.senioridade_informada),
      squad: resultado.squad,
      position: resultado.posicao,
      receivedPromotion: resultado.recebeu_promocao,
    })),
  }));
}
