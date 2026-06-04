# Phase 13: Página Aprovações - Context

**Gathered:** 2026-06-04
**Status:** Ready for planning

<domain>
## Phase Boundary

Criar a página `/admin/approvals` no painel admin: lista paginada de todas as respostas de aprovação (`ApprovalResponse`) de todos os clientes, com filtros por cliente e por decision, e wiring do link "Aprovações" no sidebar (atualmente aponta para `#`).

</domain>

<decisions>
## Implementation Decisions

### Filtro de Status (APRO-06)
- **D-01:** O filtro "por status" filtra pelo campo `decision` de `ApprovalResponse` — duas opções no dropdown: **Aprovado** (`approved`) e **Pediu Alteração** (`change_requested`). Não filtrar por `Arte.status`.

### Layout da Lista (APRO-04)
- **D-02:** Lista **plana e cronológica** — uma linha por resposta, ordenada da mais recente para a mais antiga (`responded_at DESC`). Sem agrupamento por cliente ou por arte.
- **D-03:** Paginação com **pagy** (já no Gemfile), **25 itens por página**.

### Claude's Discretion
- Nome do controller/rota: usar `Admin::ApprovalsController` com `resources :approvals` → URL `/admin/approvals`.
- Padrão de filtros com Turbo Frame (já estabelecido no dashboard Phase 6) — replicar o mesmo padrão: form fora do turbo-frame, `data: { turbo_frame: "approvals-content" }`.
- Visual padrão de tabela: `thead` formatado com colunas em uppercase, `hover:bg-slate-50` nas linhas — padrão Phase 11.
- Coluna "status" em APRO-05 exibe o `decision` da response (não o status atual da arte).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Padrão de filtros Turbo Frame (referência)
- `app/controllers/admin/dashboard_controller.rb` — filtros com `client_id` e `status` params; replicar lógica de scope
- `app/views/admin/dashboard/index.html.erb` — padrão de form fora do turbo-frame + `turbo-frame` com id; replicar para aprovações

### Modelo e schema
- `app/models/approval_response.rb` — campos: `decision` (enum: approved/change_requested), `comment`, `responded_at`; `belongs_to :arte`
- `app/models/arte.rb` — `belongs_to :client`, `has_many :approval_responses`; enum `status`
- `db/schema.rb` — tabela `approval_responses`: arte_id, decision (int), comment (text), responded_at (datetime)

### Sidebar e navegação
- `app/views/admin/shared/_sidebar.html.erb` — link "Aprovações" atualmente `#`; deve apontar para `admin_approvals_path`

### Padrão visual de tabela
- `app/views/admin/artes/index.html.erb` — thead formatado, hover nas linhas, botão "Ver" outline (padrão Phase 11)

### Paginação
- `Gemfile` — `gem "pagy", "~> 9.3"` já presente; verificar se `include Pagy::Backend` já está em `ApplicationController` ou `Admin::BaseController`

### Rotas
- `config/routes.rb` — adicionar `resources :approvals, only: [:index]` dentro do namespace `admin`

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `app/views/admin/shared/_sidebar.html.erb`: alterar apenas a linha `{ label: "Aprovações", path: "#" }` para `{ label: "Aprovações", path: admin_approvals_path }`
- `client/shared/arte_status_badge` partial: pode ser reutilizado para exibir o decision da response com badge colorida (ou criar variante para `decision`)
- `Admin::BaseController`: verificar se `include Pagy::Backend` precisa ser adicionado aqui

### Established Patterns
- Filtros com Turbo Frame: form fora do frame submete via GET com `data: { turbo_frame: "..." }`; conteúdo da tabela fica dentro do `turbo-frame`
- Queries escopadas: garantir que `ApprovalResponse.joins(:arte => :client)` inclua os dados necessários sem N+1
- Tabela admin: thead uppercase `text-xs font-semibold text-slate-500`, tbody `divide-y divide-gray-100`, rows `hover:bg-slate-50`

### Integration Points
- Sidebar link "Aprovações" → `admin_approvals_path` (nova rota)
- Link APRO-07 "ver arte" → `admin_arte_path(arte)` (rota já existente)
- `ApprovalResponse` → `arte` → `client` (join necessário para exibir nome do cliente e filtrar)

</code_context>

<specifics>
## Specific Ideas

- APRO-05 colunas na tabela: **Cliente** | **Arte** | **Status** (decision badge) | **Data da resposta** | **Comentário** | **Ações** (link "Ver arte")
- Comentário: exibir truncado se longo (ex: 80 chars), ou vazio se `nil`
- Data da resposta: formato `dd/mm/YYYY` (padrão usado no dashboard)

</specifics>

<deferred>
## Deferred Ideas

Nenhuma — discussão manteve-se dentro do escopo da fase.

</deferred>

---

*Phase: 13-Página Aprovações*
*Context gathered: 2026-06-04*
