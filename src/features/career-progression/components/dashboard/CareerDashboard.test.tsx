import { fireEvent, render, screen, within } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { TooltipProvider } from "@/components/ui/tooltip";
import { relacionarPerfisEResultados } from "../../domain";
import type { ColaboradorPerfil, ColaboradorResultado } from "../../types";
import { CareerDashboard } from "./CareerDashboard";

const profile = (id: string, name: string, active: boolean): ColaboradorPerfil => ({ id, nome_colaborador: name, nome_normalizado: name.toLowerCase(),
  posicao_atual: "SDR", squad_atual: active ? "Lobo" : "Saiu", senioridade_atual: "Júnior 1", progresso_meta3: 2, ativo: active,
  created_at: "2026-01-01T00:00:00Z", updated_at: "2026-08-01T00:00:00Z" });
const result = (id: string, collaboratorId: string, goal: string): ColaboradorResultado => ({ id, colaborador_id: collaboratorId, nome_colaborador: null,
  posicao: "SDR", squad: "Lobo", competencia: "2026-08-01", meta_alcancada: goal, senioridade: "Júnior 1", senioridade_informada: "Júnior 1",
  recebeu_promocao: false, origem: "google_sheets_progressao", mes_referencia: "2026-08-01", created_at: "2026-08-01T00:00:00Z", updated_at: "2026-08-01T00:00:00Z" });

describe("CareerDashboard", () => {
  it("aplica filtros e Limpar filtros restaura Ativos", () => {
    const perfis = [profile("1", "Ana Ativa", true), profile("2", "Bia Inativa", false)];
    const resultados = [result("r1", "1", "Meta 3"), result("r2", "2", "Sem presença")];
    render(<TooltipProvider><CareerDashboard perfis={perfis} resultados={resultados} perfisComHistorico={relacionarPerfisEResultados(perfis, resultados)}
      isFetching={false} lastUpdatedAt={null} onRefresh={vi.fn()} onNavigate={vi.fn()} initialFilters={{ status: "inativos" }} /></TooltipProvider>);
    expect(screen.getByText("Bia Inativa")).toBeInTheDocument();
    expect(screen.queryByText("Ana Ativa")).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Limpar filtros" }));
    expect(screen.getByText("Ana Ativa")).toBeInTheDocument();
  });

  it("mantém Sem presença na cobertura e fora da evolução mensal", () => {
    const perfis = [profile("1", "Ana", true)];
    const resultados = [result("r1", "1", "Sem presença")];
    render(<TooltipProvider><CareerDashboard perfis={perfis} resultados={resultados} perfisComHistorico={relacionarPerfisEResultados(perfis, resultados)}
      isFetching={false} lastUpdatedAt={null} onRefresh={vi.fn()} onNavigate={vi.fn()} /></TooltipProvider>);
    expect(screen.getByTestId("coverage-card")).toHaveTextContent("1 sem presença");
    const monthly = screen.getByTestId("monthly-goals-chart");
    expect(within(monthly).queryByText("Sem presença")).not.toBeInTheDocument();
    expect(within(monthly).getByText("Nenhuma meta")).toBeInTheDocument();
  });

  it("mantém somente os dois painéis responsivos e suas ações", () => {
    const perfis = [profile("1", "Ana", true)];
    const resultados = [{ ...result("r1", "1", "Meta 3"), recebeu_promocao: true }];
    const onNavigate = vi.fn();
    render(<TooltipProvider><CareerDashboard perfis={perfis} resultados={resultados} perfisComHistorico={relacionarPerfisEResultados(perfis, resultados)}
      isFetching={false} lastUpdatedAt={null} onRefresh={vi.fn()} onNavigate={onNavigate} /></TooltipProvider>);
    const panels = screen.getByRole("region", { name: "Painéis de acompanhamento" });
    expect(panels.children).toHaveLength(2);
    expect(panels).toHaveClass("grid-cols-1", "md:grid-cols-2");
    expect(screen.getByTestId("near-promotion-list")).toHaveTextContent("Ana");
    expect(screen.getByTestId("recent-promotions-list")).toHaveTextContent("Ana");
    expect(screen.queryByText("Pontos de atenção")).not.toBeInTheDocument();
    const actions = screen.getAllByRole("button", { name: /Ver todos/ });
    expect(actions).toHaveLength(2);
    fireEvent.click(actions[0]);
    fireEvent.click(actions[1]);
    expect(onNavigate).toHaveBeenNthCalledWith(1, "meta3");
    expect(onNavigate).toHaveBeenNthCalledWith(2, "promoted");
  });
});
