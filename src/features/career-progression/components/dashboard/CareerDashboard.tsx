import { useEffect, useMemo, useState } from "react";
import { Button } from "@/components/ui/button";
import { derivarOpcoesDeFiltro } from "../../domain";
import {
  calculateCoverage, countUniquePromoted, distributeCycle, distributeSeniority, filterProfiles, filterResultsByProfiles,
  findNearPromotion, findRecentPromotions, groupGoalsByCompetence, groupProgressBySquad,
  groupPromotionsByCompetence, latestDatabaseUpdate, listCompetences, type AnalyticsFilters,
} from "../../domain/analytics";
import type { ColaboradorPerfil, ColaboradorResultado, PerfilComHistorico } from "../../types";
import { CareerFiltersBar } from "../shared/CareerFiltersBar";
import { ProfileHistoryDialog } from "../shared/ProfileHistoryDialog";
import { DashboardCharts } from "./DashboardCharts";
import { DashboardLists } from "./DashboardLists";
import { DatabaseSummaryCard } from "./DatabaseSummaryCard";
import { MainMetrics } from "./MainMetrics";

const defaults = (competence: string): AnalyticsFilters => ({ competence, status: "ativos", squad: "todos", position: "todos", seniority: "todos", search: "" });

export function CareerDashboard({ perfis, resultados, perfisComHistorico, isFetching, lastUpdatedAt, onRefresh, onNavigate, initialFilters }: {
  perfis: ColaboradorPerfil[]; resultados: ColaboradorResultado[]; perfisComHistorico: PerfilComHistorico[];
  isFetching: boolean; lastUpdatedAt: Date | null; onRefresh: () => void; onNavigate: (focus: "meta3" | "promoted") => void;
  initialFilters?: Partial<AnalyticsFilters>;
}) {
  const competences = useMemo(() => listCompetences(resultados), [resultados]);
  const latest = competences.at(-1) ?? "";
  const [filters, setFilters] = useState<AnalyticsFilters>(() => ({ ...defaults(latest), ...initialFilters }));
  const [selected, setSelected] = useState<PerfilComHistorico | null>(null);
  useEffect(() => { if (!filters.competence && latest) setFilters((current) => ({ ...current, competence: latest })); }, [filters.competence, latest]);

  const options = useMemo(() => derivarOpcoesDeFiltro(perfis), [perfis]);
  const filtered = useMemo(() => filterProfiles(perfisComHistorico, filters), [perfisComHistorico, filters]);
  const withoutStatus = useMemo(() => filterProfiles(perfisComHistorico, { ...filters, status: "todos" }), [perfisComHistorico, filters]);
  const filteredResults = useMemo(() => filterResultsByProfiles(resultados, filtered), [resultados, filtered]);
  const coverage = useMemo(() => calculateCoverage(filtered, filters.competence), [filtered, filters.competence]);
  const promotionResults = filteredResults.filter((row) => row.recebeu_promocao);
  const databaseUpdated = latestDatabaseUpdate(perfis, resultados);
  const databaseDate = databaseUpdated ? new Date(databaseUpdated) : lastUpdatedAt;
  const competenceRecords = resultados.filter((row) => row.competencia === filters.competence).length;

  return <div className="space-y-6" data-testid="career-dashboard">
    <CareerFiltersBar filters={filters} competences={[...competences].reverse()} options={options} onChange={setFilters} onClear={() => setFilters(defaults(latest))} />
    {filtered.length === 0 ? <div role="status" className="rounded-2xl border border-dashed bg-card p-10 text-center"><p className="font-semibold">Nenhum colaborador encontrado.</p>
      <p className="mt-1 text-sm text-muted-foreground">Ajuste os filtros para recuperar a visualização.</p><Button className="mt-4" variant="outline" onClick={() => setFilters(defaults(latest))}>Limpar filtros</Button></div> : <>
      <div className="grid items-stretch gap-4 sm:grid-cols-2 xl:grid-cols-[repeat(4,minmax(0,1fr))_minmax(250px,1.15fr)]"><MainMetrics
        active={withoutStatus.filter(({ perfil }) => perfil.ativo).length} inactive={withoutStatus.filter(({ perfil }) => !perfil.ativo).length}
        promotionRecords={promotionResults.length} promotedPeople={countUniquePromoted(promotionResults)} nearPromotion={findNearPromotion(filtered).length}
        coverage={coverage} competence={filters.competence} />
        <DatabaseSummaryCard totalProfiles={perfis.length} competenceRecords={competenceRecords} competence={filters.competence}
          updatedAt={databaseDate} isFetching={isFetching} onRefresh={onRefresh} /></div>
      <DashboardCharts cycle={distributeCycle(filtered)} seniority={distributeSeniority(filtered)} monthlyGoals={groupGoalsByCompetence(filteredResults)}
        promotions={groupPromotionsByCompetence(filteredResults)} squads={groupProgressBySquad(filtered)} />
      <DashboardLists nearPromotion={findNearPromotion(filtered)} recentPromotions={findRecentPromotions(filtered)}
        onOpen={setSelected} onNavigate={onNavigate} />
    </>}
    <ProfileHistoryDialog item={selected} onClose={() => setSelected(null)} />
  </div>;
}
