import type { SupabaseClient } from "@supabase/supabase-js";
import { getSupabaseClient } from "@/integrations/supabase/client";
import type { Database } from "@/integrations/supabase/types";
import { montarDadosDeProgressao } from "../domain";
import type { CareerProgressionData, ColaboradorPerfil, ColaboradorResultado } from "../types";

export const RESULTS_PAGE_SIZE = 500;
const MAX_RESULT_PAGES = 10_000;
const PROFILE_COLUMNS = "id,nome_colaborador,nome_normalizado,posicao_atual,squad_atual,jornada_atual,senioridade_atual,progresso_meta3,ativo,created_at,updated_at";
const RESULT_COLUMNS = "id,colaborador_id,nome_colaborador,posicao,squad,competencia,meta_alcancada,senioridade,senioridade_informada,recebeu_promocao,origem,mes_referencia,created_at,updated_at";
type ReadClient = SupabaseClient<Database>;

export async function buscarTodosOsPerfis(
  signal?: AbortSignal, client: ReadClient = getSupabaseClient(),
): Promise<ColaboradorPerfil[]> {
  let query = client.from("colaboradores_perfis").select(PROFILE_COLUMNS)
    .order("nome_normalizado", { ascending: true }).order("id", { ascending: true });
  if (signal) query = query.abortSignal(signal);
  const { data, error } = await query;
  if (error) throw new Error("Não foi possível carregar os perfis.");
  return (data ?? []) as ColaboradorPerfil[];
}

export async function buscarTodosOsResultados(
  signal?: AbortSignal, client: ReadClient = getSupabaseClient(),
): Promise<ColaboradorResultado[]> {
  const rows: ColaboradorResultado[] = [];
  for (let page = 0; page < MAX_RESULT_PAGES; page += 1) {
    const from = page * RESULTS_PAGE_SIZE;
    let query = client.from("colaboradores").select(RESULT_COLUMNS)
      .order("colaborador_id", { ascending: true }).order("competencia", { ascending: true })
      .order("id", { ascending: true }).range(from, from + RESULTS_PAGE_SIZE - 1);
    if (signal) query = query.abortSignal(signal);
    const { data, error } = await query;
    if (error) throw new Error("Não foi possível carregar os resultados.");
    const pageRows = (data ?? []) as ColaboradorResultado[];
    rows.push(...pageRows);
    if (pageRows.length < RESULTS_PAGE_SIZE) return rows;
  }
  throw new Error("A paginação dos resultados excedeu o limite de segurança.");
}

export async function buscarDadosDeProgressao(signal?: AbortSignal): Promise<CareerProgressionData> {
  const [perfis, resultados] = await Promise.all([buscarTodosOsPerfis(signal), buscarTodosOsResultados(signal)]);
  return montarDadosDeProgressao(perfis, resultados);
}

async function contarTabela(table: "colaboradores_perfis" | "colaboradores"): Promise<number> {
  const { count, error } = await getSupabaseClient().from(table).select("id", { count: "exact", head: true });
  if (error || count === null) throw new Error("Não foi possível contar os registros.");
  return count;
}

export function contarPerfis(): Promise<number> { return contarTabela("colaboradores_perfis"); }
export function contarResultados(): Promise<number> { return contarTabela("colaboradores"); }
