import { describe, expect, it } from "vitest";
import { buildCareerData, type CareerProfileRow, type CareerResultRow } from "./useColaboradoresSdrs";

const profile: CareerProfileRow = {
  id: "person-1", nome_colaborador: "Gabriel Barbosa", nome_normalizado: "gabriel barbosa",
  posicao_atual: "Closer", squad_atual: "ÁGUIA", senioridade_atual: "Júnior 1",
  progresso_meta3: 2, ativo: true, created_at: "2026-01-01", updated_at: "2026-03-01",
};

const result = (id: string, competencia: string, squad: string, posicao: string, meta: string): CareerResultRow => ({
  id, colaborador_id: profile.id, competencia, nome_colaborador: profile.nome_colaborador,
  origem: "google_sheets_progressao",
  posicao, squad, meta_alcancada: meta, senioridade: "Júnior 1", senioridade_informada: "Júnior 1",
  recebeu_promocao: false, mes_referencia: competencia, created_at: competencia, updated_at: competencia,
});

describe("buildCareerData", () => {
  it("usa perfil como estado atual e preserva squad/posição do histórico", () => {
    const data = buildCareerData([
      result("jan", "2026-01-01", "LOBO", "SDR", "Meta 3"),
      result("mar", "2026-03-01", "ÁGUIA", "Closer", "Meta 3"),
    ], [profile]);
    expect(data.sdrs).toHaveLength(1);
    expect(data.sdrs[0]).toMatchObject({ squad: "ÁGUIA", position: "Closer", currentProgress: 2 });
    expect(data.sdrs[0].history.map(({ squad, position }) => [squad, position])).toEqual([
      ["LOBO", "SDR"], ["ÁGUIA", "Closer"],
    ]);
  });

  it("aceita meta vazia como Sem presença e não gera issue", () => {
    const data = buildCareerData([result("jan", "2026-01-01", "LOBO", "SDR", "")], [profile]);
    expect(data.issues).toEqual([]);
    expect(data.sdrs[0].history[0].goal).toBe("absent");
  });
});
