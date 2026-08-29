---
phase: 24-endpoints-ia-rate-limiting
fixed_at: 2026-06-13T00:00:00Z
iteration: 1
fix_scope: critical_warning
findings_in_scope: 5
fixed: 5
skipped: 0
status: all_fixed
---

# Phase 24: Code Review Fix Report

**Fixed:** 2026-06-13
**Scope:** critical_warning (Critical + Warning only)
**Status:** all_fixed

## Summary

All 5 in-scope findings (1 Critical, 4 Warnings) were fixed and committed atomically. No findings were skipped.

---

## Fixed Findings

### CR-01 — Throttle de IA não cobre requisições sem autenticação

**Commit:** `8d439e1`
**File:** `config/initializers/rack_attack.rb`

Added `"api/ai_by_ip"` throttle (limit 30/60s) after the existing `"api/ai_by_key"` throttle. Requests without an `Authorization` header now fall under IP-based rate limiting instead of being completely uncontrolled.

---

### WR-01 — CORS wildcard `"*"` como default em produção

**Commit:** `d0edb66`
**File:** `config/application.rb`

Replaced the single `ENV.fetch("CORS_ORIGINS", "*")` with a conditional: in production, `ENV.fetch("CORS_ORIGINS")` (no fallback) raises `KeyError` on boot if the variable is absent; in other environments the fallback is `"http://localhost:3000"`.

---

### WR-02 — `ArtesController#index` — range invertido retorna silenciosamente zero resultados

**Commit:** `4407311`
**File:** `app/controllers/api/v1/ai/artes_controller.rb`

Moved date parsing out of the `begin/rescue` so both `from` and `to` are available after the rescue block, then added an explicit `if from > to` guard that returns `400 bad_request` with a descriptive message before running the query.

---

### WR-03 — `ArteSerializer#resolve_media_url` — exceção de storage derruba toda a coleção

**Commit:** `a6b5201`
**File:** `app/serializers/api/v1/ai/arte_serializer.rb`

Added `rescue => e` at the end of `resolve_media_url` that logs the error (with `arte.id`) and returns `nil`, preventing a single storage failure from aborting the entire serialized collection.

---

### WR-04 — Teste de throttle verifica apenas a 60ª resposta

**Commit:** `c81f429`
**File:** `test/integration/rack_attack_test.rb`

Moved `assert_not_equal 429, response.status` inside the `60.times` block with an index variable and a descriptive failure message, so every one of the 60 requests is individually verified.

---

## Skipped Findings

None — all in-scope findings were fixed.

---

## Info Findings (out of scope)

The following Info findings were not in scope for this fix pass (use `--all` to include them):

- **IN-01:** `app/models/arte.rb` — ausência de validação de esquema em `external_url`
- **IN-02:** `test/integration/rack_attack_test.rb` — ausência de `# frozen_string_literal: true`

---

_Fixed: 2026-06-13_
_Fixer: Claude (gsd-code-fixer)_
_Scope: critical_warning_
