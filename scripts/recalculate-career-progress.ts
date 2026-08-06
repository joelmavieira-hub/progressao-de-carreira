import { createClient } from "@supabase/supabase-js";
import { computeProgression, getCurrentPosition, normalizeGoal, normalizeName, normalizeSeniority, type MonthRecord } from "../src/lib/progression.ts";
import type { Database, Tables } from "../src/integrations/supabase/types.ts";

const BLOCKED_SECRET_PREFIX = "sb_secret_";
const PAGE_SIZE = 500;
type Profile = Tables<"colaboradores_perfis">;
type Result = Tables<"colaboradores">;

function config() {
  const url = process.env.VITE_SUPABASE_URL?.trim().replace(/^['"]|['"]$/g, "");
  const key = process.env.VITE_SUPABASE_PUBLISHABLE_KEY?.trim().replace(/^['"]|['"]$/g, "");
  if (!url || !key) throw new Error("Configuração pública do Supabase ausente.");
  if (key.startsWith(BLOCKED_SECRET_PREFIX) || /service_role/i.test(key)) throw new Error("Credencial privilegiada recusada no dry-run.");
  return { url, key };
}

async function readAll(client: ReturnType<typeof createClient<Database>>, table: "colaboradores") {
  const rows: Result[] = [];
  for (let from = 0; ; from += PAGE_SIZE) {
    const { data, error } = await client.from(table).select("*").order("colaborador_id").order("competencia").order("id").range(from, from + PAGE_SIZE - 1);
    if (error) throw new Error("Falha na leitura dos resultados.");
    rows.push(...(data ?? []));
    if ((data ?? []).length < PAGE_SIZE) return rows;
  }
}

function history(rows: Result[]): MonthRecord[] {
  return rows.flatMap((row) => {
    const goal = normalizeGoal(row.meta_alcancada);
    if (!goal || !row.competencia) return [];
    return [{
      id: row.id, collaboratorId: row.colaborador_id, competence: row.competencia,
      month: row.competencia, goal, seniority: normalizeSeniority(row.senioridade),
      informedSeniority: normalizeSeniority(row.senioridade_informada), position: row.posicao,
      squad: row.squad, receivedPromotion: row.recebeu_promocao,
    }];
  });
}

/** Confirmed data correction used only by the read-only comparison, never by domain rules. */
function applyConfirmedCorrections(profile: Profile, rows: Result[]): Result[] {
  const name = normalizeName(profile.nome_colaborador);
  if (name === normalizeName("Miguel Carneiro Nunes")) return rows.map((row) => ({
    ...row,
    posicao: row.competencia && row.competencia <= "2026-06-01" ? "SDR" : "Closer",
    senioridade: "Júnior 1",
    senioridade_informada: "Júnior 1",
    meta_alcancada: row.competencia && row.competencia >= "2026-07-01" ? "Sem presença" : row.meta_alcancada,
  }));
  if (name === normalizeName("Tatyanna Lima de Freitas")) return rows.map((row) => ({
    ...row,
    posicao: row.competencia && row.competencia <= "2026-06-01" ? "SDR" : "Closer",
    senioridade: row.competencia && row.competencia >= "2026-07-01" ? "Júnior 2" : "Júnior 3",
    senioridade_informada: row.competencia && row.competencia >= "2026-07-01"
      ? "Júnior 2"
      : row.competencia && row.competencia >= "2026-04-01" ? "Júnior 3" : null,
    meta_alcancada: row.competencia && row.competencia >= "2026-07-01" ? "Sem presença" : row.meta_alcancada,
  }));
  return rows;
}

async function main() {
  const { url, key } = config();
  const client = createClient<Database>(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
  const [{ data: profiles, error }, results] = await Promise.all([
    client.from("colaboradores_perfis").select("*").order("nome_normalizado"), readAll(client, "colaboradores"),
  ]);
  if (error) throw new Error("Falha na leitura dos perfis.");
  const byProfile = new Map<string, Result[]>();
  for (const result of results) {
    if (!result.colaborador_id) continue;
    const rows = byProfile.get(result.colaborador_id) ?? [];
    rows.push(result); byProfile.set(result.colaborador_id, rows);
  }
  const duplicateKeys = results.map((row) => `${row.colaborador_id}|${row.competencia}`)
    .filter((key, index, all) => all.indexOf(key) !== index);
  const comparisons = (profiles as Profile[]).map((profile) => {
    const correctedRows = applyConfirmedCorrections(profile, byProfile.get(profile.id) ?? []);
    const correctedHistory = history(correctedRows);
    const state = computeProgression(correctedHistory, profile.senioridade_atual);
    const positionAfter = getCurrentPosition(correctedHistory);
    const reasons = [
      profile.progresso_meta3 !== state.meta3Streak ? "progresso divergente da reconstrução histórica" : null,
      profile.senioridade_atual !== state.seniorityAtPeriod ? "senioridade divergente da prioridade histórica" : null,
      profile.posicao_atual !== positionAfter ? "posição atual divergente do histórico corrigido" : null,
      state.sdrToCloserCompetences.length ? `reset SDR→Closer em ${state.sdrToCloserCompetences.at(-1)}` : null,
    ].filter((reason): reason is string => Boolean(reason));
    return {
      id: profile.id, nome: profile.nome_colaborador, antes: profile.progresso_meta3,
      depois: state.meta3Streak, senioridadeAntes: profile.senioridade_atual,
      senioridadeDepois: state.seniorityAtPeriod, resetCompetencia: state.resetCompetence,
      posicaoAntes: profile.posicao_atual, posicaoDepois: positionAfter,
      metas3Consideradas: state.currentCycleMeta3Competences,
      mudancasSdrParaCloser: state.sdrToCloserCompetences,
      promocoes: state.promotionCompetences,
      conclusoesDeCiclo: state.cycleCompletionCompetences,
      motivos: reasons,
      correcoesConfirmadasSimuladas: ["Miguel Carneiro Nunes", "Tatyanna Lima de Freitas"]
        .some((name) => normalizeName(profile.nome_colaborador) === normalizeName(name)),
      alteracaoPrevista: reasons.some((reason) => !reason.startsWith("reset SDR→Closer"))
        || profile.progresso_meta3 !== state.meta3Streak,
    };
  });
  const named = ["Adrilene", "Taty", "Miguel", "Luiz", "Luan", "Gustavo", "Leandro", "João Paulo"]
    .map((name) => {
      const comparison = comparisons.find((row) => row.nome.toLocaleLowerCase("pt-BR").includes(name.toLocaleLowerCase("pt-BR")));
      if (!comparison) return { nome: name, encontrado: false };
      const profile = (profiles as Profile[]).find((item) => item.id === comparison.id) as Profile;
      return { ...comparison,
        historicoAtual: (byProfile.get(comparison.id) ?? []).map((row) => ({ competencia: row.competencia, posicao: row.posicao, meta: row.meta_alcancada, senioridade: row.senioridade, senioridadeInformada: row.senioridade_informada, promocao: row.recebeu_promocao })),
        historicoAposCorrecoesConfirmadas: applyConfirmedCorrections(profile, byProfile.get(comparison.id) ?? []).map((row) => ({ competencia: row.competencia, posicao: row.posicao, meta: row.meta_alcancada, senioridade: row.senioridade, senioridadeInformada: row.senioridade_informada })),
      };
    });
  const report = {
    mode: "dry-run-read-only", generatedAt: new Date().toISOString(), productionWrites: 0,
    decisions: { miguelLastSdrCompetence: "2026-06-01", miguelFirstCloserCompetence: "2026-07-01", miguelJulyGoal: "Sem presença", miguelAugustGoal: "Sem presença", senior3ThirdMetaCompletesWithoutPromotion: true },
    summary: { profiles: profiles?.length ?? 0, results: results.length, duplicateCompetences: new Set(duplicateKeys).size, proposedChanges: comparisons.filter((row) => row.alteracaoPrevista).length },
    namedCases: named, inconsistencies: comparisons.filter((row) => row.alteracaoPrevista), comparisons,
  };
  const output = process.argv.includes("--named-only") ? { ...report, comparisons: undefined } : report;
  process.stdout.write(`${JSON.stringify(output, null, 2)}\n`);
}

main().catch((error: unknown) => {
  process.stderr.write(`${error instanceof Error ? error.message : "Falha no dry-run."} Nenhuma escrita foi executada.\n`);
  process.exitCode = 1;
});
