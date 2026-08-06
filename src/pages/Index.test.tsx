import { fireEvent, render, screen, waitFor, within } from "@testing-library/react";
import { MemoryRouter, useLocation, useNavigate } from "react-router-dom";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { TooltipProvider } from "@/components/ui/tooltip";

const state = vi.hoisted(() => {
  const perfil = { id: "p1", nome_colaborador: "Ana", nome_normalizado: "ana", posicao_atual: "SDR", squad_atual: "Lobo",
    senioridade_atual: "Júnior 1", progresso_meta3: 2, ativo: true, created_at: "2026-01-01T00:00:00Z", updated_at: "2026-08-01T00:00:00Z" };
  const resultado = { id: "r1", colaborador_id: "p1", nome_colaborador: "Ana", posicao: "SDR", squad: "Lobo", competencia: "2026-08-01",
    meta_alcancada: "Meta 3", senioridade: "Júnior 1", senioridade_informada: "Júnior 1", recebeu_promocao: true,
    origem: "google_sheets_progressao", mes_referencia: "2026-08-01", created_at: "2026-08-01T00:00:00Z", updated_at: "2026-08-01T00:00:00Z" };
  return { perfil, resultado, refetch: vi.fn(), mode: "loaded" as "loaded" | "loading" | "error" | "empty" };
});

vi.mock("@/features/career-progression/hooks/useCareerProgressionData", () => ({
  useCareerProgressionData: () => ({
    perfis: state.mode === "empty" ? [] : [state.perfil], resultados: state.mode === "empty" ? [] : [state.resultado], perfisComHistorico: state.mode === "empty" ? [] : [{ perfil: state.perfil, resultados: [state.resultado], totalMeta3: 1, totalPromocoes: 1, ultimaCompetencia: "2026-08-01" }],
    resumo: state.mode === "empty" ? { totalPerfis: 0 } : { totalPerfis: 1, ativos: 1, inativos: 0, totalResultados: 1, progresso0: 0, progresso1: 0, progresso2: 1,
      promocoesRegistradas: 1, pessoasPromovidas: 1, competenciaMinima: "2026-08-01", competenciaMaxima: "2026-08-01" },
    isLoading: state.mode === "loading", isFetching: false, error: state.mode === "error" ? new Error("Falha") : null, refetch: state.refetch, lastUpdatedAt: new Date("2026-08-05T20:00:00Z"),
  }),
}));

import Index from "./Index";

const renderAt = (route = "/") => {
  return render(<TooltipProvider><MemoryRouter initialEntries={[route]}><Index /><NavigationTestHarness /></MemoryRouter></TooltipProvider>);
};

function NavigationTestHarness() {
  const location = useLocation();
  const navigate = useNavigate();
  return <><output aria-label="Rota atual">{location.pathname}</output><button type="button" onClick={() => navigate(-1)}>Voltar no histórico</button></>;
}

