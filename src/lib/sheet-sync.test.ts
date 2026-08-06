import { describe, expect, it } from "vitest";
import { classifySheetRows, formatSyncReport, type SheetSyncRow } from "./sheet-sync";

const row = (rowNumber: number, overrides: Partial<SheetSyncRow> = {}): SheetSyncRow => ({
  rowNumber, name: `Pessoa ${rowNumber}`, squad: "Lobo", journey: "Ativo", ...overrides,
});

describe("validação parcial da planilha", () => {
  it("mantém Parcerias inválido", () => {
    const report = classifySheetRows([row(19, { name: "Ana", squad: "Parcerias" })], []);
    expect(report.invalidRows).toBe(1);
    expect(report.errors[0]).toMatchObject({ rowNumber: 19, field: "squad", action: "linha ignorada" });
  });

  it("preserva jornada vazia de perfil existente e continua", () => {
    const report = classifySheetRows([row(87, { name: "Ana", journey: "" })], [{ name: "Ana", journey: "Inativo" }]);
    expect(report.rows[0]).toMatchObject({ classification: "válida com aviso", effective: { journey: "Inativo" } });
    expect(report.warningRows).toBe(1);
  });

  it("ignora jornada vazia de perfil novo sem contaminar as demais linhas", () => {
    const report = classifySheetRows([row(2), row(3, { journey: "" }), row(4)], []);
    expect(report.rows.map(({ classification }) => classification)).toEqual(["válida", "inválida", "válida"]);
    expect(report.validRows).toBe(2);
    expect(report.invalidRows).toBe(1);
  });

  it("gera relatório detalhado de execução parcial", () => {
    const report = classifySheetRows([row(19, { name: "Ana", squad: "Parcerias" }), row(20)], []);
    expect(formatSyncReport(report, 1, 42)).toContain("Linha 19 | Ana | campo=squad | valor=Parcerias");
  });
});
