# Milestones

## v1.2 Calendar Summary & Approval Fix (Shipped: 2026-06-03)

**Phases completed:** 2 phases, 2 plans, 2 tasks

**Key accomplishments:**

- Faixa de resumo com 4 chips coloridos (total/aprovadas/pendentes/pediu alteração) calculada em memória via select sobre @artes, renderizada inline entre header de mês e grade do calendário

---

## v1.1 Fix Art Upload & Client Association (Shipped: 2026-06-02)

**Phases completed:** 2 phases, 5 plans, 5 tasks

**Key accomplishments:**

- `set_arte` agora atribui `@client = @arte.client` após carregar `@arte`, garantindo que todas as actions que o usam (show, edit, update, destroy, mark_revised) tenham `@client` disponível sem depender de `params[:client_id]`
- Selector condicional de cliente (hidden_field vs f.select) e bloco de erros :base no _form.html.erb, habilitando criacao de artes sem client_id pre-definido e depuracao de erros de upload
- One-liner:
- One-liner:

---

## v1.0 MVP — Calendário de Aprovação de Artes

**Shipped:** 2026-05-27
**Archived:** 2026-06-02
**Phases:** 8 (1, 2, 2.1, 3, 3.1, 4, 5, 6)
**Plans:** 23 total
**Timeline:** 2026-05-24 → 2026-05-27 (3 days)
**Files:** 284 files changed, 26.713 insertions
**Commits:** 149

### What Was Shipped

Sistema completo de aprovação de artes de social media: painel admin com CRUD de clientes e artes, portal do cliente com calendário mensal e fluxo de aprovação sem conta, e painel de feedback com dashboard, filtros e respostas internas.

### Key Accomplishments

1. **Fundação Rails 8.1.3** — PostgreSQL, Tailwind v4, Rack::Attack (4 throttles), auth generator sem Devise, bundle de 30 gems em vendor/bundle
2. **Painel admin completo** — CRUD de clientes com sidebar, rotação de token, cópia de link/senha com modal de confirmação e clipboard API
3. **Gestão de artes** — upload direto (ActiveStorage) + link externo, plataforma/formato/prazo, formulário com hidden_field client_id contextual
4. **Portal do cliente** — calendário mensal CSS grid 7 colunas, preview de imagem/vídeo/legenda, ícones de plataforma, badges de status
5. **Fluxo de aprovação** — aprovar/pedir alteração via Stimulus (sem page reload), re-aprovação após revisão, histórico de decisões por arte
6. **Dashboard de feedback** — Turbo Frame filters por cliente/status, admin_reply para artes com pedido, histórico completo por cliente

### Gap Closures (Inserted Phases)

- **Phase 2.1** — password_plain stale após update do cliente (CLIE-04)
- **Phase 3.1** — formulário de criação de artes sem client_id (ARTE-01 blocker)

### Requirements Coverage

- **35/35** v1 requirements implementados
- **Todos os 8 gaps** do audit fechados (2 por fases inseridas, outros via Plan 06-04)

### Archive

- Roadmap: `.planning/milestones/v1.0-ROADMAP.md`
- Requirements: `.planning/milestones/v1.0-REQUIREMENTS.md`
- Audit: `.planning/milestones/v1.0-MILESTONE-AUDIT.md`

---
