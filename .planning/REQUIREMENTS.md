# Requirements: Calendário de Aprovação de Artes — v1.7

**Defined:** 2026-08-29
**Milestone:** v1.7 — WhatsApp Auto-Post + Deploy
**Core Value:** O cliente consegue aprovar ou pedir alteração em cada arte sem precisar de conta — só com o link — e o admin vê tudo num só lugar.

**Goal do milestone:** O admin dispara artes aprovadas para grupos de WhatsApp selecionados, no dia e hora que escolher, com delay aleatório entre grupos — cada cliente com seu próprio número via Evolution API.

> **Nota de risco registrada:** a automação via Evolution API (Baileys) viola o ToS do WhatsApp. A alternativa oficial (Cloud API Groups) não cobre este caso de uso — limita grupos a 8 participantes e cria grupos novos em vez de entrar em grupos de consumidor existentes. A decisão por Evolution foi tomada pelo usuário de forma informada; estes requisitos carregam as mitigações. Detalhe em `.planning/research/SUMMARY.md`.

---

## v1.7 Requirements

### Infraestrutura e Fundação

- [ ] **INFRA-01**: ActiveStorage serve arquivos via S3 em produção, com URL alcançável pelo host público do Evolution
- [ ] **INFRA-02**: Jobs agendados sobrevivem a reinício do servidor em development (queue adapter explícito + schema de fila carregado), viabilizando UAT de agendamento
- [ ] **INFRA-03**: O fuso horário é determinístico entre development e produção (`TZ` fixado no deploy, com verificação no boot)
- [ ] **INFRA-04**: Segredos do Evolution (`apikey`, `hash`, `token`, QR) nunca aparecem em log — `filter_parameters` corrigido, e nenhum segredo trafega como argumento de job
- [ ] **INFRA-05**: `good_job` removido do Gemfile, restando um único adapter de fila no bundle
- [ ] **INFRA-06**: Disparos de WhatsApp rodam em fila dedicada, sem atrasar os broadcasts de ActionCable do v1.5
- [ ] **INFRA-07**: `failed_executions` do solid_queue tem política de retenção, evitando acúmulo de argumentos de job em texto claro

### Transporte Evolution API

- [ ] **EVO-01**: O contrato do Evolution é verificado empiricamente contra o host real da agência antes de qualquer código depender dele (versão, shape dos DTOs, casing dos eventos de webhook, JID de grupo em `sendMedia`)
- [ ] **EVO-02**: Toda comunicação HTTP com o Evolution passa por um único service PORO, com timeouts explícitos e header `apikey`
- [ ] **EVO-03**: Erros do Evolution são classificados em transitório / permanente / incerto / não-conectado, e cada classe tem tratamento distinto
- [ ] **EVO-04**: O token de cada instância é persistido criptografado no banco (`encrypts`), com as chaves de `active_record_encryption` configuradas antes da primeira gravação

### Instância e Pareamento

- [ ] **PAIR-01**: Admin cria uma instância de WhatsApp para um cliente que ainda não tem uma
- [ ] **PAIR-02**: Admin registra uma instância que já existe no Evolution, em vez de falhar quando o nome está em uso
- [ ] **PAIR-03**: Admin vê o QR Code na tela do app e o código se mantém escaneável enquanto ele rotaciona (~25s)
- [ ] **PAIR-04**: Admin vê o estado de conexão da instância de cada cliente (conectada / desconectada / aguardando pareamento)
- [ ] **PAIR-05**: Admin consegue verificar a conexão manualmente, sem depender do webhook
- [ ] **PAIR-06**: O app recebe eventos do Evolution por webhook autenticado, com o segredo comparado por `secure_compare` antes de qualquer consulta ao banco
- [ ] **PAIR-07**: A tela de pareamento avisa, no momento de escanear o QR, que o número está sujeito a banimento pelo WhatsApp
- [ ] **PAIR-08**: A UI informa há quanto tempo o número foi pareado e recomenda cautela em números recentes — sem bloquear o envio

### Grupos

- [ ] **GRUPO-01**: Admin sincroniza a lista de grupos da instância de um cliente
- [ ] **GRUPO-02**: A listagem de grupos é servida de cache local, não de uma chamada ao Evolution a cada request
- [ ] **GRUPO-03**: Admin seleciona quais grupos recebem o post, a partir apenas dos grupos da instância daquele cliente
- [ ] **GRUPO-04**: Grupos onde só administradores podem enviar aparecem sinalizados na seleção
- [ ] **GRUPO-05**: Grupos que sumiram do WhatsApp são marcados como inativos, nunca apagados, preservando o histórico

### Divulgação

- [ ] **DIVU-01**: Admin cria uma Divulgação escolhendo cliente, arte, grupos e data/hora de envio
- [ ] **DIVU-02**: Só artes aprovadas podem ser selecionadas para Divulgação
- [ ] **DIVU-03**: Artes cujo arquivo é um link externo (Drive/Dropbox) são recusadas na criação, com mensagem orientando o upload
- [ ] **DIVU-04**: Arquivos acima do teto que o WhatsApp aceita são recusados na criação da Divulgação, sem alterar a validação da Arte
- [ ] **DIVU-05**: A data e hora do envio são exibidas com o fuso explícito, e `Arte#scheduled_on` permanece uma data sem hora
- [ ] **DIVU-06**: Admin vê um preview do que será postado — mídia e legenda — antes de confirmar
- [ ] **DIVU-07**: Admin vê uma estimativa de duração do disparo ao agendar, dado o número de grupos e a faixa de delay
- [ ] **DIVU-08**: Admin cancela uma Divulgação agendada, e o cancelamento é respeitado pelos envios ainda não realizados
- [ ] **DIVU-09**: Cada grupo de uma Divulgação tem um registro próprio com status `pendente / enviado / falhou / incerto`, com o nome do grupo preservado como estava no momento do envio

