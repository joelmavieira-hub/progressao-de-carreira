import type {
  ColaboradorResultado,
  PerfilComHistorico,
} from "../types";

export type CareerPromotionType =
  | "seniority"
  | "role_transition";

export interface CareerRolePromotion {
  promotionType: "role_transition";
  profile: PerfilComHistorico;
  previousResult: ColaboradorResultado;
  result: ColaboradorResultado;
  competence: string | null;
  fromPosition: string | null;
  toPosition: string | null;
  previousSeniority: string | null;
  nextSeniority: string | null;
}

function normalizePosition(
  value: string | null | undefined,
): string {
  return (value ?? "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .trim()
    .replace(/\s+/g, " ")
    .toLocaleLowerCase("pt-BR");
}

/**
 * Regra oficial de promoção de função:
 *
 * SDR -> Closer = promoção.
 *
 * Outras mudanças de posição não são consideradas promoção.
 */
export function isSdrToCloserTransition(
  previous: Pick<ColaboradorResultado, "posicao">,
  current: Pick<ColaboradorResultado, "posicao">,
): boolean {
  return (
    normalizePosition(previous.posicao) === "sdr" &&
    normalizePosition(current.posicao) === "closer"
  );
}

function compareResults(
  a: ColaboradorResultado,
  b: ColaboradorResultado,
): number {
  return (
    (a.competencia ?? "9999-12-31").localeCompare(
      b.competencia ?? "9999-12-31",
    ) ||
    a.id.localeCompare(b.id)
  );
}

/**
 * Detecta promoções SDR -> Closer usando a posição histórica
 * registrada em cada competência.
 *
 * A competência da promoção é a primeira competência em que
 * o colaborador aparece como Closer imediatamente após seu
 * último registro como SDR.
 */
export function detectRoleTransitionPromotions(
  profiles: readonly PerfilComHistorico[],
  competence?: string,
): CareerRolePromotion[] {
  const promotions: CareerRolePromotion[] = [];

  for (const profile of profiles) {
    const history = [...profile.resultados].sort(compareResults);

    for (let index = 1; index < history.length; index += 1) {
      const previousResult = history[index - 1];
      const result = history[index];

      if (!isSdrToCloserTransition(previousResult, result)) {
        continue;
      }

      if (
        competence &&
        result.competencia !== competence
      ) {
        continue;
      }

      promotions.push({
        promotionType: "role_transition",
        profile,
        previousResult,
        result,
        competence: result.competencia,
        fromPosition: previousResult.posicao,
        toPosition: result.posicao,
        previousSeniority:
          previousResult.senioridade_informada ??
          previousResult.senioridade,
        nextSeniority:
          result.senioridade_informada ??
          result.senioridade,
      });
    }
  }

  return promotions.sort(
    (a, b) =>
      (b.competence ?? "").localeCompare(
        a.competence ?? "",
      ) ||
      a.profile.perfil.nome_normalizado.localeCompare(
        b.profile.perfil.nome_normalizado,
        "pt-BR",
      ),
  );
}
