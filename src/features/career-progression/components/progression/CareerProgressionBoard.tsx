import { useEffect, useMemo, useRef, useState } from "react";
import { ArrowRight, Award, CheckCircle2, Eye, Target, Users } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { derivarOpcoesDeFiltro, formatarSquadAtual } from "../../domain";
import {
  buildCareerPromotions, buildCycleColumns, countUniqueCareerPromoted,
  filterProfilesByHistoricalSquad, listCompetences, listSquadsByCompetence,
  squadForCompetence, type AnalyticsFilters, type PromotionView,
} from "../../domain/analytics";
import type { ColaboradorPerfil, ColaboradorResultado, PerfilComHistorico } from "../../types";
import { formatarCompetencia, formatarComposicaoCiclo, formatarEtapaProgresso } from "@/lib/progression";
import { CareerFiltersBar } from "../shared/CareerFiltersBar";
import { ProfileHistoryDialog } from "../shared/ProfileHistoryDialog";
import { isLeadershipPosition } from "../../domain/promotions";

const defaults = (competence: string): AnalyticsFilters => ({ competence, status: "ativos", squad: "todos", position: "todos", seniority: "todos", search: "" });

export function CareerProgressionBoard({ perfis, resultados, perfisComHistorico, focus }: {
  perfis: ColaboradorPerfil[]; resultados: ColaboradorResultado[]; perfisComHistorico: PerfilComHistorico[]; focus?: "meta3" | "promoted";
}) {
  const competences = useMemo(() => listCompetences(resultados), [resultados]);
  const latest = competences.at(-1) ?? "";
  const [filters, setFilters] = useState<AnalyticsFilters>(() => defaults(latest));
  const [selected, setSelected] = useState<PerfilComHistorico | null>(null);
  const boardRef = useRef<HTMLDivElement>(null);
  useEffect(() => { if (!filters.competence && latest) setFilters((current) => ({ ...current, competence: latest })); }, [filters.competence, latest]);
  useEffect(() => {
    if (!focus || !boardRef.current) return;
    boardRef.current.querySelector<HTMLElement>(`[data-column="${focus}"]`)?.scrollIntoView({ behavior: "smooth", inline: "center", block: "nearest" });
  }, [focus]);

  const currentOptions = useMemo(
    () => derivarOpcoesDeFiltro(perfis),
    [perfis],
  );

  const options = useMemo(
    () => ({
      ...currentOptions,
      squads: listSquadsByCompetence(
        perfisComHistorico,
        filters.competence,
      ),
    }),
    [
      currentOptions,
      perfisComHistorico,
      filters.competence,
    ],
  );

  const filtered = useMemo(
    () => filterProfilesByHistoricalSquad(
      perfisComHistorico,
      filters,
    ),
    [perfisComHistorico, filters],
  );

  // Promoção na competência selecionada tem prioridade
  // sobre os estágios 0/3, 1/3 e 2/3.
  const promotions = useMemo(
    () => buildCareerPromotions(filtered, filters.competence),
    [filtered, filters.competence],
  );

  const promotedIds = useMemo(
    () => new Set(
      promotions.map(({ profile }) => profile.perfil.id),
    ),
    [promotions],
  );

  // Quem foi promovido no período aparece exclusivamente
  // em "Promovidos no período".
  const cycleProfiles = useMemo(
    () => filtered.filter(
      ({ perfil }) => !promotedIds.has(perfil.id) &&
        !isLeadershipPosition(perfil.posicao_atual),
    ),
    [filtered, promotedIds],
  );

  const columns = useMemo(
    () => buildCycleColumns(cycleProfiles),
    [cycleProfiles],
  );

  const terminalProfiles = useMemo(
    () => filtered.filter(({ perfil }) =>
      isLeadershipPosition(perfil.posicao_atual) &&
      !promotedIds.has(perfil.id)),
    [filtered, promotedIds],
  );

  return <div className="space-y-5" data-testid="career-progression-board">
    <CareerFiltersBar filters={filters} competences={[...competences].reverse()} options={options} onChange={setFilters} onClear={() => setFilters(defaults(latest))} showSearch />
    <OperationalSummary promoted={countUniqueCareerPromoted(promotions)} promotionRecords={promotions.length} near={columns.meta3.length} monitored={filtered.length} />
    {filtered.length === 0 ? <div role="status" className="rounded-2xl border border-dashed bg-card p-10 text-center"><p className="font-semibold">Nenhum colaborador corresponde aos filtros.</p>
      <Button variant="outline" className="mt-4" onClick={() => setFilters(defaults(latest))}>Limpar filtros</Button></div> :
      <div ref={boardRef} className="mx-auto w-full pb-3" aria-label="Quadro de progressão"><div data-testid="progression-columns" className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-5">
        <CycleColumn title="0/3" description="Ciclo iniciado em junho/2026" items={columns.meta1} progress={0} competence={filters.competence} onOpen={setSelected} />
        <CycleColumn title="1/3" description="Um resultado válido no ciclo" items={columns.meta2} progress={1} competence={filters.competence} onOpen={setSelected} />
        <CycleColumn title="2/3" description="A um resultado válido da promoção" items={columns.meta3} progress={2} competence={filters.competence} onOpen={setSelected} dataColumn="meta3" />
        <PromotionColumn items={promotions} onOpen={setSelected} />
        <LeadershipColumn items={terminalProfiles} competence={filters.competence} onOpen={setSelected} />
      </div></div>}
    <ProfileHistoryDialog item={selected} onClose={() => setSelected(null)} />
  </div>;
}

