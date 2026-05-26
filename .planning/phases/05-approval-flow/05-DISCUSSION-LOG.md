# Phase 5: Approval Flow - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-26
**Phase:** 05-approval-flow
**Mode:** --auto (todas as decisões auto-selecionadas com opções recomendadas)
**Areas discussed:** Localização dos botões de aprovação, Formulário de comentário, Histórico de decisões, Feedback pós-ação

---

## Localização dos Botões de Aprovação

| Opção | Descrição | Selecionada |
|-------|-----------|-------------|
| Página da arte (/c/:token/artes/:id) | Botões na página de preview que já existe | ✓ |
| Inline na grade do calendário | Botões aparecem direto na célula do dia | |
| Ambos (grade + página) | Dois pontos de entrada para aprovação | |

**Escolha [auto]:** Página da arte (Recomendado)
**Notas:** O campo de comentário não cabe na célula da grade. A página show já existe e exibe o conteúdo completo, contexto necessário para a decisão do cliente.

---

## Formulário de Comentário ("Pedir Alteração")

| Opção | Descrição | Selecionada |
|-------|-----------|-------------|
| Expansão inline com Stimulus | textarea expande ao clicar no botão, sem mudança de URL | ✓ |
| Modal (Stimulus modal_controller) | Modal existente reutilizado | |
| Nova página separada | Formulário em URL própria | |

**Escolha [auto]:** Expansão inline com Stimulus (Recomendado)
**Notas:** Padrão usado em password_toggle_controller. Menos fricção para o cliente.

---

## Histórico de Decisões (APRO-04)

| Opção | Descrição | Selecionada |
|-------|-----------|-------------|
| Seção na página da arte | Lista abaixo dos botões, cronologia reversa | ✓ |
| Página separada "Histórico" | Nova URL /c/:token/artes/:id/historico | |

**Escolha [auto]:** Seção na página da arte (Recomendado)
**Notas:** Sem navegação extra. Contexto natural: cliente vê o conteúdo, os botões e o histórico na mesma tela.

---

## Feedback Pós-Ação

| Opção | Descrição | Selecionada |
|-------|-----------|-------------|
| Flash + redirect para a página da arte | Vê o status atualizado e o histórico imediatamente | ✓ |
| Flash + redirect para o calendário | Volta à visão geral do mês | |

**Escolha [auto]:** Flash + redirect para a página da arte (Recomendado)
**Notas:** O layout client.html.erb já renderiza flash messages. O cliente vê o status mudado sem cliques extras.

---

## Claude's Discretion

- Rota exata: `resources :responses, only: [:create]` nested sob `:artes`
- Controller `Client::ResponsesController` — estrutura interna, before_actions
- Migração para remover índice único em `approval_responses.arte_id`
- Update em `arte_must_be_pending` para aceitar `revised?` além de `pending?`
- Stimulus controller name e implementação exata do toggle inline
- Copywriting PT-BR dos botões, placeholders e flash messages
- Estilo exato dos botões e layout do histórico

## Deferred Ideas

- Painel do admin com todas as respostas — Fase 6
- Notificações — Out of scope v1
- Aprovação inline na grade — v2
- Comentário obrigatório para pedido de alteração — rejeitado (fricção desnecessária)
