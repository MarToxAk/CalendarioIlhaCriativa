# Phase 4: Client Calendar Portal - Context

**Gathered:** 2026-05-25
**Status:** Ready for planning

<domain>
## Phase Boundary

O cliente acessa o próprio calendário pelo link único, autentica com a senha simples (já implementado na Fase 1), e visualiza todas as artes do mês atual em uma grade 7 colunas. Pode navegar entre meses via parâmetro URL, clicar em uma arte para ver o preview completo em página dedicada, e ver status (Pendente/Aprovado/Pediu Alteração) e prazo de cada arte.

Requirements: CAL-01, CAL-02, CAL-03, CAL-04, CAL-05.

Ações de aprovação (Aprovar / Pedir Alteração) são da Fase 5 — fora do escopo desta fase.

</domain>

<decisions>
## Implementation Decisions

### Layout do Portal do Cliente

- **D-01:** Criar `app/views/layouts/client.html.erb` como layout dedicado para o portal do cliente — equivalente ao `layouts/admin.html.erb` do admin. `ClientController` declara `layout 'client'` (herdado por todos os controllers filhos).
- **D-02:** Header do layout: logo/brand à esquerda (`Ilha Criativa · Bom Custo`), nome do cliente ao centro ou direita, botão "Sair" (link para `client_session_path` com DELETE).
- **D-03:** A tela de login (`app/views/client/sessions/new.html.erb`) é refatorada para usar o novo `layouts/client.html.erb` — elimina o HTML inline duplicado (DOCTYPE, head, meta tags). A view passa a ser só o conteúdo do card de login.
- **D-04:** Fundo do portal: `bg-white` — diferencia visualmente do admin (`bg-gray-50`) e mantém consistência com a tela de login atual.

### Estrutura do Grid Mensal

- **D-05:** Grid CSS 7 colunas (Seg–Dom) — padrão clássico de calendário. Cabeçalho com abreviações dos dias da semana. Cada célula = um dia do mês.
- **D-06:** Dias sem artes agendadas: exibir com opacidade reduzida (número do dia em `text-gray-300` ou `text-gray-200`) — diferencia visualmente dias com e sem conteúdo, mantém a grade completa do mês.
- **D-07:** Múltiplas artes no mesmo dia: empilhadas verticalmente na célula. A célula cresce para acomodar (sem truncamento por `+N mais`).
- **D-08:** Cada arte na grade: bloco compacto com **ícone SVG da plataforma** (Instagram/Facebook/LinkedIn) + **badge de status** colorido (reutilizar lógica de badge existente adaptada para o portal). Claude define copywriting e tamanho dos blocos.

### Preview de Arte (Detalhe)

- **D-09:** Página separada `/c/:token/artes/:id` — novo `Client::ArtesController` com action `show`. Link da arte na grade aponta para `client_arte_path(token: @client.access_token, id: arte)`. URL compartilhável, botão Voltar do browser retorna ao calendário.
- **D-10:** Renderização por `media_type`:
  - `image` + arquivo local: tag `<img>` com URL assinada do ActiveStorage
  - `video` + arquivo local: tag `<video controls>` com URL assinada do ActiveStorage
  - `caption_only`: texto da legenda formatado (sem mídia)
  - Qualquer tipo + `external_url`: botão "Abrir arquivo" (`target="_blank" rel="noopener"`) — sem iframe (iframes do Drive/Dropbox são instáveis)
- **D-11:** Metadados exibidos ao cliente: plataforma (ícone + nome), data agendada, prazo de aprovação, status atual (badge), legenda/texto. Sem dados de admin (título interno) se não for relevante para o cliente — Claude decide o que expor.
- **D-12:** Link externo: **botão "Abrir arquivo"** que abre em nova aba. Nunca iframe.

### Navegação entre Meses

- **D-13:** Parâmetro URL `?month=YYYY-MM` — controller valida e parseia. Funciona sem JS, permite bookmark e compartilhamento.
- **D-14:** Sem parâmetro `?month`: exibir **mês corrente** por padrão (`Date.today.beginning_of_month`).
- **D-15:** Sem limite de navegação — cliente pode ir para qualquer mês. Meses sem artes aparecem com a grade vazia.
- **D-16:** Navegador de mês no cabeçalho acima do grid: **`< Maio 2026 >`** — seta "Anterior" à esquerda, mês/ano centralizados, seta "Próximo" à direita. Setas são links para a mesma rota com `?month` ajustado.

### Claude's Discretion

