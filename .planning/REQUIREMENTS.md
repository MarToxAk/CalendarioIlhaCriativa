# Requirements — v1.4 Admin Pages + Brazilian Calendar

**Milestone:** v1.4 Admin Pages + Brazilian Calendar
**Goal:** Completar as páginas inacabadas do painel admin (Aprovações, Calendário, Configurações) e marcar feriados e dias comemorativos brasileiros nos calendários do admin e do cliente.
**Created:** 2026-06-03

---

## Active Requirements

### Aprovações (Histórico de aprovações)

- [x] **APRO-03**: Admin acessa a página "Aprovações" pelo link do sidebar (wired, não mais `#`)
- [x] **APRO-04**: Admin vê lista paginada de todas as respostas de aprovação, ordenada pela mais recente
- [x] **APRO-05**: Cada item da lista exibe: cliente, arte, status, data da resposta e comentário (se houver)
- [x] **APRO-06**: Admin filtra a lista de aprovações por cliente e por status
- [x] **APRO-07**: Admin acessa a arte correspondente diretamente a partir de um item da lista

### Calendário Admin (Todos os clientes)

- [x] **CADM-01**: Admin acessa a página "Calendário" pelo link do sidebar (wired, não mais `#`)
- [x] **CADM-02**: Admin vê calendário mensal com artes de todos os clientes agrupadas por dia
- [x] **CADM-03**: Cada arte no calendário admin exibe cor de fundo única por cliente e nome/iniciais do cliente visível
- [x] **CADM-04**: Admin navega entre meses no calendário admin
- [x] **CADM-05**: Admin clica numa arte no calendário admin e acessa a página da arte diretamente

### Configurações

- [x] **CONF-01**: Admin acessa a página "Configurações" pelo link do sidebar (wired)
- [x] **CONF-02**: Admin altera sua própria senha pelo formulário de configurações
- [x] **CONF-03**: Admin edita o nome da agência visível no painel

### Feriados Brasileiros

- [x] **FERI-01**: Sistema contém lista hardcoded dos feriados nacionais brasileiros e dias comemorativos de marketing (Dia das Mães, Namorados, Pais, etc.) para os anos correntes
- [x] **FERI-02**: Calendário do cliente exibe dias de feriado/comemorativo com fundo destacado e nome visível na célula
- [x] **FERI-03**: Calendário do admin exibe dias de feriado/comemorativo com fundo destacado e nome visível na célula

---

## Future Requirements (deferred)

- Notificações por e-mail ao admin quando cliente aprova ou pede alteração (NOTF-01)
- Notificações por e-mail ao cliente quando arte é revisada (NOTF-02)
- Exportar relatório de aprovações de um cliente em PDF ou CSV (ADM2-01)
- Duplicar uma arte para outro cliente ou data (ADM2-02)
- Deploy em produção com Active Storage S3 (INFRA-01)

---

## Out of Scope

- Feriados estaduais ou municipais — escopo restrito a feriados nacionais e comemorativos de marketing
- Feriados via API externa — lista hardcoded é suficiente para o volume do sistema
- Feriados bloqueando agendamento — apenas indicadores visuais, não restrições
- Calendário admin com view semanal — view mensal é suficiente para planejamento
- Filtros de calendário admin por status — complexidade desnecessária neste ciclo
- Sistema de temas ou personalização visual por agência — fora de escopo

---

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| APRO-03 | Phase 13 | Complete |
| APRO-04 | Phase 13 | Complete |
| APRO-05 | Phase 13 | Complete |
| APRO-06 | Phase 13 | Complete |
| APRO-07 | Phase 13 | Complete |
| CADM-01 | Phase 14 | Complete |
| CADM-02 | Phase 14 | Complete |
| CADM-03 | Phase 14 | Complete |
| CADM-04 | Phase 14 | Complete |
| CADM-05 | Phase 14 | Complete |
| CONF-01 | Phase 15 | Complete |
| CONF-02 | Phase 15 | Complete |
| CONF-03 | Phase 15 | Complete |
| FERI-01 | Phase 16 | Complete |
| FERI-02 | Phase 16 | Complete |
| FERI-03 | Phase 16 | Complete |
