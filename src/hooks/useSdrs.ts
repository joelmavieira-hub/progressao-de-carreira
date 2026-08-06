/** @deprecated Adaptador legado somente leitura. Prefira useCareerProgressionData. */
import { useMemo } from "react";
import { adaptarPerfisParaSdr } from "@/features/career-progression/domain";
import { useCareerProgressionData } from "@/features/career-progression/hooks/useCareerProgressionData";

export function useSdrs() {
  const query = useCareerProgressionData();
  const sdrs = useMemo(() => adaptarPerfisParaSdr(query.perfisComHistorico), [query.perfisComHistorico]);
  return {
    sdrs,
    loading: query.isLoading,
    error: query.error,
    refetch: query.refetch,
  };
}
