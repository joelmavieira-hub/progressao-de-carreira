import { Badge } from "@/components/ui/badge";
import type { ColaboradorPerfil } from "../../types";

type SdrBonus = 30 | 40;

function getSdrBonus(profile: Pick<ColaboradorPerfil, "posicao_atual" | "bonificacao_sdr">): SdrBonus | null {
  const isSdr = profile.posicao_atual?.trim().toLocaleLowerCase("pt-BR") === "sdr";
  const bonus = profile.bonificacao_sdr;

  return isSdr && (bonus === 30 || bonus === 40) ? bonus : null;
}

export function SdrBonusBadge({ profile }: { profile: Pick<ColaboradorPerfil, "posicao_atual" | "bonificacao_sdr"> }) {
  const bonus = getSdrBonus(profile);

  if (bonus === null) return null;

  return <Badge className="bg-purple-100 text-purple-800 hover:bg-purple-100">Bonificação: {bonus}%</Badge>;
}
