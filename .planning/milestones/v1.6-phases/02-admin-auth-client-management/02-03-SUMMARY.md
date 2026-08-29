---
phase: 02-admin-auth-client-management
plan: "03"
subsystem: admin-clients-show
tags: [rails, tailwind, stimulus, admin, copy, modal, accessibility]
dependency_graph:
  requires:
    - phase: 02-01
      provides: [admin-layout, clients-controller, rotate_token-route]
    - phase: 02-02
      provides: [clients-show-view, password-toggle-controller]
  provides:
    - copy-controller
    - modal-controller
    - clients-show-complete
    - copy-button-partial
    - readonly-field-partial
    - confirm-modal-partial
  affects:
    - app/javascript/controllers/copy_controller.js
    - app/javascript/controllers/modal_controller.js
    - app/assets/tailwind/application.css
    - app/views/admin/clients/show.html.erb
    - app/views/admin/clients/_copy_button.html.erb
    - app/views/admin/clients/_readonly_field.html.erb
    - app/views/admin/clients/_confirm_modal.html.erb
tech_stack:
  added: []
  patterns:
    - Stimulus copy_controller com clipboard.writeText + feedback 2s + swap de classes inline
    - Stimulus modal_controller com focus trap Tab/Shift+Tab + Escape + foco inicial no cancel
    - Modal escope individual por div[data-controller=modal] contendo trigger + overlay
    - Partial _confirm_modal sem data-controller proprio — controller declarado no wrapper pai
    - _readonly_field com show_external_link condicional e copy_button embutido
key_files:
  created:
    - app/javascript/controllers/copy_controller.js
    - app/javascript/controllers/modal_controller.js
    - app/views/admin/clients/_copy_button.html.erb
    - app/views/admin/clients/_readonly_field.html.erb
    - app/views/admin/clients/_confirm_modal.html.erb
  modified:
    - app/assets/tailwind/application.css
    - app/views/admin/clients/show.html.erb
decisions:
  - "copy_controller usa private class fields (#showCopied, #resetLabel) — sintaxe moderna JS, sem Symbol tricks"
  - "modal_controller armazena focus trap handler como getter lazy (_boundFocusTrap) para permitir removeEventListener correto"
  - "Cada modal tem wrapper div[data-controller=modal] proprio no show.html.erb — 2 instancias independentes para desativar e rotacionar"
  - "_confirm_modal nao inclui data-controller no partial — segue abordagem de scoping no pai para controller envolver trigger+overlay"
  - "show.html.erb reescrito completamente para substituir stub do plan 02-02 com partials CopyButton e ConfirmModal"
metrics:
  duration: "~20 min"
  completed_date: "2026-05-25"
  tasks_completed: 2
  files_created: 5
  files_modified: 2
---

# Phase 02 Plan 03: Show + CopyButton + ConfirmModal + Stimulus copy/modal Summary

**Tela show completa com link e senha copiáveis via Stimulus copy_controller, modais de confirmação com focus trap ARIA para desativar/rotacionar token, e partials reutilizáveis _copy_button, _readonly_field e _confirm_modal.**

## What Was Built

### Task 1: Stimulus copy_controller.js + modal_controller.js + animações CSS

**copy_controller.js:** Controller Stimulus com `static values = { value: String }`. Método `execute()` usa `navigator.clipboard.writeText()` com `.then(() => this.#showCopied())`. Feedback 2s: swap de classes no elemento raiz (`text-slate-600 border-gray-200 bg-white` → `text-[#14A958] border-[#14A958]/30 bg-[#F0FDF4]`), texto muda para "Copiado!" via `data-copy-label`, ícone clipboard → check verde. `#resetLabel()` restaura tudo após 2000ms. Fallback sem clipboard API: label muda para "Selecione e copie" por 3s. Auto-registrado como `copy` via `eagerLoadControllersFrom`.

**modal_controller.js:** Controller Stimulus com `static targets = ["overlay"]`. `connect()` inicializa `boundKeydown` para Escape. `open()`: remove `.hidden` do overlay, foca `[data-modal-cancel]` para prevenir ação destrutiva acidental, adiciona listeners Escape e focus trap. Focus trap (getter lazy `boundFocusTrap`): ao pressionar Tab, cicla entre todos os elementos focáveis dentro do overlay; Shift+Tab cicla em sentido inverso. `close()`: adiciona `.hidden`, remove listeners. `disconnect()` garante cleanup do Escape listener. Auto-registrado como `modal`.

**application.css:** Adicionadas 3 animações antes do bloco `prefers-reduced-motion` (que já existia — não duplicado): `@keyframes modalIn` (scale 0.97 → 1 com translateY), `@keyframes overlayIn` (opacity), `@keyframes dropdownIn` (translateY). Classes utilitárias `.modal`, `.modal-overlay`, `.dropdown-menu` com timing correto per UI-SPEC.

### Task 2: View show + partials _readonly_field, _copy_button, _confirm_modal

**_copy_button.html.erb:** Botão com `data-controller="copy"`, `data-copy-value-value`, `data-action="click->copy#execute"`, `aria-live="polite"`. Dois sub-elementos internos: `[data-copy-icon]` para SVG clipboard trocável pelo JS e `[data-copy-label]` para o texto. Classes Tailwind corretas para estado padrão.

