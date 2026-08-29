# Security Audit — Phase 24: endpoints-ia-rate-limiting

**Audit Date:** 2026-06-13
**ASVS Level:** L1
**Auditor:** gsd-security-auditor
**Result:** SECURED — 10/10 threats closed

---

## Threat Verification

| Threat ID | Category | Disposition | Status | Evidence |
|-----------|----------|-------------|--------|----------|
| T-24-01 | Denial of Service | mitigate | CLOSED | `config/initializers/rack_attack.rb:30` — `throttle("api/ai_by_key", limit: 60, period: 60)` com path guard `req.path.start_with?("/api/v1/ai/")` na linha 31 e `.presence` nil-safety na linha 32 |
| T-24-02 | Information Disclosure | mitigate | CLOSED | `app/controllers/api/v1/ai/base_controller.rb:24` — `ActiveSupport::SecurityUtils.secure_compare(token, expected)` em `authenticate_ai_key!` |
| T-24-03 | Tampering | mitigate | CLOSED | `app/controllers/api/v1/ai/artes_controller.rb:44-49` — `params.permit(:title, :caption, :scheduled_on, :approval_deadline, :external_url, :platform, :media_type, :client_id)` — lista explícita de 8 campos; `:media_file` e `:status` ausentes |
| T-24-05 | Tampering | mitigate | CLOSED | `app/controllers/api/v1/ai/artes_controller.rb:44-49` — arte_params lista 8 campos; `:media_file` excluído; `:status` não permitido — confirmado por inspeção do método `arte_params` completo |
| T-24-06 | Tampering | mitigate | CLOSED | `app/controllers/api/v1/ai/artes_controller.rb:18` — `rescue Date::Error` seguido de `render_error(code: "bad_request", ..., status: :bad_request)` com `return` explícito na linha 20 |
| T-24-07 | Information Disclosure | mitigate | CLOSED | `app/controllers/api/v1/ai/clients_controller.rb:6` — `Client.find(params[:id])` levanta `RecordNotFound` automaticamente; `app/controllers/api/v1/base_controller.rb:4` — `rescue_from ActiveRecord::RecordNotFound, with: :not_found` presente na cadeia de herança |
| T-24-08 | Elevation of Privilege | mitigate | CLOSED | `app/controllers/api/v1/ai/artes_controller.rb:44-49` — `:status` ausente de `arte_params`; IA não pode setar status inicial via criação de Arte |
| T-24-09 | Tampering | mitigate | CLOSED | `test/integration/rack_attack_test.rb:55,65,75,88` — `Rack::Attack.cache.store.clear` presente antes de cada um dos 4 testes de throttle AI; `ensure` com `ENV["AI_API_KEY"] = original` nas linhas 58-59, 68-69, 81-82, 93-94 |
| T-24-GAP-01 | Denial of Service | mitigate | CLOSED | `config/application.rb:39` — `config.middleware.use Rack::Attack` dentro do bloco `class Application < Rails::Application`; linha não comentada; `Rack::Cors` (insert_before 0) inalterado |
| T-24-GAP-02 | Information Disclosure | mitigate | CLOSED | `app/controllers/api/v1/ai/clients_controller.rb:11-14` — 4 ocorrências de `Arte.statuses["..."]` como chave inteira; chaves string (`counts["approved"]` etc.) removidas; `total = counts.values.sum` inalterado na linha 10 |

---

## Accepted Risks

| Threat ID | Category | Acceptance Rationale | Verified |
|-----------|----------|----------------------|----------|
| T-24-04 | Spoofing | Requests sem token retornam nil no bloco do throttle (sem throttle aplicado); `authenticate_ai_key!` em `base_controller.rb:16` rejeita com 401 antes de qualquer ação ser alcançada — aceitação válida | Yes |
| T-24-10 | Information Disclosure | Keys sintéticas `ak_test_*` e `ak_throttle_test_*` usadas nos testes (não credenciais de produção); restauradas via `teardown` e `ensure` — aceitação válida | Yes |
| T-24-SC | Tampering | Nenhuma gem nova nos commits de fase 24 — últimas alterações em Gemfile/Gemfile.lock foram no commit `b22594f` (phase 21); zero risco de supply chain nesta fase | Yes |
| T-24-GAP-SC | Tampering | Plan 04 modificou apenas `config/application.rb` e `app/controllers/api/v1/ai/clients_controller.rb` — nenhuma nova dependência | Yes |

---

## Unregistered Flags

**None.** Todos os threat flags reportados nos SUMMARYs (24-01 a 24-04) mapeiam para IDs existentes no threat register:

- 24-01-SUMMARY: T-24-01, T-24-02, T-24-04 — todos registrados
- 24-02-SUMMARY: T-24-05, T-24-06, T-24-07, T-24-08 — todos registrados
- 24-03-SUMMARY: T-24-09, T-24-10, T-24-SC — todos registrados
- 24-04-SUMMARY: T-24-GAP-01, T-24-GAP-02 — todos registrados

---

## Verification Commands Executed

```
grep -n "throttle.*api/ai_by_key.*limit: 60.*period: 60" config/initializers/rack_attack.rb
# → linha 30: throttle("api/ai_by_key", limit: 60, period: 60)

grep -n "start_with.*api/v1/ai" config/initializers/rack_attack.rb
# → linha 31: if req.path.start_with?("/api/v1/ai/")

grep -n "ActiveSupport::SecurityUtils.secure_compare" app/controllers/api/v1/ai/base_controller.rb
# → linha 24: unless ActiveSupport::SecurityUtils.secure_compare(token, expected)

grep -n "params.permit" app/controllers/api/v1/ai/artes_controller.rb
# → linha 45: params.permit(

# Inspeção completa de arte_params: :title, :caption, :scheduled_on, :approval_deadline,
# :external_url, :platform, :media_type, :client_id — sem :media_file, sem :status

grep -n "Date::Error" app/controllers/api/v1/ai/artes_controller.rb
# → linha 18: rescue Date::Error

grep -n "Client.find" app/controllers/api/v1/ai/clients_controller.rb
# → linha 6: client = Client.find(params[:id])

grep -n "rescue_from.*RecordNotFound" app/controllers/api/v1/base_controller.rb
# → linha 4: rescue_from ActiveRecord::RecordNotFound, with: :not_found

grep -n "Rack::Attack.cache.store.clear" test/integration/rack_attack_test.rb
# → linhas 55, 65, 75, 88

grep -n "ensure" test/integration/rack_attack_test.rb
# → linhas 58, 68, 81, 93

grep -n "config.middleware.use Rack::Attack" config/application.rb
# → linha 39: config.middleware.use Rack::Attack

grep -n "Arte.statuses" app/controllers/api/v1/ai/clients_controller.rb
# → linhas 11-14: 4 ocorrências
```

---

## Summary

Fase 24 auditada com **10 ameaças fechadas** (10 `mitigate`) e **4 riscos aceitos** documentados. Nenhuma ameaça aberta. Nenhum flag não mapeado. A fase está aprovada para entrega.
