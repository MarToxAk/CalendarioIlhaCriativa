# Project Research Summary

**Project:** Calendário de Aprovação de Artes
**Milestone:** v1.7 — WhatsApp Auto-Post + Deploy
**Domain:** Disparo agendado de artes aprovadas em grupos de WhatsApp, via bridge não-oficial (Evolution API / Baileys), a partir de um monólito Rails 8.1.3 existente
**Researched:** 2026-08-29
**Confidence:** MEDIUM-HIGH (alta no lado Rails e nos contratos lidos do código-fonte upstream; baixa nas heurísticas de anti-ban e no que o host real da agência de fato roda)

> Esta SUMMARY substitui integralmente a versão anterior (v1.5 / ActionCable). Nenhum conteúdo daquela milestone foi mantido.

---

## Executive Summary

O v1.7 acopla ao app um **gateway de WhatsApp por cliente**: cada cliente pareia o próprio número numa instância Evolution API (v2, Baileys), o admin sincroniza a lista de grupos daquela instância, escolhe uma arte **já aprovada**, escolhe os grupos e uma data/hora, e o app dispara os envios em background com um intervalo aleatório entre grupos. As quatro pesquisas convergem numa arquitetura única e sem ambiguidade: um **service PORO `Evolution::Client` como única costura HTTP**, entidades novas (`WhatsappInstance` → `WhatsappGroup`, `Divulgacao` → item por grupo), e **um job por (divulgação × grupo)** agendado com `wait_until` — nunca um job único com `sleep`. Este último ponto não é preferência de estilo: o `config/queue.yml` deste projeto tem **3 threads no total**, então um job que dorme 20 minutos consome um terço da capacidade de background do app inteiro e perde todo o progresso num deploy.

A stack nova é deliberadamente mínima: **`faraday` + `aws-sdk-s3`**, mais a **remoção do `good_job`** (instalado, ligado a nada). Agendamento, criptografia de token, renderização de QR e broadcast ao vivo já existem no app (solid_queue, ActiveRecord::Encryption, o base64 que o próprio Evolution devolve, e o ActionCable/solid_cable da v1.5). A migração do ActiveStorage para S3 (INFRA-01) **não é conveniência de deploy — é bloqueio funcional**: quem baixa a mídia é o host do Evolution, e uma URL de `192.168.3.203` é inalcançável de fora.

Os riscos se concentram em três frentes. **Irreversibilidade:** um post errado num grupo de cliente não se desfaz — daí a prioridade em idempotência, escopo cross-client e revalidação de aprovação no momento do envio. **Segredos:** o token por instância dá controle do WhatsApp do cliente, e hoje o `filter_parameters` do projeto não casa com `apikey` nem `hash`, e argumentos de ActiveJob não são filtrados de forma alguma. **Ban:** a via oficial (Cloud API Groups) não cobre este caso de uso; a escolha do usuário por Evolution já foi feita, e o roadmap precisa carregar as mitigações (delay generoso, serialização por instância, número dedicado, aviso na UI de pareamento) em vez de reabrir a discussão.

---

## Key Findings

### Recommended Stack

Duas gems novas, uma removida, zero mudança de paradigma. Detalhe completo em [STACK.md](STACK.md).

**Core technologies:**

- **`faraday ~> 2.14`** — cliente HTTP do `Evolution::Client`. Escolhido sobre `Net::HTTP` principalmente porque traz `Faraday::Adapter::Test` (o repo não tem WebMock nem VCR — sem isso, testar o client significaria disparar mensagens reais) e porque centraliza `base_url`, header `apikey` e os três timeouts numa única `Faraday::Connection`.
- **`aws-sdk-s3 ~> 1.229, require: false`** — ActiveStorage S3 em produção. Rails 8.1.3 declara `~> 1.48`; satisfeito.
- **Remover `good_job`** — `grep` em `config/`, `db/`, `app/`, `lib/` retorna zero referências. O único adapter ligado é `:solid_queue`. Remoção isolada, cedo na milestone, antes de qualquer código de job.
- **solid_queue 1.4.0 (já instalado)** — `enqueue_at` e `limits_concurrency` confirmados na cópia em `vendor/bundle`. `set(wait_until:)` é suficiente; nenhum `whenever`, cron ou `sidekiq-scheduler`.
- **ActiveRecord::Encryption (built-in)** — `encrypts` no token por instância. Exige rodar `bin/rails db:encryption:init` e gravar as 3 chaves em credentials **antes** do primeiro `encrypts` subir.
- **QR: nenhuma gem.** O Evolution devolve `qrcode.base64` como data-URI PNG completo — `image_tag` direto. `rqrcode` seria puro desperdício.