- Estrutura interna do `Client::ArtesController` — strong params (nenhum, só leitura), before_action, escopo de segurança (arte deve pertencer a `@client`).
- Copywriting PT-BR dos estados e labels no portal do cliente.
- Responsividade mobile da grade — quantas colunas colapsar, tamanho mínimo das células.
- Estilo exato dos blocos de arte na grade (padding, border-radius, truncamento de texto se o título aparecer).
- Número de linhas de semana necessárias por mês (5 ou 6 linhas dependendo do mês).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Auth e Base do Portal

- `app/controllers/client_controller.rb` — Base do portal: `load_client_from_token`, `require_client_auth`. Todos os controllers do cliente herdam daqui.
- `app/controllers/client/sessions_controller.rb` — Auth por senha existente. Padrão de login/logout do portal.
- `app/controllers/client/home_controller.rb` — Stub atual (render plain). Esta fase o substitui pela view real do calendário.

### Modelos

- `app/models/arte.rb` — Enums `platform`, `media_type`, `status`. `has_one_attached :media_file`. `belongs_to :client`. Leitura obrigatória antes de qualquer view ou controller do cliente.
- `app/models/client.rb` — `has_secure_token :access_token`, `has_many :artes`. Relacionamento base.

### Rotas

- `config/routes.rb` — Rotas do portal do cliente: `/c/:token` namespace. Esta fase adiciona `resources :artes, only: [:show]` no scope do cliente.

### Padrões Visuais

- `.planning/phases/03-art-management/03-UI-SPEC.md` — Design tokens, badges de status, ícones de plataforma. Portal do cliente herda tokens e usa `#EA580C` (laranja) como acento (ao contrário do admin que usa `#0F7949`).
- `app/views/layouts/admin.html.erb` — Padrão de layout Rails para área dedicada. `layouts/client.html.erb` segue a mesma estrutura.
- `app/views/client/sessions/new.html.erb` — Layout atual da tela de login. Refatorar para usar o novo layout dedicado.

### Requisitos

- `.planning/REQUIREMENTS.md` — CAL-01 a CAL-05 mapeados para esta fase.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `app/views/admin/clients/_status_badge.html.erb` — Badge de status visual com cores. Adaptar para status de arte no portal do cliente (mesmas cores da UI-SPEC Phase 3: pending=amber, approved=green, change_requested=red, revised=slate).
- `app/javascript/controllers/` — Controllers Stimulus existentes: `modal`, `copy`, `dropdown`, `password_toggle`, `media_type_toggle`. Portal do cliente pode reutilizar qualquer um — `password_toggle` já usado na tela de login atual (inline, mas migrar para Stimulus).
- `app/views/layouts/admin.html.erb` — Estrutura de referência para criar `layouts/client.html.erb`.

### Established Patterns

- Escopo de segurança: todas as queries de arte devem ser `@client.artes.find(params[:id])` — nunca `Arte.find` direto. Mesmo padrão do admin (D-00 do STATE.md).
- Timezone Brasília: `Date.today` e cálculos de mês consideram `Time.zone` (já configurado na Phase 1).
- Design tokens via CSS custom properties em `application.css` — disponíveis no portal do cliente via `stylesheet_link_tag :app`.

### Integration Points

- `config/routes.rb` — Adicionar `resources :artes, only: [:show]` dentro do scope `/c/:token`.
- `ClientController` — Adicionar `layout 'client'` (ou declarar no `Client::BaseController` se extraído).
- `app/views/client/sessions/new.html.erb` — Refatorar para usar o novo layout Rails em vez de HTML inline.

</code_context>

<specifics>
## Specific Ideas

- Grade no padrão `< Maio 2026 >` (centralizado) com setas laterais — reconhecível imediatamente como navegador de calendário.
- Dias sem arte ficam esmaecidos (opacidade reduzida), não ocultos — cliente vê a grade completa do mês.
- Artes empilhadas na célula: cada arte é um bloco clicável com link para `/c/:token/artes/:id`.
- Preview de vídeo: usar `<video controls>` nativo — sem dependência de biblioteca externa.
- Link externo: botão "Abrir arquivo" com ícone de link externo (`target="_blank"`), não iframe.

</specifics>

<deferred>
## Deferred Ideas

- **Aprovação e pedido de alteração** — Fase 5. Os botões "Aprovar" e "Pedir Alteração" NÃO aparecem nesta fase.
- **Estado vazio personalizado por cliente** — Mensagem customizada quando o mês não tem artes. Claude decide o copywriting, mas não há lógica especial.
- **Resumo de status no topo** (ex: "3 aprovadas, 2 pendentes") — v2, ver REQUIREMENTS.md CAL2-01.
- **Notificações** — Out of scope v1.

</deferred>

---

*Phase: 4-client-calendar-portal*
*Context gathered: 2026-05-25*