describe("Index", () => {
  beforeEach(() => { state.refetch.mockClear(); state.mode = "loaded"; });

  it("preserva o cabeçalho e exibe somente Dashboard e Progressão", () => {
    renderAt();
    expect(screen.getByRole("heading", { level: 1, name: "Progressão de Carreira" })).toBeInTheDocument();
    const navigation = screen.getByRole("tablist", { name: "Navegação principal" });
    expect(within(navigation).getAllByRole("tab")).toHaveLength(2);
    expect(within(navigation).getByRole("tab", { name: "Dashboard" })).toHaveAttribute("aria-selected", "true");
    expect(within(navigation).getByRole("tab", { name: "Progressão" })).toBeInTheDocument();
    expect(within(navigation).queryByText("Banco de Dados")).not.toBeInTheDocument();
    expect(within(navigation).queryByText("Promoções")).not.toBeInTheDocument();
    expect(screen.queryByText("Avisos")).not.toBeInTheDocument();
    expect(screen.queryByText("Login")).not.toBeInTheDocument();
  });

  it("monta o Dashboard real com card Banco de Dados, métricas, gráficos e listas", () => {
    renderAt();
    expect(screen.getByTestId("database-summary-card")).toContainElement(screen.getByRole("button", { name: "Atualizar dados" }));
    expect(screen.getByText("Colaboradores ativos")).toBeInTheDocument();
    expect(screen.getByText("Cobertura da competência")).toBeInTheDocument();
    expect(screen.getByTestId("cycle-distribution-chart")).toBeInTheDocument();
    expect(screen.getByTestId("seniority-distribution-chart")).toBeInTheDocument();
    expect(screen.getByTestId("monthly-goals-chart")).toBeInTheDocument();
    expect(screen.getByTestId("promotions-by-competence-chart")).toBeInTheDocument();
    expect(screen.getByTestId("squad-progress-chart")).toBeInTheDocument();
    expect(screen.getByTestId("near-promotion-list")).toBeInTheDocument();
    expect(screen.getByTestId("recent-promotions-list")).toBeInTheDocument();
    expect(screen.queryByText("Pontos de atenção")).not.toBeInTheDocument();
    const cycle = screen.getByTestId("cycle-distribution-chart");
    const seniority = screen.getByTestId("seniority-distribution-chart");
    const promotions = screen.getByTestId("promotions-by-competence-chart");
    expect(cycle).toHaveAttribute("data-primary-color", "#7c3aed");
    expect(seniority).toHaveAttribute("data-primary-color", "#7c3aed");
    expect(promotions).toHaveAttribute("data-primary-color", "#7c3aed");
    const monthly = screen.getByTestId("monthly-goals-chart");
    const monthlyLegend = within(monthly).getByLabelText("Legenda evolução mensal");
    expect(within(monthlyLegend).getByText("Meta 1")).toBeInTheDocument();
    expect(within(monthlyLegend).getByText("Meta 2")).toBeInTheDocument();
    expect(within(monthlyLegend).getByText("Meta 3")).toBeInTheDocument();
    expect(within(monthlyLegend).getByText("Nenhuma meta")).toBeInTheDocument();
    expect(within(monthly).queryByText("Sem presença")).not.toBeInTheDocument();
    expect(screen.getByText(/sem presença/)).toBeInTheDocument();
  });

  it("monta a Progressão com quatro colunas calculadas e sem Atualizar", () => {
    const { container } = renderAt("/progressao");
    expect(screen.getByRole("tab", { name: "Progressão" })).toHaveAttribute("aria-selected", "true");
    expect(screen.getByRole("heading", { name: "0/3" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "1/3" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "2/3" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Promovidos no período" })).toBeInTheDocument();
    expect(screen.queryByRole("heading", { name: "Pontos de atenção" })).not.toBeInTheDocument();
    expect(screen.queryByText("Em atenção")).not.toBeInTheDocument();
    expect(screen.getAllByRole("heading", { level: 2 })).toHaveLength(4);
    expect(screen.queryByRole("button", { name: "Atualizar dados" })).not.toBeInTheDocument();
    expect(container.querySelector("[draggable='true']")).not.toBeInTheDocument();
  });

  it("navega entre as rotas sem tela branca e respeita o histórico", async () => {
    renderAt();
    fireEvent.click(screen.getByRole("tab", { name: "Progressão" }));
    await waitFor(() => expect(screen.getByLabelText("Rota atual")).toHaveTextContent("/progressao"));
    expect(screen.getByTestId("career-progression-board")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("tab", { name: "Dashboard" }));
    await waitFor(() => expect(screen.getByLabelText("Rota atual")).toHaveTextContent("/"));
    expect(screen.getByTestId("career-dashboard")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Voltar no histórico" }));
    await waitFor(() => expect(screen.getByLabelText("Rota atual")).toHaveTextContent("/progressao"));
    expect(screen.getByTestId("career-progression-board")).toBeInTheDocument();
  });

  it("apresenta estados de loading, erro e banco vazio", () => {
    state.mode = "loading";
    const loading = renderAt();
    expect(screen.getByRole("status", { name: "Carregando dados" })).toBeInTheDocument();
    loading.unmount();
    state.mode = "error";
    const error = renderAt();
    expect(screen.getByText("Não foi possível carregar os dados")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Atualizar dados" })).toBeInTheDocument();
    error.unmount();
    state.mode = "empty";
    renderAt();
    expect(screen.getByText("O banco ainda não possui perfis")).toBeInTheDocument();
  });
});
