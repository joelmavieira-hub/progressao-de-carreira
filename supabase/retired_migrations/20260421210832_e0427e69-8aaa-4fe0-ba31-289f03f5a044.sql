-- Tabela de SDRs com histórico em JSONB
CREATE TABLE public.sdrs (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  level TEXT NOT NULL,
  squad TEXT NOT NULL,
  avatar_color TEXT NOT NULL DEFAULT '270 70% 60%',
  history JSONB NOT NULL DEFAULT '[]'::jsonb,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.sdrs ENABLE ROW LEVEL SECURITY;

-- Acesso público total (qualquer pessoa com o link pode ler/editar)
CREATE POLICY "Public read sdrs"
  ON public.sdrs FOR SELECT
  USING (true);

CREATE POLICY "Public insert sdrs"
  ON public.sdrs FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Public update sdrs"
  ON public.sdrs FOR UPDATE
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Public delete sdrs"
  ON public.sdrs FOR DELETE
  USING (true);

-- Trigger para updated_at
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER set_sdrs_updated_at
  BEFORE UPDATE ON public.sdrs
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- Realtime
ALTER TABLE public.sdrs REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.sdrs;