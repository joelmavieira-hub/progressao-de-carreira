/** @deprecated Legacy editor card retained for reference; current state comes from colaboradores_perfis. */
import { useMemo, useState } from "react";
import type { GoalLevel, SDR } from "@/lib/progression";
import { computeProgression, getNextSeniority, GOAL_LABEL } from "@/lib/progression";
import { Card, CardContent, CardHeader } from "@/components/ui/card";
import { StreakStepper } from "./StreakStepper";
import { GoalBadge } from "./GoalBadge";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { ArrowUpRight, Plus, ShieldAlert, Trash2, TrendingUp, X, Zap } from "lucide-react";
import { cn } from "@/lib/utils";

interface SdrCardProps {
  sdr: SDR;
  onUpdateMonthGoal?: (id: string, month: string, goal: GoalLevel) => void | Promise<void>;
  onAddMonth?: (id: string, month: string, goal: GoalLevel) => void | Promise<void>;
  onRemoveMonth?: (id: string, month: string) => void | Promise<void>;
  onDelete?: (id: string) => void | Promise<void>;
}

const GOAL_OPTIONS: GoalLevel[] = ["below", "meta1", "meta2", "meta3", "absent"];

export function SdrCard({ sdr, onUpdateMonthGoal, onAddMonth, onRemoveMonth, onDelete }: SdrCardProps) {
  const [pendingGoal, setPendingGoal] = useState<GoalLevel | "none">("none");
  const [newMonth, setNewMonth] = useState("");
  const [newMonthGoal, setNewMonthGoal] = useState<GoalLevel>("meta3");

  const previewHistory = useMemo(() => {
    if (pendingGoal === "none") return sdr.history;
    return [...sdr.history, { month: "Atual", goal: pendingGoal }];
  }, [sdr.history, pendingGoal]);

  const state = useMemo(() => computeProgression(previewHistory, sdr.level), [previewHistory, sdr.level]);
  const nextSeniority = getNextSeniority(sdr.level);
  const initials = sdr.name
    .split(" ")
    .map((s) => s[0])
    .slice(0, 2)
    .join("");

  const headlineTone = state.wasReset
    ? "danger"
    : state.readyForLevelUp
      ? "success"
      : state.tier === 2
        ? "success"
        : "warning";

  const handleAddMonth = async () => {
    const trimmed = newMonth.trim().toUpperCase();
    if (!trimmed) return;
    await onAddMonth?.(sdr.id, trimmed, newMonthGoal);
    setNewMonth("");
    setNewMonthGoal("meta3");
  };

  return (
    <Card
      className={cn(
        "group relative overflow-hidden border-border bg-card shadow-card transition-all duration-200 hover:-translate-y-0.5",
        headlineTone === "success" && "hover:border-primary/60 hover:shadow-elevated",
        headlineTone === "danger" && "hover:border-destructive/60",
        headlineTone === "warning" && "hover:border-accent/50",
      )}
    >
      {/* corner accent */}
      <div
        className={cn(
          "absolute inset-x-0 top-0 h-1",
          headlineTone === "success" && "bg-success",
          headlineTone === "warning" && "bg-primary",
          headlineTone === "danger" && "bg-destructive",
        )}
      />

      <CardHeader className="relative space-y-3">
        <div className="flex items-start justify-between gap-3">
          <div className="flex items-center gap-3">
            <div className="flex h-12 w-12 items-center justify-center rounded-lg border border-primary/20 bg-accent font-display text-base font-bold text-primary">
              {initials}
            </div>
            <div>
              <h3 className="text-lg font-bold leading-tight text-foreground">{sdr.name}</h3>
              <p className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                {sdr.level} · FAIXA {state.tier}
              </p>
            </div>
          </div>

          <div className="flex items-center gap-1.5">
            {state.readyForLevelUp ? (
                <div className="flex items-center gap-1 rounded-full border border-success/20 bg-success/10 px-2.5 py-1 text-[10px] font-bold uppercase tracking-wider text-success">
                <ArrowUpRight className="h-3 w-3" />
                Promoção
              </div>
            ) : state.wasReset ? (
                <div className="flex items-center gap-1 rounded-full border border-destructive/20 bg-destructive/10 px-2.5 py-1 text-[10px] font-bold uppercase tracking-wider text-destructive">
                <ShieldAlert className="h-3 w-3" />
                Resetado
              </div>
            ) : state.tier === 2 ? (
                <div className="flex items-center gap-1 rounded-full border border-primary/20 bg-accent px-2.5 py-1 text-[10px] font-bold uppercase tracking-wider text-primary">
                <TrendingUp className="h-3 w-3" />
                Faixa 2
              </div>
            ) : (
                <div className="flex items-center gap-1 rounded-full border border-primary/20 bg-accent px-2.5 py-1 text-[10px] font-bold uppercase tracking-wider text-primary">
                <Zap className="h-3 w-3" />
                Construindo
              </div>
            )}
            {onDelete && (
              <Button
                size="icon"
                variant="ghost"
                className="h-7 w-7 text-muted-foreground hover:text-destructive"
                onClick={() => {
                  if (confirm(`Remover ${sdr.name}?`)) onDelete(sdr.id);
                }}
                aria-label="Remover SDR"
              >
                <Trash2 className="h-3.5 w-3.5" />
              </Button>
            )}
          </div>
        </div>
      </CardHeader>

      <CardContent className="relative space-y-5">
        {/* Streak */}
        <div className="flex items-center justify-between gap-4 rounded-lg border border-border bg-muted/40 p-4">
          <StreakStepper streak={state.meta3Streak} wasReset={state.wasReset} />
          <div className="text-right">
            <div className="font-display text-2xl font-bold tabular-nums text-foreground">
              {state.meta3Streak}/3
            </div>
            <div className="text-[10px] font-semibold uppercase tracking-wider text-muted-foreground">
              Meta 3 acumuladas
            </div>
          </div>
        </div>

        {/* Promo target */}
        {state.readyForLevelUp && nextSeniority && (
          <div className="flex items-center justify-between rounded-lg border border-primary/40 bg-primary/10 px-3 py-2">
            <span className="text-xs font-bold uppercase tracking-wider text-primary">Pronto para</span>
            <span className="font-display text-sm font-semibold text-primary">{nextSeniority}</span>
          </div>
        )}

          {/* Month goals */}
        <div className="space-y-2">
          {state.lastGoal && <GoalBadge goal={state.lastGoal} size="sm" />}

          {sdr.history.length > 0 && (
            <div className="space-y-1.5 pt-1">
              <span className="text-[10px] font-bold uppercase tracking-wider text-muted-foreground">
                Editar metas por mês
              </span>
              <div className="space-y-1.5">
                {sdr.history.map((m) => (
                  <div key={m.month} className="flex items-center gap-2">
                    <span className="w-16 text-[10px] font-semibold uppercase tracking-wider text-muted-foreground">
                      {m.month}
                    </span>
                    <Select
                      value={m.goal}
                      onValueChange={(v) => onUpdateMonthGoal?.(sdr.id, m.month, v as GoalLevel)}
                    >
                      <SelectTrigger className="h-8 flex-1 border-border bg-card text-xs">
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        {GOAL_OPTIONS.map((g) => (
                          <SelectItem key={g} value={g}>
                            {GOAL_LABEL[g]}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                    {onRemoveMonth && (
                      <Button
                        size="icon"
                        variant="ghost"
                        className="h-7 w-7 text-muted-foreground hover:text-destructive"
                        onClick={() => onRemoveMonth(sdr.id, m.month)}
                        aria-label={`Remover ${m.month}`}
                      >
                        <X className="h-3.5 w-3.5" />
                      </Button>
                    )}
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Add month */}
          {onAddMonth && (
            <div className="space-y-1.5 pt-2">
              <span className="text-[10px] font-bold uppercase tracking-wider text-muted-foreground">
                Adicionar mês
              </span>
              <div className="flex items-center gap-2">
                <Input
                  value={newMonth}
                  onChange={(e) => setNewMonth(e.target.value)}
                  placeholder="MAI/26"
                  className="h-8 w-24 border-border bg-card text-xs uppercase"
                />
                <Select value={newMonthGoal} onValueChange={(v) => setNewMonthGoal(v as GoalLevel)}>
                  <SelectTrigger className="h-8 flex-1 border-border bg-card text-xs">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {GOAL_OPTIONS.map((g) => (
                      <SelectItem key={g} value={g}>
                        {GOAL_LABEL[g]}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                <Button
                  size="icon"
                  variant="ghost"
                  className="h-8 w-8 text-primary"
                  onClick={handleAddMonth}
                  aria-label="Adicionar mês"
                >
                  <Plus className="h-4 w-4" />
                </Button>
              </div>
            </div>
          )}
        </div>

        {/* Simulator */}
        <div className="space-y-1.5">
          <label className="text-[10px] font-bold uppercase tracking-wider text-muted-foreground">
            Simular mês atual
          </label>
          <Select value={pendingGoal} onValueChange={(v) => setPendingGoal(v as GoalLevel | "none")}>
            <SelectTrigger className="h-9 border-border bg-card text-xs">
              <SelectValue placeholder="Selecione…" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="none">— Sem simulação —</SelectItem>
              {GOAL_OPTIONS.map((g) => (
                <SelectItem key={g} value={g}>
                  {GOAL_LABEL[g]}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
      </CardContent>
    </Card>
  );
}
