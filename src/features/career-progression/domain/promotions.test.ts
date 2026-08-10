import { describe, expect, it } from "vitest";

import { relacionarPerfisEResultados } from "../domain";
import type {
  ColaboradorPerfil,
  ColaboradorResultado,
  PerfilComHistorico,
} from "../types";

import {
  detectRoleTransitionPromotions,
  isSdrToCloserTransition,
} from "./promotions";

const profile = (
  id: string,
  overrides: Partial<ColaboradorPerfil> = {},
): ColaboradorPerfil => ({
  id,
  nome_colaborador: `Pessoa ${id}`,
  nome_normalizado: `pessoa ${id}`,
  posicao_atual: "SDR",
  squad_atual: "Lobo",
  senioridade_atual: "Júnior 1",
  progresso_meta3: 0,
  ativo: true,
  created_at: "2026-01-01T00:00:00Z",
  updated_at: "2026-08-01T00:00:00Z",
  ...overrides,
});

const result = (
  id: string,
  collaboratorId: string,
  competence: string,
  overrides: Partial<ColaboradorResultado> = {},
): ColaboradorResultado => ({
  id,
  colaborador_id: collaboratorId,
  nome_colaborador: `Pessoa ${collaboratorId}`,
  posicao: "SDR",
  squad: "Lobo",
  competencia: competence,
  meta_alcancada: "Meta 1",
  senioridade: "Júnior 1",
  senioridade_informada: "Júnior 1",
  recebeu_promocao: false,
  origem: "google_sheets_progressao",
  mes_referencia: competence,
  created_at: competence,
  updated_at: competence,
  ...overrides,
});

const related = (
  profiles: ColaboradorPerfil[],
  results: ColaboradorResultado[],
): PerfilComHistorico[] =>
  relacionarPerfisEResultados(
    profiles,
    results,
  );

describe("role transition promotions", () => {
  it("reconhece Miguel SDR -> Closer como promoção", () => {
    const data = related(
      [
        profile("miguel", {
          nome_colaborador: "Miguel",
          nome_normalizado: "miguel",
          posicao_atual: "Closer",
        }),
      ],
      [
        result(
          "miguel-jun",
          "miguel",
          "2026-06-01",
          {
            posicao: "SDR",
          },
        ),
        result(
          "miguel-jul",
          "miguel",
          "2026-07-01",
          {
            posicao: "Closer",
          },
        ),
      ],
    );

    const promotions =
      detectRoleTransitionPromotions(data);

    expect(promotions).toHaveLength(1);

    expect(promotions[0]).toMatchObject({
      promotionType: "role_transition",
      competence: "2026-07-01",
      fromPosition: "SDR",
      toPosition: "Closer",
      previousSeniority: "Júnior 1",
      nextSeniority: "Júnior 1",
    });

    expect(
      promotions[0].profile.perfil.nome_colaborador,
    ).toBe("Miguel");
  });

  it("considera promoção mesmo mantendo a senioridade", () => {
    const data = related(
      [
        profile("1", {
          posicao_atual: "Closer",
        }),
      ],
      [
        result(
          "r1",
          "1",
          "2026-06-01",
          {
            posicao: "SDR",
            senioridade: "Júnior 1",
            senioridade_informada: "Júnior 1",
          },
        ),
        result(
          "r2",
          "1",
          "2026-07-01",
          {
            posicao: "Closer",
            senioridade: "Júnior 1",
            senioridade_informada: "Júnior 1",
          },
        ),
      ],
    );

    expect(
      detectRoleTransitionPromotions(data),
    ).toHaveLength(1);
  });

  it("não considera SDR -> SDR promoção", () => {
    expect(
      isSdrToCloserTransition(
        { posicao: "SDR" },
        { posicao: "SDR" },
      ),
    ).toBe(false);
  });

  it("não considera Closer -> SDR promoção", () => {
    expect(
      isSdrToCloserTransition(
        { posicao: "Closer" },
        { posicao: "SDR" },
      ),
    ).toBe(false);
  });

  it("não considera SDR -> Parcerias promoção", () => {
    expect(
      isSdrToCloserTransition(
        { posicao: "SDR" },
        { posicao: "Parcerias" },
      ),
    ).toBe(false);
  });

  it("atribui a promoção à primeira competência como Closer", () => {
    const data = related(
      [
        profile("1", {
          posicao_atual: "Closer",
        }),
      ],
      [
        result(
          "r1",
          "1",
          "2026-05-01",
          { posicao: "SDR" },
        ),
        result(
          "r2",
          "1",
          "2026-06-01",
          { posicao: "SDR" },
        ),
        result(
          "r3",
          "1",
          "2026-07-01",
          { posicao: "Closer" },
        ),
        result(
          "r4",
          "1",
          "2026-08-01",
          { posicao: "Closer" },
        ),
      ],
    );

    const promotions =
      detectRoleTransitionPromotions(data);

    expect(promotions).toHaveLength(1);

    expect(
      promotions[0].competence,
    ).toBe("2026-07-01");
  });

  it("permite filtrar a promoção pela competência", () => {
    const data = related(
      [
        profile("1", {
          posicao_atual: "Closer",
        }),
      ],
      [
        result(
          "r1",
          "1",
          "2026-06-01",
          { posicao: "SDR" },
        ),
        result(
          "r2",
          "1",
          "2026-07-01",
          { posicao: "Closer" },
        ),
      ],
    );

    expect(
      detectRoleTransitionPromotions(
        data,
        "2026-07-01",
      ),
    ).toHaveLength(1);

    expect(
      detectRoleTransitionPromotions(
        data,
        "2026-08-01",
      ),
    ).toHaveLength(0);
  });
});
