---
phase: 20-admin-calendar-chips-real-time
plan: "01"
subsystem: admin-calendar-real-time
tags: [turbo-stream, actioncable, broadcast, real-time, chip-replace]
dependency_graph:
  requires:
    - "20-00 — _admin_calendar_chip.html.erb com dom_id(arte, 'admin_calendar_chip')"
    - "Phase 18 — broadcasts_to_admin em ApprovalResponse"
    - "Phase 19 — broadcasts_revised_to_all em Arte"
  provides:
    - "app/models/approval_response.rb#broadcasts_to_admin — 5 turbo-streams (toast + badge + dashboard + approvals + chip replace)"
    - "app/models/arte.rb#broadcasts_revised_to_all — admin_stream com 2 turbo-streams (badge + chip replace)"
  affects:
    - "AdminNotificationsChannel — chips do calendário admin agora atualizam em tempo real"
tech_stack:
  added: []
  patterns:
    - "Extensão de array de turbo-streams existente: inserir quinto elemento sem alterar os anteriores"
    - "ActionView::RecordIdentifier.dom_id(arte, 'admin_calendar_chip') — target seguro gerado server-side"
    - "render_partial_html reutilizado dos helpers privados já presentes nos dois models"
key_files:
  created: []
  modified:
    - app/models/approval_response.rb
    - app/models/arte.rb
    - test/models/approval_response_test.rb
    - test/models/arte_test.rb
decisions:
  - "chip_html renderizado via partial admin/calendar/admin_calendar_chip com locals: { arte: arte_with_client } — mesma partial do grid"
  - "admin_chip_html em Arte usa locals: { arte: self } — client acessado via belongs_to já carregado"
  - "admin_stream transformado em array de 2 elementos com .join — mesma convenção do client_streams existente"
  - "Ordem do chip: último no array content (após approvals) — não afeta comportamento do broadcast"
metrics:
  duration: "~15 min"
  completed: "2026-06-09"
  tasks_completed: 3
  files_modified: 4
---

# Phase 20 Plan 01: Broadcast Chip Replace Summary

Broadcasts de `ApprovalResponse` e `Arte` estendidos com turbo-stream de replace do chip do calendário admin (`arte_N_admin_calendar_chip`), fechando RTUP-08. Chips atualizam em tempo real para `approved`, `change_requested` e `revised` sem recarregar a página.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Estender broadcasts_to_admin em ApprovalResponse com chip replace | d9e874a | app/models/approval_response.rb |
| 2 | Estender broadcasts_revised_to_all em Arte com chip replace para o admin | 9df77cd | app/models/arte.rb |
| 3 | Atualizar testes para refletir o novo stream count (GREEN) | 01d4b08 | test/models/approval_response_test.rb, test/models/arte_test.rb |

## What Was Built

### ApprovalResponse#broadcasts_to_admin — 5 turbo-streams

Adicionado `chip_html` renderizado via `render_partial_html(partial: "admin/calendar/admin_calendar_chip", locals: { arte: arte_with_client })` e inserido como quinto elemento do array `content`:

```ruby
turbo_stream_tag("replace", ActionView::RecordIdentifier.dom_id(arte_with_client, "admin_calendar_chip"), chip_html)
```

O array `content` passa de 4 para 5 elementos: toast + badge + dashboard + approvals + chip replace. Sem N+1: `arte_with_client` já carregado com `includes(:client)`.

### Arte#broadcasts_revised_to_all — admin_stream com 2 turbo-streams

Adicionado `admin_chip_html` e `admin_stream` transformado de string única para array de 2 elementos com `.join`:

```ruby
admin_stream = [
  turbo_stream_tag("replace", "sidebar-badge", badge_html),
  turbo_stream_tag("replace", ActionView::RecordIdentifier.dom_id(self, "admin_calendar_chip"), admin_chip_html)
].join
```

Streams do cliente inalterados (chip do cliente + toast). Sem N+1: `self.client` carregado via `belongs_to`.

### Testes Atualizados

**approval_response_test.rb:**
- Test E: `assert_equal 4` → `assert_equal 5` (change_requested)
- Test F: `assert_equal 4` → `assert_equal 5` (approved)
- Test H (novo): `assert_match(/target="arte_\d+_admin_calendar_chip"/, content)` — verifica target do chip no broadcast

**arte_test.rb:**
- "revised! dispara broadcast": `assert_equal 1` → `assert_equal 2` para admin_calls (badge + chip)
- Novo teste "revised! broadcast admin inclui replace do admin calendar chip": `assert_match(/target="arte_\d+_admin_calendar_chip"/, admin_calls.first)`

## Verification

```
2. grep -c 'admin_calendar_chip' app/models/approval_response.rb → 2 ✓
3. grep -c 'admin_calendar_chip' app/models/arte.rb → 2 ✓
4. grep -c 'assert_equal 5' test/models/approval_response_test.rb → 2 ✓ (Tests E e F)
5. grep -c 'Admin deve receber 2 turbo streams' test/models/arte_test.rb → 1 ✓
```

**Nota sobre bin/rails test:** O banco de dados de teste (`calendario_livia_test`) é propriedade do usuário `chatwoot`; o bot não tem permissão SELECT em `ar_internal_metadata`, o que impede `bin/rails test` de inicializar. Este é um problema pré-existente documentado no SUMMARY 20-00 e nas fases 18/19. A verificação estrutural via `bin/rails runner` confirma que os models carregam corretamente, a partial existe, e os counts de streams estão corretos. Verificação funcional dos testes delegada ao checkpoint humano (mesmo padrão das fases anteriores).

```
bin/rails runner → content array tem 5 turbo_stream_tag calls ✓
bin/rails runner → admin_stream array tem 2 turbo_stream_tag calls ✓
```

## Deviations from Plan

Nenhuma — plano executado exatamente como escrito.

## Known Stubs

Nenhum — sem dados hardcoded ou placeholders introduzidos.

## Threat Flags

Nenhuma superfície nova além do descrito no threat model do plano (T-20-03, T-20-04, T-20-05 analisados e aceitos).

## Self-Check: PASSED

- [x] app/models/approval_response.rb contém `admin_calendar_chip` (2 ocorrências)
- [x] app/models/arte.rb contém `admin_calendar_chip` (2 ocorrências)
- [x] test/models/approval_response_test.rb tem `assert_equal 5` (2 ocorrências — Tests E e F)
- [x] test/models/arte_test.rb tem "Admin deve receber 2 turbo streams" (1 ocorrência)
- [x] commit d9e874a existe: feat(20-01): estender broadcasts_to_admin
- [x] commit 9df77cd existe: feat(20-01): estender broadcasts_revised_to_all
- [x] commit 01d4b08 existe: test(20-01): atualizar testes
- [x] content array tem 5 turbo_stream_tag calls (verificado via bin/rails runner)
- [x] admin_stream array tem 2 turbo_stream_tag calls (verificado via bin/rails runner)
