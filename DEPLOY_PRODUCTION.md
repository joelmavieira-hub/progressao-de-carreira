# Publicação de produção na Vercel

Este projeto possui somente desenvolvimento local e produção remota. Não existe ambiente remoto de Preview, Development, QA, homologação ou staging, nem banco de teste.

## Configuração obrigatória

- Environment: somente `Production`.
- Framework Preset: `Vite`.
- Root Directory: raiz deste projeto.
- Install Command: `npm ci`.
- Build Command: `npm run build`.
- Output Directory: `dist`.
- Node.js Version: `24.x`.
- Production Branch: `main`, caso o repositório utilize esse nome.

Adicionar exclusivamente ao ambiente `Production`:

- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_PUBLISHABLE_KEY`

Não configurar essas variáveis em `Preview`, `Development` ou Custom Environment. Não registrar seus valores em arquivos, documentação ou logs.

## Política de publicação

- Validar localmente instalação, testes, lint, typecheck, build e leitura do Supabase antes de cada publicação.
- O único comando permitido para uma publicação manual é `vercel --prod`.
- É proibido executar `vercel` sem `--prod`, `vercel deploy`, `vercel dev` ou deploy de branch auxiliar.
- Se houver integração Git, desabilitar Preview Deployments e permitir publicação somente pela Production Branch.
- O deploy utiliza os dados reais do Supabase e qualquer publicação afeta usuários reais.
- Não configurar banco de teste, domínio personalizado ou DNS nesta etapa.

Após o primeiro deploy de produção autorizado, validar a URL gerada pela Vercel antes de configurar qualquer domínio personalizado.
