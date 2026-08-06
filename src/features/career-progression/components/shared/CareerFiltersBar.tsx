import { Search, SlidersHorizontal } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { formatarCompetencia } from "@/lib/progression";
import { SENIORITY_ORDER, type AnalyticsFilters } from "../../domain/analytics";
import type { CareerProgressionFilterOptions } from "../../types";

interface CareerFiltersBarProps {
  filters: AnalyticsFilters;
  competences: string[];
  options: CareerProgressionFilterOptions;
  onChange: (filters: AnalyticsFilters) => void;
  onClear: () => void;
  showSearch?: boolean;
}

export function CareerFiltersBar({ filters, competences, options, onChange, onClear, showSearch = false }: CareerFiltersBarProps) {
  const set = (key: keyof AnalyticsFilters, value: string) => onChange({ ...filters, [key]: value });
  return <section aria-label="Filtros" className="rounded-2xl border bg-card p-4 shadow-card">
    <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3 xl:flex xl:items-end">
      <FilterSelect label="Competência" value={filters.competence} onChange={(value) => set("competence", value)}
        options={competences.map((value) => ({ value, label: formatarCompetencia(value) }))} />
      <FilterSelect label="Status" value={filters.status} onChange={(value) => set("status", value)} options={[
        { value: "ativos", label: "Ativos" }, { value: "inativos", label: "Inativos" }, { value: "todos", label: "Todos" },
      ]} />
      <FilterSelect label="Squad" value={filters.squad} onChange={(value) => set("squad", value)}
        options={[{ value: "todos", label: "Todos" }, ...options.squads.map((value) => ({ value, label: value }))]} />
      <FilterSelect label="Posição" value={filters.position} onChange={(value) => set("position", value)}
        options={[{ value: "todos", label: "Todas" }, ...options.posicoes.map((value) => ({ value, label: value }))]} />
      <FilterSelect label="Senioridade" value={filters.seniority} onChange={(value) => set("seniority", value)} options={[
        { value: "todos", label: "Todas" }, ...SENIORITY_ORDER.map((value) => ({ value, label: value })),
      ]} />
      {showSearch && <div className="min-w-52 flex-1 space-y-1.5"><Label htmlFor="career-search">Buscar colaborador</Label>
        <div className="relative"><Search aria-hidden="true" className="absolute left-3 top-2.5 h-4 w-4 text-muted-foreground" />
          <Input id="career-search" value={filters.search} onChange={(event) => set("search", event.target.value)} className="pl-9" placeholder="Nome do colaborador" /></div></div>}
      <Button type="button" variant="outline" onClick={onClear} className="gap-2"><SlidersHorizontal aria-hidden="true" className="h-4 w-4" />Limpar filtros</Button>
    </div>
  </section>;
}

function FilterSelect({ label, value, options, onChange }: { label: string; value: string; options: Array<{ value: string; label: string }>; onChange: (value: string) => void }) {
  const id = `filter-${label.toLocaleLowerCase("pt-BR").normalize("NFD").replace(/[^a-z]/g, "")}`;
  return <div className="min-w-36 flex-1 space-y-1.5"><Label htmlFor={id}>{label}</Label>
    <Select value={value} onValueChange={onChange}><SelectTrigger id={id} aria-label={label}><SelectValue /></SelectTrigger>
      <SelectContent>{options.map((option) => <SelectItem key={option.value} value={option.value}>{option.label}</SelectItem>)}</SelectContent>
    </Select></div>;
}
