import type { Tables } from "@/integrations/supabase/types";

type GeneratedColaboradorPerfil = Tables<"colaboradores_perfis">;
export type ColaboradorPerfil = Omit<GeneratedColaboradorPerfil, "jornada_atual"> & { jornada_atual?: string | null };
export type ColaboradorResultado = Tables<"colaboradores">;

export interface PerfilComHistorico {
  perfil: ColaboradorPerfil;
  resultados: ColaboradorResultado[];
  totalMeta3: number;
  totalPromocoes: number;
  ultimaCompetencia: string | null;
}

export interface CareerProgressionSummary {
  totalPerfis: number;
  ativos: number;
  inativos: number;
  totalResultados: number;
  progresso0: number;
  progresso1: number;
  progresso2: number;
  promocoesRegistradas: number;
  pessoasPromovidas: number;
  competenciaMinima: string | null;
  competenciaMaxima: string | null;
}

export interface CareerProgressionData {
  perfis: ColaboradorPerfil[];
  resultados: ColaboradorResultado[];
  perfisComHistorico: PerfilComHistorico[];
  resumo: CareerProgressionSummary;
  perfisOperacionais: ColaboradorPerfil[];
  resultadosOperacionais: ColaboradorResultado[];
  perfisOperacionaisComHistorico: PerfilComHistorico[];
  resumoOperacional: CareerProgressionSummary;
}

export type ProfileStatusFilter = "todos" | "ativos" | "inativos";

export interface CareerProgressionFilters {
  busca: string;
  status: ProfileStatusFilter;
  squad: string;
  posicao: string;
  senioridade: string;
  progresso: "todos" | "0" | "1" | "2";
}

export interface CareerProgressionFilterOptions {
  squads: string[];
  posicoes: string[];
  senioridades: string[];
}