function LeadershipColumn({ items, competence, onOpen }: { items: PerfilComHistorico[]; competence: string; onOpen: (item: PerfilComHistorico) => void }) {
  return <ColumnShell title="Trilha concluída" description="Evolução para liderança" count={items.length} tone="bg-slate-100" dataColumn="leadership">
    {items.map((item) => {
      const result = item.resultados.find((row) => row.competencia === competence);
      return <PersonCard key={item.perfil.id} item={item} onOpen={onOpen}>
        <div className="flex flex-wrap gap-1.5"><Badge variant={item.perfil.ativo ? "secondary" : "outline"}>{item.perfil.ativo ? "Ativo" : "Inativo"}</Badge>
          <Badge className="bg-slate-200 text-slate-800 hover:bg-slate-200"><CheckCircle2 aria-hidden="true" className="mr-1 h-3.5 w-3.5" />Evolução de função</Badge></div>
        <p className="text-xs font-medium">{item.perfil.posicao_atual}</p>
        <p className="text-xs text-muted-foreground">Trilha comercial encerrada · resultados somente históricos</p>
        <p className="text-xs"><span className="text-muted-foreground">{competence ? formatarCompetencia(competence) : "Competência"}:</span> {result?.meta_alcancada ?? "Sem resultado"}</p>
      </PersonCard>;
    })}
  </ColumnShell>;
}

function OperationalSummary({ promoted, promotionRecords, near, monitored }: { promoted: number; promotionRecords: number; near: number; monitored: number }) {
  const items = [
    { label: "Promovidos no período", value: promoted, support: `${promotionRecords} promoções`, icon: Award },
    { label: "Próximos da promoção", value: near, support: "2/3", icon: Target },
    { label: "Colaboradores monitorados", value: monitored, support: "perfis filtrados", icon: Users },
  ];
  return <section aria-label="Resumo operacional" className="grid overflow-hidden rounded-2xl border bg-card shadow-card md:grid-cols-3">{items.map(({ label, value, support, icon: Icon }) => <div key={label} className="flex items-center gap-4 border-b p-5 last:border-0 md:border-b-0 md:border-r"><div className="rounded-full bg-primary/10 p-3"><Icon aria-hidden="true" className="h-5 w-5 text-primary" /></div>
    <div><p className="text-xs text-muted-foreground">{label}</p><p className="text-2xl font-extrabold">{value}</p><p className="text-xs text-muted-foreground">{support}</p></div></div>)}</section>;
}

function ColumnShell({ title, description, count, tone, dataColumn, children }: { title: string; description: string; count: number; tone: string; dataColumn?: string; children: React.ReactNode }) {
  return <section data-column={dataColumn} className="overflow-hidden rounded-2xl border bg-card shadow-card"><header className={`border-b p-4 ${tone}`}><div className="flex items-center justify-between gap-2"><h2 className="font-display text-base font-bold">{title}</h2><Badge variant="secondary">{count}</Badge></div><p className="mt-1 text-xs text-muted-foreground">{description}</p></header>
    <div className="max-h-[590px] space-y-3 overflow-y-auto p-3">{count === 0 ? <p role="status" className="rounded-xl border border-dashed p-5 text-center text-xs text-muted-foreground">Nenhum colaborador nesta etapa.</p> : children}</div></section>;
}

