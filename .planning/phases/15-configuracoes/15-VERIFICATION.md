---
phase: 15-configuracoes
verified: 2026-06-04T12:00:00Z
status: gaps_found
score: 2/3 success criteria verified
gaps:
  - truth: "Admin edita o nome da agência e salva, o novo nome aparece refletido no painel"
    status: failed
    reason: "O commit 638abf1 (entre Wave 1 e Wave 2) substituiu o span de texto dinâmico `<%= Current.user&.agency_name %>` por uma imagem de logo estática com agency_name apenas como atributo `alt`. O nome da agência não é mais visível como texto no painel após salvar."
    artifacts:
      - path: "app/views/admin/shared/_sidebar.html.erb"
        issue: "Branding exibe `image_tag '/logo-livia.svg', alt: Current.user&.agency_name` em vez de texto visível. O agency_name só aparece no atributo alt, invisível para o usuário."
    missing:
      - "Restaurar exibição textual do agency_name no sidebar (ex: span abaixo do logo, ou substituir alt por texto visível) para que o usuário veja o novo nome refletido visualmente ao salvar"
---

# Phase 15: Configurações — Verification Report

**Phase Goal:** Admin consegue alterar sua senha e o nome da agência através de uma página de configurações acessível pelo sidebar
**Verified:** 2026-06-04T12:00:00Z
**Status:** gaps_found — 1 gap bloqueando objetivo
**Re-verification:** No — verificação inicial

---

## Goal Achievement

### Observable Truths (Success Criteria do ROADMAP)

| # | Truth | Status | Evidence |
|---|-------|--------|---------|
| SC-1 | Admin clica em "Configurações" no sidebar e é levado à página de configurações (link não aponta mais para `#`) | VERIFIED | `_sidebar.html.erb` linha 18: `{ label: "Configurações", path: admin_settings_path }` — rota confirmada em `config/routes.rb` |
| SC-2 | Admin preenche formulário de troca de senha (senha atual + nova + confirmação) e a senha é atualizada com feedback de sucesso ou erro | VERIFIED | Controller implementado em `admin/settings_controller.rb`; view com os 3 campos em `show.html.erb`; 4 cenários de teste de integração passando |
| SC-3 | Admin edita o nome da agência e salva, o novo nome aparece refletido no painel | FAILED | Salvar funciona (controller + view corretos), mas a exibição no sidebar foi substituída por imagem de logo. `agency_name` só aparece como `alt` invisível — não é texto visível no painel |

**Score: 2/3 success criteria verified**

---

## Análise Detalhada

### SC-3: Regressão no Sidebar (Bloqueador)

**Linha do tempo:**

1. **203febf** (Wave 1): sidebar correto — `<span class="text-white font-semibold text-sm block"><%= Current.user&.agency_name || "Ilha Criativa" %></span>`
2. **638abf1** (chore, entre Wave 1 e Wave 2): sidebar sobrescrito — span removido, substituído por `image_tag "/logo-livia.svg", alt: Current.user&.agency_name`
3. **0be130b** (Wave 2): não corrigiu o sidebar
4. **29965d9** (Wave 3): não corrigiu o sidebar

**Estado atual** (`app/views/admin/shared/_sidebar.html.erb`, linhas 3–7):

```erb
<div class="px-4 py-4 border-b border-white/20 flex items-center justify-center">
  <%= image_tag "/logo-livia.svg",
        alt: Current.user&.agency_name || "Logo",
        class: "h-10 w-auto object-contain" %>
</div>
```

O `agency_name` está conectado ao banco de dados — `update_agency` funciona e persiste. O problema é que o valor não é exibido como texto visível. O atributo `alt` é lido por leitores de tela mas não é texto visual na interface. O Success Criteria 3 exige que "o novo nome **apareça refletido no painel**" — requisito visual não satisfeito.

---

### Required Artifacts

| Artifact | Fornece | Status | Detalhes |
|----------|---------|--------|----------|
| `db/migrate/20260604121724_add_agency_name_to_users.rb` | Coluna agency_name | VERIFIED | `add_column :users, :agency_name, :string, null: false, default: "Ilha Criativa"` |
| `db/schema.rb` | Coluna agency_name na tabela users | VERIFIED | Linha 95: `t.string "agency_name", default: "Ilha Criativa", null: false` |
| `app/models/user.rb` | Validação de agency_name | VERIFIED | `validates :agency_name, presence: true, length: { maximum: 100 }` |
| `config/routes.rb` | resource :settings com member routes | VERIFIED | `resource :settings, only: [:show]` com `patch :update_password` e `patch :update_agency` |
| `app/views/admin/shared/_sidebar.html.erb` | Link Configurações wired + agency_name visível | PARTIAL | Link wired: OK. agency_name visível: FALHO — está apenas como `alt` da imagem |
| `app/controllers/admin/settings_controller.rb` | Controller com show, update_password, update_agency | VERIFIED | 3 actions implementadas, herda de `Admin::BaseController` (autenticação garantida) |
| `app/views/admin/settings/show.html.erb` | View com dois cards de formulário | VERIFIED | Card senha: 3 campos + submit para `update_password_admin_settings_path`. Card agência: campo pré-preenchido + submit para `update_agency_admin_settings_path` |
| `test/controllers/admin/settings_controller_test.rb` | Testes de integração completos | VERIFIED | 8 testes, 0 skip, Rack::Attack isolado, cobertura de todos os cenários |

---

### Key Link Verification

