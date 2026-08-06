import { Flame, Shield, Skull, Trophy } from "lucide-react";

export function RulesLegend() {
  const items = [
    {
      icon: Flame,
      title: "Meta 3",
      desc: "Continue avançando",
      tone: "primary",
    },
    {
      icon: Shield,
      title: "Meta 1 / 2",
      desc: "​Meta segurança",
      tone: "accent",
    },
    {
      icon: Skull,
      title: "Sem meta",
      desc: "Reseta a contagem",
      tone: "destructive",
    },
    {
      icon: Trophy,
      title: "3 Meta 3",
      desc: "Subida de Nível ",
      tone: "primary",
    },
  ] as const;

  return (
    <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
      {items.map(({ icon: Icon, title, desc, tone }) => (
        <div
          key={title}
          className="flex items-center gap-3 rounded-lg border border-border bg-card p-3 shadow-card"
        >
          <div
            className={
              tone === "primary"
                    ? "flex h-9 w-9 items-center justify-center rounded-lg border border-primary/20 bg-accent text-primary"
                : tone === "accent"
                  ? "flex h-9 w-9 items-center justify-center rounded-lg border border-primary/20 bg-accent text-primary"
                  : "flex h-9 w-9 items-center justify-center rounded-lg border border-destructive/20 bg-destructive/10 text-destructive"
            }
          >
            <Icon className="h-4 w-4" />
          </div>
          <div className="min-w-0">
            <div className="font-display text-sm font-semibold text-foreground">{title}</div>
            <div className="truncate text-[11px] font-medium text-muted-foreground">{desc}</div>
          </div>
        </div>
      ))}
    </div>
  );
}