**Contrato do Evolution (v2, tag `2.3.7`):** auth pelo header **`apikey`** (nunca `Authorization: Bearer`), rotas no formato `{BASE}/{recurso}/{ação}/{instanceName}` com a única exceção de `POST /instance/create`. Chave **global** para ciclo de vida de instância; **token por instância** (`hash`) para envio. `getParticipants` é obrigatório na query de `fetchAllGroups`. O campo `delay` do `sendMedia` é simulação de "digitando" que **bloqueia a request HTTP** — não é espaçamento entre grupos.

### Expected Features

Detalhe em [FEATURES.md](FEATURES.md).

**Must have (table stakes):**
- `Evolution::Client` PORO com timeouts e taxonomia de erros — tudo depende dele
- Instância Evolution 1:1 por cliente, com **create + QR** e **adoção de instância existente** (403 "already in use" → adotar)
- Badge de estado da conexão + pré-check `connectionState == open` imediatamente antes de cada envio
- Sync e cache de grupos em tabela (a chamada é lenta demais para o request), com `announce` visível
- `Divulgacao` (`send_at` datetime) + item por grupo com status `pendente / enviado / falhou`
- Seleção só de artes aprovadas + preview obrigatório antes de confirmar
- Job por grupo com delay aleatório vindo de ENV
- `sendMedia` (image/video com `caption`) e `sendText` (caption_only)
- Cancelar Divulgação agendada — checado **dentro** do job
- INFRA-01: ActiveStorage S3 com URL alcançável pelo host do Evolution

**Should have (competitivo, nesta ordem):**
- Timeline de envio ao vivo via ActionCable — melhor custo/benefício da milestone, a infra já existe desde a v1.5
- Aviso `announce` ("só admins enviam") na seleção de grupos — converte falha silenciosa em decisão informada
- Retry manual por grupo, com confirmação e registro de quem reenviou
- Webhook receiver (`CONNECTION_UPDATE`, `QRCODE_UPDATED`) para QR ao vivo e alerta de logout
- Estimativa de duração exibida ao agendar ("12 grupos × 45–120s ≈ 9–24 min")

**Defer (v1.7.x / v2+):**
- Status "entregue" via `MESSAGES_UPDATE` / `DELIVERY_ACK` — enriquecimento, não fonte de verdade
- Conjuntos de grupos salvos; duplicar Divulgação (casa com ADM2-02); circuit breaker por instância
- Flag "sou admin" via `getParticipants=true` (caro e não confiável com a migração `@lid`)

**Anti-features (explicitamente NÃO construir):** UI de configuração do delay (a faixa fica em ENV, por decisão já registrada); botão "enviar para todos os grupos"; recorrência/cron por Divulgação; caixa de entrada de mensagens; cliente escolhendo grupos ou horário no portal; envio para números individuais; `mentionsEveryOne`; retry automático agressivo; editar/apagar mensagem já enviada; rotação de números.

### Architecture Approach

Detalhe em [ARCHITECTURE.md](ARCHITECTURE.md). O padrão é o já estabelecido no app: controllers finos → services PORO em `app/services/whatsapp/` (precedente `Api::JwtService`) → jobs que só carregam, delegam e consolidam status. **Nenhum controller e nenhum job fala HTTP diretamente.**

**Componentes principais:**
1. **`Evolution::Client` / `Whatsapp::EvolutionClient`** — única costura HTTP; auth, timeouts, classificação de erro em `Transient` / `Permanent` / `Unknown` / `NotConnected`.
2. **`InstanceProvisioner` + `InstanceSynchronizer`** — cria **ou adota** instância; ao adotar, **sempre re-aponta o webhook** (esquecer isso é a causa do painel que fica eternamente "conectando").
3. **`GroupSynchronizer`** — `fetchAllGroups` → upsert em `whatsapp_groups`; grupos sumidos viram `active: false`, nunca são apagados.
4. **`DispatchScheduler`** — o **único lugar onde `rand` é chamado**; computa e **persiste** o horário por grupo antes de enfileirar qualquer filho. `rng:` injetável para teste determinístico.
5. **`MediaResolver`** — `Arte` → payload que o Evolution consegue baixar; **minta a URL presignada aqui, no momento do envio**, com `expires_in: 15.minutes`.
6. **`GroupMessageSender`** — unidade de idempotência: claim atômico → resolve mídia → envia → classifica → grava.
7. **`Webhooks::EvolutionController` + `WebhookProcessor`** — fronteira de entrada não confiável; `secure_compare` do segredo **antes** de qualquer lookup, `head :ok` rápido, throttle no Rack::Attack.

