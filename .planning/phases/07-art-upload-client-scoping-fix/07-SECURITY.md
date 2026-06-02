---
phase: "07"
slug: art-upload-client-scoping-fix
status: verified
threats_open: 0
asvs_level: 1
created: 2026-06-02
---

# Phase 07 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| URL → set_arte | params[:id] controlado pelo usuário HTTP | Inteiro de ID de arte (pode ser manipulado) |
| form submit → controller | params[:arte][:client_id] via select ou hidden_field | ID de cliente (pode ser manipulado) |
| form submit → controller | params[:arte][:media_file] via upload | Arquivo binário do usuário |
| URL → index | params[:client_id] como filtro | Inteiro de ID de cliente |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-07-01-01 | Information Disclosure | set_arte / params[:id] | accept | Sistema single-admin autenticado via require_authentication (BaseController). ActiveRecord lança RecordNotFound (404) para IDs inexistentes. Exposição cross-user não se aplica. | closed |
| T-07-01-SC | Tampering | npm/pip/cargo installs | accept | Nenhuma dependência nova instalada no plano 07-01. | closed |
| T-07-02-01 | Tampering | params[:arte][:client_id] via select | accept | Sistema single-admin. arte_params permite :client_id; model valida presença. Admin tem acesso legítimo a todos os clientes. | closed |
| T-07-02-02 | Tampering | params[:arte][:media_file] upload | accept | ActiveStorage valida no backend. Armazenamento local (:local). ASVS L1 não exige validação de content-type server-side para sistema single-admin interno. | closed |
| T-07-02-03 | Information Disclosure | arte.errors exibidos na view | accept | Erros gerados pelo próprio model (não refletem input bruto do usuário). Sem PII exposto nos erros :base definidos em arte.rb. | closed |
| T-07-02-SC | Tampering | npm/pip/cargo installs | accept | Nenhuma dependência nova instalada no plano 07-02. Alterações apenas em ERB/view. | closed |
| T-07-03-01 | Information Disclosure | set_arte / Arte.find irrestrito | mitigate | `@client.artes.includes(:approval_responses).find(params[:id])` quando @client presente — RecordNotFound automático via Active Record para IDs fora do escopo. Verificado em artes_controller.rb:77. | closed |
| T-07-03-02 | Information Disclosure | index / Arte.all irrestrito | mitigate | `Arte.where(client_id: params[:client_id])` quando params[:client_id].present? — index escopado ao cliente. Verificado em artes_controller.rb:9. | closed |
| T-07-03-03 | Tampering | params[:client_id] não validado em index | accept | Sistema single-admin (D-07): admin tem acesso legítimo a todos os clientes. client_id é filtro de conveniência, não boundary de segurança. | closed |
| T-07-03-SC | Tampering | npm/pip/cargo installs | accept | Nenhuma instalação de pacote no plano 07-03. | closed |

*Status: open · closed*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-07-01 | T-07-01-01 | Sistema single-admin autenticado — não há múltiplos usuários entre os quais isolar dados. RecordNotFound protege IDs inexistentes. | gsd-security-auditor | 2026-06-02 |
| AR-07-02 | T-07-02-01 | Admin é o único usuário autenticado. Não há boundary inter-admin para proteger. | gsd-security-auditor | 2026-06-02 |
| AR-07-03 | T-07-02-02 | ActiveStorage valida no backend. ASVS L1 não exige content-type validation server-side para sistema interno single-admin. | gsd-security-auditor | 2026-06-02 |
| AR-07-04 | T-07-02-03 | Erros de model não expõem PII nem refletem input bruto do usuário. | gsd-security-auditor | 2026-06-02 |
| AR-07-05 | T-07-03-03 | client_id é filtro de conveniência UI, não boundary de segurança. Admin single-tenant tem acesso legítimo a todos os clientes. | gsd-security-auditor | 2026-06-02 |

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-06-02 | 10 | 10 | 0 | gsd-security-auditor (automated) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-06-02
