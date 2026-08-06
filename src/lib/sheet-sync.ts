import { normalizeName } from "./progression";

export const VALID_SQUADS = ["Lobo", "Águia", "Sharks", "Serpente", "Gorila", "Urso", "Saiu"] as const;
export const VALID_JOURNEYS = ["Ativo", "Inativo", "Desligado", "Saiu"] as const;

export interface SheetSyncRow {
  rowNumber: number;
  name: string;
  squad: string;
  journey: string;
  [field: string]: unknown;
}

export interface ExistingSheetProfile {
  name: string;
  journey: string | null;
}

export interface SyncIssue {
  rowNumber: number;
  collaborator: string | null;
  field: "nome_colaborador" | "squad" | "jornada";
  receivedValue: string;
  classification: "erro de linha" | "aviso";
  action: "linha ignorada" | "jornada anterior preservada";
  message: string;
}

export interface ClassifiedSheetRow {
  classification: "válida" | "válida com aviso" | "inválida";
  source: SheetSyncRow;
  effective: SheetSyncRow | null;
  issues: SyncIssue[];
}

export interface SheetSyncReport {
  rowsRead: number;
  validRows: number;
  warningRows: number;
  invalidRows: number;
  errors: SyncIssue[];
  warnings: SyncIssue[];
  rows: ClassifiedSheetRow[];
}

function fold(value: string): string {
  return value.normalize("NFD").replace(/[\u0300-\u036f]/g, "").trim().replace(/\s+/g, " ").toLocaleLowerCase("pt-BR");
}

function canonical(value: string, domain: readonly string[]): string | null {
  const key = fold(value);
  return domain.find((entry) => fold(entry) === key) ?? null;
}

export function classifySheetRows(
  rows: readonly SheetSyncRow[],
  existingProfiles: readonly ExistingSheetProfile[],
): SheetSyncReport {
  const existing = new Map(existingProfiles.map((profile) => [normalizeName(profile.name), profile]));
  const classified = rows.map((source): ClassifiedSheetRow => {
    const issues: SyncIssue[] = [];
    const name = source.name.trim().replace(/\s+/g, " ");
    if (!name) issues.push({ rowNumber: source.rowNumber, collaborator: null, field: "nome_colaborador", receivedValue: source.name, classification: "erro de linha", action: "linha ignorada", message: "Nome do colaborador vazio." });

    const squad = canonical(source.squad, VALID_SQUADS);
    if (!squad) issues.push({ rowNumber: source.rowNumber, collaborator: name || null, field: "squad", receivedValue: source.squad, classification: "erro de linha", action: "linha ignorada", message: "Squad inválido." });

    const profile = name ? existing.get(normalizeName(name)) : undefined;
    let journey = canonical(source.journey, VALID_JOURNEYS);
    if (!source.journey.trim()) {
      const previous = profile?.journey ? canonical(profile.journey, VALID_JOURNEYS) : null;
      if (previous) {
        journey = previous;
        issues.push({ rowNumber: source.rowNumber, collaborator: name, field: "jornada", receivedValue: "", classification: "aviso", action: "jornada anterior preservada", message: "Jornada vazia; valor existente mantido." });
      } else {
        issues.push({ rowNumber: source.rowNumber, collaborator: name || null, field: "jornada", receivedValue: "", classification: "erro de linha", action: "linha ignorada", message: profile ? "Jornada vazia e perfil existente sem valor preservável." : "Jornada vazia para colaborador novo." });
      }
    } else if (!journey) {
      issues.push({ rowNumber: source.rowNumber, collaborator: name || null, field: "jornada", receivedValue: source.journey, classification: "erro de linha", action: "linha ignorada", message: "Jornada inválida." });
    }

    const errors = issues.filter((issue) => issue.classification === "erro de linha");
    if (errors.length) return { classification: "inválida", source, effective: null, issues };
    const effective = { ...source, name, squad: squad as string, journey: journey as string };
    return { classification: issues.length ? "válida com aviso" : "válida", source, effective, issues };
  });
  const errors = classified.flatMap((row) => row.issues.filter((issue) => issue.classification === "erro de linha"));
  const warnings = classified.flatMap((row) => row.issues.filter((issue) => issue.classification === "aviso"));
  return {
    rowsRead: rows.length,
    validRows: classified.filter((row) => row.classification === "válida").length,
    warningRows: classified.filter((row) => row.classification === "válida com aviso").length,
    invalidRows: classified.filter((row) => row.classification === "inválida").length,
    errors, warnings, rows: classified,
  };
}

export function formatSyncReport(report: SheetSyncReport, synchronizedRows: number, durationMs: number): string {
  const status = report.invalidRows || report.warningRows ? "Sincronização concluída parcialmente." : "Sincronização concluída.";
  const details = [...report.errors, ...report.warnings].map((issue) =>
    `Linha ${issue.rowNumber} | ${issue.collaborator ?? "sem nome"} | campo=${issue.field} | valor=${issue.receivedValue || "vazio"} | classificação=${issue.classification} | ação=${issue.action} | ${issue.message}`,
  );
  return [status,
    `linhas lidas: ${report.rowsRead}`,
    `linhas válidas: ${report.validRows}`,
    `linhas sincronizadas: ${synchronizedRows}`,
    `linhas sincronizadas com aviso: ${report.warningRows}`,
    `linhas ignoradas: ${report.invalidRows}`,
    `erros: ${report.errors.length}`,
    `avisos: ${report.warnings.length}`,
    `duração da execução: ${durationMs} ms`,
    ...details,
  ].join("\n");
}