**Modelagem:** `whatsapp_instances` como **tabela separada** (não colunas em `clients` — `clients` está no caminho quente de auth e do ActionCable, e o QR é um blob multi-KB que rotaciona a cada ~25s). Nos itens de envio, **denormalizar `group_jid` e `group_subject`**: o picker lê o estado atual, o histórico lê o snapshot, o envio lê só a identidade. Índice único `(divulgacao_id, group_jid)`.

### Critical Pitfalls

Top 5 de [PITFALLS.md](PITFALLS.md), por dano:

1. **Duplicar envio em retry de `Net::ReadTimeout`** — o Evolution é documentado por dar timeout HTTP *enquanto entrega*. Prevenção: claim atômico (`UPDATE ... WHERE status IN (pending, queued)`) + separar `Net::OpenTimeout` (nada foi enviado → retry) de `Net::ReadTimeout` (pode ter enviado → estado `incerto`, **nunca** retry automático, revisão humana).
2. **Vazamento cross-client** — arte do cliente A no grupo do cliente B, irreversível e com dois clientes lesados. Prevenção: nunca aceitar `group_jid` cru de `params` (só PK interna resolvida via `@client.whatsapp_instance.whatsapp_groups`), validação `arte.client_id == client_id` no model, reafirmar escopo dentro do job, e **usar o token por instância no envio** — assim um erro de escopo vira 401 barulhento em vez de post silencioso no cliente errado.
3. **Burst disparando o anti-spam** — o Evolution **não tem rate limiter, fila nem retry embutidos** (confirmado na issue #2538). Prevenção: delay aleatório do lado Rails, **serialização por instância** (`limits_concurrency key: instance/client, to: 1`), e não confiar no param `delay`.
4. **URL de mídia inalcançável ou expirada** — cinco modos de falha: LAN/localhost, URL assinada expirada (default de **5 minutos** contra um disparo que dura ~1h), `external_url` de Drive/Dropbox que devolve HTML, arquivo entre 16 MB e os 50 MB que o model aceita, e mimetype/codec divergente. Prevenção: S3 + URL gerada **dentro do `perform`**, bloqueio de `external_url` na criação da Divulgação, validação de tamanho específica de divulgação.
5. **Assumir que a instância pareada continua pareada** — `statusReason` 401/403/402/406 **não** auto-reconectam e exigem QR novo. Prevenção: consultar `connectionState` imediatamente antes de cada envio; se `!= open`, marcar `pendente_reconexao` — **jamais** `enviado`.

**Menções honrosas obrigatórias:** `sleep` no job travando 1 das 3 threads; segredo passado como argumento de job (o solid_queue grava argumentos em texto claro e `failed_executions` não é limpo pelo `recurring.yml` atual); webhook público sem autenticação; timezone com `default_timezone = :local`; job agendado para daqui a dias que quebra em rename de classe ou ignora um cancelamento.

---

## Riscos de contradição com o cliente (ranqueados)

São as falhas que destroem confiança de forma não recuperável. Ordem por severidade × irreversibilidade:

| # | Falha | Por que é a pior | Mitigação que o roadmap deve carregar |
|---|-------|------------------|----------------------------------------|
| 1 | **Envio cross-client** — arte de A no grupo de B | Incidente de confidencialidade com **dois** clientes ao mesmo tempo, entregue a dezenas de pessoas, sem desfazer | Grupos como registros escopados; só PK interna vinda do form; validação no model; escopo reafirmado no job; token por instância no envio; testes negativos A×B |
| 2 | **Publicar arte cuja aprovação foi retirada depois do agendamento** | Viola a proposta de valor central do produto (o calendário existe para aprovar antes de publicar); o cliente vê no ar exatamente o que pediu para mudar | **Revalidar `arte.approved?` dentro do job**, não só no formulário; validar também `client.active?`; bloquear/cancelar quando o status regredir para `change_requested` |
| 3 | **Post duplicado no mesmo grupo** | Constrangedor e é o comportamento que faz participantes denunciarem o número — ou seja, alimenta o risco de ban | Índice único `(divulgacao_id, group_jid)`; claim atômico; `Net::ReadTimeout` → `incerto` e nunca retry; reenvio manual com confirmação explícita |

Nota: 1 e 2 são erros de *conteúdo* (o app fez a coisa errada); 3 é erro de *entrega*. Os três compartilham a mesma propriedade — não há "desfazer" no WhatsApp — e por isso as três mitigações são requisitos de fase, não polimento.

---

## A decisão de risco (ToS / ban) — registro factual

A automação via cliente não-oficial viola o ToS do WhatsApp (texto literal em `whatsapp.com/legal`: proibição de "unofficial clients, bulk messaging, auto-messaging... or automation" e de engenharia reversa). A alternativa sancionada — WhatsApp Business Cloud API — **não cobre este caso de uso**: a Groups API exige Official Business Account, limita grupos a **8 participantes**, **cria** grupos novos em vez de entrar em grupos de consumidor já existentes, e é indisponível para números do app WhatsApp Business. Para "postar nos grupos de WhatsApp que o cliente já tem", a escolha real é **Evolution assumindo o risco de ban** ou **não ter o recurso**.

O usuário já decidiu por Evolution. O roadmap não reabre a decisão; ele carrega as mitigações:

- Número **dedicado** por cliente, nunca o número principal do negócio
- Consentimento por escrito do cliente mencionando o risco de ban
- Uma linha de aviso na UI de pareamento, no momento de escanear o QR
- Delay generoso e serialização por instância (Pitfall 1)
- Gate de warm-up para instância recém-pareada — é o único ponto em que todas as fontes concordam qualitativamente
- Isolamento por instância já garante que um cliente banido não contamina os outros

Todos os números concretos de anti-ban da literatura (delay de 15–45s, "10–20 msg/min", "1 em 5 contas banidas") são **anedóticos, de fornecedor, sem metodologia** — a dispersão entre fontes (1s a 45s) é a prova de que ninguém conhece o limiar. Meta nunca publicou. Trate como heurística defensiva, não como contrato.

---

## Defeitos pré-existentes no codebase

Encontrados pelos pesquisadores por inspeção direta do repo. **São bugs de hoje, não trabalho novo.**

| Defeito | Evidência | Veredicto |
|---------|-----------|-----------|
| `config/environments/development.rb` **sem queue adapter** → cai no `:async`; todo job agendado se perde ao reiniciar `bin/dev` | ausência de `config.active_job.queue_adapter`; default em `activejob-8.1.3/lib/active_job/queue_adapter.rb:35` | **BLOQUEIA.** Impossível fazer UAT de "agendei para amanhã às 9h". Corrigir na primeira fase, junto com carregar `db/queue_schema.rb` no banco de development e rodar `bin/jobs` ao lado do `bin/dev` |
| `ActiveStorage.service_urls_expire_in` no default de **5 minutos** | `activestorage-8.1.3/lib/active_storage.rb:357` | **BLOQUEIA** o caminho de envio — mas a correção **não é** subir o default global (isso enfraquece toda URL do app). A correção é passar `expires_in:` explícito por chamada, dentro do job |
| `filter_parameter_logging.rb` não casa com **`apikey`** nem **`hash`** (o filtro `:_key` casa `instance_key`, não `apikey`) | leitura do initializer | **BLOQUEIA** a fase que grava o primeiro token. Adicionar `:apikey, :api_key, :instance_token, :hash, :qrcode, :base64, :pairing_code`. Lembrar: `filter_parameters` **não** filtra argumentos de ActiveJob — a regra de "só IDs como argumento" é separada e igualmente obrigatória |
| `arte.rb` valida até **50 MB**, WhatsApp entrega ~**16 MB** | `app/models/arte.rb` | **BLOQUEIA** parcialmente: existe uma janela 16–50 MB que passa no Rails e falha no WhatsApp. Validar na `Divulgacao` (não mexer no `Arte`). O teto exato **deve ser medido em UAT**, não copiado de blog |
| `config/application.rb:25` — `active_record.default_timezone = :local` | leitura direta | **BLOQUEIA por decisão**, não por código: a `Divulgacao` reintroduz o datetime que a v1.0 evitou. Recomendação das pesquisas: **manter `:local` e travar `TZ=America/Sao_Paulo` no deploy**, com verificação no boot. Migrar para `:utc` está fora do escopo do v1.7 |
| `good_job` no Gemfile ligado a nada | zero referências em `config/`, `db/`, `app/`, `lib/` | **Limpeza oportunista**, mas de baixo custo e com valor real: dois adapters no bundle fazem um typo de `queue_adapter` falhar em silêncio. Fazer como commit isolado antes de escrever job |
| `app/jobs/application_job.rb` com `retry_on`/`discard_on` **comentados** | leitura direta | **BLOQUEIA a fase de envio**: o default valeria para o job novo sem ninguém decidir. A taxonomia de retry precisa ser explícita no job de envio |
| `config/recurring.yml` limpa `finished`, não `failed`; `queue.yml` com fila única `"*"` e 3 threads | leitura direta | **Oportunista + acoplado ao envio**: fila `whatsapp` dedicada é requisito da fase de envio; retenção de `failed_executions` é hardening (segredos antigos persistem lá) |
| `rack_attack.rb` sem regra para as rotas novas | leitura direta | **Acoplado**: nasce junto com o webhook, não é dívida anterior |

---

## Implications for Roadmap

### Ordem de build reconciliada

ARCHITECTURE.md propôs fases numeradas 25→30; PITFALLS.md propôs slugs `INFRA-S3 → EVO-CLIENT → EVO-PAREAMENTO → EVO-GRUPOS → DIVU-MODEL → DIVU-ENVIO → HARDENING`. **Concordam na direção das dependências**; divergem em granularidade (6 vs 7 passos) e em onde o S3 entra — ARCHITECTURE o funde com o transporte na fase 25; PITFALLS o coloca sozinho, primeiro, argumentando que o Pitfall 5 é o que mais gera retrabalho se descoberto tarde.

**Reconciliação:** os dois estão certos sobre a *ordem*; a divergência é só de empacotamento. S3 e transporte Evolution são **independentes entre si** e ambos precedem tudo mais — podem ser um passo com dois planos paralelos, ou dois passos. Fica a critério do roadmapper. Abaixo está a espinha dorsal com as **restrições duras** explicitadas; a contagem final de fases é decisão do roadmapper.

| Passo | Entrega | Restrições duras |
|-------|---------|------------------|
| **A. Fundação: transporte + storage** | `Evolution::Client` + `Errors` + `config/initializers/whatsapp.rb`; `faraday`; remoção do `good_job`; `aws-sdk-s3` + `storage.yml` amazon + `production.rb` → `:amazon`; `TZ` travado no deploy; queue adapter no `development.rb` | **PRECEDE TUDO.** Sem S3 (ou uma decisão explícita de base64) nenhum envio de mídia funciona — o download é feito pelo host do Evolution, não pelo Rails. Sem adapter em development não há UAT de agendamento. Verificação = round-trip real contra o host da agência e um upload real no S3 |
| **B. Modelo de segredos + instância** | migration `whatsapp_instances`, `encrypts :api_token`, chaves `active_record_encryption` em credentials, `filter_parameters` corrigido, `InstanceProvisioner` (create **e** adopt), `InstanceSynchronizer` | **PRECEDE a gravação do primeiro token.** Adicionar `encrypts` depois significa migrar dados sensíveis já persistidos. Depende de A (o client HTTP) |
| **C. Pareamento: QR, estado, webhook** | tela de QR com auto-refresh, `Webhooks::EvolutionController` + `WebhookProcessor` + `secure_compare` + Rack::Attack, botão manual "Verificar conexão", `paired_at`, aviso de risco de ban na UI | **PRECEDE qualquer listagem de grupo.** Sem instância `open` não existem grupos. O webhook de instância adotada **tem** que ser re-apontado aqui. O botão manual é obrigatório: em dev o Evolution pode não alcançar o LAN |
| **D. Grupos: sync, cache, seleção** | `whatsapp_groups` + `GroupSynchronizer` + `SyncGroupsJob` + picker com badge `announce` e fallback de `subject` nulo | **PRECEDE a `Divulgacao`**, que referencia grupos. É aqui que a modelagem escopada fecha o risco cross-client. `fetchAllGroups` é lento demais para o request — cache obrigatório desde o dia 1 |
| **E. `Divulgacao` + itens (sem enviar)** | migrations `divulgacoes` + itens por grupo, **índice único `(divulgacao_id, group_jid)`**, snapshot de `group_jid`/`group_subject`, validações cruzadas de client, `send_at` com `Time.zone.parse` e fuso visível na UI, bloqueio de `external_url`, teto de 16 MB, preview, gate de warm-up | **PRECEDE o envio.** Parar deliberadamente antes de enviar torna o schema — a parte mais cara de errar — verificável isoladamente e permite rollback do envio sem levar o CRUD junto |
| **F. Motor de envio** | `DispatchScheduler` (o único `rand`), `MediaResolver`, `GroupMessageSender` com claim atômico, jobs pai/filho com `wait_until`, taxonomia de retry, fila `whatsapp` dedicada, job de reconciliação, histórico por grupo | **Fase de maior densidade de risco** (pitfalls 1, 4, 5, 7, 8, 11). Depende de A + E. Merece code review dedicado |
| **G. UI ao vivo + hardening** | linhas de status ao vivo pelo cable da v1.5, reenvio manual por item, cancelar, alerta de "divulgação atrasada", auditoria de segredos, testes negativos cross-client, retenção de `failed_executions` | Reusa o padrão de broadcast da v1.5 integralmente |

**Restrições de ordenação, resumidas:** A → B → C → D → E → F → G. Nenhum par pode ser invertido. Os únicos paralelismos legítimos são *dentro* de A (S3 e transporte Evolution não se tocam) e, parcialmente, entre a UI de G e o final de F.

**Onde o S3 fica, resolvido:** em A, junto com o transporte. Fundir não perde nada — ambos são "de-risking sem UI" — e evita uma fase de uma linha só. Se o roadmapper preferir separar, S3 vem **primeiro**, não depois.

### Research Flags

Fases que provavelmente precisam de `--research-phase` no planejamento:

- **Passo A (fundação)** — a verificação empírica do contrato Evolution é *a* tarefa mais importante da milestone e é pesquisa, não implementação. Ver "Verificado vs. Assumido" abaixo.
- **Passo F (motor de envio)** — apontado explicitamente pela pesquisa de pitfalls: a API exata de concurrency controls na versão do solid_queue instalada, e o **formato exato do erro do `sendMedia`** para mapear retry vs. discard (o Evolution devolve `BadRequestException(error.toString())` — texto livre, não estruturado).

Fases com padrões estabelecidos (dispensam research):

- **Passo E (CRUD da Divulgação)** — migrations, validações e formulário são Rails padrão e o repo já tem os precedentes (`@client.artes.find`, `set_arte`).
- **Passo G (UI ao vivo)** — o padrão de broadcast já foi construído e validado na v1.5; é replicação, não descoberta.

---

## Verificado vs. Assumido

O roadmapper precisa saber quais afirmações são fatos lidos de fonte primária e quais precisam ser confirmadas contra o host real da agência (`whatsapp.bomcustoilhabela.com.br`) **no passo A, antes de qualquer código depender delas**.

### VERIFICADO (HIGH — não re-pesquisar)

- Versões de gem (faraday 2.14.3, aws-sdk-s3 1.229.0, solid_queue 1.7.0 disponível) — API do rubygems.org, 2026-08-29
- Auth do Evolution pelo header `apikey`; modelo de credencial dupla (global vs. por instância) — `src/api/guards/auth.guard.ts` no upstream
- Forma das rotas; `getParticipants` obrigatório como string; DTOs de `sendText`/`sendMedia`; semântica do campo `delay`; QR como data-URI base64 completo — código-fonte no **tag `2.3.7`**
- Quebra de payload v1 → v2 (só o corpo muda; os paths são iguais) — comparação entre os tags `1.8.2` e `2.3.7`
- `enqueue_at` e `limits_concurrency` presentes no solid_queue 1.4.0 — gem instalada em `vendor/bundle`
- Expiry default de 5 min do ActiveStorage; restrição de gem do S3Service — fonte da gem instalada
- Todos os defeitos do codebase da seção anterior — inspeção direta deste repo
- Ausência de rate limiter/fila/retry no Evolution — issue #2538
- Limitações da Groups API oficial (OBA, 8 participantes, cria em vez de entrar) — documentação da Meta

### ASSUMIDO (precisa de verificação empírica no passo A)

1. **Qual versão o host da agência realmente roda.** Tudo acima foi lido no tag `2.3.7` ou no `main` (que já é a linha 2.4.0-rc). `GET /` devolve um banner de versão. **Se divergir, os DTOs mudam.** Esta é a verificação nº 1.
2. **Diferenças entre `main` e o tag `2.3.7`** em `auth.guard.ts`, `group.schema.ts` e `sendMessage.dto.ts` — a pesquisa de stack leu do `main`, que está à frente do estável.
3. **Shape e *casing* exatos dos payloads de webhook** (`QRCODE_UPDATED` vs `qrcode.updated`; `CONNECTION_UPDATE`) — as fontes divergem entre versões; o `WebhookProcessor` deve aceitar ambas as grafias.
4. **Se o host do Evolution alcança este app Rails** para webhooks — hoje o app está em `192.168.3.203`. Se não alcançar, o botão manual "Verificar conexão" deixa de ser fallback e vira o caminho principal em dev.
5. **Teto real de tamanho de mídia** para imagem e vídeo através deste gateway — ~16 MB é heurística convergente, não documentada no repo do Evolution. **Medir em UAT e codificar o valor medido.**
6. **Se `sendMedia` aceita JID de grupo em `number` nesse build** — a leitura do `createJid.ts` diz que sim (`@g.us` passa intacto), mas confirmar com um envio real para um grupo de teste.
7. **Toda a camada anti-ban** (faixa de delay, cadência de warm-up, volume seguro por instância) — anedótica por natureza. A postura correta é conservadorismo (delay generoso, poucos grupos, warm-up), não precisão falsa.
8. **Comportamento de `ProcessPrunedError`** do solid_queue (pruned → failed, sem retry) — vem do README oficial, é afirmação carregadora de peso para o desenho de jobs, e deve ser reconfirmada contra a versão instalada no passo F.

---

## Confidence Assessment

| Área | Confiança | Notas |
|------|-----------|-------|
| Stack | **HIGH** | Toda versão veio da API do rubygems.org ou da gem instalada em `vendor/bundle`. Único item MEDIUM: a escolha Faraday-sobre-Net::HTTP, que é juízo de design com o contra-argumento declarado |
| Features | **HIGH** para contratos de endpoint / **LOW** para heurísticas de mercado | Endpoints, DTOs e schemas lidos do código-fonte upstream num tag fixo (`2.3.7`) — mais forte que a doc pública, que retornou 404. Comparativos de mercado e faixas anti-ban vêm de material de fornecedor |
| Architecture | **HIGH** no lado Rails / **LOW-MEDIUM** no contrato de rede | O desenho Rails foi derivado da leitura direta deste repo (`queue.yml`, `storage.yml`, `production.rb`, `arte.rb`, `jwt_service.rb`, `connection.rb`). O contrato Evolution nessa pesquisa veio de docs de comunidade, com drift real entre 2.1/2.2/2.4 — **a pesquisa de features corrige isso lendo o código-fonte no tag** |
| Pitfalls | **MEDIUM** | ToS e limitações da Cloud API são citação literal; ausência de rate limiter é confirmada em issue; comportamento do solid_queue é documentado; **todos os números de anti-ban são anedóticos** e o próprio documento é explícito sobre isso |

**Overall confidence:** MEDIUM-HIGH — alta o suficiente para planejar o roadmap inteiro; a única incerteza que pode alterar o desenho é a versão real do Evolution em produção, e ela é barata de verificar no primeiro passo.

### Gaps to Address

- **Versão real do Evolution deployado** → primeira tarefa verificável do passo A; um `GET /` e um diff dos três arquivos de DTO. Se for 2.4.x, re-checar antes de escrever o client.
- **Teto de tamanho de mídia** → medir em UAT com arquivos de 5/15/20/30 MB; codificar o valor medido na validação da `Divulgacao`. Não copiar número de blog.
- **Política para artes com `external_url` (Drive/Dropbox)** → decisão de produto pendente. As pesquisas divergem levemente: STACK/ARCHITECTURE sugerem "normalizar os dois hosts conhecidos **ou** bloquear"; PITFALLS recomenda **bloquear**, porque não existe normalização confiável para todos os provedores. **Recomendação desta síntese: bloquear na criação da Divulgação com mensagem acionável ("faça upload do arquivo"), e tratar normalização como melhoria posterior.** Resolver no passo E.
- **Alcançabilidade do webhook a partir do host do Evolution** → testar no passo A/C; determina se o webhook é o caminho principal ou se o botão manual carrega o fluxo em dev.
- **URL vs. base64 para a mídia** → o consenso é URL presignada do S3 gerada dentro do job. Base64 é saída de emergência válida para imagem (< ~10 MB) e ruim para vídeo. Manter como branch documentado no `MediaResolver`, não como caminho padrão.
- **Blobs locais já existentes** na migração para S3 → decidir explicitamente entre migrar/espelhar ou aceitar que artes pré-deploy percam o arquivo. Passo A.
- **Variação de legenda anti-spam** → risco estrutural não eliminável (o produto *é* "mande esta arte para estes grupos"). Se houver variação, ela **precisa ser visível ao admin no preview**, senão vai ao ar conteúdo que o cliente não aprovou. Decisão no passo E.

---

## Sources

### Primary (HIGH confidence)
- `evolution-foundation/evolution-api` @ tag **`2.3.7`** — routers, controllers, guards, DTOs, schemas de validação, `wa.types.ts`, `createJid.ts`, `whatsapp.baileys.service.ts`, `.env.example`
- `evolution-foundation/evolution-api` @ tag **`1.8.2`** — diferença de payload v1 → v2
- `WhiskeySockets/Baileys` — `src/Types/GroupMetadata.ts` (`announce`, `restrict`, `GroupParticipant.admin`, `addressingMode`)
- GitHub Releases + Docker Hub tags API — v2.3.7 estável, 2.4.0-rc, v1 EOL, imagem canônica `evoapicloud/evolution-api`
- rubygems.org API — versões de todas as gems avaliadas
- Gems instaladas em `vendor/bundle` — `solid_queue-1.4.0`, `activejob-8.1.3`, `activestorage-8.1.3`, `activerecord-8.1.3`
- Este repositório — `config/application.rb`, `config/queue.yml`, `config/recurring.yml`, `config/storage.yml`, `config/environments/production.rb`, `config/initializers/filter_parameter_logging.rb`, `config/initializers/rack_attack.rb`, `app/models/arte.rb`, `app/models/client.rb`, `app/jobs/application_job.rb`, `app/services/api/jwt_service.rb`, `app/channels/application_cable/connection.rb`, `db/schema.rb`
- [WhatsApp Messaging Guidelines](https://www.whatsapp.com/legal/messaging-guidelines) e [Terms of Service](https://www.whatsapp.com/legal/terms-of-service) — citação literal
- [Meta — WhatsApp Groups API](https://developers.facebook.com/documentation/business-messaging/whatsapp/groups) — OBA, limite de 8 participantes

### Secondary (MEDIUM confidence)
- [rails/solid_queue README](https://github.com/rails/solid_queue/blob/main/README.md) — scheduled_executions, `limits_concurrency`, failed_executions, `ProcessPrunedError`
- [solid_queue issue #176](https://github.com/rails/solid_queue/issues/176) — concurrency control bloqueia duplicatas, não descarta
- [evolution-api issue #2538](https://github.com/evolution-foundation/evolution-api/issues/2538) — sem rate limiter/fila/retry embutidos
- [evolution-api issue #1499](https://github.com/EvolutionAPI/evolution-api/issues/1499) — timeout de request em envio para grupo (base do desenho de idempotência)
- [evolution-api issue #2124](https://github.com/EvolutionAPI/evolution-api/issues/2124) — `fetchAllGroups` devolve grupos sem `subject`
- [evolution-api issue #2385](https://github.com/EvolutionAPI/evolution-api/issues/2385) — `/instance/connect` devolve `count:0` sem QR em alguns builds
- [rails/rails issue #32236](https://github.com/rails/rails/issues/32236) — URL presignada do ActiveStorage expirando

### Tertiary (LOW confidence — não planejar em cima)
- WasenderApi, YCloud, Unipile e demais blogs de fornecedor — faixas de delay (15–45s vs 1–5s), cronograma de warm-up, "1 em 5 contas banidas". **Sem metodologia; a dispersão entre fontes é a prova de que o limiar real é desconhecido**
- [Baileys #1869](https://github.com/WhiskeySockets/Baileys/issues/1869) e [#2075](https://github.com/WhiskeySockets/Baileys/issues/2075) — relatos de bans em massa; #1869 ficou stale sem resposta técnica. Sinal útil apenas em um ponto: a fiscalização muda com o tempo, então "funcionou mês passado" não é garantia
- Postman collections e gists de integração do Evolution v2.2 — úteis como corroboração, superados pela leitura do código-fonte no tag

---
*Research completed: 2026-08-29*
*Ready for roadmap: yes*
