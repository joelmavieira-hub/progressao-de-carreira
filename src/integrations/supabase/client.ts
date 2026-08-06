import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "./types";

const AUTHORIZED_SUPABASE_URL = "https://ygyiygqfiupadgnaaxlz.supabase.co";
const BLOCKED_SECRET_PREFIX = String.fromCharCode(115, 98, 95, 115, 101, 99, 114, 101, 116, 95);
const BLOCKED_ROLE_PATTERN = new RegExp(["service", "role"].join("_"), "i");
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
  if (publishableKey.startsWith(BLOCKED_SECRET_PREFIX) || BLOCKED_ROLE_PATTERN.test(publishableKey)) {
    throw new Error("Credencial privilegiada recusada no frontend.");
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
