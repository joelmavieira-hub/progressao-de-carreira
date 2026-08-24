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

function foldedPosition(value: string | null | undefined): string {
  return (value ?? "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").trim().toUpperCase();
}

function compactGoal(value: string | null | undefined): string {
  const goal = normalizeGoal(value);
  return ({ meta1: "M1", meta2: "M2", meta3: "M3", below: "NM", absent: "SP" } as const)[goal ?? "absent"];
}

function promotionLabels(rows: Result[], promotionCompetences: string[], roleCompetences: string[]) {
  const old = rows.filter((row) => row.competencia && row.competencia >= "2026-06-01" && row.recebeu_promocao)
    .map((row) => `senioridade ${row.competencia}`);
  const newer = [
    ...promotionCompetences.map((competence) => `senioridade ${competence}`),
    ...roleCompetences.map((competence) => `função ${competence}`),
  ];
  return { old: old.length ? old.join(", ") : "Não", newer: newer.length ? newer.join(", ") : "Não" };
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
  if (name === normalizeName("João Paulo Maciel Sousa")) return rows.map((row) => ({
    ...row,
    posicao: row.competencia && row.competencia < "2026-06-01" ? "SDR" : "Closer",
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
    const finalIsSdr = foldedPosition(profile.posicao_atual) === "SDR";
    const bonusAfter = finalIsSdr ? state.sdrBonus : 0;
    const bonusStreakAfter = finalIsSdr ? state.sdrBonusStreak : 0;
    const promotions = promotionLabels(correctedRows, state.promotionCompetences, state.sdrToCloserCompetences);
    const reasons = [
      profile.progresso_meta3 !== state.meta3Streak ? "progresso divergente da reconstrução histórica" : null,
      typeof profile.progresso_meta2 === "number" && profile.progresso_meta2 !== state.meta2Count ? "âncora Meta 2 divergente da reconstrução histórica" : null,
      typeof profile.progresso_ciclo === "number" && profile.progresso_ciclo !== state.cycleProgress ? "etapa do ciclo divergente da reconstrução histórica" : null,
      typeof profile.bonificacao_sdr === "number" && profile.bonificacao_sdr !== bonusAfter ? "bonificação SDR divergente da reconstrução histórica" : null,
      typeof profile.streak_meta3_bonificacao === "number" && profile.streak_meta3_bonificacao !== bonusStreakAfter ? "streak de bonificação divergente da reconstrução histórica" : null,
      profile.senioridade_atual !== state.seniorityAtPeriod ? "senioridade divergente da prioridade histórica" : null,
      profile.posicao_atual !== positionAfter ? "posição atual divergente do histórico corrigido" : null,
      state.sdrToCloserCompetences.length ? `reset SDR→Closer em ${state.sdrToCloserCompetences.at(-1)}` : null,
    ].filter((reason): reason is string => Boolean(reason));
    return {
      id: profile.id, nome: profile.nome_colaborador, antes: profile.progresso_meta3,
      depois: state.meta3Streak, senioridadeAntes: profile.senioridade_atual,
      senioridadeDepois: state.seniorityAtPeriod, resetCompetencia: state.resetCompetence,
      meta2Antes: profile.progresso_meta2, meta2Depois: state.meta2Count,
      cicloAntes: profile.progresso_ciclo, cicloDepois: state.cycleProgress,
      bonificacaoAntes: profile.bonificacao_sdr, bonificacaoDepois: bonusAfter,
      streakBonusAntes: profile.streak_meta3_bonificacao, streakBonusDepois: bonusStreakAfter,
      posicaoAntes: profile.posicao_atual, posicaoDepois: positionAfter,
      metas3Consideradas: state.currentCycleMeta3Competences,
      mudancasSdrParaCloser: state.sdrToCloserCompetences,
      promocoes: state.promotionCompetences,
      promocaoAntiga: promotions.old,
      promocaoNova: promotions.newer,
      conclusoesDeCiclo: state.cycleCompletionCompetences,
      motivos: reasons,
      correcoesConfirmadasSimuladas: ["Miguel Carneiro Nunes", "Tatyanna Lima de Freitas", "João Paulo Maciel Sousa"]
        .some((name) => normalizeName(profile.nome_colaborador) === normalizeName(name)),
      alteracaoPrevista: profile.progresso_meta3 !== state.meta3Streak
        || profile.progresso_meta2 !== state.meta2Count
        || profile.progresso_ciclo !== state.cycleProgress
        || profile.bonificacao_sdr !== bonusAfter
        || profile.streak_meta3_bonificacao !== bonusStreakAfter
        || profile.senioridade_atual !== state.seniorityAtPeriod,
      metasDesdeJunho: correctedRows.filter((row) => row.competencia && row.competencia >= "2026-06-01")
        .map((row) => `${row.competencia}:${compactGoal(row.meta_alcancada)}`),
    };
  });
  const named = [
    "Luan Nicolas Sinesio Crisostomo", "João Paulo Maciel Sousa", "Gustavo Duarte Pinheiro Silva",
    "Leandro Dos Santos Pereira", "Miguel Carneiro Nunes", "Tatyanna Lima de Freitas",
    "Adrilene Azevedo da Silva", "Luiz Fernando de Medeiros Paiva Moura", "Cleber Rodrigues Souza",
    "Gabrielly de Oliveira Medeiros",
  ].map((name) => {
      const comparison = comparisons.find((row) => normalizeName(row.nome) === normalizeName(name));
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
    summary: {
      profiles: profiles?.length ?? 0,
      results: results.length,
      duplicateCompetences: new Set(duplicateKeys).size,
      schemaReady: (profiles as Profile[]).every((profile) => typeof profile.progresso_meta2 === "number" && typeof profile.bonificacao_sdr === "number"),
      proposedChanges: comparisons.filter((row) => row.alteracaoPrevista).length,
      projectedBonus30: comparisons.filter((row) => row.bonificacaoDepois === 30).length,
      projectedBonus40: comparisons.filter((row) => row.bonificacaoDepois === 40).length,
      projectedNearPromotion: comparisons.filter((row) => row.cicloDepois === 2).length,
      referenceReplaySecondPassDifferences: (profiles as Profile[]).filter((profile) => {
        const sourceRows = applyConfirmedCorrections(profile, byProfile.get(profile.id) ?? []);
        return JSON.stringify(computeProgression(history(sourceRows), profile.senioridade_atual))
          !== JSON.stringify(computeProgression(history(sourceRows), profile.senioridade_atual));
      }).length,
    },
    namedCases: named, inconsistencies: comparisons.filter((row) => row.alteracaoPrevista), comparisons,
  };
  if (process.argv.includes("--validation-tables")) {
    const impacted = comparisons.filter((row) => row.alteracaoPrevista).map((row) => ({
      colaborador: row.nome,
      posicao: row.posicaoAntes ?? "Não informada",
      metas: row.metasDesdeJunho.join(" ") || "Sem resultados",
      senioridadeAntes: row.senioridadeAntes ?? "Não informada",
      senioridadeDepois: row.senioridadeDepois ?? "Não informada",
      cicloAntes: `${row.antes} M3 (legado)`,
      cicloDepois: row.cicloDepois === 0 ? "0/3" : `${row.cicloDepois}/3 (${row.depois} M3 + ${row.meta2Depois} M2)`,
      promocaoAntiga: row.promocaoAntiga,
      promocaoNova: row.promocaoNova,
      competenciaPromocao: [...row.promocoes, ...row.mudancasSdrParaCloser].join(", ") || "—",
      bonificacao: `${row.bonificacaoDepois}%`,
      motivo: [
        row.antes !== row.depois ? "progresso legado diverge do replay" : null,
        row.meta2Depois ? "Meta 2 compõe/ancora o ciclo" : null,
        row.senioridadeAntes !== row.senioridadeDepois ? "senioridade recalculada" : null,
        row.promocaoAntiga !== row.promocaoNova ? "promoções recalculadas" : null,
        row.mudancasSdrParaCloser.length ? "reset SDR→Closer" : null,
        row.bonificacaoDepois ? "bonificação materializada" : null,
        row.streakBonusDepois ? `streak SDR=${row.streakBonusDepois}` : null,
      ].filter(Boolean).join("; ") || "novo estado materializado",
    }));
    const sdrRows = (profiles as Profile[]).filter((profile) => foldedPosition(profile.posicao_atual) === "SDR").map((profile) => {
      const sourceRows = applyConfirmedCorrections(profile, byProfile.get(profile.id) ?? []);
      const state = computeProgression(history(sourceRows), profile.senioridade_atual);
      const byCompetence = new Map(sourceRows.map((row) => [row.competencia, compactGoal(row.meta_alcancada)]));
      return { colaborador: profile.nome_colaborador, jun: byCompetence.get("2026-06-01") ?? "—", jul: byCompetence.get("2026-07-01") ?? "—",
        ago: byCompetence.get("2026-08-01") ?? "—", set: byCompetence.get("2026-09-01") ?? "—", streak: state.sdrBonusStreak, bonificacao: state.sdrBonus };
    });
    process.stdout.write(`${JSON.stringify({ summary: report.summary, impacted, sdrRows }, null, 2)}\n`);
    return;
  }
  const output = process.argv.includes("--summary-only")
    ? { mode: report.mode, generatedAt: report.generatedAt, productionWrites: report.productionWrites, summary: report.summary }
    : process.argv.includes("--named-only") ? { ...report, inconsistencies: undefined, comparisons: undefined } : report;
  process.stdout.write(`${JSON.stringify(output, null, 2)}\n`);
}

main().catch((error: unknown) => {
  process.stderr.write(`${error instanceof Error ? error.message : "Falha no dry-run."} Nenhuma escrita foi executada.\n`);
  process.exitCode = 1;
});
