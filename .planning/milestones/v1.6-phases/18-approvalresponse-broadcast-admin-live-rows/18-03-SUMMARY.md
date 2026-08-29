---
phase: 18-approvalresponse-broadcast-admin-live-rows
plan: "03"
subsystem: model-broadcast-views
tags: [turbo-streams, hotwire, actioncable, broadcast, gap-closure, approval-response]
dependency_graph:
  requires:
    - partial:admin/shared/approval_toast (Plan 01)
    - partial:admin/shared/sidebar_badge (Plan 01)
    - partial:admin/dashboard/arte_dashboard_row (Plan 02)
    - partial:admin/approvals/approval_row (Plan 01)
    - channel:AdminNotificationsChannel (Phase 17)
  provides:
    - model:ApprovalResponse#broadcasts_to_admin-sem-turbo_stream-view_context
    - view:approvals-index-tbody-sempre-presente
    - fix:CR-01-nil-guard-arte_must_be_pending
    - fix:CR-02-badge-sempre-broadcast
    - fix:WR-01-arte-with-client-no-prepend
  affects:
    - app/models/approval_response.rb
    - app/views/admin/approvals/index.html.erb
    - test/models/approval_response_test.rb
tech_stack:
  added: []
  patterns:
    - ApplicationController.render(partial:, locals:, formats:[:html]) para renderizar partials em contexto AR
    - String interpolation para montar tags <turbo-stream> sem dependência de view_context
    - AdminNotificationsChannel.broadcast_to(admin, content_string) — broadcast como string HTML
    - Badge sempre incluído no broadcast (CR-02 — sem condicional por decision)
    - tbody vazio hidden como target DOM em estado vazio (GAP 1 / SC3)
key_files:
  created: []
  modified:
    - app/models/approval_response.rb
    - app/views/admin/approvals/index.html.erb
    - test/models/approval_response_test.rb
decisions:
  - "ApplicationController.render + string interpolation — API correta para renderizar partials em contexto AR sem view_context"
  - "turbo_stream_tag helper privado constrói a string <turbo-stream> diretamente — elimina dependência de ActionHelper no model"
  - "Badge sempre broadcast (CR-02) — badge pode decrementar quando arte sai de change_requested; broadcast incondicional é server-authoritative"
  - "tbody vazio hidden no branch empty — cirúrgico e mínimo; preserva UX do empty-state visível ao usuário"
  - "Stubs posicionais ->(user, content) substituem **kwargs — reflete a assinatura real de AdminNotificationsChannel.broadcast_to"
metrics:
  duration: "~9 minutes"
  completed: "2026-06-05T19:47:39Z"
  tasks_completed: 2
  files_changed: 3
---

# Phase 18 Plan 03: Gap Closure — Fix turbo_stream em model + tbody vazio — Summary

**One-liner:** broadcasts_to_admin reescrito com ApplicationController.render + string HTML sem turbo_stream.* de view_context; tbody#approvals-tbody presente em ambos os estados (vazio/com dados); testes E/F atualizados para 4 streams via scan (CR-02).

## O que foi feito

Este plano fecha os dois gaps críticos identificados na verificação e code review da Fase 18:

**GAP 2 (WARNING-01):** O método `broadcasts_to_admin` chamava `turbo_stream.append/replace/prepend` que requerem `view_context` disponível apenas em controllers/views. Em contexto AR (`after_create_commit`), essas chamadas levantariam `NoMethodError` em runtime. A solução reescreve o método usando `ApplicationController.render` para renderizar cada partial como HTML e string interpolation para montar as tags `<turbo-stream>`, enviando o HTML concatenado via `AdminNotificationsChannel.broadcast_to(admin, content)`.

**GAP 1 (SC3/RTUP-04 PARTIAL):** O `tbody#approvals-tbody` estava ausente da DOM quando a página Aprovações estava em estado vazio. O `turbo_stream.prepend("approvals-tbody", ...)` falharia silenciosamente pois o target não existiria. A solução adiciona um `<tbody id="approvals-tbody">` vazio dentro de uma `<table class="hidden">` no branch `if @approval_responses.empty?`, garantindo que o target sempre exista na DOM.

Adicionalmente:
- **CR-01:** nil guard `return unless arte` adicionado em `arte_must_be_pending`
- **CR-02:** badge agora é sempre broadcast (para `approved` e `change_requested`) — badge pode decrementar
- **WR-01:** `arte: arte_with_client` passado nos locals do prepend de `_approval_row`
- **WR-02:** `User.order(:id).first` para comportamento determinístico

## Tarefas Completadas

| # | Nome | Commit | Arquivos |
|---|------|--------|---------|
| 1 | Reescrever broadcasts_to_admin + atualizar testes E/F | `ee511ca` | `app/models/approval_response.rb`, `test/models/approval_response_test.rb` |
| 2 | tbody#approvals-tbody em ambos os branches da view | `2fc0149` | `app/views/admin/approvals/index.html.erb` |

## Arquivos Modificados

### `app/models/approval_response.rb`

