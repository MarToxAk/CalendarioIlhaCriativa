# Requirements: Calendário de Aprovação de Artes

**Defined:** 2026-06-02
**Core Value:** O cliente consegue aprovar ou pedir alteração em cada arte sem precisar de conta — só com o link — e o admin vê tudo num só lugar.

## v1.2 Requirements

### Aprovação — Correção de Bug

- [ ] **APRO-01**: Cliente consegue aprovar uma arte clicando em "Aprovar" sem receber erro "Resposta inválida"
- [ ] **APRO-02**: Cliente consegue pedir alteração (com ou sem comentário) sem receber erro "Resposta inválida"

### Calendário — Faixa de Resumo

- [ ] **CAL2-01**: Cliente vê no topo do calendário a contagem de artes do mês por status (total, aprovadas, pendentes, pediu alteração)

## Backlog (v1.3+)

- **NOTF-01**: Admin recebe e-mail quando cliente aprova ou pede alteração
- **NOTF-02**: Cliente recebe e-mail quando arte é revisada
- **ADM2-01**: Exportar relatório de aprovações de um cliente em PDF ou CSV
- **ADM2-02**: Duplicar uma arte para outro cliente ou data
- **INFRA-01**: Deploy em produção com Active Storage S3
- **INFRA-02**: Sidebar links "Aprovações" e "Calendário" wired

## Out of Scope

| Feature | Reason |
|---------|--------|
| Login OAuth / conta de cliente | Link+senha suficiente |
| Integração com APIs de redes sociais | Meta API exige app review |
| App mobile nativo | Web-first |
| Real-time collaboration | Volume não justifica |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| APRO-01 | Phase 8 | Planned |
| APRO-02 | Phase 8 | Planned |
| CAL2-01 | Phase 9 | Planned |

---
*Requirements defined: 2026-06-02*
