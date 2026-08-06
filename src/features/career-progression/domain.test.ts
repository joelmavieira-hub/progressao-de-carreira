import { describe, expect, it } from "vitest";
import {
  CareerDataIntegrityError, calcularResumo, derivarOpcoesDeFiltro, filtrarPerfis, formatarSquadAtual, relacionarPerfisEResultados,
} from "./domain";
import type { CareerProgressionFilters, ColaboradorPerfil, ColaboradorResultado } from "./types";

const profile = (overrides: Partial<ColaboradorPerfil> = {}): ColaboradorPerfil => ({
  id: "p1", nome_colaborador: "Álvaro da Silva", nome_normalizado: "álvaro da silva", posicao_atual: "SDR",
  squad_atual: "Lobo", senioridade_atual: "Júnior 1", progresso_meta3: 1, ativo: true,
  created_at: "2026-01-01T00:00:00Z", updated_at: "2026-01-01T00:00:00Z", ...overrides,
});
const result = (competencia: string, overrides: Partial<ColaboradorResultado> = {}): ColaboradorResultado => ({
  id: `r-${competencia}`, colaborador_id: "p1", nome_colaborador: "Álvaro da Silva", posicao: "SDR", squad: "Lobo",
  competencia, meta_alcancada: "Meta 3", senioridade: "Júnior 1", senioridade_informada: "Júnior 1",
  recebeu_promocao: false, origem: "google_sheets_progressao", mes_referencia: competencia,
  created_at: "2026-01-01T00:00:00Z", updated_at: "2026-01-01T00:00:00Z", ...overrides,
});
const filters = (overrides: Partial<CareerProgressionFilters> = {}): CareerProgressionFilters => ({
  busca: "", status: "todos", squad: "todos", posicao: "todos", senioridade: "todos", progresso: "todos", ...overrides,
});

describe("dados puros de progressão", () => {
  it("relaciona perfis e resultados por colaborador_id", () => {
    expect(relacionarPerfisEResultados([profile()], [result("2026-01-01")])[0].resultados).toHaveLength(1);
  });
  it("ordena o histórico cronologicamente", () => {
    const rows = relacionarPerfisEResultados([profile()], [result("2026-03-01"), result("2026-01-01")]);
    expect(rows[0].resultados.map((row) => row.competencia)).toEqual(["2026-01-01", "2026-03-01"]);
  });
  it("identifica resultado órfão", () => {
    expect(() => relacionarPerfisEResultados([profile()], [result("2026-01-01", { colaborador_id: "outro" })]))
      .toThrow(CareerDataIntegrityError);
  });
  it("identifica competência duplicada", () => {
    expect(() => relacionarPerfisEResultados([profile()], [result("2026-01-01"), result("2026-01-01", { id: "r2" })]))
      .toThrow(CareerDataIntegrityError);
  });
  it("calcula o resumo do dashboard sem hardcode", () => {
    const summary = calcularResumo([profile(), profile({ id: "p2", nome_normalizado: "bia", ativo: false, progresso_meta3: 2 })], [
      result("2026-01-01", { recebeu_promocao: true }), result("2026-02-01"),
    ]);
    expect(summary).toMatchObject({ totalPerfis: 2, ativos: 1, inativos: 1, totalResultados: 2, progresso1: 1, progresso2: 1, promocoesRegistradas: 1 });
  });
  it("filtra por status", () => {
    const data = relacionarPerfisEResultados([profile(), profile({ id: "p2", nome_normalizado: "bia", ativo: false })], []);
    expect(filtrarPerfis(data, filters({ status: "inativos" }))).toHaveLength(1);
  });
  it("filtra por squad", () => expect(filtrarPerfis(relacionarPerfisEResultados([profile()], []), filters({ squad: "Lobo" }))).toHaveLength(1));
  it("filtra por posição", () => expect(filtrarPerfis(relacionarPerfisEResultados([profile()], []), filters({ posicao: "SDR" }))).toHaveLength(1));
  it("filtra por senioridade", () => expect(filtrarPerfis(relacionarPerfisEResultados([profile()], []), filters({ senioridade: "Júnior 1" }))).toHaveLength(1));
  it("filtra por progresso", () => expect(filtrarPerfis(relacionarPerfisEResultados([profile()], []), filters({ progresso: "1" }))).toHaveLength(1));
  it("busca nome com ou sem acento e normaliza espaços", () => {
    const data = relacionarPerfisEResultados([profile()], []);
    expect(filtrarPerfis(data, filters({ busca: "  alvaro   da " }))).toHaveLength(1);
  });
  it("preserva perfil inativo com seu histórico", () => {
    const data = relacionarPerfisEResultados([profile({ ativo: false })], [result("2026-01-01")]);
    expect(data[0]).toMatchObject({ perfil: { ativo: false }, resultados: [{ competencia: "2026-01-01" }] });
  });
  it("preserva senioridade informada nula", () => {
    const data = relacionarPerfisEResultados([profile()], [result("2026-01-01", { senioridade_informada: null })]);
    expect(data[0].resultados[0].senioridade_informada).toBeNull();
  });
  it("preserva promoção conforme armazenada no banco", () => {
    const data = relacionarPerfisEResultados([profile()], [result("2026-01-01", { recebeu_promocao: true, meta_alcancada: "Meta 1" })]);
    expect(data[0]).toMatchObject({ totalPromocoes: 1, resultados: [{ recebeu_promocao: true }] });
  });
  it("deriva opções dos dados reais", () => {
    expect(derivarOpcoesDeFiltro([profile()])).toEqual({ squads: ["Lobo"], posicoes: ["SDR"], senioridades: ["Júnior 1"] });
  });
  it("mantém perfil com squad Saiu, mas remove Saiu das opções operacionais", () => {
    const saiu = profile({ ativo: false, squad_atual: "Saiu" });
    expect(relacionarPerfisEResultados([saiu], [])).toHaveLength(1);
    expect(filtrarPerfis(relacionarPerfisEResultados([saiu], []), filters({ status: "inativos" }))).toHaveLength(1);
    expect(derivarOpcoesDeFiltro([saiu]).squads).toEqual([]);
    expect(formatarSquadAtual("Saiu")).toBe("Não se aplica");
  });
});
