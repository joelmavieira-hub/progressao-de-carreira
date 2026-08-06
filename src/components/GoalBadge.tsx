import { GOAL_LABEL, type GoalLevel, goalTone } from "@/lib/progression";
import { Check, Flame, Minus, Shield, Skull } from "lucide-react";
import { cn } from "@/lib/utils";

interface GoalBadgeProps {
  goal: GoalLevel;
  size?: "sm" | "md";
}

const ICONS: Record<GoalLevel, React.ComponentType<{ className?: string }>> = {
  meta3: Flame,
  meta2: Check,
  meta1: Shield,
  below: Skull,
  absent: Minus,
};

export function GoalBadge({ goal, size = "md" }: GoalBadgeProps) {
  const tone = goalTone(goal);
  const Icon = ICONS[goal];

  return (
    <span
      className={cn(
        "inline-flex items-center gap-1.5 rounded-full border font-semibold uppercase tracking-wider",
        size === "sm" ? "px-2 py-0.5 text-[10px]" : "px-2.5 py-1 text-xs",
        tone === "success" && "border-success/20 bg-success/10 text-success",
        tone === "warning" && "border-primary/20 bg-accent text-primary",
        tone === "danger" && "border-destructive/20 bg-destructive/10 text-destructive",
        tone === "muted" && "border-border bg-muted text-muted-foreground",
      )}
    >
      <Icon className={size === "sm" ? "h-3 w-3" : "h-3.5 w-3.5"} />
      {GOAL_LABEL[goal]}
    </span>
  );
}