### Motor de Envio

- [ ] **ENVIO-01**: Na hora agendada, o sistema envia a arte para cada grupo selecionado com um intervalo aleatório entre eles
- [ ] **ENVIO-02**: A faixa mínima e máxima do intervalo vem de variáveis de ambiente, não da interface nem do banco
- [ ] **ENVIO-03**: Um disparo longo não ocupa capacidade de background do app enquanto espera entre grupos
- [ ] **ENVIO-04**: Um grupo nunca recebe a mesma Divulgação duas vezes, mesmo com re-tentativa de job, worker morto ou deploy no meio do disparo
- [ ] **ENVIO-05**: Timeout de leitura no envio é tratado como resultado incerto e nunca re-tentado automaticamente, ficando para revisão humana
- [ ] **ENVIO-06**: A aprovação da arte é revalidada no momento do envio — se o cliente pediu alteração depois do agendamento, o envio não acontece
- [ ] **ENVIO-07**: O estado da conexão é verificado imediatamente antes de cada envio; instância desconectada nunca é registrada como enviada
- [ ] **ENVIO-08**: A URL da mídia é gerada no momento do envio, com validade suficiente para o disparo inteiro
- [ ] **ENVIO-09**: Envios de uma mesma instância são serializados, nunca disparados em paralelo pelo mesmo número
- [ ] **ENVIO-10**: Arte com legenda vai como mídia com legenda; arte só de texto vai como mensagem de texto

### Isolamento entre Clientes

- [ ] **SEG-01**: O identificador do grupo nunca vem cru do formulário — só chaves internas resolvidas dentro do escopo do cliente
- [ ] **SEG-02**: O sistema recusa uma Divulgação cuja arte e cujos grupos não pertençam ao mesmo cliente
- [ ] **SEG-03**: O envio usa o token da instância daquele cliente, de forma que um erro de escopo falhe com 401 em vez de postar no cliente errado
- [ ] **SEG-04**: Existem testes que provam que a arte do cliente A não alcança os grupos do cliente B

### Acompanhamento

- [ ] **ACOMP-01**: Admin acompanha o progresso do disparo ao vivo, sem recarregar a página
- [ ] **ACOMP-02**: Admin reenvia manualmente para um grupo específico que falhou, com confirmação explícita
- [ ] **ACOMP-03**: Admin vê o histórico de Divulgações de um cliente, com o resultado por grupo

---

## Future Requirements

Reconhecidos, fora do roadmap do v1.7.

### Entrega e Enriquecimento

- **DELIV-01**: Status "entregue" real via webhook `MESSAGES_UPDATE` / `DELIVERY_ACK` — enriquecimento, não fonte de verdade
- **DELIV-02**: Circuit breaker por instância após N falhas consecutivas

### Produtividade

- **PROD-01**: Conjuntos de grupos salvos e reutilizáveis
- **PROD-02**: Duplicar uma Divulgação para outra data (casa com ADM2-02)
- **PROD-03**: Gate de warm-up que bloqueia disparos grandes em número recém-pareado (no v1.7 é apenas aviso — ver PAIR-08)
- **PROD-04**: Normalização de links de Drive/Dropbox para download direto (no v1.7 são bloqueados — ver DIVU-03)

### Backlog anterior, ainda válido

- **NOTF-01**: Notificações por e-mail ao admin quando cliente aprova ou pede alteração
- **NOTF-02**: Notificações por e-mail ao cliente quando arte é revisada
- **ADM2-01**: Exportar relatório de aprovações em PDF ou CSV
- **ADM2-02**: Duplicar uma arte para outro cliente ou data
- **DOCS-01**: Documentação Swagger/OpenAPI da API v1

---

## Out of Scope

Excluídos explicitamente, para impedir scope creep.

| Feature | Motivo |
|---------|--------|
| UI de configuração da faixa de delay | Decisão do usuário: a faixa fica em ENV. Expor na UI convida a baixar o delay até o ban |
| Botão "enviar para todos os grupos" | Remove a fricção que protege o número; a seleção deliberada é a mitigação |
| Recorrência / cron por Divulgação | Multiplica o volume sem supervisão — o vetor de ban mais direto |
| Caixa de entrada de mensagens dos grupos | O produto é aprovação de artes, não atendimento |
| Cliente escolhendo grupos ou horário no portal | Decisão do usuário: o portal do cliente segue exclusivo para aprovação |
| Envio para números individuais | Escopo é grupos; mensagem individual não solicitada tem risco de ban muito maior |
| `mentionsEveryOne` | Marcar todos os participantes é o gatilho clássico de denúncia |
| Retry automático agressivo | Colide com a idempotência do ENVIO-05 e com o anti-spam |
| Editar ou apagar mensagem já enviada | Não há "desfazer" confiável no WhatsApp; falsa sensação de segurança |
| Rotação de múltiplos números por cliente | Padrão de evasão; aumenta o risco em vez de reduzir |
| Migrar `default_timezone` para `:utc` | Mudança transversal em todo o app; INFRA-03 resolve o risco fixando `TZ` |
| Publicação automática em Instagram/Facebook/LinkedIn | Já fora de escopo desde o v1.0 — Meta API exige app review |

---

## Traceability

Preenchido durante a criação do roadmap.

| Requirement | Phase | Status |
|-------------|-------|--------|
| (a mapear) | | |

**Coverage:**
- v1.7 requirements: 50 total
- Mapped to phases: 0
- Unmapped: 50 ⚠️

---
*Requirements defined: 2026-08-29*
*Last updated: 2026-08-29 after research synthesis*
