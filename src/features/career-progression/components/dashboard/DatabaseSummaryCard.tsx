import { Database, RefreshCw } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { formatarCompetencia } from "@/lib/progression";

export function DatabaseSummaryCard({ totalProfiles, competenceRecords, competence, updatedAt, isFetching, onRefresh }: {
  totalProfiles: number; competenceRecords: number; competence: string; updatedAt: Date | null; isFetching: boolean; onRefresh: () => void;
}) {
  return <Card data-testid="database-summary-card" className="h-full border-primary/20 bg-gradient-to-br from-white to-purple-50"><CardHeader className="flex flex-row items-center justify-between space-y-0 p-4 pb-3"><CardTitle className="flex items-center gap-2 text-sm"><Database aria-hidden="true" className="h-4 w-4 text-primary" />Banco de Dados</CardTitle>
    <Button aria-label="Atualizar dados" variant="outline" size="sm" onClick={onRefresh} disabled={isFetching} className="h-8 px-2.5 text-xs"><RefreshCw aria-hidden="true" className={`mr-1.5 h-3.5 w-3.5 ${isFetching ? "animate-spin" : ""}`} />{isFetching ? "Atualizando" : "Atualizar"}</Button></CardHeader>
    <CardContent className="grid gap-2 px-4 pb-4 text-xs"><Summary label="Colaboradores totais" value={String(totalProfiles)} /><Summary label="Registros na competência" value={String(competenceRecords)} />
      <Summary label="Última atualização" value={updatedAt ? updatedAt.toLocaleString("pt-BR") : "Não informada"} /><Summary label="Competência" value={competence ? formatarCompetencia(competence) : "Não informada"} /><Summary label="Fonte" value="Supabase" /></CardContent></Card>;
}

function Summary({ label, value }: { label: string; value: string }) { return <div className="flex items-start justify-between gap-2 border-b pb-1.5 last:border-0"><span className="text-muted-foreground">{label}</span><strong className="text-right leading-4">{value}</strong></div>; }
