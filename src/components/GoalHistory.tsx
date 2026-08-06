import { useMemo } from "react";
import { GoalBadge } from "@/components/GoalBadge";
import type { GoalLevel, SDR } from "@/lib/progression";

interface GoalHistoryProps {
  sdrs: SDR[];
}

interface HistoryGroup {
  id: string;
  sdrName: string;
  squad: SDR["squad"];
  level: SDR["level"];
  history: Array<{
    id: string;
    month: string;
    goal: GoalLevel;
  }>;
}

export function GoalHistory({ sdrs }: GoalHistoryProps) {
  const groups = useMemo<HistoryGroup[]>(() => {
    return sdrs
      .filter((sdr) => sdr.history.length > 0)
      .map((sdr) => ({
        id: sdr.id,
        sdrName: sdr.name,
        squad: sdr.squad,
        level: sdr.level,
        history: sdr.history.map((record, index) => ({
          id: `${sdr.id}-${record.month}-${index}`,
          month: record.month,
          goal: record.goal,
        })),
      }));
  }, [sdrs]);

  if (groups.length === 0) {
    return (
      <div className="rounded-lg border border-dashed border-border bg-card p-8 text-center shadow-card">
        <span className="text-xs font-semibold uppercase tracking-wider text-primary">
          Nenhuma meta preenchida ainda
        </span>
      </div>
    );
  }

  return (
    <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
      {groups.map((group) => (
        <section key={group.id} className="relative overflow-hidden rounded-lg border border-border bg-card shadow-card">
          <div className="absolute inset-x-0 top-0 h-1 bg-primary" />
          <div className="flex items-start justify-between gap-3 border-b border-border p-4 pt-5">
            <div>
              <h3 className="font-display text-lg font-bold tracking-tight text-primary">{group.sdrName}</h3>
              <p className="text-[10px] font-semibold uppercase tracking-wider text-muted-foreground">
                {group.squad} · {group.level}
              </p>
            </div>
            <span className="rounded-full border border-primary/20 bg-accent px-2.5 py-1 text-[10px] font-bold uppercase tracking-wider text-primary">
              {group.history.length} {group.history.length === 1 ? "mês" : "meses"}
            </span>
          </div>

          <div className="divide-y divide-border/60">
            {group.history.map((record) => (
              <div key={record.id} className="flex items-center justify-between gap-3 p-4">
                <span className="text-xs font-bold uppercase tracking-wider text-foreground">{record.month}</span>
                <GoalBadge goal={record.goal} size="sm" />
              </div>
            ))}
          </div>
        </section>
      ))}
    </div>
  );
}