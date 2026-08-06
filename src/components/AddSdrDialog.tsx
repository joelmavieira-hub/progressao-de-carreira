/** @deprecated Legacy direct-management dialog; stage 1 keeps the UI analytical. */
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger, DialogFooter } from "@/components/ui/dialog";
import { Plus } from "lucide-react";
import { SENIORITIES, type Level } from "@/lib/progression";

type Squad = "LOBO" | "ÁGUIA";

interface AddSdrDialogProps {
  defaultSquad: Squad;
  onCreate: (input: { name: string; level: Level; squad: Squad; avatarColor: string }) => void | Promise<void>;
}

const COLOR_POOL = [
  "262 83% 58%",
  "270 95% 65%",
  "222 47% 11%",
  "142 71% 45%",
];

export function AddSdrDialog({ defaultSquad, onCreate }: AddSdrDialogProps) {
  const [open, setOpen] = useState(false);
  const [name, setName] = useState("");
  const [level, setLevel] = useState<Level>("Júnior 1");
  const [squad, setSquad] = useState<Squad>(defaultSquad);

  const handleCreate = async () => {
    if (!name.trim()) return;
    const color = COLOR_POOL[Math.floor(Math.random() * COLOR_POOL.length)];
    await onCreate({ name: name.trim(), level, squad, avatarColor: color });
    setName("");
    setLevel("Júnior 1");
    setSquad(defaultSquad);
    setOpen(false);
  };

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button
          size="sm"
          variant="outline"
          className="gap-1.5 text-[10px] font-bold uppercase tracking-wider"
        >
          <Plus className="h-3.5 w-3.5" />
          Adicionar SDR
        </Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle className="font-display">Adicionar SDR</DialogTitle>
        </DialogHeader>
        <div className="space-y-4 py-2">
          <div className="space-y-1.5">
            <label className="text-[10px] font-bold uppercase tracking-wider text-muted-foreground">Nome</label>
            <Input value={name} onChange={(e) => setName(e.target.value)} placeholder="Nome completo" />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1.5">
              <label className="text-[10px] font-bold uppercase tracking-wider text-muted-foreground">Nível</label>
              <Select value={level} onValueChange={(v) => setLevel(v as Level)}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {SENIORITIES.map((l) => (
                    <SelectItem key={l} value={l}>{l}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-1.5">
              <label className="text-[10px] font-bold uppercase tracking-wider text-muted-foreground">Squad</label>
              <Select value={squad} onValueChange={(v) => setSquad(v as Squad)}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  <SelectItem value="LOBO">LOBO</SelectItem>
                  <SelectItem value="ÁGUIA">ÁGUIA</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>
        </div>
        <DialogFooter>
          <Button onClick={handleCreate} disabled={!name.trim()}>Criar</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
