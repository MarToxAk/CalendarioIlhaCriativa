---
phase: 10-arte-form-polish
plan: "01"
subsystem: ui
tags: [tailwind, stimulus, erb, rails-views, form-styling]

# Dependency graph
requires:
  - phase: 07.1-fix-media-source-params-destroy-feedback-sc3-ui
    provides: media_type_toggle_controller.js com targets uploadField/linkField/uploadRadio/linkRadio
provides:
  - _form.html.erb de artes totalmente estilizado com Tailwind puro (zero form-input/btn/btn-primary)
  - Locals button_label e cancel_path com fallback via ||=
  - Radio pills com targets Stimulus uploadLabel/linkLabel prontos para highlight visual
  - media_type_toggle_controller.js atualizado com togglePills() e novos targets
affects: [10-02-plan, 10-03-plan]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Form fields com h-11 px-3 border border-gray-200 rounded-lg e focus ring verde #0F7949"
    - "Textarea com min-h-[80px] resize-y py-2 em vez de h-11"
    - "File input com pseudo-classes file: (file:bg-green-50 file:text-green-700)"
    - "Radio pills: label wrapper com sr-only radio button dentro, targets Stimulus nos labels"
    - "Rodapé com flex justify-end gap-3 pt-2 (padrão clients/_form.html.erb)"
    - "Locals ||= para compatibilidade retroativa em partials"

key-files:
  created: []
  modified:
    - app/views/admin/artes/_form.html.erb
    - app/javascript/controllers/media_type_toggle_controller.js

key-decisions:
  - "Escrever o arquivo _form.html.erb completo de uma vez (Tasks 1 e 2 juntas) para garantir coerência do documento; commitado em dois commits distintos para rastreabilidade"
  - "Atualizar media_type_toggle_controller.js com togglePills() via Rule 2: targets uploadLabel/linkLabel declarados no HTML precisam de suporte no controller para evitar erro Stimulus runtime"

patterns-established:
  - "Radio pill pattern: <label data-...-target='uploadLabel' class='cursor-pointer flex ...'><%= f.radio_button class: 'sr-only' %> Texto</label>"
  - "Locals com fallback: <% button_label ||= arte.persisted? ? 'Salvar alterações' : 'Criar' %>"

requirements-completed: [FORM-01, FORM-02, FORM-03]

# Metrics
duration: 3min
completed: 2026-06-03
---

# Phase 10 Plan 01: Arte Form Polish — Form Partial Summary

**Form partial de artes completamente estilizado com Tailwind puro: zero `form-input`/`btn`/`btn-primary`, radio pills interativos com targets Stimulus, locals `button_label`/`cancel_path` com fallback, e controller atualizado com `togglePills()`**

## Performance

- **Duration:** 3 min
- **Started:** 2026-06-03T14:16:45Z
- **Completed:** 2026-06-03T14:18:48Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Substituídas todas as 9 ocorrências de `form-input` por Tailwind puro — inputs com `h-11`, border `border-gray-200`, focus ring verde `#0F7949`; textarea com `min-h-[80px] resize-y`; selects sem placeholder; file field com pseudo-classes `file:`
- Radio buttons de "Tipo de mídia" transformados em pills horizontais clicáveis com targets Stimulus `uploadLabel`/`linkLabel` e radio buttons `sr-only` dentro dos labels
- Rodapé de botões refatorado: submit verde `#0F7949` usando local `button_label`; cancelar neutro usando `cancel_path`; wrapper com `flex justify-end gap-3 pt-2`
- `media_type_toggle_controller.js` atualizado com novos targets e método `togglePills()` para highlight visual do pill ativo/inativo

## Task Commits

Cada task foi commitada atomicamente:

1. **Task 1: Estilizar campos e labels (FORM-01)** - `fb224f8` (feat)
2. **Task 2: Radio pills, botões e locals (FORM-02, FORM-03) + [Rule 2] togglePills no controller** - `b098aff` (feat)

## Files Created/Modified

