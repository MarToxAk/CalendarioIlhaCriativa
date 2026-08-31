---
phase: 28
slug: divulga-o-agendar-sem-enviar
status: verified
# threats_open = count of OPEN threats at or above workflow.security_block_on severity (the blocking gate)
threats_open: 0
asvs_level: 1
created: 2026-08-30
---

# Phase 28 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| admin browser -> `Admin::DivulgacoesController` (nested under `clients`) | untrusted `params[:client_id]`, `params[:divulgacao][:arte_id]`, `params[:divulgacao][:whatsapp_group_ids][]`, `params[:divulgacao][:scheduled_for]`, `params[:id]` | arte id, group ids, datetime |
| resolved `WhatsappGroup` -> `divulgacao_grupos` snapshot row | `group_name`/`remote_jid` written server-side from the resolved record, never from params | group metadata (frozen) |
| `arte.media_file` blob (private bucket) -> `<img>`/`<video>` in the admin browser | streamed via `rails_storage_proxy_path` (auth-gated), never a presigned S3 URL | media bytes |
| `arte.caption` (client-authored text) -> HTML in `_preview.html.erb` | rendered with ERB auto-escaping | caption text |
| `Divulgacao` model validations -> phase-29 send engine | the model is the last gate before an arte/file/datetime reaches the (future) send path | validated record |
| `#cancel` PATCH -> `divulgacoes.status` | the only state mutation in this phase; phase 29 reads the result | status transition |
| `admin/clients#show` -> `@divulgacoes` mirror card | scoped `@client.divulgacoes` — no cross-client leak path | divulgação list |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-28-01 | Elevation of Privilege / Info Disclosure | `#create` arte_id + whatsapp_group_ids resolution | high | mitigate | `@client.artes.find` + `scoped_active_groups.find` — foreign/inactive id -> `RecordNotFound` -> generic re-render; canonical A×B negative test both directions (confirmed in code: `divulgacoes_controller.rb:46-48`) | closed |
| T-28-06 | Elevation of Privilege | crafted POST combining another client's arte with this client's groups | high | mitigate | model backstop `validate :arte_e_grupos_do_mesmo_cliente` — regression net behind the controller's scoped `.find`; asserted at model layer + end-to-end A×B test | closed |
| T-28-11 | Cross-site Scripting (Tampering) | `arte.caption` rendered in `_preview.html.erb` | high | mitigate | `<%= arte.caption %>` ERB auto-escapes; no `raw`/`html_safe`/`sanitize` anywhere in the file (grep-confirmed) | closed |
| T-28-15 | Access Control | cancel a divulgação of another client / replay cancel | high | mitigate | `set_divulgacao = @client.divulgacoes.find(params[:id])` (cross-client -> 404, not 403); `cancelar!` guarded by `status_agendada?` -> idempotent no-op on replay; PATCH + Rails CSRF (confirmed in code) | closed |
| T-28-02 | Tampering | raw group JID via `whatsapp_group_ids[]` | high | mitigate | `_group_row.html.erb` emits integer `group.id` only; ids coerced `Array(...).map(&:to_i).uniq.reject(&:zero?)`; `remote_jid` written only as a server-resolved snapshot | closed |
| T-28-03 | Tampering | mass-assignment of `status`/`client_id` | medium | mitigate | strong params permit only `:arte_id, :scheduled_for, whatsapp_group_ids: []` (confirmed: `divulgacoes_controller.rb:106`, hardened further by the CR-02 code-review fix) | closed |
| T-28-07 | Business Logic / Integrity | over-ceiling or external-link media slipping toward the phase-29 send path | medium | mitigate | `arte_nao_usa_link_externo` + `arquivo_dentro_do_teto_whatsapp` enforced at create time; `Arte` validations untouched | closed |
| T-28-16 | Information Disclosure | `#show` of another client's divulgação id | medium | mitigate | `@client.divulgacoes.find` scoping; 404 on cross-client; response body excludes foreign arte/group data | closed |
| T-28-05 | Information Disclosure | `RecordNotFound` revealing which client owns an id | medium | mitigate | rescued to a generic pt-BR flash; `#index` scoped to `@client.divulgacoes`; no id/owner disclosure | closed |
| T-28-04 | Denial of Service (data integrity) | same group twice / double-submit -> duplicate child rows | low | mitigate | `uniq` on submitted ids + DB unique index `[divulgacao_id, whatsapp_group_id]` + model uniqueness scope; single `save` transaction | closed |
| T-28-08 | Business Logic | scheduling in the past -> undefined phase-29 timing behavior | low | mitigate | `validate :scheduled_for_no_futuro` + presence check (scoped `on: :create` per the CR-01 code-review fix, so `cancelar!` remains reachable after the scheduled time passes) | closed |
| T-28-09 | Denial of Service | unparseable `scheduled_for` param -> 500 | low | mitigate | AR `:datetime` cast through `Time.zone` yields nil on garbage -> caught by presence; never passed to a stdlib time parser | closed |
| T-28-12 | Information Disclosure | media URL expiring/leaking while the admin edits the form | low | mitigate | `rails_storage_proxy_path` (auth-gated stream) — no presign, no S3 URL in the DOM | closed |
| T-28-13 | Denial of Service | every hidden per-arte preview pane fetching media on page load | low | mitigate | `<video preload="none">` + `image_tag loading: "lazy"`; only the selected pane is visible | closed |
| T-28-17 | Tampering | forcing an arbitrary status transition via `#cancel` | low | mitigate | `#cancel` reads no params — calls `cancelar!`, which only does `agendada -> cancelada`; no `destroy` route/action | closed |
| T-28-19 | Information Disclosure | long frozen group_name / null-subject fallback leaking layout or full JID | low | mitigate | `group_name` span `truncate` + full text in `title=`; null-subject fallback inherited from `display_name` at create time | closed |
| T-28-10 | Information Disclosure | validation messages leaking internal state | low | accept | messages state only the admin's own arte status / file size / arte-vs-groups mismatch — no cross-client identifiers | accepted |
| T-28-14 | Tampering | client-side estimate value | low | accept | pure arithmetic, no network, no persistence; server helper is the source of truth; delay range is ENV-only, never from form or DB | accepted |
| T-28-18 | Business Logic | admin assumes "cancelada" already stops in-flight sends | low | accept | phase 28 has no send path; cancelada banner states "Nenhum envio será feito"; DIVU-08 honoring is explicitly phase 29 | accepted |
| T-28-SC | Tampering | supply-chain (new packages) | low | accept | phase 28 installs zero packages (git grep + Gemfile.lock confirm no bundle add, no importmap pin) | accepted |

*Status: open · closed · open — below {block_on} threshold (non-blocking)*
*Severity: critical > high > medium > low — only open threats at or above workflow.security_block_on (high) count toward threats_open*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-28-01 | T-28-10 | Validation messages are scoped to the admin's own data; no cross-client identifiers ever appear | autonomous orchestrator (plan-time disposition) | 2026-08-30 |
| AR-28-02 | T-28-14 | Client-side estimate is advisory arithmetic only; server helper remains the source of truth | autonomous orchestrator (plan-time disposition) | 2026-08-30 |
| AR-28-03 | T-28-18 | No send path exists in this phase; DIVU-08 (honoring cancel against un-sent groups) is explicitly phase 29 | autonomous orchestrator (plan-time disposition) | 2026-08-30 |
| AR-28-04 | T-28-SC | No new gems/packages installed in this phase | autonomous orchestrator (plan-time disposition) | 2026-08-30 |

*Accepted risks do not resurface in future audit runs.*

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-08-30 | 19 | 15 | 0 (4 accepted) | autonomous orchestrator (L1 grep + code-inspection verification; register authored at plan time across 28-01/28-02/28-03/28-04; code review's CR-01/CR-02 fixes independently reinforced T-28-08/T-28-01/T-28-03) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-08-30
