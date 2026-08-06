/** @deprecated Legacy overview retained but not mounted by an active route. */
import { useMemo } from "react";
import { computeProgression, getNextSeniority, type Level, type SDR } from "@/lib/progression";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { ArrowUpRight, ShieldAlert, TrendingUp, Users } from "lucide-react";
import { cn } from "@/lib/utils";

interface ManagementOverviewProps {
  sdrs: SDR[];
}

const JR_LEVELS: Level[] = ["Júnior 1", "Júnior 2", "Júnior 3"];

export function ManagementOverview({ sdrs }: ManagementOverviewProps) {
  const buckets = useMemo(() => {
    const tier1: SDR[] = [];
    const tier2: SDR[] = [];
    const oneAway: SDR[] = []; // streak === 2
    const reset: SDR[] = [];

    sdrs.forEach((sdr) => {
      const s = computeProgression(sdr.history, sdr.level);
      if (s.wasReset) reset.push(sdr);
      if (s.meta3Streak === 2) oneAway.push(sdr);
      if (s.tier === 2) tier2.push(sdr);
      else tier1.push(sdr);
    });

    return { tier1, tier2, oneAway, reset };
  }, [sdrs]);

  const groupByJrLevel = (list: SDR[]) => {
    const groups: Record<string, SDR[]> = {
      "Júnior 1": [],
      "Júnior 2": [],
      "Júnior 3": [],
      Outros: [],
    };
    list.forEach((s) => {
      if (JR_LEVELS.includes(s.level)) groups[s.level].push(s);
      else groups.Outros.push(s);
    });
    return groups;
  };

  const tier1Groups = groupByJrLevel(buckets.tier1);
  const tier2Groups = groupByJrLevel(buckets.tier2);

  return (
    <div className="grid grid-cols-1 gap-3 md:grid-cols-2 xl:grid-cols-4">
        <GroupedStatCard
          icon={Users}
          label="Faixa 1"
          total={buckets.tier1.length}
          groups={tier1Groups}
          tone="muted"
        />
        <GroupedStatCard
          icon={TrendingUp}
          label="Faixa 2"
          total={buckets.tier2.length}
          groups={tier2Groups}
          tone="success"
        />
        <StatCard
          icon={ArrowUpRight}
          label="A 1 mês da promoção"
          value={buckets.oneAway.length}
          names={buckets.oneAway.map((s) => `${s.name} (${s.level}) → ${getNextSeniority(s.level) ?? "Topo"}`)}
          tone="success"
          glow
        />
        <StatCard
          icon={ShieldAlert}
          label="Resetados"
          value={buckets.reset.length}
          names={buckets.reset.map((s) => `${s.name} · ${s.level}`)}
          tone="danger"
        />
    </div>
  );
}

interface GroupedStatCardProps {
  icon: React.ComponentType<{ className?: string }>;
  label: string;
  total: number;
  groups: Record<string, SDR[]>;
  tone: "success" | "warning" | "danger" | "muted";
}

function GroupedStatCard({ icon: Icon, label, total, groups, tone }: GroupedStatCardProps) {
  const orderedKeys = ["Júnior 1", "Júnior 2", "Júnior 3", "Outros"].filter(
    (k) => groups[k] && groups[k].length > 0,
  );

  return (
      <Card className="relative overflow-hidden border-border bg-card shadow-card">
       <div className="absolute inset-x-0 top-0 h-1 bg-primary" />
      <CardHeader className="px-4 pb-1 pt-4">
        <div className="flex items-center justify-between">
          <CardTitle className="text-sm font-bold uppercase tracking-wider text-primary">
            {label}
          </CardTitle>
          <Icon className="h-4 w-4 text-muted-foreground" />
        </div>
      </CardHeader>
      <CardContent className="space-y-2 px-4 pb-4">
        <div className="font-display text-3xl font-bold tabular-nums text-foreground">
          {total}
        </div>

        {orderedKeys.length === 0 && (
          <p className="text-sm text-muted-foreground">— ninguém —</p>
        )}

        <div className="grid gap-2 sm:grid-cols-2 xl:grid-cols-1">
          {orderedKeys.map((levelKey) => (
            <div key={levelKey} className="space-y-1 rounded-lg border border-border bg-muted/40 p-2">
              <div className="flex items-center justify-between border-b border-border/50 pb-1">
                 <span className="text-[10px] font-bold uppercase tracking-wider text-foreground">
                  {levelKey}
                </span>
                 <span className="text-[10px] font-semibold tabular-nums text-muted-foreground">
                  {groups[levelKey].length}
                </span>
              </div>
              <ul className="space-y-0.5">
                {groups[levelKey].map((s) => (
                   <li key={s.id} className="text-xs font-medium text-muted-foreground">
                    {s.name}
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>
      </CardContent>
    </Card>
  );
}

interface StatCardProps {
  icon: React.ComponentType<{ className?: string }>;
  label: string;
  value: number;
  names: string[];
  tone: "success" | "warning" | "danger" | "muted";
  glow?: boolean;
}

function StatCard({ icon: Icon, label, value, names, tone, glow }: StatCardProps) {
  return (
    <Card className="relative overflow-hidden border-border bg-card shadow-card">
      <div className="absolute inset-x-0 top-0 h-1 bg-primary" />
      <CardHeader className="px-4 pb-1 pt-4">
        <div className="flex items-center justify-between">
          <CardTitle className="text-sm font-bold uppercase tracking-wider text-primary">
            {label}
          </CardTitle>
          <Icon className="h-4 w-4 text-muted-foreground" />
        </div>
      </CardHeader>
      <CardContent className="space-y-2 px-4 pb-4">
        <div className="font-display text-3xl font-bold tabular-nums text-foreground">
          {value}
        </div>
        <ul className="space-y-0.5">
          {names.length === 0 && (
            <li className="text-sm text-muted-foreground">— ninguém —</li>
          )}
          {names.map((n) => (
            <li key={n} className="text-xs font-medium text-muted-foreground">
              {n}
            </li>
          ))}
        </ul>
      </CardContent>
    </Card>
  );
}
