---
phase: 04-client-calendar-portal
plan: 03
subsystem: ui
tags: [rails, tdd, activestorage, tailwind, security, idor-prevention, pt-BR]

# Dependency graph
requires:
  - phase: 04-client-calendar-portal
    plan: 01
    provides: "layouts/client.html.erb, locale pt-BR, client_arte_path route"
  - phase: 04-client-calendar-portal
    plan: 02
    provides: "_arte_status_badge partial, _platform_icon partial, ClientController auth chain"

provides:
  - Client::ArtesController#show com escopo de segurança @client.artes.find(params[:id])
  - rescue ActiveRecord::RecordNotFound → redirect para calendário (arte inexistente ou de outro cliente)
  - Preview de arte por media_type: imagem (rails_blob_path), vídeo (rails_service_blob_proxy_path), caption_only, external_url
  - Botão "Abrir arquivo" target=_blank rel=noopener noreferrer para external_url (sem iframe — D-12)
  - Metadados: plataforma (ícone SVG + nome PT-BR), data agendada (I18n.l), approval_deadline, status badge
  - 4 testes cobrindo CAL-03, isolamento cross-client (IDOR prevention), sem auth, arte inexistente

affects: [fase 5 — botões de aprovação usarão este controller como base]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "@client.artes.find(params[:id]) com rescue ActiveRecord::RecordNotFound — padrão de segurança cross-client"
    - "rails_blob_path(media_file, disposition: 'inline') para imagens (URL assinada 5min)"
    - "rails_service_blob_proxy_path(media_file.blob) para vídeos (sem expiração)"
    - "Prioridade external_url > media_type na renderização condicional da view"
    - "case/when inline em <%=...%> para nomes PT-BR de plataforma (evita sintaxe ERB problemática)"

key-files:
  created:
    - app/controllers/client/artes_controller.rb
    - app/views/client/artes/show.html.erb
    - test/controllers/client/artes_controller_test.rb
  modified: []

key-decisions:
  - "rails_service_blob_proxy_path para vídeos (não rails_blob_path) — evita expiração de 5min em vídeos pausados (Pitfall 4)"
  - "external_url renderiza botão 'Abrir arquivo', nunca iframe (D-12, T-04-03-03)"
  - "case/when embutido em <%=...%> em vez de multi-linha <% case %>/<% when %> — evita syntax error ERB"
  - "rescue ActiveRecord::RecordNotFound inline no set_arte (não como before_action separado) — padrão mais limpo"

patterns-established:
  - "Pattern: @client.artes.find com rescue → redirect — aplicar em todas as actions de arte no portal do cliente"
  - "Pattern: rails_service_blob_proxy_path para qualquer mídia que o usuário possa pausar/bufferar"

requirements-completed: [CAL-03, CAL-04, CAL-05]

# Metrics
duration: 2min
completed: 2026-05-26
---

# Phase 4 Plan 03: Arte Preview Summary

**Controller Client::ArtesController#show com escopo cross-client (@client.artes.find), view de preview por media_type (imagem, vídeo via proxy, legenda, link externo) e 4 testes TDD cobrindo acesso próprio, isolamento IDOR, sem auth e arte inexistente**

## Performance

- **Duration:** 2 min
- **Started:** 2026-05-26T02:18:32Z
- **Completed:** 2026-05-26T02:20:30Z
- **Tasks:** 2 (Task 1 TDD RED+GREEN, Task 2 view completa)
- **Files created:** 3

## Accomplishments

- `Client::ArtesController` criado com herança de `ClientController` (recebe `load_client_from_token` + `require_client_auth` automaticamente), `before_action :set_arte`, e `def set_arte` com `@client.artes.find(params[:id])` + rescue RecordNotFound
- View `show.html.erb` com renderização condicional por precedência: external_url → image → video → caption_only → fallback
- Botão "Abrir arquivo" com `target="_blank" rel="noopener noreferrer"` e ícone SVG de link externo — sem iframe (D-12)
- `<video controls>` com `rails_service_blob_proxy_path` para evitar expiração de URL em vídeos pausados (T-04-03-04)
- `image_tag rails_blob_path(media_file, disposition: "inline")` para imagens com URL assinada
- Metadados: ícone SVG de plataforma + nome PT-BR, data agendada formatada (`I18n.l` com locale pt-BR), `approval_deadline` condicional (CAL-04), badge de status reutilizado do plano 02
- Link de volta ao calendário via `client_root_path(token: @client.access_token)`
- 4 testes TDD: acesso à própria arte, isolamento cross-client (IDOR), sem autenticação, arte inexistente — todos verdes
- Suite completa: 61 testes, 0 falhas