**_readonly_field.html.erb:** Aceita `label:`, `value:`, `font_mono:` (default true), `show_external_link:` (default false). Input readonly com `select-all cursor-text`. Link externo condicional com `rel="noopener noreferrer"`. Renderiza `_copy_button` abaixo.

**_confirm_modal.html.erb:** Aceita `id:`, `title:`, `body:`, `confirm_label:`, `cancel_label:`, `confirm_variant:` (default "danger"), `form_action:`, `method:` (default :post). Estrutura: `div.hidden[data-modal-target="overlay"]` com classe `modal-overlay` para animação + `div[role="dialog" aria-modal="true" aria-labelledby aria-describedby]` com classe `modal` para animação. Botão cancelar com `data-modal-cancel` (focus inicial) e `data-action="click->modal#close"`. `form_with` para submit com variante de cor configurable. Usa `raw(body)` para permitir HTML no corpo (tag ⚠ com bold).

**show.html.erb (reescrito do stub do Plan 02):** `content_for(:page_title)`. Barra de ações com link ← Clientes, botão Editar, e condicional Desativar/Reativar. Para Desativar: `div[data-controller="modal"]` envolvendo trigger + render `_confirm_modal` (PATCH `active:false`). Para Reativar: `button_to` direto sem modal (não destrutivo). Card "Dados de acesso do portal": `_readonly_field` para link (font_mono, show_external_link), campo senha com `password-toggle` reutilizado (type="text" inicial, aria-pressed="true"), `_copy_button` para senha. `div[data-controller="modal"]` para rotação + `_confirm_modal` (POST rotate_token). Card "Informações": status badge, criado em, última atualização.

## Verification Results

```
ls app/javascript/controllers/copy_controller.js app/javascript/controllers/modal_controller.js
→ ambos existem

grep "data-modal-cancel" app/views/admin/clients/_confirm_modal.html.erb
→ data-modal-cancel

grep 'type="text"' app/views/admin/clients/show.html.erb
→ <input type="text" (campo senha readonly com type text)

grep "modalIn|overlayIn|dropdownIn" app/assets/tailwind/application.css
→ 3 keyframes + 3 classes utilitárias

bin/rails routes | grep rotate_token_admin_client
→ rotate_token_admin_client POST /admin/clients/:id/rotate_token(.:format)

bin/rails routes | grep client_root
→ client_root GET /c/:token(.:format) → helper client_root_url(token:)
```

## Deviations from Plan

### Auto-fixed Issues

Nenhum — plano executado exatamente como escrito.

### Ajustes de Implementação

**1. [Fidelidade] show.html.erb reescrito (não apenas modificado)**
- O stub criado no Plan 02-02 foi completamente substituído pela implementação final com partials
- Isso estava previsto no plano e no STATE.md: "show.html.erb criada em 02-02 (bloqueador Rule 3) — Plan 03 completa com CopyButton e ConfirmModal"
- Nenhuma funcionalidade foi perdida; todos os dados readonly já existentes foram preservados no novo layout

**2. [Implementação] Modal controller com getter lazy para focus trap**
- `boundFocusTrap` implementado como getter com cache `_boundFocusTrap` para garantir que o mesmo handler possa ser removido via `removeEventListener`
- Necessário porque arrow functions criam novas referências a cada chamada — sem cache, `removeEventListener` não consegue remover o handler correto

**3. [Segurança/ARIA] raw(body) nos modais**
- Body dos modais usa `raw()` para permitir HTML (tag ⚠, `<strong>` com nome do cliente)
- Aceitável pois os valores são gerados server-side pelo próprio template Rails, não por input de usuário

## Known Stubs

Nenhum — todos os campos exibem dados reais. O stub do plan 02-02 foi completamente substituído.

## Threat Flags

Nenhum novo — todos os trust boundaries cobertos pelo plan:
- T-02-09: CSRF token via `form_with` (padrão Rails) no modal de rotate_token
- T-02-10: Modal de confirmação é UX client-side; proteção real é CSRF do form interno
- T-02-11: password_plain visível apenas na tela show acessível por admin autenticado (decisão intencional D-08/D-09/D-11)
- T-02-13: navigator.clipboard só funciona em HTTPS/localhost — produção usa HTTPS

## Self-Check: PASSED

Arquivos criados:
- app/javascript/controllers/copy_controller.js — FOUND (9939340)
- app/javascript/controllers/modal_controller.js — FOUND (9939340)
- app/views/admin/clients/_copy_button.html.erb — FOUND (3760a4b)
- app/views/admin/clients/_readonly_field.html.erb — FOUND (3760a4b)
- app/views/admin/clients/_confirm_modal.html.erb — FOUND (3760a4b)

Arquivos modificados:
- app/assets/tailwind/application.css — FOUND (9939340)
- app/views/admin/clients/show.html.erb — FOUND (3760a4b)

Commits:
- 9939340: feat(02-03): Stimulus copy_controller.js + modal_controller.js + animações CSS — FOUND
- 3760a4b: feat(02-03): view show completa com partials copy_button, readonly_field e confirm_modal — FOUND
