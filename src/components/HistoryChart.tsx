import type { MonthRecord } from "@/lib/progression";
import { goalTone } from "@/lib/progression";
import { cn } from "@/lib/utils";

interface HistoryChartProps {
  history: MonthRecord[];
}

const HEIGHTS = { below: 18, meta1: 40, meta2: 70, meta3: 100 } as const;

export function HistoryChart({ history }: HistoryChartProps) {
  return (
    <div className="flex h-32 items-end gap-3 rounded-lg border border-border bg-muted/40 p-3">
      {history.map((m) => {
        const tone = goalTone(m.goal);
        const h = HEIGHTS[m.goal];
        return (
          <div key={m.month} className="flex flex-1 flex-col items-center gap-1.5">
            <div className="relative flex w-full flex-1 items-end">
              <div
                className={cn(
                  "w-full rounded-md transition-all",
                  tone === "success" && "bg-success",
                  tone === "warning" && "bg-primary",
                  tone === "danger" && "bg-destructive",
                )}
                style={{ height: `${h}%` }}
              />
            </div>
            <span className="text-[10px] font-semibold uppercase tracking-wider text-muted-foreground">
              {m.month}
            </span>
          </div>
        );
      })}
    </div>
  );
}
