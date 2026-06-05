# Requirements — v1.5 Real-time & Notifications

**Milestone:** v1.5 Real-time & Notifications
**Goal:** Admin e cliente veem atualizações em tempo real via ActionCable/Turbo Streams — sem recarregar a página — e recebem toasts globais quando eventos relevantes ocorrem.
**Created:** 2026-06-05

---

## Active Requirements

### Infraestrutura Cable

- [ ] **CABLE-01**: ActionCable WebSocket conecta para admin (via sessão Rails) e para cliente (via token de URL) sem erro de conexão
- [ ] **CABLE-02**: Sidebar do admin exibe badge numérico com contagem de artes com "Pediu Alteração" não revisadas

### Notificações do Admin (acionadas por: cliente envia resposta de aprovação)

- [ ] **RTUP-01**: Badge no sidebar do admin atualiza em tempo real — incrementa quando nova resposta "Pediu Alteração" chega, decrementa quando admin marca arte como revisada
- [ ] **RTUP-02**: Admin recebe toast em qualquer página do painel quando nova resposta de cliente chega (sem recarregar)
- [ ] **RTUP-03**: Dashboard admin recebe nova linha de arte em tempo real quando cliente registra aprovação ou pedido de alteração
- [ ] **RTUP-04**: Página Aprovações do admin recebe nova linha em tempo real quando nova resposta chega

### Real-time do Cliente (acionadas por: admin marca arte como revisada)

- [ ] **RTUP-05**: Célula do calendário do cliente atualiza em tempo real quando admin marca arte como revisada (badge de status muda)
- [ ] **RTUP-06**: Faixa de resumo de status no topo do calendário do cliente atualiza em tempo real quando arte muda de status
- [ ] **RTUP-07**: Cliente recebe toast no calendário quando arte é revisada pelo admin
- [ ] **RTUP-08**: Chips do calendário admin atualizam em tempo real quando status de arte muda

---

## Future Requirements (deferred)

- Notificações por e-mail ao admin quando cliente aprova ou pede alteração (NOTF-01)
- Notificações por e-mail ao cliente quando arte é revisada (NOTF-02)
- Exportar relatório de aprovações de um cliente em PDF ou CSV (ADM2-01)
- Duplicar uma arte para outro cliente ou data (ADM2-02)
- Deploy em produção com Active Storage S3 (INFRA-01)

---

## Out of Scope

- Push notifications do browser (Web Push API) — toast in-page é suficiente para o volume atual
- Notificações por e-mail — deferred para próximo milestone
- Contador de "não lidas" persistente no banco — badge calculado dinamicamente é suficiente
- Real-time para a página de Clientes ou Configurações — sem eventos relevantes nessas páginas
- Presença de usuário (quem está online) — complexidade desnecessária
- WebSockets via Redis — solid_cable (já instalado) usa PostgreSQL sem Redis

---

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| CABLE-01 | Phase 17 | Not started |
| CABLE-02 | Phase 17 | Not started |
| RTUP-01 | Phase 17–19 | Not started |
| RTUP-02 | Phase 18 | Not started |
| RTUP-03 | Phase 18 | Not started |
| RTUP-04 | Phase 18 | Not started |
| RTUP-05 | Phase 19 | Not started |
| RTUP-06 | Phase 19 | Not started |
| RTUP-07 | Phase 19 | Not started |
| RTUP-08 | Phase 20 | Not started |
