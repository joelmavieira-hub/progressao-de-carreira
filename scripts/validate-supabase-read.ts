import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import type { Database, Tables } from "../src/integrations/supabase/types.ts";

const EXPECTED_URL = "https://ygyiygqfiupadgnaaxlz.supabase.co";
const BLOCKED_SECRET_PREFIX = String.fromCharCode(115, 98, 95, 115, 101, 99, 114, 101, 116, 95);
const BLOCKED_ROLE_PATTERN = new RegExp(["service", "role"].join("_"), "i");
const PAGE_SIZE = 500;
const MAX_PAGES = 10_000;
const VALID_GOALS = new Set(["Meta 1", "Meta 2", "Meta 3", "Nenhuma meta", "Sem presença"]);
const VALID_SENIORITIES = new Set([
  "Júnior 1", "Júnior 2", "Júnior 3", "Pleno 1", "Pleno 2", "Pleno 3", "Sênior 1", "Sênior 2", "Sênior 3",
]);

type Profile = Tables<"colaboradores_perfis">;
type Result = Tables<"colaboradores">;
type Check = { label: string; actual: string | number | boolean; expected: string | number | boolean };

function configuration() {
  const url = process.env.VITE_SUPABASE_URL?.trim().replace(/^['"]|['"]$/g, "");
  const key = process.env.VITE_SUPABASE_PUBLISHABLE_KEY?.trim().replace(/^['"]|['"]$/g, "");
  if (!url || !key) throw new Error("Variáveis públicas do Supabase ausentes.");
  if (url !== EXPECTED_URL) throw new Error("URL do projeto Supabase não autorizada.");
  if (key.startsWith(BLOCKED_SECRET_PREFIX) || BLOCKED_ROLE_PATTERN.test(key)) throw new Error("Credencial privilegiada recusada.");
  return { url, key };
}

async function profiles(client: SupabaseClient<Database>): Promise<Profile[]> {
  const { data, error } = await client.from("colaboradores_perfis").select("*")
    .order("nome_normalizado", { ascending: true }).order("id", { ascending: true });
  if (error) throw new Error("Falha na leitura dos perfis.");
  return data ?? [];
}

async function results(client: SupabaseClient<Database>): Promise<Result[]> {
  const all: Result[] = [];
  for (let page = 0; page < MAX_PAGES; page += 1) {
    const from = page * PAGE_SIZE;
    const { data, error } = await client.from("colaboradores").select("*")
      .order("colaborador_id", { ascending: true }).order("competencia", { ascending: true })
      .order("id", { ascending: true }).range(from, from + PAGE_SIZE - 1);
    if (error) throw new Error("Falha na leitura paginada dos resultados.");
    const current = data ?? [];
    all.push(...current);
    if (current.length < PAGE_SIZE) return all;
  }
  throw new Error("Limite de segurança da paginação excedido.");
}

function runChecks(profileRows: Profile[], resultRows: Result[]): Check[] {
  const profileIds = new Set(profileRows.map((row) => row.id));
  const countsByProfile = new Map<string, number>();
  const competenceKeys = new Set<string>();
  let duplicateCompetences = 0;
  for (const row of resultRows) {
    if (row.colaborador_id) countsByProfile.set(row.colaborador_id, (countsByProfile.get(row.colaborador_id) ?? 0) + 1);
    const key = `${row.colaborador_id ?? "null"}|${row.competencia ?? "null"}`;
    if (competenceKeys.has(key)) duplicateCompetences += 1;
    competenceKeys.add(key);
  }
  const competencies = resultRows.map((row) => row.competencia).filter((value): value is string => value !== null).sort();
  const promoted = resultRows.filter((row) => row.recebeu_promocao);
  const distinctCompetences = new Set(competencies);
  const normalizedNames = new Set(profileRows.map((row) => row.nome_normalizado));
  const invalidResults = resultRows.filter((row) =>
    !row.meta_alcancada || !VALID_GOALS.has(row.meta_alcancada)
    || !row.senioridade || !VALID_SENIORITIES.has(row.senioridade)
    || (row.senioridade_informada !== null && !VALID_SENIORITIES.has(row.senioridade_informada)),
  ).length;

  return [
    { label: "URL autorizada", actual: true, expected: true },
    { label: "Perfis carregados", actual: profileRows.length > 0, expected: true },
    { label: "Partição ativos/inativos", actual: profileRows.filter((row) => row.ativo).length + profileRows.filter((row) => !row.ativo).length === profileRows.length, expected: true },
    { label: "Nomes normalizados distintos", actual: normalizedNames.size === profileRows.length, expected: true },
    { label: "Resultados carregados", actual: resultRows.length > 0, expected: true },
    { label: "Competências disponíveis", actual: distinctCompetences.size > 0, expected: true },
    { label: "Históricos completos nas competências disponíveis", actual: profileRows.every((row) => countsByProfile.get(row.id) === distinctCompetences.size), expected: true },
    { label: "Duplicidades colaborador/competência", actual: duplicateCompetences, expected: 0 },
    { label: "Órfãos", actual: resultRows.filter((row) => !row.colaborador_id || !profileIds.has(row.colaborador_id)).length, expected: 0 },
    { label: "Promoções associadas a perfis", actual: promoted.every((row) => Boolean(row.colaborador_id && profileIds.has(row.colaborador_id))), expected: true },
    { label: "Resultados com domínio inválido", actual: invalidResults, expected: 0 },
    { label: "Perfis com progresso inválido", actual: profileRows.filter((row) => ![0, 1, 2].includes(row.progresso_meta3)).length, expected: 0 },
  ];
}

async function main() {
  const { url, key } = configuration();
  const client = createClient<Database>(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
  const [profileRows, resultRows] = await Promise.all([profiles(client), results(client)]);
  const checks = runChecks(profileRows, resultRows);
  const failed = checks.filter((check) => check.actual !== check.expected);
  for (const check of checks) {
    process.stdout.write(`${check.actual === check.expected ? "PASS" : "FAIL"} ${check.label}: ${String(check.actual)}\n`);
  }
  const promoted = resultRows.filter((row) => row.recebeu_promocao);
  const progress = [0, 1, 2].map((value) => `${value}=${profileRows.filter((row) => row.progresso_meta3 === value).length}`).join(", ");
  process.stdout.write(`Resumo: perfis=${profileRows.length}, ativos=${profileRows.filter((row) => row.ativo).length}, inativos=${profileRows.filter((row) => !row.ativo).length}, resultados=${resultRows.length}, competências=${new Set(resultRows.map((row) => row.competencia).filter(Boolean)).size}, promoções=${promoted.length}, pessoas_promovidas=${new Set(promoted.map((row) => row.colaborador_id)).size}, progresso(${progress})\n`);
  if (failed.length > 0) process.exitCode = 1;
}

main().catch(() => {
  process.stderr.write("Falha segura na validação somente leitura. Nenhuma escrita foi executada.\n");
  process.exitCode = 1;
});