| From | To | Via | Status | Detalhes |
|------|----|-----|--------|---------|
| `config/routes.rb` | `Admin::SettingsController` | `resource :settings` namespace admin | WIRED | Controller existe em `app/controllers/admin/settings_controller.rb` |
| `Admin::SettingsController` | `Admin::BaseController` | herança | WIRED | `require_authentication` + `layout 'admin'` garantidos |
| `show.html.erb` | `update_password_admin_settings_path` | `form_with url:, method: :patch` | WIRED | Linha 9 da view |
| `show.html.erb` | `update_agency_admin_settings_path` | `form_with url:, method: :patch` | WIRED | Linha 47 da view |
| `admin/shared/_sidebar.html.erb` | `admin_settings_path` | `path: admin_settings_path` | WIRED | Linha 18 do sidebar |
| `update_agency` action | `users.agency_name` (DB) | `Current.user.update(agency_name:)` | WIRED | Controller linha 26; validação do model aplica |
| `agency_name` (DB) | sidebar visível | `Current.user&.agency_name` como texto | BROKEN | Valor existe no banco, mas o sidebar exibe imagem, não texto |

---

### Data-Flow Trace (Level 4)

| Artifact | Variável de dados | Fonte | Produz dado real | Status |
|----------|-------------------|-------|------------------|--------|
| `show.html.erb` (campo agency_name) | `Current.user&.agency_name` | DB via `Current.user` | Sim — lê `users.agency_name` | FLOWING |
| `_sidebar.html.erb` (agency_name visível) | `Current.user&.agency_name` | DB via `Current.user` | Dado existe mas vai para `alt`, não para texto | HOLLOW — conectado ao DB mas não renderiza visualmente |

---

### Requirements Coverage

| Requirement | Planos | Descrição | Status | Evidência |
|-------------|--------|-----------|--------|---------|
| CONF-01 | 15-01, 15-03 | Admin acessa página "Configurações" pelo link do sidebar (wired) | SATISFIED | Sidebar tem `admin_settings_path`; GET retorna 200; link não é mais `#` |
| CONF-02 | 15-02, 15-03 | Admin altera sua própria senha pelo formulário de configurações | SATISFIED | Controller valida senha atual, blank, mismatch; atualiza via `has_secure_password`; 4 cenários testados |
| CONF-03 | 15-01, 15-02, 15-03 | Admin edita o nome da agência visível no painel | BLOCKED | Salvar persiste no DB; mas o nome não aparece como texto visível no sidebar (regredido por commit 638abf1) |

---

### Behavioral Spot-Checks

| Comportamento | Verificação | Resultado | Status |
|---------------|-------------|-----------|--------|
| Controller herda autenticação | `Admin::BaseController` tem `before_action :require_authentication` | Confirmado | PASS |
| Rota PATCH update_password existe | `patch :update_password, on: :member` em routes.rb | Confirmado | PASS |
| Rota PATCH update_agency existe | `patch :update_agency, on: :member` em routes.rb | Confirmado | PASS |
| View pré-preenche campo agency_name | `text_field_tag :agency_name, Current.user&.agency_name` em show.html.erb linha 50 | Confirmado | PASS |
| agency_name visível no sidebar após salvar | span de texto com `Current.user&.agency_name` | FALHO — apenas no `alt` da imagem | FAIL |
| Flash messages renderizadas no layout | `admin.html.erb` renderiza `flash[:notice]` e `flash[:alert]` | Confirmado | PASS |

---

### Anti-Patterns Found

| Arquivo | Linha | Padrão | Severidade | Impacto |
|---------|-------|--------|-----------|---------|
| Nenhum debt marker (TBD/FIXME/XXX) encontrado nos arquivos da fase | — | — | — | — |

---

### Human Verification Required

#### 1. Reflexo visual do agency_name no painel

**Test:** Fazer login como admin, alterar o nome da agência para um valor diferente, clicar "Salvar", observar o sidebar.
**Expected:** O novo nome da agência deve aparecer como texto visível no sidebar (não apenas como tooltip/alt da imagem de logo).
**Why human:** A regressão é confirmada em código, mas a decisão de design (logo vs texto ou logo + texto) requer decisão humana sobre a solução correta.

---

## Gaps Summary

**1 gap bloqueando o objetivo da fase:**

O commit 638abf1 ("chore: commit session changes — calendar preview, logo, client layout, phase 15 plans"), realizado entre a Wave 1 e a Wave 2 da fase 15, substituiu o span de texto dinâmico no sidebar (`<%= Current.user&.agency_name %>`) por uma imagem de logo estática. As Waves 2 e 3 que vieram depois não restauraram a exibição textual.

**Resultado:** O mecanismo de salvar o nome da agência funciona corretamente (backend e formulário). O gap é estritamente de apresentação: o valor salvo não aparece como texto visível no painel, violando o Success Criteria 3 do ROADMAP ("o novo nome aparece refletido no painel").

**Correção sugerida:** Adicionar texto do `agency_name` abaixo ou ao lado do logo no sidebar, como por exemplo:

```erb
<div class="px-4 py-4 border-b border-white/20 flex flex-col items-center justify-center gap-1">
  <%= image_tag "/logo-livia.svg", alt: "Logo", class: "h-10 w-auto object-contain" %>
  <span class="text-white/80 text-xs font-medium"><%= Current.user&.agency_name %></span>
</div>
```

---

_Verified: 2026-06-04T12:00:00Z_
_Verifier: Claude (gsd-verifier)_
