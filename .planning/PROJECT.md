# Calendário de Aprovação de Artes

## What This Is

Sistema web em Ruby on Rails para agências e freelancers de social media gerenciarem o fluxo de aprovação de conteúdo com seus clientes. Cada cliente recebe um link único com senha simples para acessar um calendário mensal, visualizar as artes agendadas por dia e registrar aprovação ou solicitar alterações com comentários. O administrador gerencia todo o processo pelo painel interno.

## Core Value

O cliente consegue aprovar ou pedir alteração em cada arte sem precisar de conta — só com o link — e o admin vê tudo num só lugar.

## Requirements

### Validated

- [x] Admin pode cadastrar e gerenciar clientes (nome, link, senha) — Validated in Phase 02: admin-auth-client-management
- [x] Admin pode desativar um cliente (bloqueia acesso ao portal) — Validated in Phase 02: admin-auth-client-management

### Active

- [ ] Admin pode cadastrar e gerenciar clientes (nome, link, senha)
- [ ] Cada cliente tem um calendário mensal de artes com link público + senha simples
- [ ] Admin pode adicionar artes a dias específicos do calendário (upload direto ou link externo)
- [ ] Arte pode ter formato: imagem, vídeo ou texto/legenda
- [ ] Arte pode ser marcada para Instagram, Facebook ou LinkedIn
- [ ] Cliente visualiza o calendário com as artes do mês
- [ ] Cliente marca cada arte como Aprovado ou Pediu Alteração
- [ ] Cliente pode escrever comentário explicando as alterações desejadas
- [ ] Admin visualiza todas as respostas dos clientes no painel
- [ ] Cada arte tem data limite de aprovação (prazo)
- [ ] Admin pode marcar arte como revisada após fazer as alterações

### Out of Scope

- Login OAuth / conta de cliente — link+senha é suficiente para v1
- Notificações por e-mail ou WhatsApp — admin verifica pelo painel
- Agendamento automático de publicação — não integra com APIs de redes sociais em v1
- App mobile — web-first

## Context

- Carteira de 10–30 clientes ativos
- Conteúdo para Instagram, Facebook e LinkedIn
- Admin faz upload direto de arquivos OU cola links externos (Google Drive, Dropbox)
- Status simplificado: só Aprovado ou Pediu Alteração (sem estados intermediários)
- Prazo de aprovação por arte (data limite definida pelo admin)
- Notificações: admin verifica o painel quando quiser, sem alertas automáticos

## Constraints

- **Tech Stack**: Ruby on Rails — decisão do usuário
- **Acesso do cliente**: Link único por cliente + senha simples, sem autenticação complexa
- **Storage**: Suporte a upload local e links externos (Drive/Dropbox) para os arquivos
- **Escala**: Projetado para 10–30 clientes simultâneos

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Rails como stack | Escolha do usuário | — Pending |
| Link + senha simples para cliente | Evita fricção de cadastro para o cliente | — Pending |
| Status binário (Aprovado/Pediu Alteração) | Mantém o fluxo simples | — Pending |
| Sem notificações automáticas v1 | Reduz complexidade inicial | — Pending |

---

## Evolution

Este documento evolui a cada transição de fase e marco do projeto.

**Após cada transição de fase** (via `/gsd-transition`):
1. Requisitos invalidados? → Mover para Out of Scope com motivo
2. Requisitos validados? → Mover para Validated com referência da fase
3. Novos requisitos surgiram? → Adicionar em Active
4. Decisões a registrar? → Adicionar em Key Decisions
5. "What This Is" ainda preciso? → Atualizar se divergiu

**Após cada marco** (via `/gsd-complete-milestone`):
1. Revisão completa de todas as seções
2. Verificar Core Value — ainda é a prioridade certa?
3. Auditar Out of Scope — os motivos ainda são válidos?
4. Atualizar Context com o estado atual

---
*Last updated: 2026-05-24 after initialization*
