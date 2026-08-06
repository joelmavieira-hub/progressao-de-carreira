import { Badge } from "@/components/ui/badge";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { formatarCompetencia, formatarEtapaProgresso } from "@/lib/progression";
import { formatarSquadAtual } from "../../domain";
import type { PerfilComHistorico } from "../../types";

export function ProfileHistoryDialog({ item, onClose }: { item: PerfilComHistorico | null; onClose: () => void }) {
  return <Dialog open={Boolean(item)} onOpenChange={(open) => { if (!open) onClose(); }}><DialogContent className="max-h-[88vh] max-w-5xl overflow-y-auto">
    {item && <><DialogHeader><DialogTitle>{item.perfil.nome_colaborador}</DialogTitle>
      <DialogDescription>{item.perfil.ativo ? "Ativo" : "Inativo"} · {item.perfil.posicao_atual ?? "Posição não informada"} · {formatarSquadAtual(item.perfil.squad_atual)}</DialogDescription></DialogHeader>
      <div className="flex flex-wrap gap-2"><Badge variant="secondary">{item.perfil.senioridade_atual ?? "Senioridade não informada"}</Badge>
        <Badge variant="outline">{formatarEtapaProgresso(item.perfil.progresso_meta3)}</Badge></div>
      <div className="overflow-x-auto"><Table><TableHeader><TableRow><TableHead>Competência</TableHead><TableHead>Meta</TableHead><TableHead>Senioridade histórica</TableHead><TableHead>Senioridade informada</TableHead><TableHead>Squad histórico</TableHead><TableHead>Posição histórica</TableHead><TableHead>Promoção</TableHead></TableRow></TableHeader>
        <TableBody>{item.resultados.map((row) => <TableRow key={row.id}><TableCell>{row.competencia ? formatarCompetencia(row.competencia) : "Não informada"}</TableCell>
          <TableCell>{row.meta_alcancada ?? "Não informada"}</TableCell><TableCell>{row.senioridade ?? "Não informada"}</TableCell>
          <TableCell>{row.senioridade_informada ?? "Não informada"}</TableCell><TableCell>{row.squad ?? "Não informado"}</TableCell>
          <TableCell>{row.posicao ?? "Não informada"}</TableCell><TableCell>{row.recebeu_promocao ? "Sim" : "Não"}</TableCell></TableRow>)}</TableBody>
      </Table></div></>}
  </DialogContent></Dialog>;
}
