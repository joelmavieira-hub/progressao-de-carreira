import { useMemo, useState } from "react";
import { AlertCircle, Radio, RefreshCw, Search } from "lucide-react";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { formatCompetence, GOAL_LABEL, normalizeGoal, normalizeSeniority } from "@/lib/progression";
import { normalizeSquad, type CareerResultRow } from "@/hooks/useColaboradoresSdrs";

interface MetasSdrLiveProps {
  rows: CareerResultRow[];
  availableCompetences: string[];
  selectedCompetence: string;
  onSelectedCompetenceChange: (value: string) => void;
  loading: boolean;
  error: string | null;
  live: boolean;
  lastUpdated: Date | null;
  onRefresh: () => void;
}

export function MetasSdrLive({
  rows, availableCompetences, selectedCompetence, onSelectedCompetenceChange,
  loading, error, live, lastUpdated, onRefresh,
}: MetasSdrLiveProps) {
  const [selectedSquad, setSelectedSquad] = useState("all");
  const [search, setSearch] = useState("");
  const squads = useMemo(() => Array.from(new Set(rows.map((row) => normalizeSquad(row.squad)).filter(Boolean))).sort(), [rows]);
  const filtered = useMemo(() => rows
    .filter((row) => !selectedCompetence || row.competencia === selectedCompetence)
    .filter((row) => selectedSquad === "all" || normalizeSquad(row.squad) === selectedSquad)
    .filter((row) => !search.trim() || (row.nome_colaborador ?? "").toLocaleLowerCase("pt-BR").includes(search.trim().toLocaleLowerCase("pt-BR")))
    .sort((a, b) => (a.nome_colaborador ?? "").localeCompare(b.nome_colaborador ?? "", "pt-BR", { sensitivity: "base" })),
  [rows, search, selectedCompetence, selectedSquad]);

  return (
    <section className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex flex-wrap items-center gap-3">
          <Select value={selectedCompetence} onValueChange={onSelectedCompetenceChange}>
            <SelectTrigger className="h-8 w-[180px] text-xs"><SelectValue placeholder="Competência" /></SelectTrigger>
            <SelectContent>{availableCompetences.map((value) => <SelectItem key={value} value={value}>{formatCompetence(value)}</SelectItem>)}</SelectContent>
          </Select>
          <Select value={selectedSquad} onValueChange={setSelectedSquad}>
            <SelectTrigger className="h-8 w-[160px] text-xs"><SelectValue placeholder="Squad" /></SelectTrigger>
            <SelectContent><SelectItem value="all">Todos os squads</SelectItem>{squads.map((squad) => <SelectItem key={squad} value={squad}>{squad}</SelectItem>)}</SelectContent>
          </Select>
          <div className="relative">
            <Search className="pointer-events-none absolute left-2 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-muted-foreground" />
            <Input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Buscar colaborador..." className="h-8 w-[220px] pl-7 text-xs" />
          </div>
        </div>
        <div className="flex items-center gap-3 text-xs">
          {lastUpdated && <span className="text-muted-foreground">Atualizado {lastUpdated.toLocaleTimeString("pt-BR")}</span>}
          <span className={live ? "font-semibold text-primary" : "text-muted-foreground"}><Radio className="mr-1 inline h-4 w-4" />{live ? "LIVE" : "Offline"}</span>
          <Button size="sm" variant="outline" className="h-8 gap-1.5" onClick={onRefresh}><RefreshCw className="h-3.5 w-3.5" />Atualizar</Button>
        </div>
      </div>
      {error && <div role="alert" className="flex gap-2 rounded-lg border border-destructive/30 p-3 text-sm text-destructive"><AlertCircle className="h-4 w-4" />{error}</div>}
      {loading ? <div role="status" className="p-8 text-center text-sm text-muted-foreground">Carregando…</div> : (
        <div className="rounded-lg border border-border bg-card shadow-card">
          <Table>
            <TableHeader><TableRow>
              <TableHead>Colaborador</TableHead><TableHead>Squad no mês</TableHead><TableHead>Posição</TableHead><TableHead>Senioridade no mês</TableHead>
              <TableHead>Competência</TableHead><TableHead>Meta</TableHead><TableHead>Promoção</TableHead>
            </TableRow></TableHeader>
            <TableBody>{filtered.map((row) => {
              const goal = normalizeGoal(row.meta_alcancada);
              return <TableRow key={row.id}>
                <TableCell className="text-xs font-medium">{row.nome_colaborador ?? "—"}</TableCell>
                <TableCell className="text-xs">{normalizeSquad(row.squad) || "—"}</TableCell>
                <TableCell className="text-xs">{row.posicao ?? "—"}</TableCell>
                <TableCell className="text-xs">{normalizeSeniority(row.senioridade) ?? <Badge variant="destructive">Inválida</Badge>}</TableCell>
                <TableCell className="text-xs">{row.competencia ? formatCompetence(row.competencia) : <Badge variant="outline">Pendente</Badge>}</TableCell>
                <TableCell className="text-xs">{goal ? <Badge variant="outline">{GOAL_LABEL[goal]}</Badge> : <Badge variant="destructive">Valor inválido</Badge>}</TableCell>
                <TableCell className="text-xs">{row.recebeu_promocao ? <Badge className="bg-emerald-600 text-white">Sim</Badge> : "—"}</TableCell>
              </TableRow>;
            })}</TableBody>
          </Table>
          {!loading && filtered.length === 0 && <p className="p-8 text-center text-sm text-muted-foreground">Nenhum registro encontrado.</p>}
        </div>
      )}
    </section>
  );
}