## TDD Gate Compliance

- **RED:** `test/controllers/client/artes_controller_test.rb` criado com 4 testes → 4 errors (ActionDispatch::MissingController) confirmados — commit `2575d4c`
- **GREEN:** Controller + placeholder view criados → 4/4 testes passando — commit `95d6822`
- **REFACTOR:** View substituída pela implementação completa → testes continuam passando — commit `023bb9a`

## Task Commits

1. **Task 1 RED:** `2575d4c` — `test(04-03): add failing tests for Client::ArtesController (RED)`
2. **Task 1 GREEN:** `95d6822` — `feat(04-03): implement Client::ArtesController#show com escopo cross-client`
3. **Task 2:** `023bb9a` — `feat(04-03): preview de arte com renderização por media_type e isolamento cross-client`

## Files Created/Modified

- `app/controllers/client/artes_controller.rb` — Controller com `@client.artes.find` e rescue RecordNotFound
- `app/views/client/artes/show.html.erb` — Preview completo: external_url botão, imagem, vídeo proxy, caption_only, metadados
- `test/controllers/client/artes_controller_test.rb` — 4 testes TDD cobrindo CAL-03 e isolamento cross-client

## Decisions Made

- `rails_service_blob_proxy_path` para vídeos em vez de `rails_blob_path` — URL assinada expira em 5min, inadequada para vídeos que o cliente pode pausar
- `case/when` embutido em `<%= ... %>` para nomes PT-BR de plataforma — sintaxe `<% case %>` / `<% when %>` em ERB causou `SyntaxError` (auto-fixed, Rule 1)
- Sem iframe para external_url — decisão D-12 e T-04-03-03 explicitamente proíbem

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Syntax error em ERB com case/when multi-linha**
- **Found during:** Task 2, primeira execução dos testes após escrever a view
- **Issue:** `<% case @arte.platform %> <% when 'instagram' %>Instagram` causou `SyntaxError: unexpected instance variable, expecting 'when'` — Ruby parser não aceita este formato quando há ERB entre `case` e `when`
- **Fix:** Refatorado para `<%= case @arte.platform; when 'instagram' then 'Instagram'; ... end %>` em bloco único
- **Files modified:** `app/views/client/artes/show.html.erb`
- **Commit:** `023bb9a`

## Known Stubs

Nenhum — todas as funcionalidades especificadas estão implementadas.

## Threat Flags

Nenhum novo risco de segurança identificado além do threat model do plano.
- T-04-03-01 (IDOR): mitigado via `@client.artes.find` com teste explícito
- T-04-03-02 (external_url): mitigado via `target="_blank" rel="noopener noreferrer"`
- T-04-03-03 (iframe): mitigado — view não contém `<iframe`
- T-04-03-04 (vídeo URL): mitigado via `rails_service_blob_proxy_path`

## Self-Check: PASSED

- `app/controllers/client/artes_controller.rb` existe: FOUND
- `app/views/client/artes/show.html.erb` existe: FOUND
- `test/controllers/client/artes_controller_test.rb` existe: FOUND
- Commit `2575d4c` (RED): FOUND
- Commit `95d6822` (GREEN): FOUND
- Commit `023bb9a` (Task 2): FOUND
- `grep "@client.artes.find"` → 1 match: CONFIRMED
- `grep -i "iframe"` → 0 matches: CONFIRMED
- `grep "noopener"` → 1 match: CONFIRMED
- `grep "approval_deadline"` → 1 match: CONFIRMED
- `grep "platform_icon\|arte_status_badge"` → 2 matches: CONFIRMED
- `bundle exec rails test` → 61 testes, 0 falhas: CONFIRMED

---
*Phase: 04-client-calendar-portal*
*Completed: 2026-05-26*
