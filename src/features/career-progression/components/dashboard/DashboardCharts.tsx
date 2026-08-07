import { Bar, BarChart, CartesianGrid, LabelList, Legend, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { formatarCompetencia, formatarEtapaProgresso } from "@/lib/progression";
import type { MonthlyGoalEvolution } from "../../domain/analytics";
import { DASHBOARD_CHART_COLORS } from "./dashboard-chart-colors";

interface DashboardChartsProps {
  cycle: Array<{ progress: number; total: number }>;
  seniority: Array<{ seniority: string; total: number }>;
  monthlyGoals: MonthlyGoalEvolution[];
  promotions: Array<{ competence: string; total: number }>;
  squads: Array<{ squad: string; meta1: number; meta2: number; meta3: number; total: number }>;
}

export function DashboardCharts({ cycle, seniority, monthlyGoals, promotions, squads }: DashboardChartsProps) {
  const cycleData = cycle.map((item) => ({ name: formatarEtapaProgresso(item.progress), total: item.total }));

  const monthly = monthlyGoals.map((item) => ({
    competenceLabel: formatarCompetencia(item.competence),
    "Meta 1": item["Meta 1"],
    "Meta 2": item["Meta 2"],
    "Meta 3": item["Meta 3"],
    "Atingiram meta": item["Atingiram meta"],
  }));

  const promotionData = promotions.map((item) => ({
    ...item,
    competenceLabel: formatarCompetencia(item.competence),
  }));

  return <div className="grid gap-5 xl:grid-cols-2">
    <ChartCard title="Distribuição do ciclo" description="Colaboradores por etapa atual do ciclo" testId="cycle-distribution-chart" primaryColor={DASHBOARD_CHART_COLORS.primary}>
      <ResponsiveContainer width="100%" height={260}><BarChart data={cycleData} layout="vertical" margin={{ left: 10, right: 30 }}><CartesianGrid strokeDasharray="3 3" horizontal={false} />
        <XAxis type="number" allowDecimals={false} /><YAxis type="category" dataKey="name" width={78} /><Tooltip /><Bar dataKey="total" name="Colaboradores" fill={DASHBOARD_CHART_COLORS.primary} radius={[0, 8, 8, 0]}><LabelList dataKey="total" position="right" /></Bar></BarChart></ResponsiveContainer>
    </ChartCard>

    <ChartCard title="Senioridade atual" description="Distribuição nos nove níveis oficiais" testId="seniority-distribution-chart" primaryColor={DASHBOARD_CHART_COLORS.primary}>
      <ResponsiveContainer width="100%" height={260}><BarChart data={seniority} margin={{ top: 20 }}><CartesianGrid strokeDasharray="3 3" vertical={false} /><XAxis dataKey="seniority" interval={0} angle={-30} textAnchor="end" height={70} fontSize={11} />
        <YAxis allowDecimals={false} /><Tooltip /><Bar dataKey="total" name="Colaboradores" fill={DASHBOARD_CHART_COLORS.primary} radius={[7, 7, 0, 0]}><LabelList dataKey="total" position="top" /></Bar></BarChart></ResponsiveContainer>
    </ChartCard>

    <ChartCard title="Evolução mensal de atingimento" description="Colaboradores distintos que alcançaram Meta 1, Meta 2 ou Meta 3 em cada competência" testId="monthly-goals-chart" wide>
      <div aria-label="Gráfico empilhado da evolução mensal por Meta 1, Meta 2 e Meta 3">
        <ResponsiveContainer width="100%" height={310}>
          <BarChart data={monthly} margin={{ top: 20 }}>
            <CartesianGrid strokeDasharray="3 3" vertical={false} />
            <XAxis dataKey="competenceLabel" />
            <YAxis allowDecimals={false} />
            <Tooltip />

            <Bar
              stackId="goals"
              dataKey="Meta 1"
              name="Meta 1"
              fill={DASHBOARD_CHART_COLORS.light}
            />
            <Bar
              stackId="goals"
              dataKey="Meta 2"
              name="Meta 2"
              fill={DASHBOARD_CHART_COLORS.medium}
            />
            <Bar
              stackId="goals"
              dataKey="Meta 3"
              name="Meta 3"
              fill={DASHBOARD_CHART_COLORS.dark}
              radius={[7, 7, 0, 0]}
            >
              <LabelList dataKey="Atingiram meta" position="top" />
            </Bar>
          </BarChart>
        </ResponsiveContainer>
      </div>

      <div aria-label="Legenda evolução mensal" className="mt-2 flex flex-wrap items-center justify-center gap-x-4 gap-y-2 text-xs text-muted-foreground">
        <span className="font-medium text-foreground">Incluídas:</span>
        {[
          ["Meta 1", DASHBOARD_CHART_COLORS.light],
          ["Meta 2", DASHBOARD_CHART_COLORS.medium],
          ["Meta 3", DASHBOARD_CHART_COLORS.dark],
        ].map(([label, color]) => <span key={label} className="flex items-center gap-1.5"><span aria-hidden="true" className="h-2.5 w-2.5 rounded-sm" style={{ backgroundColor: color }} />{label}</span>)}
        <span className="font-medium text-foreground">Excluída:</span>
        <span className="flex items-center gap-1.5"><span aria-hidden="true" className="h-2.5 w-2.5 rounded-sm" style={{ backgroundColor: DASHBOARD_CHART_COLORS.neutral }} />Nenhuma meta</span>
      </div>

      <p className="mt-2 text-center text-xs text-muted-foreground">Sem presença, Sem registro e Nenhuma meta não entram no atingimento.</p>
    </ChartCard>

    <ChartCard title="Promoções por competência" description="Quantidade de registros de promoção por mês" testId="promotions-by-competence-chart" primaryColor={DASHBOARD_CHART_COLORS.primary}>
      <ResponsiveContainer width="100%" height={270}><BarChart data={promotionData} margin={{ top: 20 }}><CartesianGrid strokeDasharray="3 3" vertical={false} /><XAxis dataKey="competenceLabel" /><YAxis allowDecimals={false} /><Tooltip />
        <Bar dataKey="total" name="Promoções" fill={DASHBOARD_CHART_COLORS.primary} radius={[7, 7, 0, 0]}><LabelList dataKey="total" position="top" /></Bar></BarChart></ResponsiveContainer>
    </ChartCard>

    <ChartCard title="Progressão por squad" description="Squads operacionais distribuídos por etapa" testId="squad-progress-chart">
      {squads.length === 0 ? <ChartEmpty /> : <ResponsiveContainer width="100%" height={Math.max(270, squads.length * 42)}><BarChart data={squads} layout="vertical" margin={{ left: 8, right: 20 }}><CartesianGrid strokeDasharray="3 3" horizontal={false} /><XAxis type="number" allowDecimals={false} /><YAxis type="category" dataKey="squad" width={90} /><Tooltip /><Legend />
        <Bar stackId="cycle" dataKey="meta1" name="0/3" fill={DASHBOARD_CHART_COLORS.light} /><Bar stackId="cycle" dataKey="meta2" name="1/3" fill={DASHBOARD_CHART_COLORS.medium} /><Bar stackId="cycle" dataKey="meta3" name="2/3" fill={DASHBOARD_CHART_COLORS.dark} radius={[0, 6, 6, 0]} /></BarChart></ResponsiveContainer>}
    </ChartCard>
  </div>;
}

function ChartCard({ title, description, testId, wide = false, primaryColor, children }: { title: string; description: string; testId: string; wide?: boolean; primaryColor?: string; children: React.ReactNode }) {
  return <Card data-testid={testId} data-primary-color={primaryColor} className={wide ? "xl:col-span-2" : undefined}><CardHeader className="pb-2"><CardTitle className="text-base">{title}</CardTitle><p className="text-xs text-muted-foreground">{description}</p></CardHeader>
    <CardContent aria-label={`${title}. ${description}`}>{children}</CardContent></Card>;
}

function ChartEmpty() { return <div role="status" className="flex h-64 items-center justify-center text-sm text-muted-foreground">Sem dados para os filtros selecionados.</div>; }
