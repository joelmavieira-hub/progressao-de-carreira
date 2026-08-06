import { Flame } from "lucide-react";
import { cn } from "@/lib/utils";

interface StreakStepperProps {
  streak: number; // 0..3
  wasReset?: boolean;
}

/**
 * 3-slot streak visualization.
 * Slots 1 & 2 lit = Tier 2 reached. Slot 3 lit = Level Up unlocked.
 */
export function StreakStepper({ streak, wasReset = false }: StreakStepperProps) {
  const slots = [0, 1, 2];

  return (
    <div className="flex items-center gap-2">
      {slots.map((i) => {
        const filled = i < streak;
        const isLevelUp = i === 2;
        const dangerEmpty = wasReset && i === 0;

        return (
          <div key={i} className="flex flex-col items-center gap-1">
            <div
              className={cn(
                "relative flex h-12 w-12 items-center justify-center rounded-lg border transition-all",
                filled && !isLevelUp && "border-success/30 bg-success/10 text-success animate-pulse-glow",
                filled && isLevelUp && "border-success bg-success text-success-foreground animate-pulse-glow",
                !filled && !dangerEmpty && "border-border bg-muted/40",
                dangerEmpty && "border-destructive/60 bg-destructive/10",
              )}
            >
              {filled ? (
                <Flame
                  className={cn(
                    "h-6 w-6 animate-flame",
                    isLevelUp ? "text-success-foreground" : "text-success",
                  )}
                  strokeWidth={2.5}
                  fill="currentColor"
                />
              ) : (
                <span className={cn("text-xs font-semibold", dangerEmpty ? "text-destructive" : "text-muted-foreground")}>
                  {i + 1}
                </span>
              )}
            </div>
            <span className="text-[10px] font-semibold uppercase tracking-wider text-muted-foreground">
              {isLevelUp ? "Nível" : `M${i + 1}`}
            </span>
          </div>
        );
      })}
    </div>
  );
}
