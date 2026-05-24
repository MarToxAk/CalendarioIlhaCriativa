# Phase 2: Admin Auth + Client Management - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-24
**Phase:** 2-admin-auth-client-management
**Areas discussed:** Layout do admin, Rotas de desativar/reativar, Senha na edição

---

## Layout do Admin

| Option | Description | Selected |
|--------|-------------|----------|
| Layout dedicado `admin.html.erb` | Permite sidebar, topbar e estrutura própria do admin sem poluir o application layout. Padrão Rails para área administrativa separada. | ✓ |
| Application layout com conditionals | Um só layout, mas com conditionals para renderizar a sidebar. Mais simples, mas fica confuso à medida que o sistema cresce. | |

**User's choice:** Layout dedicado `admin.html.erb`
**Notes:** —

| Option | Description | Selected |
|--------|-------------|----------|
| `layout 'admin'` no BaseController | Todos os controllers que herdam de Admin::BaseController usam o layout admin automaticamente. | ✓ |
| Declarar manualmente em cada controller | Mais verboso, só faz sentido se algum controller do admin precisar de layout diferente. | |

**User's choice:** `layout 'admin'` no BaseController
**Notes:** —

| Option | Description | Selected |
|--------|-------------|----------|
| Hardcoded no partial | Simples e suficiente para v1 com 5 itens de menu. | ✓ |
| Você decide | Claude escolhe a abordagem. | |

**User's choice:** Hardcoded no partial
**Notes:** —

| Option | Description | Selected |
|--------|-------------|----------|
| Helper `current_page?` + CSS condicional | Padrão Rails simples, sem JS adicional. | ✓ |
| Stimulus controller para gerenciar estado ativo | Mais flexível para navegação complexa, mas overengineering para 5 links fixos. | |

**User's choice:** Helper `current_page?` + CSS condicional
**Notes:** —

---

## Rotas de Desativar/Reativar

| Option | Description | Selected |
|--------|-------------|----------|
| Via `update` com params `active: false/true` | PATCH /admin/clients/:id com `{client: {active: false}}`. Reutiliza o update action, sem rotas customizadas. Mais REST. | ✓ |
| Ações member customizadas `deactivate`/`reactivate` | `member do patch :deactivate; patch :reactivate end`. Mais explícito por URL mas duplica lógica de update. | |
| Ação member única `toggle_active` | Um só endpoint que alterna o estado. Mais simples mas menos semântico. | |

**User's choice:** Via `update` com params `active: false/true`
**Notes:** —

| Option | Description | Selected |
|--------|-------------|----------|
| Rota member `rotate_token` | `member do post :rotate_token end` — semântica clara. A UI-SPEC já referencia `rotate_token_admin_client_path`. | ✓ |
| Via `update` com param especial | PATCH com `{rotate: true}` no controller. Menos semântico. | |

**User's choice:** Rota member `rotate_token`
**Notes:** A UI-SPEC aprovada já referenciava `rotate_token_admin_client_path`, confirmando essa abordagem.

| Option | Description | Selected |
|--------|-------------|----------|
| Todas as 6 + rotate_token | `resources :clients, only: [:index, :show, :new, :create, :edit, :update]` + `member do post :rotate_token end`. | ✓ |
| Sem destroy | Excluir não está nos requisitos v1 — apenas desativar. | — |

**User's choice:** Todas as 6 actions (sem destroy) + rotate_token member
**Notes:** Sem destroy é o comportamento correto. As opções eram equivalentes; confirmado sem destroy.

---

## Senha na Edição

| Option | Description | Selected |
|--------|-------------|----------|
| `has_secure_password` + filtrar no controller | Filtrar campo password vazio antes de `update`. Sem complexidade extra no model. | ✓ |
| `password_optional: true` ou `allow_nil: true` no model | Habilita atualização com senha nil. Precisa cuidado para não aceitar senha vazia em `create`. | |
| Você decide | Claude escolhe a abordagem mais segura. | |

**User's choice:** Filtrar no controller antes de `update`
**Notes:** —

**Conflito identificado durante discussão:** A UI-SPEC Screen 4 especifica "senha em texto puro visível por padrão" para o admin copiar. Mas `has_secure_password` usa bcrypt (hash irreversível). Sem armazenar a senha em texto puro, não é possível exibir a senha original.

| Option | Description | Selected |
|--------|-------------|----------|
| Guardar senha em texto puro (coluna `password_plain`) | Adicionar coluna `password_plain` na tabela `clients`. Admin vê e copia a senha real. Necessário para o fluxo WhatsApp. | ✓ |
| Admin só redefine a senha, não vê a atual | Mostrar '••••••••' na tela de detalhe. Admin cria nova senha quando precisar. Mais seguro, mas muda o fluxo. | |
| Mostrar a senha só após criar/editar (flash de sucesso) | Exibir a senha no flash imediatamente após salvar. Admin copia nesse momento. | |

**User's choice:** Guardar senha em texto puro (coluna `password_plain`)
**Notes:** Requisito real de negócio — admin envia senha ao cliente por WhatsApp. Ciente do risco de segurança de armazenar senhas em texto puro.

---

## Claude's Discretion

- Estrutura interna do `admin.html.erb` (head, meta tags, asset includes)
- Strong parameters para `Admin::ClientsController`
- Tratamento de erros de validação no form (render :new / render :edit com errors)
- Ordenação padrão da lista de clientes

## Deferred Ideas

None — discussão ficou dentro do escopo da fase.