- `app/views/admin/artes/_form.html.erb` — Substituição completa de todas as classes placeholder por Tailwind puro; locals `button_label`/`cancel_path` com fallback; radio pills com targets Stimulus
- `app/javascript/controllers/media_type_toggle_controller.js` — Adicionados targets `uploadLabel`/`linkLabel` no `static targets`; novo método `togglePills()` para highlight visual; `toggleFields()` chama `togglePills()` em cada ciclo

## Decisions Made

- Escrever o arquivo `_form.html.erb` completo de uma vez para garantir coerência — as Tasks 1 e 2 modificam o mesmo arquivo e a divisão seria artificial durante a implementação; commitado em dois commits distintos para rastreabilidade das responsabilidades
- Atualizar o controller JS no commit da Task 2 como correção Rule 2: os novos targets `uploadLabel`/`linkLabel` declarados no HTML causariam erro Stimulus runtime sem registro no controller

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Atualizado media_type_toggle_controller.js com targets e togglePills()**
- **Found during:** Task 2 (Radio pills implementation)
- **Issue:** O HTML do form declara `data-media-type-toggle-target="uploadLabel"` e `data-media-type-toggle-target="linkLabel"` nos labels dos pills, mas o controller não registrava esses targets em `static targets` e não tinha lógica para aplicar/remover classes de destaque — causaria erro Stimulus no console e pills sem feedback visual
- **Fix:** Adicionado `"uploadLabel"` e `"linkLabel"` ao array `static targets`; criado método `togglePills()` conforme padrão documentado no PATTERNS.md; `toggleFields()` chama `togglePills()` ao final de cada invocação
- **Files modified:** `app/javascript/controllers/media_type_toggle_controller.js`
- **Verification:** `grep "static targets" controller.js` mostra uploadLabel e linkLabel presentes; `grep -c "togglePills"` retorna 2 (definição + chamada)
- **Committed in:** `b098aff` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 2 — missing critical functionality)
**Impact on plan:** Correção essencial para o funcionamento correto dos pills visuais. O PATTERNS.md já documentava a modificação necessária do controller — foi aplicada como parte da Task 2 conforme o contexto do plano orientava.

## Issues Encountered

Nenhum — arquivo escrito e verificado em uma passagem única com todos os critérios de aceitação passando.

## Known Stubs

Nenhum — o form partial está completamente funcional com Tailwind puro e sem dados hardcoded ou placeholders.

## Threat Flags

Nenhuma nova superfície de segurança introduzida — mudanças são exclusivamente de classes CSS em markup já existente. Os locals `button_label`/`cancel_path` são definidos server-side via `||=` e nunca expostos a input de usuário (conforme T-10-01 no threat model do plano).

## User Setup Required

Nenhum — nenhuma configuração externa necessária.

## Next Phase Readiness

- `_form.html.erb` pronto com targets Stimulus (`uploadLabel`, `linkLabel`) para receber o highlight visual do `media_type_toggle_controller.js`
- Plano 02 (controller Stimulus) pode assumir o controller atualizado como ponto de partida — `togglePills()` já existe
- Plano 03 (new/edit wrappers) pode usar os locals `button_label`/`cancel_path` com `render "form", arte: @arte, button_label: "...", cancel_path: ...`

## Self-Check: PASSED

- app/views/admin/artes/_form.html.erb: FOUND
- app/javascript/controllers/media_type_toggle_controller.js: FOUND
- .planning/phases/10-arte-form-polish/10-01-SUMMARY.md: FOUND
- Commit fb224f8: FOUND
- Commit b098aff: FOUND
- form-input count: 0 (expected 0)
- btn/btn-primary count: 0 (expected 0)
- focus:border-[#0F7949] count: 8 (expected >= 5)
- sr-only count: 2 (expected 2)
- button_label count: 2 (expected 2)
- cancel_path count: 2 (expected 2)

---
*Phase: 10-arte-form-polish*
*Completed: 2026-06-03*
