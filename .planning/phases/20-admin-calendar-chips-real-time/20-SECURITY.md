---
phase: 20
slug: admin-calendar-chips-real-time
status: verified
threats_open: 0
asvs_level: 1
created: 2026-06-09
---

# Phase 20 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Server-rendered partial → HTML DOM | Turbo Stream `replace` injeta HTML renderizado server-side no DOM do admin | Markup do chip (nome do cliente, status, título, plataforma, data, URL de preview) |
| Model callback → AdminNotificationsChannel | Broadcasts de `ApprovalResponse#broadcasts_to_admin` e `Arte#broadcasts_revised_to_all` enviam o chip ao canal admin autenticado | Mesmo markup do chip, sobre canal `stream_for current_user` (Phase 17) |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-20-01 | Tampering | `_admin_calendar_chip.html.erb` | accept | Partial renderizado server-side a partir de registros Arte/Client confiáveis; nenhuma entrada de usuário é interpolada. Mesma superfície XSS do chip inline pré-existente do grid — sem superfície nova. | closed |
| T-20-02 | Information Disclosure | broadcasts via AdminNotificationsChannel | accept | Canal scoped a `Current.user` (admin autenticado, Phase 17). Chip não contém dado secreto do cliente. | closed |
| T-20-03 | Information Disclosure | `ApprovalResponse#broadcasts_to_admin` chip stream | accept | Usa `arte_with_client` (includes(:client)); renderiza o mesmo partial do grid; não expõe nada além do que já está no calendário admin. | closed |
| T-20-04 | Information Disclosure | `Arte#broadcasts_revised_to_all` admin chip stream | accept | `self.client` já carregado; mesmo partial do grid; nenhum dado sensível (token/email/senha) incluído. | closed |
| T-20-05 | Spoofing | Turbo Stream target dom_id | accept | Target `arte_<id>_admin_calendar_chip` gerado via `ActionView::RecordIdentifier.dom_id` com o ID da arte do banco — não derivado de entrada de usuário. Replace falha silenciosamente se o DOM não tiver o alvo. | closed |
| T-20-SC | Tampering | npm/pip/cargo/bundler installs | accept | Nenhuma nova dependência instalada nesta fase (Gemfile/Gemfile.lock/package.json inalterados — verificado no diff da fase). | closed |

*Status: open · closed*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-20-01 | T-20-01 | O chip é markup server-side de registros confiáveis; a mesma superfície já existia no grid inline antes da Phase 20. Verificado: o partial expõe apenas `client.name`, `platform`, `status`, `title`, `scheduled_on`, `external_url`/`media_file` (preview) — nenhum campo sensível. | junior.ilha | 2026-06-09 |
| AR-20-02 | T-20-02, T-20-03, T-20-04 | Broadcasts trafegam pelo `AdminNotificationsChannel`, já autenticado e scoped a `Current.user`. Verificado: o chip não contém token, email, senha nem outro dado secreto do cliente. | junior.ilha | 2026-06-09 |
| AR-20-03 | T-20-05 | DOM id derivado do ID de banco da arte, não de input. Spoofing exigiria controle do banco; replace em alvo ausente falha silenciosamente (sem efeito colateral). | junior.ilha | 2026-06-09 |
| AR-20-04 | T-20-SC | Fase não adicionou dependências; risco de supply-chain inalterado. Verificado no diff `b010a6a^..HEAD`. | junior.ilha | 2026-06-09 |

*Accepted risks do not resurface in future audit runs.*

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-06-09 | 6 | 6 | 0 | /gsd-secure-phase (orchestrator — register all-accept, authored at plan time; rationales verified against source) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-06-09
