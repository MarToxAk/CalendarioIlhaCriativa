# Phase 17: Cable Foundation + Admin Channel + Badge + Toast - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-05
**Phase:** 17-cable-foundation-admin-channel-badge-toast
**Areas discussed:** connection.rb escopo de auth, Badge quando count é 0, Toast posição e auto-dismiss, Admin channel stream scope

---

## connection.rb — Escopo de autenticação

| Option | Description | Selected |
|--------|-------------|----------|
| Expandir agora | identified_by :current_user, :current_client — tenta session admin primeiro, depois token URL do cliente. Canais individuais rejeitam se não autorizado. Nenhuma mudança de connection.rb na Phase 19 | ✓ |
| Admin-only agora | Manter connection.rb sem mudança. Phase 19 expande quando o canal do cliente for criado. YAGNI — não construir o que não é necessário agora | |

**User's choice:** Expandir agora  
**Notes:** Três sub-decisões adicionais:
- Token do cliente via `params[:token]` (URL query param) — sim
- Cliente desativado (active: false) rejeitado na connection — sim
- Mecanismo de token: padrão confirmado

---

## Badge quando count é 0

| Option | Description | Selected |
|--------|-------------|----------|
| Sumir completamente | Padrão do Gmail, GitHub, Slack — badge some quando não há nada pendente. Sidebar fica limpo. Em tempo real: Turbo Stream remove o elemento quando count chega a 0 | ✓ |
| Mostrar '0' discreto | Badge permanece visível com '0' — confirma que o sistema está conectado e funcionando. Útil durante desenvolvimento para confirmar que o cable está ativo | |

**User's choice:** Sumir completamente  

| Option | Description | Selected |
|--------|-------------|----------|
| Junto ao item 'Aprovações' | Badge ao lado direito do label 'Aprovações' — indica exatamente onde estão as artes pendentes. Padrão mais comum (Gmail, Slack) | ✓ |
| Indicador geral no topo do sidebar | Um ícone ou ponto no cabeçalho do sidebar, sem associação direta a um item do menu | |

**User's choice:** Junto ao item 'Aprovações'

| Option | Description | Selected |
|--------|-------------|----------|
| Vermelho red-500 | Já usado no projeto para status 'Pediu Alteração' (badges vermelhos na página Aprovações). Consistente com o padrão visual existente | ✓ |
| Laranja orange-500 | Mais suave que vermelho, comum para 'atenção'. Diferencia do vermelho de 'erro/danger' | |

**User's choice:** Vermelho red-500

---

## Toast — Posição e auto-dismiss

| Option | Description | Selected |
|--------|-------------|----------|
| Canto inferior direito | Fixed bottom-right — padrão mais comum em apps de admin/dashboard. Não cobre o conteúdo principal no centro. Discreto | ✓ |
| Canto superior direito | Fixed top-right — mais visível. Pode sobrepor botões no cabeçalho. Padrão do GitHub | |

**User's choice:** Canto inferior direito

| Option | Description | Selected |
|--------|-------------|----------|
| 5 segundos | Tempo suficiente para ler a mensagem. Padrão da maioria dos sistemas (Gmail, Slack) | ✓ |
| 3 segundos | Mais rápido, menos intrusivo | |
| 8 segundos | Mais tempo para admin ler e decidir se quer navegar até a arte | |

**User's choice:** 5 segundos

| Option | Description | Selected |
|--------|-------------|----------|
| Sim, botão × | Admin pode fechar antes dos 5s. Acessibilidade melhor. Prático se vários toasts chegarem | ✓ |
| Não, só auto-dismiss | Mais simples de implementar. Toast some sozinho | |

**User's choice:** Sim, botão ×

| Option | Description | Selected |
|--------|-------------|----------|
| Empilhar (stack) — até 3 visíveis | Toasts mais novos aparecem acima dos anteriores. Máximo 3 simultâneos. Os mais antigos somem primeiro quando máximo atingido. Cada um com timer próprio de 5s | ✓ |
| Substituir — sempre 1 por vez | Novo toast substitui o atual. Pode perder informação se vários chegarem juntos | |

**User's choice:** Empilhar (stack) — até 3 visíveis

---

## Admin channel stream scope

| Option | Description | Selected |
|--------|-------------|----------|
| Por-usuário: stream_for current_user | Broadcasts direcionados ao usuário específico. Mais seguro para o futuro (multi-admin). Custo zero — sistema tem apenas 1 admin hoje | ✓ |
| Global: 'admin_notifications' | Mais simples. Qualquer admin conectado recebe todos os broadcasts. Adequado para sistema single-admin | |

**User's choice:** Por-usuário: stream_for current_user

| Option | Description | Selected |
|--------|-------------|----------|
| Não — badge renderizado server-side no load | Phase 17: badge calculado no render da sidebar. Cable só envia updates de mudança (Phase 18+). Mais simples, sem round-trip extra | ✓ |
| Sim — canal envia badge count no subscribe | Após WebSocket conectar, canal faz transmit({badge_count: N}). Mais robusto se página ficar aberta muito tempo, mas adiciona complexidade na Phase 17 | |

**User's choice:** Não — badge renderizado server-side no load

| Option | Description | Selected |
|--------|-------------|----------|
| Verificar no canal também (defesa em profundidade) | stream_for current_user falha com erro claro se current_user for nil. Defense in depth | ✓ |
| Confiar na connection.rb | connection.rb já rejeitou conexões sem current_user. Sem código duplicado | |

**User's choice:** Verificar no canal também (defesa em profundidade)

---

## Claude's Discretion

- Nome do arquivo do canal: `app/channels/admin_notifications_channel.rb`
- Stimulus controller: `app/javascript/controllers/toast_controller.js`
- Badge HTML: `<span id="sidebar-badge">` dentro do link "Aprovações", condicional quando count > 0
- Toast region: `<div id="admin-toast-region">` fixed bottom-right no admin layout
- `turbo_stream_from current_user, channel: AdminNotificationsChannel` no admin layout
- Tamanho do badge: `text-xs font-bold px-1.5 py-0.5 rounded-full`
- Toast visual seguindo padrão de card do projeto: `bg-white border border-gray-200 shadow-lg rounded-lg`

## Deferred Ideas

- Broadcasts reais (toast payload, badge increment/decrement) — Phase 18
- Canal do cliente (ClientCalendarChannel) — Phase 19
- Chips do calendário admin em tempo real — Phase 20
- Push notifications do browser (Web Push API) — out of scope v1.5
- Contador de "não lidas" persistente no banco — badge calculado dinamicamente é suficiente
