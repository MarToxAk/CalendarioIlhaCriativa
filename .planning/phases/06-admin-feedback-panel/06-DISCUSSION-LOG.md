# Phase 6: Admin Feedback Panel - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-26
**Phase:** 6-admin-feedback-panel
**Areas discussed:** Ponto de entrada do painel, Filtros — mecanismo de update, Resposta do admin ao comentário, Histórico do cliente (CLIE-05)

---

## Ponto de entrada do painel

| Opção | Descrição | Selecionado |
|-------|-----------|-------------|
| Substituir o dashboard raiz | O /admin vira o painel de feedback. Admin::DashboardController#index carrega as respostas. O stub atual é descartado. | ✓ |
| Nova rota /admin/feedback | O dashboard raiz (/admin) fica como home genérica (ou resumo), e um novo /admin/feedback é o painel de respostas. Dois controllers, sidebar link dedicado. | |
| Seção dentro de /admin/artes/index | A listagem de artes existente ganha filtro de 'tem resposta' e vira o painel. Nenhuma rota nova — reutiliza Admin::ArtesController. | |

**Escolha:** Substituir o dashboard raiz
**Notas:** —

| Opção | Descrição | Selecionado |
|-------|-----------|-------------|
| Apenas artes com resposta | Só artes que já foram aprovadas ou receberam pedido de alteração aparecem. Artes pendentes sem resposta ficam ocultas por padrão. | |
| Todas as artes, com badge de status | Todas as artes aparecem (pendente, aprovada, pediu alteração, revisada). O admin vê o quadro completo. Filtragem reduz a lista. | ✓ |
| Apenas pedidos de alteração não revisados | Por padrão mostra apenas artes com status change_requested — a fila de trabalho do admin. Outros status precisam de filtro. | |

**Escolha:** Todas as artes, com badge de status
**Notas:** —

| Opção | Descrição | Selecionado |
|-------|-----------|-------------|
| Uma linha por arte (recomendado) | Cada arte aparece uma vez com a última resposta (ou status atual). Link para admin/artes/:id para ver detalhes e histórico completo. Mais limpo, sem duplicatas. | ✓ |
| Uma linha por resposta | Cada ApprovalResponse aparece separadamente. Uma arte com 3 respostas gera 3 linhas. Útil para ver o volume de interações mas repete dados da arte. | |

**Escolha:** Uma linha por arte
**Notas:** —

| Opção | Descrição | Selecionado |
|-------|-----------|-------------|
| Lista plana por data (mais recente primeiro) | Todas as artes em uma única lista ordenada por scheduled_on ou responded_at. Colunas: Cliente, Arte, Data, Status, Última resposta. | |
| Agrupadas por cliente | Cada cliente tem uma seção com o nome e suas artes abaixo. Mais fácil visualizar a situação de cada cliente de uma vez. | ✓ |
| Você decide | Claude escolhe a abordagem com base no padrão já usado no projeto. | |

**Escolha:** Agrupadas por cliente
**Notas:** —

---

## Filtros — mecanismo de update

| Opção | Descrição | Selecionado |
|-------|-----------|-------------|
| Turbo Frame (recomendado) | O painel dentro de um <turbo-frame>. Filtros são um form GET — submetendo o form só a frame é atualizada. URL preserva ?client_id=&status= (bookmarkável). Rails 8 nativo, sem JS extra. | ✓ |
| Stimulus + fetch | Controller Stimulus escuta change nos selects, faz fetch para a mesma rota com parâmetros, injeta o HTML retornado. Mais flexível para animações mas exige mais código JS. | |
| Reload normal (GET redirect) | Form GET padrão, página recarrega. Mais simples de implementar, mas o success criteria pede 'sem recarregar'. | |

**Escolha:** Turbo Frame
**Notas:** —

| Opção | Descrição | Selecionado |
|-------|-----------|-------------|
| Barra horizontal acima da lista (recomendado) | Select de cliente + select de status em linha acima da lista agrupada. Padrão visto em admin/artes/index. Submit automático no change (Stimulus auto-submit) ou botão Filtrar. | ✓ |
| Sidebar lateral | Painel de filtros à esquerda, lista de artes à direita. Mais espaço para filtros mas muda o layout geral da página. | |
| Você decide | Claude escolhe baseado no padrão existente. | |

**Escolha:** Barra horizontal acima da lista
**Notas:** —

| Opção | Descrição | Selecionado |
|-------|-----------|-------------|
| Sim — todos os 4 status | Pendente / Aprovado / Pediu Alteração / Revisado. Admin vê tudo pelo dashboard. | ✓ |
| Não — apenas artes com resposta | Pendente não aparece no filtro pois o dashboard é de feedback. Artes sem resposta ficam em admin/artes/index. | |

