import { Award, Target, Users } from "lucide-react";
import { Card, CardContent } from "@/components/ui/card";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import { formatarCompetencia } from "@/lib/progression";
import type { CoverageSummary } from "../../domain/analytics";

export function MainMetrics({ active, inactive, promotionRecords, promotedPeople, seniorityPromotions, roleTransitionPromotions, nearPromotion, coverage, competence }: {
  active: number; inactive: number; promotionRecords: number; promotedPeople: number; seniorityPromotions: number; roleTransitionPromotions: number; nearPromotion: number; coverage: CoverageSummary; competence: string;
}) {
  return <>
    <MetricCard title="Colaboradores ativos" value={active} secondary={`${inactive} inativos`} icon={Users} />
    <Tooltip><TooltipTrigger asChild><div className="h-full"><MetricCard title="Promoções" value={`${promotionRecords} promoções registradas`} secondary={`${seniorityPromotions} de senioridade · ${roleTransitionPromotions} para Closer`} icon={Award} /></div></TooltipTrigger>
      <TooltipContent>{promotedPeople} colaboradores promovidos. Uma pessoa pode ter mais de uma promoção registrada.</TooltipContent></Tooltip>
    <MetricCard title="Progresso 2/3" value={nearPromotion} secondary="colaboradores a uma Meta 3 da promoção" icon={Target} />
    <Card data-testid="coverage-card" className="h-full"><CardContent className="flex h-full min-h-44 items-center gap-3 p-4"><div className="relative grid h-20 w-20 shrink-0 place-items-center rounded-full"
      style={{ background: `conic-gradient(hsl(var(--primary)) ${coverage.presentPercentage}%, hsl(var(--muted)) 0)` }} aria-label={`${coverage.presentPercentage}% com presença`}>
      <div className="grid h-14 w-14 place-items-center rounded-full bg-card text-sm font-extrabold">{coverage.presentPercentage}%</div></div>
      <div><p className="text-sm font-semibold">Cobertura da competência</p><p className="mt-2 text-xs text-muted-foreground">{competence ? formatarCompetencia(competence) : "Sem competência"}</p>
        <p className="mt-1 text-xs"><strong>{coverage.present}</strong> com presença · <strong>{coverage.absent}</strong> sem presença</p></div></CardContent></Card>
  </>;
}

function MetricCard({ title, value, secondary, icon: Icon }: { title: string; value: number | string; secondary: string; icon: React.ComponentType<{ className?: string }> }) {
  return <Card className="h-full"><CardContent className="flex h-full min-h-44 items-start justify-between gap-3 p-4"><div><p className="text-sm font-semibold text-muted-foreground">{title}</p><p className="mt-3 font-display text-2xl font-extrabold leading-tight">{value}</p><p className="mt-2 text-xs leading-5 text-muted-foreground">{secondary}</p></div>
    <div className="rounded-xl bg-primary/10 p-3"><Icon aria-hidden="true" className="h-5 w-5 text-primary" /></div></CardContent></Card>;
}
