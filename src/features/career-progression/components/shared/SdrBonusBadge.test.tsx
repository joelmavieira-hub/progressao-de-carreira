import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import type { ColaboradorPerfil } from "../../types";
import { SdrBonusBadge } from "./SdrBonusBadge";

const profile = (position: string, bonus: number): Pick<ColaboradorPerfil, "posicao_atual" | "bonificacao_sdr"> => ({
  posicao_atual: position,
  bonificacao_sdr: bonus,
});

describe("SdrBonusBadge", () => {
  it.each([30, 40] as const)("renderiza a bonificação de %i%% recebida do backend", (bonus) => {
    render(<SdrBonusBadge profile={profile("SDR", bonus)} />);

    expect(screen.getByText(`Bonificação: ${bonus}%`)).toBeInTheDocument();
  });

  it.each([
    ["SDR", 0],
    ["SDR", 20],
    ["Closer", 40],
    ["Liderança de SDRs", 40],
    ["Liderança de Closers", 40],
  ])("não exibe bonificação para posição %s com valor %i", (position, bonus) => {
    const { container } = render(<SdrBonusBadge profile={profile(position, bonus)} />);

    expect(container).toBeEmptyDOMElement();
  });
});
