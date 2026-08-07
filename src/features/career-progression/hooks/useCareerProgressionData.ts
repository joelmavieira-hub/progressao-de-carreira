import { useQuery } from "@tanstack/react-query";
import { buscarDadosDeProgressao } from "../data/career-progression-repository";

export const CAREER_PROGRESSION_QUERY_KEY = ["career-progression", "read-model"] as const;

export function useCareerProgressionData() {
  const query = useQuery({
    queryKey: CAREER_PROGRESSION_QUERY_KEY,
    queryFn: ({ signal }) => buscarDadosDeProgressao(signal),
    refetchOnWindowFocus: true,
    staleTime: 30_000,
  });
  return {
    perfis: query.data?.perfis ?? [], resultados: query.data?.resultados ?? [],
    perfisComHistorico: query.data?.perfisComHistorico ?? [], resumo: query.data?.resumo ?? null,
    perfisOperacionais: query.data?.perfisOperacionais ?? [],
    resultadosOperacionais: query.data?.resultadosOperacionais ?? [],
    perfisOperacionaisComHistorico: query.data?.perfisOperacionaisComHistorico ?? [],
    resumoOperacional: query.data?.resumoOperacional ?? null,
    isLoading: query.isLoading, isFetching: query.isFetching,
    error: query.error instanceof Error ? query.error : null, refetch: query.refetch,
    lastUpdatedAt: query.dataUpdatedAt > 0 ? new Date(query.dataUpdatedAt) : null,
  };
}
