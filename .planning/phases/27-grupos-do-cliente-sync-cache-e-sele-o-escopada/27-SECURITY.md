---
phase: 27
slug: grupos-do-cliente-sync-cache-e-sele-o-escopada
status: verified
# threats_open = count of OPEN threats at or above workflow.security_block_on severity (the blocking gate)
threats_open: 0
asvs_level: 1
created: 2026-08-30
---

# Phase 27 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| admin browser -> `Admin::WhatsappGroupsController` | sessão admin autenticada (`require_authentication`); `params[:client_id]`/`params[:id]` são input não confiável | client_id, group id |
| Rails -> host Evolution (`GET /group/fetchAllGroups`) | saída HTTPS, header `apikey` = token da instância (`encrypts`), atrás de Cloudflare | instance token (outbound only) |
| payload JSON de `fetchAllGroups` -> `Whatsapp::GroupSynchronizer` | dado externo não confiável (subject nulo, elemento não-Hash, chaves inesperadas, corpo não-Array) | group metadata |
| ActiveJob args (GlobalID) -> `solid_queue_jobs` | argumentos de job persistem em texto no banco — nada sensível pode entrar | WhatsappInstance record ref (não token) |
| `group_sync_controller.js` (browser) -> `#sync_status` | GET same-origin sem efeito colateral | sync state (não nomes/JIDs) |
| view do picker (fase 28) -> params de seleção | ids de grupo submetidos re-resolvidos pelo escopo `@client.whatsapp_instance.whatsapp_groups` | group id (re-validated server-side) |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-27-01 | Elevation of Privilege / Info Disclosure | acesso cross-client a grupo via `whatsapp_group_id` forjado (`#show`, picker) | high | mitigate | finder sempre `@client.whatsapp_instance.whatsapp_groups.find(params[:id])` -> `RecordNotFound` -> 404; canonical A×B test automatizado (`whatsapp_groups_controller_test.rb:194-223`) | closed |
| T-27-04 | Elevation of Privilege | IDOR no `whatsapp_groups#show` aninhado | high | mitigate | mesma associação escopada; nenhum `WhatsappGroup.find` cru em nenhum controller action (confirmado via grep) | closed |
| T-27-02 | Information Disclosure | token da instância em log / job args | high | mitigate | job recebe o registro `WhatsappInstance` (GlobalID serializa classe+id, não o token); `Evolution::Client` loga só método/path/status/ms; `filter_parameter_logging` cobre token/apikey/hash | closed |
| T-27-03 | Information Disclosure | `#index`/`#sync_status` enumerável cross-client | medium | mitigate | escopados por `params[:client_id]` via `Client.find`; 404 (não 403) em id cross-client, sem sinal de existência | closed |
| T-27-06 | Denial of Service (auto-infligido, risco de ban) | sync-spam em `POST .../sync` | medium | mitigate | throttle Rack::Attack `admin/whatsapp_groups_sync_by_ip` (6/60s) + `Rails.cache` guard (15s TTL) + gate `groups_sync_syncing?` (endurecido no code review: fecha a janela de corrida sem criar lockout permanente — `discard_on(StandardError)` catch-all garante que todo caminho de exceção sai do estado `syncing`) | closed |
| T-27-07 | Tampering | `subject`/elemento nulo ou malformado do payload virando rótulo/opção, ou crashando o sync | medium | mitigate | `display_name` fallback no model; picker/views renderizam `display_name`, nunca `subject` cru; `row_for` descarta elemento não-Hash (`WR-2`, endurecido no code review); entradas sem `@g.us` descartadas no sync | closed |
| T-27-08 | Tampering / Integrity | read-timeout no meio da resposta lido como "0 grupos" -> desativação em massa | medium | mitigate | `fetch_groups` roda e pode levantar ANTES de `upsert_all`/`update_all`; a passada de desativação só executa após parse bem-sucedido (confirmado por leitura de `group_synchronizer.rb:22-38`) | closed |
| T-27-09 | Information Disclosure | `groups_sync_error` guardando texto cru do upstream | low | mitigate | `mark_error` grava só códigos curtos fixos (`transient`/`permanent`/`not_connected`/`config_error`/`unexpected_error`), nunca a mensagem de erro do Evolution (endurecido no code review — códigos distintos por classe de erro, WR-03-DUP) | closed |
| T-27-05 | Tampering (CSRF) | poller GET `#sync_status` | low | accept | leitura pura, sem efeito colateral — GET sem CSRF é correto; `#sync` (que muta) continua POST com CSRF de formulário Rails | accepted |
| T-27-SC | Tampering | supply-chain (novos pacotes) | low | accept | fase 27 não instala pacote nenhum (27-RESEARCH.md "Package Legitimacy Audit" = N/A) | accepted |

*Status: open · closed · open — below {block_on} threshold (non-blocking)*
*Severity: critical > high > medium > low — only open threats at or above workflow.security_block_on (high) count toward threats_open*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-27-01 | T-27-05 | GET-only poller, no state mutation — CSRF has no exploitable effect; the mutating `#sync` action keeps standard Rails form CSRF | autonomous orchestrator (plan-time disposition) | 2026-08-30 |
| AR-27-02 | T-27-SC | No new gems/packages installed in this phase | autonomous orchestrator (plan-time disposition) | 2026-08-30 |

*Accepted risks do not resurface in future audit runs.*

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-08-30 | 10 | 8 | 0 (2 accepted) | autonomous orchestrator (L1 grep-depth verification; register authored at plan time across 27-01/27-02/27-03) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-08-30