- `after_create_commit :broadcasts_to_admin` adicionado
- `arte_must_be_pending` recebe nil guard `return unless arte` (CR-01)
- `broadcasts_to_admin` reescrito:
  - `User.order(:id).first` com guard `return unless admin` (WR-02)
  - `Arte.includes(:client).find(arte_id)` — eager-load (D-15)
  - `Arte.change_requested.count` — server-authoritative (D-11)
  - Método privado `render_partial_html` encapsula `ApplicationController.render`
  - Método privado `turbo_stream_tag` constrói string `<turbo-stream ...>`
  - 4 tags sempre geradas: toast (append), badge (replace — CR-02 sem condicional), dashboard (replace), approvals (prepend — WR-01 com arte: arte_with_client)
  - `AdminNotificationsChannel.broadcast_to(admin, content)` — posicional, não kwargs

### `test/models/approval_response_test.rb`

- Stubs C-G atualizados: `stub_fn = ->(user, content)` (posicional, reflete assinatura real)
- Test E atualizado: `content.scan(/<turbo-stream/).count == 4` (change_requested — 4 streams)
- Test F atualizado: `content.scan(/<turbo-stream/).count == 4` (approved — badge sempre — CR-02)
- Nomenclatura do Test F atualizada: "approved broadcast gera 4 turbo streams com badge"

### `app/views/admin/approvals/index.html.erb`

- `id="approvals-tbody"` adicionado no `<tbody>` do branch `else` (estado com dados)
- `<table class="hidden" aria-hidden="true"><tbody id="approvals-tbody"></tbody></table>` adicionado no branch `if @approval_responses.empty?` (estado vazio)
- 2 ocorrências de `approvals-tbody` — uma por branch, nunca simultâneas na DOM renderizada

## Deviations from Plan

### Auto-aplicadas (previstas no plano como parte do gap closure)

**1. [Plan 01 herdado] id="approvals-tbody" no tbody do branch else**
- O worktree foi criado a partir de um commit anterior ao Plan 01, então o `id="approvals-tbody"` no `<tbody>` do branch `else` ainda não estava aplicado
- Aplicado junto com a Task 2 (sem custo adicional, mesma mudança no mesmo arquivo)
- Arquivos modificados: `app/views/admin/approvals/index.html.erb`

## Observacoes de Ambiente

Os testes `bundle exec ruby -Itest test/models/approval_response_test.rb` não puderam ser executados por ausência de conexão com banco de dados PostgreSQL no ambiente de execução (erro: `ActiveRecord::DatabaseConnectionError — username: bot`). Verificações realizadas via:
- `ruby -c app/models/approval_response.rb` → "Syntax OK"
- `ruby -c test/models/approval_response_test.rb` → "Syntax OK"
- Todos os critérios de aceitação verificados por grep

## Known Stubs

Nenhum. Os partials referenciados em `broadcasts_to_admin` existem no repositório (criados pelos planos 01 e 02). O método privado `turbo_stream_tag` gera strings HTML reais, não placeholders.

## Threat Flags

Nenhuma nova superfície de segurança. As mitigações do threat_model do plano foram aplicadas:
- `ApplicationController.render` renderiza partials com dados já persistidos e validados (T-18-03-01)
- ERB auto-escapa os outputs dos partials — XSS prevenido (T-18-03-02)
- Nenhum novo pacote instalado (T-18-03-SC)

## Self-Check: PASSED

- [x] `app/models/approval_response.rb` — `return unless arte` presente (CR-01)
- [x] `app/models/approval_response.rb` — `turbo_stream.` ausente (0 ocorrências)
- [x] `app/models/approval_response.rb` — `ApplicationController.render` presente (1 ocorrência)
- [x] `app/models/approval_response.rb` — `AdminNotificationsChannel.broadcast_to` presente (1 ocorrência)
- [x] `app/models/approval_response.rb` — `after_create_commit :broadcasts_to_admin` presente (1 ocorrência)
- [x] `app/models/approval_response.rb` — badge sem condicional `if decision == "change_requested"` (CR-02)
- [x] `app/models/approval_response.rb` — `User.order(:id).first` presente (WR-02)
- [x] `app/models/approval_response.rb` — `arte: arte_with_client` no locals de approvals-tbody (WR-01)
- [x] `app/views/admin/approvals/index.html.erb` — 2 ocorrências de `approvals-tbody`
- [x] `app/views/admin/approvals/index.html.erb` — tbody vazio hidden no branch empty?
- [x] `app/views/admin/approvals/index.html.erb` — tbody com id no branch else
- [x] `test/models/approval_response_test.rb` — stubs posicionais ->(user, content) em C-G (5 ocorrências)
- [x] `test/models/approval_response_test.rb` — Test E verifica 4 via scan(/<turbo-stream/)
- [x] `test/models/approval_response_test.rb` — Test F verifica 4 via scan(/<turbo-stream/) (CR-02)
- [x] `ruby -c app/models/approval_response.rb` → "Syntax OK"
- [x] `ruby -c test/models/approval_response_test.rb` → "Syntax OK"
- [x] Commits `ee511ca` e `2fc0149` existem no `git log`
