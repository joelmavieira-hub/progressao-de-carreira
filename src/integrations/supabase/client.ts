import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "./types";

const AUTHORIZED_SUPABASE_URL = "https://ygyiygqfiupadgnaaxlz.supabase.co";
const REQUIRED_PUBLIC_KEY_PREFIX = "sb_publishable_";
let singleton: SupabaseClient<Database> | null = null;

function readPublicConfiguration() {
  const url = import.meta.env.VITE_SUPABASE_URL?.trim();
  const publishableKey = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY?.trim();

  if (!url || !publishableKey) {
    throw new Error(
      "Configuração de leitura indisponível. Defina VITE_SUPABASE_URL e VITE_SUPABASE_PUBLISHABLE_KEY.",
    );
  }
  if (url !== AUTHORIZED_SUPABASE_URL) {
    throw new Error("O frontend não está configurado para o projeto Supabase autorizado.");
  }
  if (!publishableKey.startsWith(REQUIRED_PUBLIC_KEY_PREFIX)) {
    throw new Error("A credencial do frontend não é uma chave publicável.");
  }

  return { url, publishableKey };
}

export function getSupabaseClient(): SupabaseClient<Database> {
  if (!singleton) {
    const { url, publishableKey } = readPublicConfiguration();
    singleton = createClient<Database>(url, publishableKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
        detectSessionInUrl: false,
      },
    });
  }
  return singleton;
}
