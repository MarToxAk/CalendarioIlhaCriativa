# Phase 19: Client Real-time + Arte Status Broadcast - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-06
**Phase:** 19-client-real-time-arte-status-broadcast
**Areas discussed:** Trigger do broadcast, Canal do cliente, Granularidade do replace no calendário, Posição do turbo_stream_from no cliente

---

## Trigger do broadcast

| Option | Description | Selected |
|--------|-------------|----------|
| Model after_update_commit | after_update_commit(when: -> { saved_change_to_status? && revised? }) no model Arte. Simétrico com ApprovalResponse#after_create_commit (Phase 18 D-03). Model fica ciente dos canais. | ✓ |
| Controller mark_revised explícito | Broadcast manual após @arte.revised! no controller. Mais visível, sem magia no model. | |

**User's choice:** Model after_update_commit (Recomendado)
**Notes:** Preferência por consistência com o padrão D-03 estabelecido na Phase 18.

---

## Canal do cliente

| Option | Description | Selected |
|--------|-------------|----------|
| ClientCalendarChannel novo | Cria app/channels/client_calendar_channel.rb com stream_for current_client. Simétrico com AdminNotificationsChannel. | ✓ |
| Turbo built-in broadcast_to @client | Sem canal custom. Turbo assina via signed stream names. Menos arquivos, sem controle de auth no canal. | |

**User's choice:** ClientCalendarChannel novo (Recomendado)
**Notes:** Controle total e simetria com a arquitetura admin.

---

## Granularidade do replace no calendário

### Chip da arte (RTUP-05)

| Option | Description | Selected |
|--------|-------------|----------|
| Chip individual como partial | id="arte_chip_#{arte.id}" no link_to, extraído para _arte_calendar_chip.html.erb. Replace cirúrgico. Falha silenciosa se arte não está no mês atual. | ✓ |
| Replace da grade inteira | Broadcast envia HTML de toda a _month_calendar.html.erb. Mais simples, maior transferência. | |

### Faixa de resumo (RTUP-06)

| Option | Description | Selected |
|--------|-------------|----------|
| Extrair para partial _calendar_summary.html.erb | id="calendar-summary". Contagens recalculadas via arte.scheduled_on.beginning_of_month. | ✓ |
| Deixar o replace do chip cuidar | Não atualiza resumo em real-time — RTUP-06 incompleto. | |

### Mês do resumo

| Option | Description | Selected |
|--------|-------------|----------|
| Mês do scheduled_on da arte | Calcula summary para arte.scheduled_on.beginning_of_month. Falha silenciosa se cliente em outro mês. | ✓ |
| Claude decide | Claude resolve a lógica. | |

**Notes:** Padrão de falha silenciosa herdado do D-06 da Phase 18.

---

## Posição do turbo_stream_from no cliente

### Localização do stream

| Option | Description | Selected |
|--------|-------------|----------|
| layouts/client.html.erb com guard if @client | Conecta em todas as páginas do cliente. Padrão do layout admin. | ✓ |
| Somente em client/home/index.html.erb | Conecta só no calendário; toast não funciona na página show. | |

### Toast region

| Option | Description | Selected |
|--------|-------------|----------|
| Reutilizar toast_controller.js | Zero JavaScript novo. Auto-dismiss 5s, botão ×, max 3. id="client-toast-region". | ✓ |
| Toast diferente para o cliente | Comportamento específico, posição diferente. | |

**Notes:** Decisão consistente com o padrão do layout admin e reutilização máxima de código.

---

## Claude's Discretion

- Nome do partial do toast do cliente: `app/views/client/shared/_arte_revised_toast.html.erb`
- ID do chip: `dom_id(arte, "calendar_chip")` → gera `"arte_42_calendar_chip"`
- Ordem dos Turbo Streams: (1) replace chip → (2) replace summary → (3) append toast
- Toast content: "Arte revisada" + data da arte + link para client_arte_path
- Nome do método no model: `broadcasts_revised_to_all`

## Deferred Ideas

- Chips do calendário admin em tempo real → Phase 20
- Toast quando admin cria nova arte → fora do escopo v1.5
- Indicador de presença online → complexidade desnecessária para o volume atual
