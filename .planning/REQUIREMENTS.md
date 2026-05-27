# Requirements: Calendário de Aprovação de Artes

**Defined:** 2026-05-24
**Core Value:** O cliente consegue aprovar ou pedir alteração em cada arte sem precisar de conta — só com o link — e o admin vê tudo num só lugar.

## v1 Requirements

### Autenticação (AUTH)

- [x] **AUTH-01**: Admin pode criar conta e fazer login com email e senha
- [x] **AUTH-02**: Admin pode fazer logout da sessão
- [x] **AUTH-03**: Cada cliente tem um link público único (token de 24 chars) para acessar o próprio calendário
- [x] **AUTH-04**: Cliente precisa digitar uma senha simples ao acessar o link pela primeira vez na sessão
- [x] **AUTH-05**: Admin pode rotacionar o token de um cliente (gera novo link, invalida o anterior e a sessão existente)
- [x] **AUTH-06**: Cliente pode fazer logout do portal

### Clientes (CLIE)

- [x] **CLIE-01**: Admin pode criar um novo cliente com nome e senha do portal
- [x] **CLIE-02**: Admin pode editar os dados de um cliente (nome, senha)
- [x] **CLIE-03**: Admin pode desativar um cliente (bloqueia acesso ao portal)
- [x] **CLIE-04**: Admin pode ver o link de acesso e a senha do portal de cada cliente para copiar e enviar
- [ ] **CLIE-05**: Admin pode ver o histórico de aprovações de um cliente específico (todas as artes respondidas)

### Artes / Conteúdo (ARTE)

- [x] **ARTE-01**: Admin pode criar uma arte associada a um cliente e a uma data específica
- [x] **ARTE-02**: Admin pode fazer upload direto de arquivo (imagem ou vídeo) para a arte
- [x] **ARTE-03**: Admin pode colar um link externo (Google Drive, Dropbox) como arquivo da arte
- [x] **ARTE-04**: Admin pode definir a plataforma da arte (Instagram, Facebook ou LinkedIn)
- [x] **ARTE-05**: Admin pode definir o formato da arte (imagem, vídeo ou legenda)
- [x] **ARTE-06**: Admin pode definir uma data limite de aprovação para a arte
- [x] **ARTE-07**: Admin pode adicionar uma legenda/texto que acompanha a arte
- [ ] **ARTE-08**: Admin pode editar os dados de uma arte (antes da aprovação do cliente)
- [ ] **ARTE-09**: Admin pode excluir uma arte

### Calendário do Cliente (CAL)

- [x] **CAL-01**: Cliente vê um grid mensal com todas as artes agendadas para o mês
- [x] **CAL-02**: Cliente pode navegar entre meses (mês anterior / próximo)
- [x] **CAL-03**: Cliente pode ver o preview completo de cada arte (imagem, vídeo ou legenda)
- [x] **CAL-04**: Cliente vê o prazo de aprovação e o status atual de cada arte
- [x] **CAL-05**: Cliente vê o ícone da plataforma (Instagram, Facebook, LinkedIn) em cada arte

### Aprovação (APRO)

- [x] **APRO-01**: Cliente pode aprovar uma arte com um clique
- [x] **APRO-02**: Cliente pode pedir alteração em uma arte e escrever um comentário explicando o que quer
- [x] **APRO-03**: Após o admin revisar e marcar como revisada, a arte volta ao status pendente e o cliente precisa aprovar novamente (re-aprovação)
- [x] **APRO-04**: Cliente pode ver o histórico de decisões de cada arte (aprovações e pedidos anteriores)
- [x] **APRO-05**: Somente artes com status pendente podem receber ação de aprovação (sem duplo-envio)

### Painel do Admin (PAIN)

- [ ] **PAIN-01**: Admin vê um dashboard com todas as respostas de todos os clientes (artes aprovadas e com pedido de alteração)
- [ ] **PAIN-02**: Admin pode filtrar o dashboard por cliente
- [ ] **PAIN-03**: Admin pode filtrar o dashboard por status (Aprovado / Pediu Alteração / Revisado)
- [ ] **PAIN-04**: Admin pode marcar uma arte como "Revisada" após fazer as alterações solicitadas
- [ ] **PAIN-05**: Admin pode responder ao comentário do cliente dentro do sistema

## v2 Requirements

### Notificações

- **NOTF-01**: Admin recebe e-mail quando cliente aprova ou pede alteração
- **NOTF-02**: Cliente recebe e-mail quando arte é revisada e volta para aprovação

### Calendário

- **CAL2-01**: Faixa de resumo no topo do calendário (X aprovados, Y pedindo alteração, Z pendentes)

### Admin

- **ADM2-01**: Exportar relatório de aprovações de um cliente em PDF ou CSV
- **ADM2-02**: Duplicar uma arte para outro cliente ou data

## Out of Scope

| Feature | Motivo |
|---------|--------|
| Login OAuth (Google, etc.) para clientes | Link + senha é suficiente e menos fricção para o cliente |
| Integração com APIs de redes sociais (publicação automática) | Meta API exige app review e infraestrutura complexa; fora do escopo de aprovação |
| App mobile nativo | Web-first; mobile via browser responsivo |
| Multi-stage workflows (aprovação em etapas) | Feature de enterprise, desnecessária para 10-30 clientes |
| White-labeling / domínio personalizado | Complexidade de infra sem benefício imediato |
| IA para geração de legendas | Fora do escopo de aprovação |
| Drag-and-drop de artes no calendário | Conforto de UX para v2+ |
| Real-time collaboration | WebSockets desnecessário neste volume |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| AUTH-01 | Phase 1 | Complete |
| AUTH-02 | Phase 1 | Complete |
| AUTH-03 | Phase 1 | Complete |
| AUTH-04 | Phase 1 | Complete |
| AUTH-05 | Phase 1 | Complete |
| AUTH-06 | Phase 1 | Complete |
| CLIE-01 | Phase 2 | Complete |
| CLIE-02 | Phase 2 | Complete |
| CLIE-03 | Phase 2 | Complete |
| CLIE-04 | Phase 2 | Complete |
| CLIE-05 | Phase 6 | Pending |
| ARTE-01 | Phase 3 | Complete |
| ARTE-02 | Phase 3 | Complete |
| ARTE-03 | Phase 3 | Complete |
| ARTE-04 | Phase 3 | Complete |
| ARTE-05 | Phase 3 | Complete |
| ARTE-06 | Phase 3 | Complete |
| ARTE-07 | Phase 3 | Complete |
| ARTE-08 | Phase 3 | Pending |
| ARTE-09 | Phase 3 | Pending |
| CAL-01 | Phase 4 | Complete |
| CAL-02 | Phase 4 | Complete |
| CAL-03 | Phase 4 | Complete |
| CAL-04 | Phase 4 | Complete |
| CAL-05 | Phase 4 | Complete |
| APRO-01 | Phase 5 | Complete |
| APRO-02 | Phase 5 | Complete |
| APRO-03 | Phase 5 | Complete |
| APRO-04 | Phase 5 | Complete |
| APRO-05 | Phase 5 | Complete |
| PAIN-01 | Phase 6 | Pending |
| PAIN-02 | Phase 6 | Pending |
| PAIN-03 | Phase 6 | Pending |
| PAIN-04 | Phase 6 | Pending |
| PAIN-05 | Phase 6 | Pending |

**Coverage:**
- v1 requirements: 35 total
- Mapped to phases: 35
- Unmapped: 0 ✓

---
*Requirements defined: 2026-05-24*
*Last updated: 2026-05-24 after initial definition*
