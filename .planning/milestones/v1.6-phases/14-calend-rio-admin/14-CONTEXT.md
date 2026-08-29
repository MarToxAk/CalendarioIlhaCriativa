# Phase 14: Calendário Admin - Context

**Gathered:** 2026-06-04
**Status:** Ready for planning

<domain>
## Phase Boundary

Criar `Admin::CalendarController#index` — calendário mensal no painel admin que exibe artes de todos os clientes distribuídas nos dias corretos, diferenciadas por cor e iniciais do cliente, com navegação entre meses via Turbo Frame e link direto para cada arte. Wiring do link "Calendário" no sidebar (atualmente `#`).

</domain>

<decisions>
## Implementation Decisions

### D-01: Cores por cliente
- Paleta automática baseada no índice do cliente: `client.id % palette_size` → cor da paleta. **Sem migration.**
- Helper `client_color(client)` em `ApplicationHelper` — retorna par de classes Tailwind (fundo suave + texto escuro), ex: `{ bg: "bg-[#F0FDF4]", text: "text-[#14A958]" }`.
- Paleta com 8 cores distintas e acessíveis (fundo suave + texto escuro, estilo badges existentes do design system).

### D-02: Navegação entre meses
- **Turbo Frame** — setas de navegação e título do mês ficam FORA do turbo-frame; grade do calendário fica DENTRO. Padrão Phase 6/13.
- Layout: `[← seta] [Mês Ano] [seta →]` no cabeçalho da página, acima do turbo-frame.
- Frame id: `"calendar-content"` (padrão do projeto).

### D-03: Chip de arte na célula do dia
- Cada arte exibe: **fundo colorido do cliente + iniciais do cliente (2 chars)**, sem informações adicionais.
- Chip é um `link_to admin_arte_path(arte)` — clique leva ao show da arte (CADM-05).
- Sem ícone de plataforma, sem título da arte no chip.

### D-04: Overflow de artes por dia
- Mostrar **máximo 3 chips** por célula; se houver mais, exibir contador `+N` em cinza.
- O `+N` é texto estático (não clicável) nesta fase. Modal/expansão é funcionalidade futura.
- Ordenação dos chips: por `id` (insertion order) — sem ordenação especial.

### Claude's Discretion
- Nome do controller/rota: `Admin::CalendarController`, rota `resources :calendar, only: [:index]` → URL `/admin/calendar`.
- Wiring do sidebar: alterar `{ label: "Calendário", path: "#" }` para `{ label: "Calendário", path: admin_calendar_index_path }`.
- Altura mínima das células: `min-h-[80px]` para manter grid consistente independente do conteúdo.
- Paleta de 8 cores sugerida (fundo/texto): verde, azul, roxo, laranja, rosa, teal, amarelo, índigo — adaptar ao design system.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Calendário existente (referência principal)
- `app/views/client/home/_month_calendar.html.erb` — grade 7 colunas, lógica de células, iteração por data; adaptar para admin (cores por cliente em vez de status)
- `app/controllers/client/home_controller.rb` — padrão de parse_month_param, cálculo de grid_start/grid_end, agrupamento por data; replicar para admin

### Padrão Turbo Frame (navegação)
- `app/views/admin/approvals/index.html.erb` — padrão de filtros fora do frame, turbo-frame envolvendo conteúdo (Phase 13, mais recente)
- `app/views/admin/dashboard/index.html.erb` — padrão original Phase 6

### Sidebar e rota
- `app/views/admin/shared/_sidebar.html.erb` — link "Calendário" linha 16, atualmente `path: "#"`; alterar para `admin_calendar_index_path`
- `config/routes.rb` — adicionar `resources :calendar, only: [:index]` dentro do namespace admin

### Models e schema
- `app/models/arte.rb` — `belongs_to :client`, campo `scheduled_on` (date), enum `status`
- `app/models/client.rb` — campos: id, name, active; sem campo color
- `db/schema.rb` — confirmar tipos de `scheduled_on` e ausência de `color` em clients

### Helper de cor
- `app/helpers/application_helper.rb` — adicionar `client_color(client)` aqui (já tem `include Pagy::Frontend`)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `app/views/client/home/_month_calendar.html.erb`: grade 7 colunas reutilizável — adaptar `artes_do_dia.each` para incluir `link_to admin_arte_path` e chips coloridos por cliente
- `parse_month_param` (client/home_controller): lógica de parsing de `?month=YYYY-MM` — copiar para Admin::CalendarController
- `grid_start/grid_end` pattern: `beginning_of_week`/`end_of_month.end_of_week` já validado

### Established Patterns
- Turbo Frame: `<turbo-frame id="calendar-content">` envolve a grade; links de setas usam `data: { turbo_frame: "calendar-content" }` para atualização parcial
- Cores hex arbitrárias: projeto usa `bg-[#HEX]` e `text-[#HEX]` — manter mesmo padrão para a paleta de clientes
- Células com altura mínima: calendário do cliente usa `min-h-[100px]` — usar `min-h-[80px]` para admin (chips menores)

### Integration Points
- Sidebar `{ label: "Calendário", path: "#" }` → `admin_calendar_index_path`
- Chip link_to → `admin_arte_path(arte)` (rota já existente desde Phase 3)
- Query: `Arte.where(scheduled_on: grid_start..grid_end).includes(:client).order(:scheduled_on)` — sem N+1

</code_context>

<specifics>
## Specific Ideas

- Iniciais do cliente: `client.name.split.map(&:first).first(2).join.upcase` — ex: "Ilha Livia" → "IL", "Mercado Verde" → "MV"
- Paleta de 8 cores (par fundo/texto, mesma linguagem dos badges existentes):
  1. `bg-[#F0FDF4] / text-[#14A958]` — verde (já no design system)
  2. `bg-[#EFF6FF] / text-[#2563EB]` — azul
  3. `bg-[#FAF5FF] / text-[#7C3AED]` — roxo
  4. `bg-[#FFF7ED] / text-[#EA580C]` — laranja
  5. `bg-[#FFF0F3] / text-[#E11D48]` — rosa
  6. `bg-[#F0FDFA] / text-[#0D9488]` — teal
  7. `bg-[#FEFCE8] / text-[#CA8A04]` — amarelo
  8. `bg-[#EEF2FF] / text-[#4F46E5]` — índigo

</specifics>

<deferred>
## Deferred Ideas

- Clique no `+N` para expandir artes do dia (modal ou página) — fase futura
- Admin escolher cor de cada cliente manualmente (campo `color` na tabela) — fase futura
- Chips com ícone de plataforma (Instagram/Facebook/LinkedIn) — fase futura

</deferred>

---

*Phase: 14-Calendário Admin*
*Context gathered: 2026-06-04*
