# Roadmap: Calendário de Aprovação de Artes

## Overview

O projeto entrega um sistema de aprovação de conteúdo de social media em seis fases verticais. Cada fase adiciona uma capacidade completa e verificável: a fundação de dados e segurança, depois o painel do admin, depois o gerenciamento de artes, o portal do cliente, o fluxo de aprovação e finalmente o painel de feedback. Ao final da Fase 6, o admin consegue gerenciar clientes e artes, e o cliente consegue aprovar ou pedir alteração em cada arte pelo link, sem conta.

## Phases

- [ ] **Phase 1: Data Foundation + Security** - Modelos, migrações, Rack::Attack e primitivos de autenticação
- [x] **Phase 2: Admin Auth + Client Management** - Login do admin, CRUD de clientes, exibição de link e senha (completed 2026-05-25)
- [x] **Phase 3: Art Management** - Criar/editar/excluir artes, upload de arquivo, link externo, plataforma/formato/prazo (completed 2026-05-25)
- [x] **Phase 4: Client Calendar Portal** - Auth por token + senha, calendário mensal, preview de artes (completed 2026-05-26)
- [x] **Phase 5: Approval Flow** - Aprovar, pedir alteração + comentário, re-aprovação após revisão, histórico (completed 2026-05-26)
- [ ] **Phase 6: Admin Feedback Panel** - Dashboard, filtros, marcar revisado, responder comentário, histórico do cliente

## Phase Details

### Phase 1: Data Foundation + Security

**Goal:** O projeto tem estrutura de dados correta e proteção contra brute-force antes de qualquer código de aplicação
**Mode:** mvp
**Depends on:** Nothing (first phase)
**Requirements:** AUTH-01, AUTH-02, AUTH-03, AUTH-04, AUTH-05, AUTH-06
**Success Criteria**:

1. As migrações rodam sem erro e criam as tabelas Client, Arte e ApprovalResponse com todos os campos e índices definidos na pesquisa
2. O Rails auth generator está configurado para o admin com Session model DB-persistida (Current.user + Current.session via concern Authentication)
3. O modelo Client gera um token de acesso de 24 chars via has_secure_token e armazena senha com has_secure_password
4. Rack::Attack está ativo e bloqueia mais de 5 tentativas de senha num intervalo de 20 segundos no endpoint do portal do cliente
5. O admin pode rotacionar o token de um cliente e o token anterior é invalidado imediatamente

**Plans:** 2/5 plans executed
**Wave 1**

- [x] 01-01-PLAN.md — Criar projeto Rails 8.1.3 + Gemfile completo + banco PostgreSQL + timezone Brasilia + design tokens

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 01-02-PLAN.md — Rails auth generator + Admin::BaseController + Dashboard stub + formulário de login UI-SPEC + seeds
- [ ] 01-03-PLAN.md — Migrações Create Clients/Artes/ApprovalResponses + models + testes unitários

**Wave 3** *(blocked on Wave 2 completion)*

- [ ] 01-04-PLAN.md — Rack::Attack com 4 throttles + teste de integração brute-force
- [ ] 01-05-PLAN.md — ClientController + Client::SessionsController + formulário cliente UI-SPEC + rotação de token + isolamento cross-client

**UI hint:** yes

### Phase 2: Admin Auth + Client Management

**Goal:** O admin consegue fazer login, criar e gerenciar clientes, e copiar o link + senha de acesso de cada cliente
**Mode:** mvp
**Depends on:** Phase 1
**Requirements:** CLIE-01, CLIE-02, CLIE-03, CLIE-04
**Success Criteria**:

1. Admin acessa /admin/login, entra com email e senha e é redirecionado ao painel; sessão persiste entre requests
2. Admin consegue fazer logout e a sessão é destruída
3. Admin cria um cliente com nome e senha, edita esses dados e desativa o cliente — acesso ao portal é bloqueado após desativação
4. Na tela de detalhes do cliente, o admin vê o link de acesso completo e a senha em texto claro prontos para copiar

**Plans:** 5/5 plans complete
**Wave 1**

- [x] 02-01-PLAN.md — Migração password_plain + layout admin + sidebar + ClientsController skeleton + index view + dropdown_controller

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 02-02-PLAN.md — Views new/edit + _form partial + password toggle + testes de controller (CLIE-01, CLIE-02)
- [x] 02-03-PLAN.md — View show + partials _copy_button/_confirm_modal/_readonly_field + copy_controller + modal_controller (CLIE-03, CLIE-04)

**Wave 3** *(gap closure — blocked on Wave 2 completion)*

- [x] 02-04-PLAN.md — Gap closure: _confirm_modal suporta hidden_fields + portal bloqueia clientes inativos (CLIE-03)

**UI hint:** yes

### Phase 3: Art Management

**Goal:** O admin consegue criar, editar e excluir artes associadas a clientes, com upload de arquivo ou link externo, plataforma, formato, prazo e legenda
**Mode:** mvp
**Depends on:** Phase 2
**Requirements:** ARTE-01, ARTE-02, ARTE-03, ARTE-04, ARTE-05, ARTE-06, ARTE-07, ARTE-08, ARTE-09
**Success Criteria**:

1. Admin cria uma arte para um cliente em uma data específica, define plataforma (Instagram/Facebook/LinkedIn) e formato (imagem/vídeo/legenda), e a arte aparece no calendário interno
2. Admin faz upload de um arquivo de imagem ou vídeo diretamente, ou cola um link externo (Drive/Dropbox), e ambos ficam acessíveis na arte
3. Admin define data limite de aprovação e adiciona legenda/texto; esses campos aparecem na visualização da arte
4. Admin edita qualquer campo de uma arte existente antes de ela ser aprovada
5. Admin exclui uma arte e ela some do sistema