function CycleColumn({ title, description, items, progress, competence, onOpen, dataColumn }: { title: string; description: string; items: PerfilComHistorico[]; progress: number; competence: string; onOpen: (item: PerfilComHistorico) => void; dataColumn?: string }) {
  const tones = ["bg-blue-50", "bg-purple-50", "bg-violet-100"];
  return <ColumnShell title={title} description={description} count={items.length} tone={tones[progress]} dataColumn={dataColumn}>{items.map((item) => {
    const result = item.resultados.find((row) => row.competencia === competence);
    return <PersonCard key={item.perfil.id} item={item} onOpen={onOpen}><div className="flex flex-wrap gap-1.5"><Badge variant={item.perfil.ativo ? "secondary" : "outline"}>{item.perfil.ativo ? "Ativo" : "Inativo"}</Badge>
      {progress === 2 && <Badge className="bg-amber-100 text-amber-800 hover:bg-amber-100">Próximo da promoção</Badge>}
      {item.perfil.posicao_atual?.trim().toLocaleLowerCase("pt-BR") === "sdr" && (item.perfil.bonificacao_sdr === 30 || item.perfil.bonificacao_sdr === 40) &&
        <Badge className="bg-purple-100 text-purple-800 hover:bg-purple-100">Bonificação: {item.perfil.bonificacao_sdr}%</Badge>}</div>
      <p className="text-xs text-muted-foreground">{squadForCompetence(item, competence) ? formatarSquadAtual(squadForCompetence(item, competence)!) : "Squad não informado"} · {item.perfil.posicao_atual ?? "Posição não informada"}</p>
      <p className="text-xs text-muted-foreground">{item.perfil.senioridade_atual ?? "Senioridade não informada"} · {formatarEtapaProgresso(progress)}</p>
      <p className="text-xs text-muted-foreground">{formatarComposicaoCiclo(item.perfil.progresso_meta3, item.perfil.progresso_meta2 ?? 0, item.perfil.posicao_atual)}</p>
      <p className="text-xs"><span className="text-muted-foreground">{competence ? formatarCompetencia(competence) : "Competência"}:</span> {result?.meta_alcancada ?? "Sem resultado"}</p></PersonCard>;
  })}</ColumnShell>;
}

function PromotionColumn({ items, onOpen }: { items: PromotionView[]; onOpen: (item: PerfilComHistorico) => void }) {
  return <ColumnShell
    title="Promovidos no período"
    description="Registros da competência"
    count={items.length}
    tone="bg-emerald-50"
    dataColumn="promoted"
  >
    {items.map((promotion) => {
      const {
        profile,
        result,
        previousSeniority,
        nextSeniority,
      } = promotion;

      const roleTransition =
        promotion.promotionType === "role_transition";

      const from = roleTransition
        ? promotion.fromPosition ?? "SDR"
        : previousSeniority;

      const to = roleTransition
        ? promotion.toPosition ?? "Closer"
        : nextSeniority;

      return <PersonCard
        key={`${promotion.promotionType}-${result.id}`}
        item={profile}
        onOpen={onOpen}
        accent="green"
      >
        <p className="text-xs text-muted-foreground">
          {result.squad
            ? formatarSquadAtual(result.squad)
            : "Squad não informado"}
          {" · "}
          {profile.perfil.posicao_atual ?? "Posição não informada"}
        </p>

        <p
          className="flex items-center gap-2 text-sm font-semibold text-emerald-700"
          aria-label={`${from} para ${to}`}
        >
          <span>{from}</span>
          <ArrowRight
            aria-hidden="true"
            className="h-4 w-4"
          />
          <span>{to}</span>
        </p>

        <p className="text-xs text-muted-foreground">
          {result.competencia
            ? formatarCompetencia(result.competencia)
            : "Competência não informada"}
        </p>
      </PersonCard>;
    })}
  </ColumnShell>;
}

function PersonCard({ item, onOpen, accent, children }: { item: PerfilComHistorico; onOpen: (item: PerfilComHistorico) => void; accent?: "green"; children: React.ReactNode }) {
  return <Card className={accent === "green" ? "border-emerald-200 bg-emerald-50/40" : "bg-white"}><CardContent className="space-y-2 p-4"><p className="font-semibold leading-snug">{item.perfil.nome_colaborador}</p>{children}
    <Button variant="link" className="h-auto p-0 text-xs" onClick={() => onOpen(item)}><Eye aria-hidden="true" className="mr-1 h-3.5 w-3.5" />Ver histórico</Button></CardContent></Card>;
}