**Escolha:** Sim — todos os 4 status
**Notas:** —

---

## Resposta do admin ao comentário (PAIN-05)

| Opção | Descrição | Selecionado |
|-------|-----------|-------------|
| Na página admin/artes/:id (show da arte) | Campo de resposta inline na view de detalhe da arte, junto ao botão 'Marcar como Revisada'. Admin vai na arte, vê o comentário e responde. Não no dashboard. | ✓ |
| Inline no dashboard (expand na linha) | Cada linha do dashboard tem um botão 'Responder' que expande um textarea inline (padrão do toggle Stimulus já existente). Admin responde sem sair do painel. | |
| Modal no dashboard | Botão 'Responder' abre um modal (padrão modal_controller já existente) com o textarea e botão de salvar. | |

**Escolha:** Na página admin/artes/:id (show da arte)
**Notas:** —

| Opção | Descrição | Selecionado |
|-------|-----------|-------------|
| Campo admin_reply em artes (recomendado) | Uma coluna texto simples na tabela artes. Uma resposta por arte — se o admin revisar e responder de novo, sobrescreve. Mais simples, zero tabela nova. | ✓ |
| Campo admin_reply em approval_responses | A resposta fica na última approval_response da arte. Ligada ao comentário específico que o cliente enviou. Exige migração na tabela approval_responses. | |
| Nova tabela admin_replies | AdminReply belongs_to :arte. Histórico completo de respostas do admin por arte. Mais flexível mas adiciona complexidade desnecessaria para v1. | |

**Escolha:** Campo admin_reply em artes
**Notas:** —

| Opção | Descrição | Selecionado |
|-------|-----------|-------------|
| Sim — na página da arte (/c/:token/artes/:id) | Se admin_reply estiver preenchido, o portal exibe a resposta do admin na seção de histórico ou abaixo dos metadados. O cliente sabe que o admin respondeu. | |
| Não — apenas interno ao admin | A resposta é nota interna do admin. O cliente não vê. O sistema só registra a resposta para uso interno. | ✓ |

**Escolha:** Não — apenas interno ao admin
**Notas:** —

---

## Histórico do cliente (CLIE-05)

| Opção | Descrição | Selecionado |
|-------|-----------|-------------|
| Seção nova na admin/clients/show existente | Terceiro card 'Histórico de artes respondidas' adicionado ao admin/clients/:id. Zero rota nova. Admin acessa via link já existente na sidebar de clientes. | ✓ |
| Rota dedicada /admin/clients/:id/history | View separada com histórico completo. Bom para clientes com muitas artes. Requer novo método no controller + rota member :get. | |
| Filtro no dashboard por cliente | O histórico é o dashboard já filtrado por esse cliente. Nenhuma view nova — o link 'ver histórico' do cliente abre /admin com ?client_id=:id. | |

**Escolha:** Seção nova na admin/clients/show existente
**Notas:** —

| Opção | Descrição | Selecionado |
|-------|-----------|-------------|
| Todas as artes com resposta, ordenadas por data (recomendado) | Lista de artes que receberam pelo menos uma ApprovalResponse. Exibe: título da arte, data agendada, status atual, última resposta + comentário. Link para admin/artes/:id. | ✓ |
| Todas as ApprovalResponses individuais | Cada resposta individual listada em ordem cronológica. Mostra o volume de interações mas pode repetir a mesma arte várias vezes. | |
| Você decide | Claude escolhe baseado no padrão. | |

**Escolha:** Todas as artes com resposta, ordenadas por data
**Notas:** —

---

## Claude's Discretion

- Ordenação dentro de cada grupo de cliente no dashboard (scheduled_on desc vs. responded_at da última resposta)
- Copywriting PT-BR dos labels de status nos filtros
- Controle de submit automático do filtro (auto-submit Stimulus vs. botão "Filtrar")
- Estilo exato do card de histórico na página do cliente
- Botão "Marcar como Revisada" no dashboard: link para a arte ou ação direta na linha

## Deferred Ideas

- Resposta do admin visível para o cliente — decidido como nota interna (D-10); visibilidade pode ser adicionada numa fase futura
- Notificações por e-mail/WhatsApp — Out of scope v1
- Exportar relatório de aprovações (PDF/CSV) — v2, ADM2-01
- Fila de trabalho como default (só pedidos de alteração) — considerado mas rejeitado; o default é "todas as artes"