**Plans:** 1/1 plans complete
**UI hint:** yes

### Phase 4: Client Calendar Portal

**Goal:** O cliente acessa o próprio calendário pelo link único, autentica com a senha simples e visualiza todas as artes do mês com preview, status e prazo
**Mode:** mvp
**Depends on:** Phase 3
**Requirements:** CAL-01, CAL-02, CAL-03, CAL-04, CAL-05
**Success Criteria**:

1. Cliente acessa o link único, é solicitado a digitar a senha, e após autenticação vê o calendário mensal com as artes agendadas em cada dia
2. Cliente navega para o mês anterior e o próximo mês, e o calendário carrega as artes corretas de cada mês
3. Cliente abre uma arte e vê o preview completo — imagem renderizada, player de vídeo ou texto da legenda conforme o tipo
4. Cada arte no calendário exibe o ícone da plataforma (Instagram, Facebook ou LinkedIn) e a data limite de aprovação com o status atual

**Plans:** 3/3 plans complete
**Wave 1**

- [x] 04-01-PLAN.md — Layout client.html.erb + ClientController layout + locale pt-BR + refatorar sessions/new + rota client_arte_path

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 04-02-PLAN.md — Client::HomeController#index + grade CSS 7 colunas + _platform_icon + _arte_status_badge + testes CAL-01/02/04/05

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 04-03-PLAN.md — Client::ArtesController#show + view preview (imagem/vídeo/legenda/external_url) + testes CAL-03

**UI hint:** yes

### Phase 5: Approval Flow

**Goal:** O cliente consegue aprovar artes ou pedir alteração com comentário; o fluxo de re-aprovação funciona após revisão do admin; histórico de decisões é visível
**Mode:** mvp
**Depends on:** Phase 4
**Requirements:** APRO-01, APRO-02, APRO-03, APRO-04, APRO-05
**Success Criteria**:

1. Cliente clica "Aprovar" em uma arte pendente e o status muda para Aprovado imediatamente, sem recarregar a página completa
2. Cliente clica "Pedir Alteração", escreve um comentário e o status muda para Pediu Alteração com o comentário salvo
3. Após o admin marcar a arte como Revisada, o status volta para Pendente e o cliente precisa aprovar novamente — não é possível aprovar uma arte já aprovada sem esse ciclo
4. Cliente vê o histórico de decisões de uma arte (aprovações e pedidos anteriores em ordem cronológica)
5. Botões de aprovação ficam desabilitados em artes que não estão com status pendente, impedindo duplo envio

**Plans:** 3/3 plans complete
**Wave 1**

- [x] 05-01-PLAN.md — Migração allow_multiple_approval_responses + Arte has_many + validator revised? + consolidação de rotas admin + mark_revised action
**Wave 2** *(blocked on Wave 1 completion)*

- [x] 05-02-PLAN.md — Client::ResponsesController + approval_controller.js + show.html.erb com botões e histórico (APRO-01, APRO-02, APRO-04, APRO-05)
**Wave 3** *(blocked on Wave 1+2 completion)*

- [x] 05-03-PLAN.md — Botão mark_revised na admin show view + testes ciclo completo (APRO-03)
**UI hint:** yes

### Phase 6: Admin Feedback Panel

**Goal:** O admin consegue ver todas as respostas dos clientes num dashboard, filtrar por cliente ou status, marcar artes como revisadas, responder comentários e consultar o histórico de um cliente específico
**Mode:** mvp
**Depends on:** Phase 5
**Requirements:** PAIN-01, PAIN-02, PAIN-03, PAIN-04, PAIN-05, CLIE-05
**Success Criteria**:

1. Admin vê um dashboard com todas as artes respondidas de todos os clientes, mostrando status (Aprovado / Pediu Alteração / Revisado) e comentários
2. Admin filtra o dashboard por cliente específico e por status, e a lista atualiza sem recarregar a página
3. Admin clica "Marcar como Revisado" em uma arte com pedido de alteração e o status muda para Revisado, recolocando a arte na fila de aprovação do cliente
4. Admin escreve uma resposta ao comentário do cliente dentro do sistema e a resposta fica associada à arte
5. Admin acessa o histórico completo de aprovações de um cliente específico, listando todas as artes respondidas com decisões e comentários

**Plans:** 3 plans
**Wave 1**

- [ ] 06-01-PLAN.md — Migração admin_reply + stubs Wave 0 + DashboardController#index + view com Turbo Frame e filtros por cliente/status (PAIN-01, PAIN-02, PAIN-03, PAIN-04)

**Wave 2** *(blocked on Wave 1 completion — paralelo)*

- [ ] 06-02-PLAN.md — Formulário admin_reply em artes/show + expandir arte_params (PAIN-05)
- [ ] 06-03-PLAN.md — Histórico de aprovações em clients/show + ClientsController#show com @artes_with_responses (CLIE-05)

**UI hint:** yes

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Data Foundation + Security | 2/5 | In Progress|  |
| 2. Admin Auth + Client Management | 5/5 | Complete    | 2026-05-25 |
| 3. Art Management | 1/1 | Complete   | 2026-05-25 |
| 4. Client Calendar Portal | 3/3 | Complete   | 2026-05-26 |
| 5. Approval Flow | 3/3 | Complete    | 2026-05-26 |
| 6. Admin Feedback Panel | 0/3 | Not started | - |
