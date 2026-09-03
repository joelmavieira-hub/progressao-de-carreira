import { ArrowRight, Award, Rocket } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { formatarCompetencia, formatarEtapaProgresso } from "@/lib/progression";
import { formatarSquadAtual } from "../../domain";
import { squadForCompetence, type PromotionView } from "../../domain/analytics";
import type { PerfilComHistorico } from "../../types";
import { SdrBonusBadge } from "../shared/SdrBonusBadge";

export function DashboardLists({ nearPromotion, recentPromotions, competence, onOpen, onNavigate }: {
  nearPromotion: PerfilComHistorico[];
  recentPromotions: PromotionView[];
  competence: string;
  onOpen: (item: PerfilComHistorico) => void;
  onNavigate: (focus: "meta3" | "promoted") => void;
}) {
  return <div role="region" aria-label="Painéis de acompanhamento" className="mx-auto grid w-full items-stretch grid-cols-1 gap-4 md:grid-cols-2 lg:gap-5">
    <ListCard title="Próximos da promoção" icon={Rocket} action={() => onNavigate("meta3")} testId="near-promotion-list">
      {nearPromotion.length === 0 ? <Empty /> : nearPromotion.slice(0, 5).map((item) => {
        const squad = squadForCompetence(
          item,
          competence,
        );

        return <ProfileRow
          key={item.perfil.id}
          item={item}
          onOpen={onOpen}
          detail={`${squad ? formatarSquadAtual(squad) : "Squad não informado"} · ${item.perfil.senioridade_atual ?? "Não informada"}`}
          badge={formatarEtapaProgresso(2)}
        />;
      })}
    </ListCard>
    <ListCard title="Promovidos recentemente" icon={Award} action={() => onNavigate("promoted")} testId="recent-promotions-list">
      {recentPromotions.length === 0 ? <Empty /> : recentPromotions.slice(0, 5).map((promotion) => {
        const { profile, result, previousSeniority, nextSeniority } = promotion;
        const isRoleTransition = promotion.promotionType === "role_transition";
        const detail = isRoleTransition
          ? `${result.competencia ? formatarCompetencia(result.competencia) : "Sem competência"} · ${promotion.fromPosition ?? "SDR"} → ${promotion.toPosition ?? "Closer"}`
          : `${result.competencia ? formatarCompetencia(result.competencia) : "Sem competência"} · ${previousSeniority} → ${nextSeniority}`;

        return <ProfileRow
          key={`${promotion.promotionType}-${result.id}`}
          item={profile}
          onOpen={onOpen}
          detail={detail}
          badge={isRoleTransition ? "Promoção de função" : "Promoção de senioridade"}
        />;
      })}
    </ListCard>
  </div>;
}

function ListCard({ title, icon: Icon, action, testId, children }: { title: string; icon: React.ComponentType<{ className?: string }>; action?: () => void; testId: string; children: React.ReactNode }) {
  return <Card data-testid={testId} className="flex h-full flex-col overflow-hidden"><CardHeader className="flex flex-row items-center justify-between space-y-0 border-b bg-muted/25 pb-4"><CardTitle className="flex items-center gap-2 text-base"><Icon aria-hidden="true" className="h-4 w-4 text-primary" />{title}</CardTitle>
    {action && <Button variant="ghost" size="sm" onClick={action}>Ver todos<ArrowRight aria-hidden="true" className="ml-1 h-3.5 w-3.5" /></Button>}</CardHeader><CardContent className="flex-1 divide-y p-0">{children}</CardContent></Card>;
}

function ProfileRow({ item, detail, badge, onOpen }: { item: PerfilComHistorico; detail: string; badge: string; onOpen: (item: PerfilComHistorico) => void }) {
  return <div className="flex items-start justify-between gap-3 p-4"><div className="min-w-0"><p className="truncate text-sm font-semibold">{item.perfil.nome_colaborador}</p><p className="mt-1 text-xs text-muted-foreground">{detail}</p>
    <Button variant="link" className="h-auto p-0 pt-2 text-xs" onClick={() => onOpen(item)}>Ver histórico</Button></div><div className="flex max-w-36 flex-wrap justify-end gap-1.5"><Badge variant="secondary" className="whitespace-normal text-center">{badge}</Badge>
      <SdrBonusBadge profile={item.perfil} /></div></div>;
}

function Empty() { return <div role="status" className="p-6 text-center text-sm text-muted-foreground">Nenhum registro para os filtros selecionados.</div>; }
