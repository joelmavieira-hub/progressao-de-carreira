import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { relacionarPerfisEResultados } from "../../domain";
import type { CareerProgressionEvent, ColaboradorPerfil, ColaboradorResultado } from "../../types";
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

  it("renderiza cinco colunas responsivas e três indicadores operacionais", () => {
    const perfis = [profile("1", "Ana", 0), profile("2", "Bia", 1), profile("3", "Carla", 2)];
    const resultados = [result("r1", "1", true), result("r2", "2"), result("r3", "3")];
    const { container } = render(<CareerProgressionBoard perfis={perfis} resultados={resultados} perfisComHistorico={relacionarPerfisEResultados(perfis, resultados)} />);
    const columns = screen.getByTestId("progression-columns");
    expect(columns.children).toHaveLength(5);
    expect(columns).toHaveClass("grid-cols-1", "md:grid-cols-2", "xl:grid-cols-5");
    expect(screen.getByRole("heading", { name: "0/3" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "1/3" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "2/3" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Promovidos no período" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Trilha concluída" })).toBeInTheDocument();
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
  it("mantém junho/julho no squad histórico quando o squad atual muda em agosto", () => {
    const ana = {
      ...profile(
        "ana-historico",
        "Ana Histórico",
        1,
      ),
      squad_atual: "Gorila",
    };

    const junho = {
      ...result(
        "ana-jun",
        "ana-historico",
      ),
      competencia: "2026-06-01",
      mes_referencia: "2026-06-01",
      squad: "Urso",
      recebeu_promocao: false,
      created_at: "2026-06-01T00:00:00Z",
      updated_at: "2026-06-01T00:00:00Z",
    };
    const julho = { ...junho, id: "ana-jul", competencia: "2026-07-01", mes_referencia: "2026-07-01", created_at: "2026-07-01T00:00:00Z", updated_at: "2026-07-01T00:00:00Z" };
    const agosto = { ...junho, id: "ana-ago", competencia: "2026-08-01", mes_referencia: "2026-08-01", squad: "Gorila", created_at: "2026-08-01T00:00:00Z", updated_at: "2026-08-01T00:00:00Z" };

    render(
      <CareerProgressionBoard
        perfis={[ana]}
        resultados={[junho, julho, agosto]}
        perfisComHistorico={relacionarPerfisEResultados(
          [ana],
          [junho, julho, agosto],
        )}
      />,
    );

    expect(
      screen.getByText("Gorila · SDR"),
    ).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Ver histórico" }));
    expect(screen.getAllByText("Urso")).toHaveLength(2);
    expect(screen.getByText("Gorila")).toBeInTheDocument();
  });
  it("mantém liderança fora de 0/3, 1/3 e 2/3", () => {
    const leader = {
      ...profile("lider", "Marcos Líder", 0),
      posicao_atual: "Liderança de SDRs",
      progresso_ciclo: 0,
      bonificacao_sdr: 0,
      streak_meta3_bonificacao: 0,
    };
    const julho = { ...result("lider-jul", "lider"), competencia: "2026-07-01", mes_referencia: "2026-07", posicao: "SDR" };
    const agosto = { ...result("lider-ago", "lider"), posicao: "Liderança de SDRs" };
    const setembro = { ...result("lider-set", "lider"), competencia: "2026-09-01", mes_referencia: "2026-09", posicao: "Liderança de SDRs", meta_alcancada: "Meta 2" };
    const event: CareerProgressionEvent = { id: "event-lider", colaborador_id: "lider", competencia: "2026-08-01", event_type: "role_promotion", senioridade: "Júnior 1", recebeu_promocao: false, created_at: "2026-08-01T00:00:00Z" };
    const results = [julho, agosto, setembro];
    render(<CareerProgressionBoard perfis={[leader]} resultados={results} perfisComHistorico={relacionarPerfisEResultados([leader], results, [event])} />);
    const terminal = screen.getByRole("heading", { name: "Trilha concluída" }).closest("section");
    expect(terminal).toHaveTextContent("Marcos Líder");
    expect(terminal).toHaveTextContent("Evolução de função");
    expect(terminal).not.toHaveTextContent("0/3");
    expect(terminal).not.toHaveTextContent("Bonificação:");
    fireEvent.click(screen.getByRole("button", { name: "Ver histórico" }));
    expect(screen.getByText(/Promoção de função · SDR → Liderança de SDRs/)).toBeInTheDocument();
    expect(screen.getAllByText("Somente histórico")).toHaveLength(2);
  });
  it("renderiza bonificação roxa somente para SDR com 30% ou 40% e preserva os demais badges", () => {
    const sdr40 = { ...profile("sdr40", "SDR Quarenta", 2), progresso_ciclo: 2, progresso_meta2: 1, progresso_meta3: 1, bonificacao_sdr: 40 };
    const sdr30 = { ...profile("sdr30", "SDR Trinta", 1), progresso_ciclo: 1, progresso_meta2: 0, bonificacao_sdr: 30 };
    const sdr0 = { ...profile("sdr0", "SDR Zero", 0), progresso_ciclo: 0, bonificacao_sdr: 0 };
    const closer = { ...profile("closer", "Closer Quarenta", 0), posicao_atual: "Closer", progresso_ciclo: 0, bonificacao_sdr: 40 };
    const perfis = [sdr40, sdr30, sdr0, closer];
    const resultados = perfis.map((item) => ({ ...result(`r-${item.id}`, item.id), posicao: item.posicao_atual }));
    render(<CareerProgressionBoard perfis={perfis} resultados={resultados} perfisComHistorico={relacionarPerfisEResultados(perfis, resultados)} />);

    const badge40 = screen.getByText("Bonificação: 40%");
    const badge30 = screen.getByText("Bonificação: 30%");
    expect(badge40).toHaveClass("bg-purple-100", "text-purple-800");
    expect(badge30).toHaveClass("bg-purple-100", "text-purple-800");
    expect(screen.getByText("SDR Quarenta").closest(".bg-white")).toHaveTextContent("AtivoPróximo da promoçãoBonificação: 40%");
    expect(screen.getByText("SDR Zero").closest(".bg-white")).not.toHaveTextContent("Bonificação:");
    expect(screen.getByText("Closer Quarenta").closest(".bg-white")).not.toHaveTextContent("Bonificação:");
  });

  it("usa somente o streak M3 do backend para composição e proximidade de Closer", () => {
    const closer = {
      ...profile("closer-streak", "Closer Streak", 1),
      posicao_atual: "Closer",
      progresso_meta3: 1,
      progresso_meta2: 1,
      progresso_ciclo: 2,
    };
    const resultados = [{ ...result("r-closer-streak", closer.id), posicao: "Closer" }];
    render(<CareerProgressionBoard perfis={[closer]} resultados={resultados} perfisComHistorico={relacionarPerfisEResultados([closer], resultados)} />);

    const card = screen.getByText("Closer Streak").closest(".bg-white");
    expect(card).toHaveTextContent("1/3");
    expect(card).toHaveTextContent("1 Meta 3");
    expect(card).not.toHaveTextContent("Meta 2");
    expect(card).not.toHaveTextContent("Próximo da promoção");
  });
});
