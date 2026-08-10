import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { relacionarPerfisEResultados } from "../../domain";
import type { ColaboradorPerfil, ColaboradorResultado } from "../../types";
import { CareerProgressionBoard } from "./CareerProgressionBoard";

const profile = (id: string, name: string, progress: number): ColaboradorPerfil => ({ id, nome_colaborador: name, nome_normalizado: name.toLocaleLowerCase("pt-BR"),
  posicao_atual: "SDR", squad_atual: "Lobo", senioridade_atual: "Júnior 1", progresso_meta3: progress, ativo: true,
  created_at: "2026-01-01T00:00:00Z", updated_at: "2026-08-01T00:00:00Z" });
const result = (id: string, collaboratorId: string, promoted = false): ColaboradorResultado => ({ id, colaborador_id: collaboratorId, nome_colaborador: null,
  posicao: "SDR", squad: "Lobo", competencia: "2026-08-01", meta_alcancada: "Meta 3", senioridade: "Júnior 1", senioridade_informada: null,
  recebeu_promocao: promoted, origem: "google_sheets_progressao", mes_referencia: "2026-08-01", created_at: "2026-08-01T00:00:00Z", updated_at: "2026-08-01T00:00:00Z" });

describe("CareerProgressionBoard", () => {
  it("filtra busca sem acento, limpa filtros e abre o histórico", () => {
    const perfis = [profile("1", "José Álvaro", 0), profile("2", "Beatriz Lima", 1)];
    const resultados = [result("r1", "1"), result("r2", "2")];
    render(<CareerProgressionBoard perfis={perfis} resultados={resultados} perfisComHistorico={relacionarPerfisEResultados(perfis, resultados)} />);
    fireEvent.change(screen.getByLabelText("Buscar colaborador"), { target: { value: "  jose   alvaro " } });
    expect(screen.getByText("José Álvaro")).toBeInTheDocument();
    expect(screen.queryByText("Beatriz Lima")).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Limpar filtros" }));
    expect(screen.getByText("Beatriz Lima")).toBeInTheDocument();
    fireEvent.click(screen.getAllByRole("button", { name: "Ver histórico" })[0]);
    expect(screen.getByRole("dialog")).toBeInTheDocument();
    expect(screen.getByText("Não informada")).toBeInTheDocument();
  });

  it("anuncia colunas vazias sem criar elementos arrastáveis", () => {
    const perfis = [profile("1", "Ana", 0)];
    const { container } = render(<CareerProgressionBoard perfis={perfis} resultados={[]} perfisComHistorico={relacionarPerfisEResultados(perfis, [])} />);
    expect(screen.getAllByText("Nenhum colaborador nesta etapa.").length).toBeGreaterThanOrEqual(3);
    expect(container.querySelector("[draggable='true']")).toBeNull();
  });

  it("renderiza somente quatro colunas responsivas e três indicadores operacionais", () => {
    const perfis = [profile("1", "Ana", 0), profile("2", "Bia", 1), profile("3", "Carla", 2)];
    const resultados = [result("r1", "1", true), result("r2", "2"), result("r3", "3")];
    const { container } = render(<CareerProgressionBoard perfis={perfis} resultados={resultados} perfisComHistorico={relacionarPerfisEResultados(perfis, resultados)} />);
    const columns = screen.getByTestId("progression-columns");
    expect(columns.children).toHaveLength(4);
    expect(columns).toHaveClass("grid-cols-1", "md:grid-cols-2", "xl:grid-cols-4");
    expect(screen.getByRole("heading", { name: "0/3" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "1/3" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "2/3" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Promovidos no período" })).toBeInTheDocument();
    expect(screen.queryByText("Pontos de atenção")).not.toBeInTheDocument();
    expect(screen.queryByText("Em atenção")).not.toBeInTheDocument();
    expect(screen.getByRole("region", { name: "Resumo operacional" }).children).toHaveLength(3);
    expect(container.querySelector("[draggable='true']")).toBeNull();
  });
  it("mantém SDR -> Closer somente em Promovidos no período", () => {
    const miguel = {
      ...profile(
        "miguel",
        "Miguel Carneiro Nunes",
        1,
      ),
      posicao_atual: "Closer",
      squad_atual: "Urso",
    };

    const junho = {
      ...result(
        "miguel-jun",
        "miguel",
      ),
      competencia: "2026-06-01",
      mes_referencia: "2026-06-01",
      posicao: "SDR",
      squad: "Urso",
      meta_alcancada: "Meta 1",
      senioridade: "Júnior 1",
      senioridade_informada: "Júnior 1",
      recebeu_promocao: false,
      created_at: "2026-06-01T00:00:00Z",
      updated_at: "2026-06-01T00:00:00Z",
    };

    const julho = {
      ...result(
        "miguel-jul",
        "miguel",
      ),
      competencia: "2026-07-01",
      mes_referencia: "2026-07-01",
      posicao: "Closer",
      squad: "Urso",
      meta_alcancada: "Meta 3",
      senioridade: "Júnior 1",
      senioridade_informada: "Júnior 1",
      recebeu_promocao: false,
      created_at: "2026-07-01T00:00:00Z",
      updated_at: "2026-07-01T00:00:00Z",
    };

    const perfis = [miguel];
    const resultados = [junho, julho];

    render(
      <CareerProgressionBoard
        perfis={perfis}
        resultados={resultados}
        perfisComHistorico={relacionarPerfisEResultados(
          perfis,
          resultados,
        )}
      />,
    );

    const zeroThirdColumn = screen
      .getByRole("heading", { name: "0/3" })
      .closest("section");

    const oneThirdColumn = screen
      .getByRole("heading", { name: "1/3" })
      .closest("section");

    const twoThirdColumn = screen
      .getByRole("heading", { name: "2/3" })
      .closest("section");

    const promotedColumn = screen
      .getByRole("heading", {
        name: "Promovidos no período",
      })
      .closest("section");

    if (
      !zeroThirdColumn ||
      !oneThirdColumn ||
      !twoThirdColumn ||
      !promotedColumn
    ) {
      throw new Error(
        "Colunas da Progressão não encontradas.",
      );
    }

    expect(zeroThirdColumn)
      .not.toHaveTextContent("Miguel Carneiro Nunes");

    expect(oneThirdColumn)
      .not.toHaveTextContent("Miguel Carneiro Nunes");

    expect(twoThirdColumn)
      .not.toHaveTextContent("Miguel Carneiro Nunes");

    expect(promotedColumn)
      .toHaveTextContent("Miguel Carneiro Nunes");

    expect(promotedColumn)
      .toHaveTextContent("SDR");

    expect(promotedColumn)
      .toHaveTextContent("Closer");

    expect(promotedColumn)
      .not.toHaveTextContent("Júnior 1 → Júnior 1");
  });
});
