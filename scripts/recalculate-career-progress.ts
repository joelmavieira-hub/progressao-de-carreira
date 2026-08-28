import { createClient } from "@supabase/supabase-js";
import { computeProgression, getCurrentPosition, normalizeGoal, normalizeName, normalizeSeniority, projectNextCloserPromotion, type MonthRecord } from "../src/lib/progression.ts";
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

function addMonths(competence: string | null | undefined, months: number): string | null {
  const match = competence?.match(/^(\d{4})-(\d{2})-01$/);
  if (!match) return null;
  const date = new Date(Date.UTC(Number(match[1]), Number(match[2]) - 1 + months, 1));
  return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, "0")}-01`;
}

function projectedNextPromotion(rows: Result[], streak: number): string | null {
  const latestCompetence = rows.map((row) => row.competencia).filter((value): value is string => Boolean(value)).sort().at(-1);
  const latest = [...rows].reverse().find((row) => row.competencia === latestCompetence);
  const latestGoal = normalizeGoal(latest?.meta_alcancada);
  const firstSlotOffset = latestGoal === "meta1" || latestGoal === "meta2" || latestGoal === "meta3" ? 1 : 0;
  return addMonths(latestCompetence, firstSlotOffset + Math.max(0, 3 - streak - 1));
}

const ACCEPTANCE_CASES = new Map([
  ["Luan Nicolas Sinesio Crisostomo", "2026-09-01"],
  ["João Paulo Maciel Sousa", "2026-09-01"],
  ["Miguel Carneiro Nunes", "2026-10-01"],
  ["Tatyanna Lima de Freitas", "2026-10-01"],
  ["Leandro Dos Santos Pereira", "2026-10-01"],
  ["Gustavo Duarte Pinheiro Silva", "2026-09-01"],
  ["Guilherme da Silva Gomes", "2026-10-01"],
  ["Letícia Wendy da Silva Alves", "2026-10-01"],
  ["Diego Nobre do Santos", "2026-11-01"],
  ["José Albesson Damasceno Silva", null],
  ["Cleber Rodrigues Souza", "2026-10-01"],
  ["Johnathan Ranier Brito de Oliveira", "2026-09-01"],
] as const);

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
    const sourceRows = byProfile.get(profile.id) ?? [];
    const sourceHistory = history(sourceRows);
    const state = computeProgression(sourceHistory, profile.senioridade_atual);
    const positionAfter = getCurrentPosition(sourceHistory);
    const finalIsSdr = foldedPosition(profile.posicao_atual) === "SDR";
    const bonusAfter = finalIsSdr ? state.sdrBonus : 0;
    const bonusStreakAfter = finalIsSdr ? state.sdrBonusStreak : 0;
    const promotions = promotionLabels(sourceRows, state.promotionCompetences, state.sdrToCloserCompetences);
    const lastPromotion = [...sourceRows].reverse().find((row) => row.recebeu_promocao)?.competencia ?? null;
    const previousNextPromotion = projectedNextPromotion(sourceRows, profile.progresso_ciclo ?? profile.progresso_meta3);
    const isOperationalCloser = profile.ativo
      && foldedPosition(profile.posicao_atual) === "CLOSER"
      && foldedPosition(profile.jornada_atual) !== "SAIU"
      && foldedPosition(profile.squad_atual) !== "SAIU";
    const projection = isOperationalCloser ? projectNextCloserPromotion(sourceHistory, profile.senioridade_atual) : null;
    const correctNextPromotion = projection?.promotionCompetence ?? null;
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
      ativo: profile.ativo, jornada: profile.jornada_atual, squad: profile.squad_atual,
      metas3Consideradas: state.currentCycleMeta3Competences,
      mudancasSdrParaCloser: state.sdrToCloserCompetences,
      promocoes: state.promotionCompetences,
      promocaoAntiga: promotions.old,
      promocaoNova: promotions.newer,
      conclusoesDeCiclo: state.cycleCompletionCompetences,
      primeiraCompetenciaCloser: state.firstCloserCompetence,
      competenciaRampingIgnorada: state.rampingIgnoredCompetence,
      ultimaPromocao: lastPromotion,
      proximaPromocaoAnterior: previousNextPromotion,
      proximaPromocaoCorreta: correctNextPromotion,
      rampingProjetado: projection?.rampingMetaCompetence ?? null,
      metas3Projetadas: projection?.projectedMeta3Competences ?? [],
      motivos: reasons,
      alteracaoPrevista: profile.progresso_meta3 !== state.meta3Streak
        || profile.progresso_meta2 !== state.meta2Count
        || profile.progresso_ciclo !== state.cycleProgress
        || profile.bonificacao_sdr !== bonusAfter
        || profile.streak_meta3_bonificacao !== bonusStreakAfter
        || profile.senioridade_atual !== state.seniorityAtPeriod,
      historicoDesdeJunho: sourceRows.filter((row) => row.competencia && row.competencia >= "2026-06-01")
        .map((row) => `${row.competencia}:${foldedPosition(row.posicao) || "?"}/${compactGoal(row.meta_alcancada)}[${row.meta_alcancada ?? "vazio"}]`),
    };
  });
  const named = [...ACCEPTANCE_CASES].map(([name, expectedPromotion]) => {
      const comparison = comparisons.find((row) => normalizeName(row.nome) === normalizeName(name));
      if (!comparison) return { nome: name, encontrado: false, esperado: expectedPromotion, aceite: false };
      const correctPromotion = comparison.promocoes.at(-1) ?? null;
      const zeroedExpected = expectedPromotion === null;
      return { ...comparison, esperado: expectedPromotion ?? "Zerado / sem meta",
        promocaoMaterializadaCorreta: correctPromotion, aceite: zeroedExpected
          ? correctPromotion === null && comparison.depois === 0
          : comparison.proximaPromocaoCorreta === expectedPromotion };
    });
  const report = {
    mode: "dry-run-read-only", generatedAt: new Date().toISOString(), productionWrites: 0,
    rule: { epoch: "2026-06-01", closerPromotion: "3 M3 consecutivas após ramping", closerMeta2: "quebra streak", closerBonus: false, sdrRuleChanged: false },
    summary: {
      profiles: profiles?.length ?? 0,
      results: results.length,
      duplicateCompetences: new Set(duplicateKeys).size,
      schemaReady: (profiles as Profile[]).every((profile) => typeof profile.progresso_meta2 === "number" && typeof profile.bonificacao_sdr === "number"),
      proposedChanges: comparisons.filter((row) => row.alteracaoPrevista).length,
      projectedBonus30: comparisons.filter((row) => row.bonificacaoDepois === 30).length,
      projectedBonus40: comparisons.filter((row) => row.bonificacaoDepois === 40).length,
      projectedNearPromotion: comparisons.filter((row) => row.cicloDepois === 2).length,
      acceptancePassed: named.filter((row) => row.aceite).length,
      acceptanceTotal: ACCEPTANCE_CASES.size,
      unexpectedSeniorityChanges: comparisons.filter((row) => row.senioridadeAntes !== row.senioridadeDepois).length,
      gatePassed: named.every((row) => row.aceite)
        && comparisons.every((row) => row.senioridadeAntes === row.senioridadeDepois)
        && new Set(duplicateKeys).size === 0,
      referenceReplaySecondPassDifferences: (profiles as Profile[]).filter((profile) => {
        const sourceRows = byProfile.get(profile.id) ?? [];
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
      metas: row.historicoDesdeJunho.join(" ") || "Sem resultados",
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
      const sourceRows = byProfile.get(profile.id) ?? [];
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
