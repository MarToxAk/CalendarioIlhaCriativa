# Phase 18: ApprovalResponse Broadcast + Admin Live Rows - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-05
**Phase:** 18-ApprovalResponse-Broadcast-Admin-Live-Rows
**Areas discussed:** Trigger do broadcast, Dashboard live rows (RTUP-03), Toast content (RTUP-02), Badge DOM strategy (RTUP-01)

---

## Trigger do broadcast

| Option | Description | Selected |
|--------|-------------|----------|
| Model callback (after_create_commit) | Padrão Rails/Turbo; model ciente do canal; testado com assert_broadcasts | ✓ |
| Controller after response.save | Mais explícito; controller tem contexto do request; acopla infra ao controller cliente | |
| ActiveJob assíncrono | Desacopla completamente; complexidade de fila desnecessária para o volume atual | |

**User's choice:** Model callback (after_create_commit)
**Notes:** Padrão Rails estabelecido para ActionCable + Turbo Streams.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Um único broadcast com múltiplos streams | Toast + badge + row em um pacote; atômico; eficiente | ✓ |
| Broadcasts separados por destino | Mais modular; 3+ transmissões por evento; ordem não garantida | |

**User's choice:** Um único broadcast com múltiplos Turbo Streams
**Notes:** Transmissão única via AdminNotificationsChannel.broadcast_to.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Diretamente no model | Método privado broadcasts_to_admin; simples; sem abstração prematura | ✓ |
| Concern Broadcastable | Módulo separado; justificado só se Phases 19/20 precisarem de lógica compartilhada | |

**User's choice:** Método privado direto no model ApprovalResponse
**Notes:** Concern seria prematuro; revisitar se Phases 19-20 criarem padrão similar.

---

## Dashboard live rows (RTUP-03)

| Option | Description | Selected |
|--------|-------------|----------|
| Replace in-place da linha existente | Arte já está na tabela; broadcast replace com dom_id(arte); mais preciso | ✓ |
| Adicionar nova linha no topo | Prepend simples; pode criar duplicata se arte já aparece | |
| Refresh da turbo-frame dashboard-content | Mais simples; faz request HTTP extra a cada resposta | |

**User's choice:** Replace in-place via dom_id(arte)
**Notes:** Criar partial _arte_dashboard_row.html.erb; adicionar id: dom_id(arte) nas <tr>.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Criar _arte_dashboard_row.html.erb | Partial em admin/dashboard/; dashboard refatora para render collection | ✓ |
| Inline no broadcast (sem partial) | Broadcast envia HTML como string; mistura HTML no model | |

**User's choice:** Partial _arte_dashboard_row.html.erb
**Notes:** Separação de camadas; consistent com o padrão _approval_row.html.erb existente.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Falha silenciosa se filtro esconde arte | Turbo Stream replace ignora silenciosamente se elemento ausente na DOM | ✓ |
| Checar filtros no server antes de broadcast | Model não tem contexto de estado de filtro do admin; inviável | |

**User's choice:** Falha silenciosa — comportamento aceitável
**Notes:** Volume 10-30 clientes; edge case raro; Turbo já trata silenciosamente.

---

## Toast content (RTUP-02)

| Option | Description | Selected |
|--------|-------------|----------|
| Cliente + decisão + link para a arte | Badge colorido + botão "Ver arte" com link admin_arte_path; informação útil sem ocupar muito espaço | ✓ |
| Cliente + decisão + título da arte | Mais detalhe; toast maior | |
| Só cliente + decisão (sem link) | Minimalista; admin navega manualmente | |

**User's choice:** Cliente + decisão + link para a arte
**Notes:** Badge vermelho/verde + "Ver arte" link.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Badge colorido interno, toast sempre branco | Toast bg-white/border/shadow; badge interno colorido por decisão | ✓ |
| Toast com borda colorida esquerda | border-l-4 vermelho/verde; mais agressivo; pode distrair | |
| Visual neutro para qualquer decisão | Sem diferenciação; admin lê o texto | |

**User's choice:** Badge interno colorido, toast sempre branco
**Notes:** Consistente com padrão de cards e badges existentes no projeto.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Sim, toast sempre aparece | Broadcast vai para todos os destinos independente da página atual | ✓ |
| Suprimir toast se já na página Aprovações | Precisaria checar URL no Stimulus; complexidade desnecessária | |

**User's choice:** Toast sempre aparece
**Notes:** Toast e nova linha na lista são complementares, não redundantes.

---

## Badge DOM strategy (RTUP-01)

| Option | Description | Selected |
|--------|-------------|----------|
| Sempre renderizar o span, toggle hidden quando count=0 | Remover condicional; span#sidebar-badge sempre na DOM; Turbo Stream sempre pode fazer replace | ✓ |
| Wrapper sempre presente (#sidebar-badge-wrapper) | Tag wrapper com ID estável; badge partial dentro; mais explícito | |
| Turbo-frame no sidebar | Frame com src reload; request HTTP extra | |

**User's choice:** Sempre renderizar o span com toggle hidden
**Notes:** Solução mais simples; remove if badge_count > 0 do sidebar.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Recalcular do banco a cada broadcast | Arte.change_requested.count server-authoritative; sem dessincronismo | ✓ |
| Incremento client-side via Stimulus | Mais leve; pode desincronizar com múltiplos tabs ou eventos perdidos | |

**User's choice:** Recalcular do banco — server-authoritative
**Notes:** Volume pequeno; query simples; evita edge cases de sincronismo.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Só quando change_requested | Badge conta artes pendentes de revisão; aprovados não incrementam | ✓ |
| Sempre, para qualquer decisão | Reflete volume total; menos preciso para indicar pending actions | |

**User's choice:** Só quando decision = change_requested
**Notes:** Consistent com a definição do badge da Fase 17 (artes que precisam de ação do admin).

---

## Claude's Discretion

- Nome do partial do toast: `app/views/admin/shared/_approval_toast.html.erb`
- Nome do partial do badge sidebar: criado inline no replace ou via partial `_sidebar_badge.html.erb`
- Ordem dos Turbo Streams no broadcast: append toast → replace badge → replace dashboard row → prepend approval row
- Eager loading de `arte: :client` no broadcast para evitar N+1

## Deferred Ideas

- Broadcasts para ClientCalendarChannel — Phase 19
- Badge decremento quando admin marca arte como revisada — Phase 19
- Chips do calendário admin em tempo real — Phase 20
- Supressão de toast condicional por página — descartado por complexidade
