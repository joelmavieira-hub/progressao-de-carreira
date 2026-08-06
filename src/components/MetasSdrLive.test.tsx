import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { MetasSdrLive } from "./MetasSdrLive";
import type { CareerResultRow } from "@/hooks/useColaboradoresSdrs";

const row: CareerResultRow = {
  id: "result-1", colaborador_id: "person-1", competencia: "2026-01-01",
  origem: "google_sheets_progressao",
  nome_colaborador: "Ana", posicao: "SDR", squad: "LOBO", meta_alcancada: "Meta 3",
  senioridade: "Júnior 1", senioridade_informada: "Júnior 1", recebeu_promocao: false,
  mes_referencia: "Janeiro", created_at: "2026-01-01", updated_at: "2026-01-01",
};

describe("MetasSdrLive", () => {
  it("mostra squad e posição preservados no resultado do mês", () => {
    render(<MetasSdrLive rows={[row]} availableCompetences={["2026-01-01"]} selectedCompetence="2026-01-01"
      onSelectedCompetenceChange={vi.fn()} loading={false} error={null} live={false} lastUpdated={null} onRefresh={vi.fn()} />);
    expect(screen.getByRole("columnheader", { name: "Squad no mês" })).toBeInTheDocument();
    expect(screen.getByRole("cell", { name: "LOBO" })).toBeInTheDocument();
    expect(screen.getByRole("cell", { name: "SDR" })).toBeInTheDocument();
  });
});
