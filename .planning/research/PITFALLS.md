# Pitfalls Research — WhatsApp Auto-Post via Evolution API (v1.7)

**Domain:** Automação de postagem em grupos de WhatsApp a partir de um app Rails 8 existente, usando Evolution API (bridge não-oficial baseada em Baileys)
**Researched:** 2026-08-29
**Confidence:** MEDIUM geral — MEDIUM para ToS/política e para solid_queue; LOW→MEDIUM para números concretos de rate limit (ver "Qualidade da evidência")

> **Nota de numeração de fases.** O roadmap v1.7 ainda não existe. As fases citadas abaixo são **slugs sugeridos**, não números fixos. O roadmapper deve mapear cada slug para o número real. A ordem sugerida está em [Pitfall-to-Phase Mapping](#pitfall-to-phase-mapping).
>
> | Slug | Escopo |
> |------|--------|
> | `INFRA-S3` | Active Storage S3 + deploy público (INFRA-01) |
> | `EVO-CLIENT` | Service PORO Evolution + credenciais + modelo `WhatsappInstance` |
> | `EVO-PAREAMENTO` | Criação de instância, QR Code, estado de conexão, webhook |
> | `EVO-GRUPOS` | Listagem/cache/seleção de grupos |
> | `DIVU-MODEL` | Entidade `Divulgacao` + agendamento (data/hora) + UI admin |
> | `DIVU-ENVIO` | Job de envio, delay, throttling, histórico por grupo |
> | `HARDENING` | Logs, filtros, observabilidade, code review, UAT |

---

## Qualidade da evidência (leia antes de usar os números)

Esta é uma área onde a internet está cheia de números confiantes sem metodologia. Sendo direto sobre o que é o quê:

| Afirmação | Qualidade |
|-----------|-----------|
| Automação via cliente não-oficial viola o ToS do WhatsApp | **Fato verificável.** Texto literal em `whatsapp.com/legal` (citado abaixo). |
| Evolution API **não** tem rate limiter nem fila embutidos | **Fato verificável.** Confirmado na issue [#2538](https://github.com/evolution-foundation/evolution-api/issues/2538); mantenedores não ofereceram números seguros. |
| Estados de conexão, statusReason, endpoints, params de `sendMedia` | **Documentado** (docs oficiais Evolution v2). |
| Comportamento de `solid_queue` (args no banco, at-least-once, sem discard de duplicatas) | **Documentado** no README oficial e nas issues [#176](https://github.com/rails/solid_queue/issues/176). |
| "~10–20 mensagens/minuto por instância antes do anti-spam" | **Anedótico / opinião de fornecedor.** Nenhuma fonte cita medição. |
| "delay de 15–45s entre mensagens, pausa de 10–15min a cada 50" | **Anedótico / opinião de fornecedor** (WasenderApi). Outras fontes dizem 1–5s. A dispersão de 1s→45s entre fontes é a prova de que ninguém sabe o limite real. |
| Cronograma de warm-up (semana 1 manual, semana 2 ~10–20 msg/dia, +20%) | **Anedótico**, mas é o único ponto em que **todas** as fontes concordam qualitativamente. |
| "1 em cada 5 contas com API não-oficial é banida em um ano" | **Marketing de fornecedor sem metodologia.** Não use para planejar. |
| Bans em massa relatados nas issues Baileys [#1869](https://github.com/WhiskeySockets/Baileys/issues/1869) / [#2075](https://github.com/WhiskeySockets/Baileys/issues/2075) | **Anedótico.** Issue #1869 ficou *stale* sem explicação técnica de mantenedor. Sinal útil: contas com 3+ anos sem problema foram banidas de repente — a fiscalização **muda com o tempo**, então "funcionou mês passado" não é garantia. |

**Meta nunca publicou os limiares de detecção.** Qualquer número neste documento é heurística defensiva, não contrato.

---

## Seção 0: A decisão de ToS e ban (o usuário decide; o papel aqui é informar)

### O que o ToS diz, literalmente

**WhatsApp Messaging Guidelines** proíbe explicitamente:

> "use unofficial clients, bulk messaging, auto-messaging, auto-dialing, or automation to harm WhatsApp or our users"

**WhatsApp Terms of Service:**

> "create accounts for our Services through unauthorized or automated means"
>
> "reverse engineer, alter, modify, create derivative works from, decompile, or extract code from our Services"
>
> "We may modify, suspend, or terminate your access to or use of our Services anytime for any reason, such as if you violate the letter or spirit of our Terms..."
>
> "If you violate our Terms or policies, we may take action with respect to your account, including disabling or suspending your account and, if we do, you agree not to create another account without our permission."

Baileys funciona **se passando por um dispositivo companion** (o mesmo mecanismo do WhatsApp Web). Isso é exatamente o que o parágrafo de engenharia reversa cobre. **Não há leitura do ToS em que Evolution/Baileys esteja permitido.**

### O risco concreto para este projeto

O que está em jogo **não é a conta do usuário** — é a **conta de WhatsApp de cada cliente da agência**, já que cada cliente pareia o próprio número:

| Consequência | Detalhe |
|--------------|---------|
| Ban do número do cliente | Enforcement documentado: "temporarily or permanently suspending an account". Bans por API não-oficial tendem a ser permanentes e **sem apelação prática** (anedótico, mas consistente entre fontes). |
| Perda da presença do cliente no WhatsApp | O número banido é o número comercial do cliente. Ele perde histórico, grupos e contatos — não só a automação. |
| Restrição em grupos | "preventing further activity in groups and/or communities" — pode ficar mudo nos grupos sem perder a conta. |
| Responsabilidade contratual da agência | Se a agência opera o número do cliente e ele é banido, o dano é do cliente e a conversa é comercial, não técnica. |
| Quebra silenciosa por atualização do WhatsApp | Baileys é engenharia reversa. O WhatsApp muda o protocolo sem aviso; o parear/enviar pode parar de funcionar em qualquer deploy do lado deles. |

### O que a alternativa oficial oferece — e por que ela não resolve este caso

**WhatsApp Business Cloud API** (Meta) é o caminho sancionado: sem risco de ban por ToS, com SLA, templates aprovados, webhooks estáveis.

Mas para **este** requisito específico — "postar uma arte nos grupos de WhatsApp que o cliente já tem" — a Cloud API **não atende**:

| Restrição da Groups API (Cloud API, lançada out/2025) | Impacto aqui |
|---|---|
| Exige **Official Business Account (OBA)** | Clientes de agência pequena não têm OBA. |
| Grupos limitados a **8 participantes** | Grupos de divulgação reais têm 50–1000. Inviável. |
| Apenas **1 negócio Cloud API por grupo** | — |
| A API **cria** grupos novos; não entra em grupos de consumidor já existentes | O caso de uso é exatamente postar em grupos que já existem. |
| Indisponível para números do app WhatsApp Business | A maioria dos clientes usa exatamente isso. |
| Preço por mensagem | Custo recorrente por grupo × por post. |

**Conclusão factual, sem juízo de valor:** o caminho oficial existe e é seguro, mas **não cobre "postar em grupos de WhatsApp preexistentes de terceiros"**. Uma agência pequena que quer esse recurso não tem uma alternativa oficial equivalente — a escolha real é entre *fazer via Evolution assumindo o risco de ban* ou *não ter o recurso*. Essa é a decisão do usuário; o papel deste documento é garantir que ela seja tomada com o preço na mesa.

### Mitigações de produto (independentes de código)

Se o caminho não-oficial for escolhido, essas medidas reduzem o dano **quando** — não *se* — um número for banido:

1. **Número dedicado por cliente, nunca o número pessoal/principal do cliente.** Chip separado. Se banir, o cliente perde um canal de divulgação, não o WhatsApp do negócio.
2. **Consentimento explícito e por escrito do cliente**, mencionando o risco de ban. Vira cláusula de contrato, não surpresa.
3. **Aviso na UI de pareamento**, no momento de escanear o QR: uma linha dizendo que o número pode ser banido pelo WhatsApp.
4. Um cliente banido **não pode contaminar os outros** — instâncias são isoladas por número. Isso é a favor do design escolhido (uma instância por cliente).

**Fase:** `EVO-PAREAMENTO` (aviso na UI) + decisão de produto antes do roadmap.

---

## Critical Pitfalls

### Pitfall 1: Rajada de envios (burst) dispara o anti-spam e derruba o número

**What goes wrong:**
Uma Divulgação com 12 grupos vira 12 chamadas `sendMedia` no mesmo segundo, porque o job faz `groups.each { send }` sem pacing, ou porque 3 threads do solid_queue processam 3 Divulgações simultâneas. O número entra em restrição ou ban em minutos.

**Why it happens:**
A causa técnica mais citada de ban é **concorrência não gerenciada e tráfego em rajada**. E o Evolution API **não protege**: a issue [#2538](https://github.com/evolution-foundation/evolution-api/issues/2538) confirma que não existe rate limiter, fila ou retry embutido — sends vão direto para a instância. O parâmetro `delay` do `sendMedia` **é uma simulação de "digitando..." antes de um único envio, não um rate limiter** entre envios. Quem assume que `delay` protege contra ban está enganado.

**How to avoid:**
- Delay aleatório **entre** grupos, aplicado no lado Rails, não no `delay` do Evolution. Faixa em ENV conforme já decidido no PROJECT.md. Sugestão de default conservador: `WHATSAPP_DELAY_MIN=45`, `WHATSAPP_DELAY_MAX=120` (segundos). Justificativa: 10–30 clientes com poucos grupos cada não têm pressa; o custo de um delay generoso é zero e o custo de um ban é o cliente.
- **Serialização por instância**, não só delay. Dois jobs da mesma instância nunca podem enviar em paralelo. Use `ActiveJob` concurrency control do solid_queue com `key: "whatsapp-#{instance_id}"` e `to_concurrency_limit: 1`.
- **Teto por janela** por instância (ex.: máx. 30 envios/hora, contador em tabela ou `Rails.cache`), com a Divulgação transbordando para a hora seguinte em vez de estourar.
- Randomizar também a **ordem** dos grupos entre execuções.

**Warning signs:**
- Logs mostram dois `sendMedia` da mesma instância com timestamps < faixa mínima de delay.
- `connectionState` volta `close` com `statusReason` 401/403 logo depois de uma Divulgação grande.
- Cliente relata "meu WhatsApp pediu para confirmar o número".
- Histórico por grupo com uma sequência de sucessos seguida de falhas em bloco.

**Phase to address:** `DIVU-ENVIO` (obrigatório antes de qualquer envio real).

---

### Pitfall 2: Mensagem byte-a-byte idêntica em N grupos

**What goes wrong:**
A mesma legenda e a mesma mídia disparadas para 12 grupos em sequência formam o padrão exato que sistemas anti-spam procuram. Uma fonte descreve o sinal como "500 mensagens idênticas em 5 segundos" — o formato do caso de uso é uma versão diluída disso.

**Why it happens:**
O produto é literalmente "mande esta arte para estes grupos". A identidade do conteúdo é o requisito, não um bug. Isso torna o pitfall estrutural, não acidental.

**How to avoid:**
- Aceitar que este é um risco residual **não eliminável** e dimensioná-lo: menos grupos por Divulgação, delay maior.
- Variação leve e barata da legenda, se o usuário quiser: sufixo aleatório invisível-ish (variação de emoji final, quebra de linha, saudação por horário). **Não implementar "spinning" agressivo** — muda o texto que o cliente aprovou, o que quebra o contrato do produto (o cliente aprovou *aquela* arte).
- Se implementar variação, ela precisa ser **visível ao admin na tela de Divulgação** antes do envio; caso contrário vira conteúdo não aprovado indo ao ar.
- **Não usar `mentionsEveryOne`** — marcar todos em grupos grandes é um dos comportamentos mais denunciáveis pelos participantes, e denúncia de usuário é sinal de ban.

**Warning signs:**
- Divulgações com mais de ~10 grupos viram rotina.
- Nenhuma variação e delay no mínimo da faixa.
- Participantes saindo dos grupos após os posts (proxy de denúncia).

**Phase to address:** `DIVU-MODEL` (decidir se há variação e expô-la na UI) + `DIVU-ENVIO`.

**Evidência:** anedótica. Nenhuma fonte mede o efeito da variação de conteúdo sobre a taxa de ban.

---

### Pitfall 3: Número novo pareado hoje, disparando hoje (sem warm-up)

**What goes wrong:**
Cliente novo entra no sistema, compra um chip, pareia o QR e o admin agenda uma Divulgação para 8 grupos no mesmo dia. Este é o cenário que as fontes descrevem como ban quase certo em minutos — "conectar um SIM novo e imediatamente disparar broadcast".

**Why it happens:**
O fluxo do produto convida a isso: parear → listar grupos → criar Divulgação é uma sequência natural de 5 minutos na UI. Nada no caminho feliz sugere esperar.

**How to avoid:**
- Registrar `paired_at` (ou `first_connected_at`) na instância.
- **Gate de maturidade no app**, não só documentação: bloquear ou avisar em vermelho ao criar Divulgação quando `paired_at < 14.days.ago`, e limitar o nº de grupos por Divulgação nas primeiras semanas (ex.: 2 grupos na semana 1, 5 na semana 2, livre depois). Um `WhatsappInstance#max_groups_per_divulgacao` derivado da idade resolve.
- Texto explícito no onboarding: usar o número **manualmente** por ~1 semana (conversar, entrar em grupos, receber mensagens) antes de automatizar.
- Preferir **número que o cliente já usa há meses** a chip novo, quando possível — mas ver Pitfall 0 (o risco recai sobre um número com histórico).

**Warning signs:**
- `paired_at` e a primeira Divulgação no mesmo dia.
- Instância com razão enviadas/recebidas extremamente assimétrica (só envia, nunca recebe).

**Phase to address:** `EVO-PAREAMENTO` (campo `paired_at` + aviso) e `DIVU-MODEL` (gate na criação).

**Evidência:** anedótica, mas é o único ponto de consenso entre todas as fontes consultadas.

---

### Pitfall 4: O app assume que a instância pareada continua pareada

**What goes wrong:**
A sessão Baileys cai: o cliente desconectou "Dispositivos conectados" no celular, o celular ficou offline demais, o container Evolution reiniciou sem volume persistente, ou o WhatsApp invalidou a sessão. A Divulgação agendada para as 18h dispara às 18h, o Evolution retorna erro (ou pior, aceita e não entrega), e o histórico marca "enviado" para grupos que nunca receberam nada. O admin descobre dias depois.

**Why it happens:**
O modelo mental de "instância criada = canal permanente" é falso. Evolution expõe três estados — `open`, `close`, `connecting` — com `statusReason` numérico. Crucialmente, **nem toda desconexão se auto-recupera**:

| `statusReason` | Causa | Auto-reconecta? |
|---|---|---|
| 401, 403, 402, 406 | logout, banido, pagamento, sessão inválida | **NÃO** — exige novo QR |
| 408, 428, 500 | timeout, conexão perdida, erro de servidor | Sim, com backoff exponencial |

Um app que só faz retry cego nunca sai do 401 — ele precisa **pedir um QR novo ao admin**.

**How to avoid:**
- **Checar `GET /instance/connectionState/:instance` imediatamente antes de cada envio.** Se `state != "open"`, **não envie**: marque o item do histórico como `pendente_reconexao` (não `falhou`, não `enviado`) e notifique o admin. Nunca marque como enviado sem confirmação do Evolution.
- Persistir na tabela `whatsapp_instances`: `connection_state`, `status_reason`, `last_seen_at`, `wuid` (o número real conectado).
- **Webhook `connection.update`** apontando para um endpoint Rails: atualiza o estado em tempo real e permite o badge/toast do ActionCable já existente (v1.5) avisar o admin na hora em que cai.
- Distinguir **recuperável** (agendar retry) de **não recuperável** (exigir re-pareamento). `statusReason` 401/403 → estado `requires_pairing` na UI, com botão "Gerar novo QR".
- Guardar `wuid` no pareamento e **comparar antes do envio**: se o número conectado mudou, algo foi re-pareado com outro chip — abortar (ver Pitfall 10).
- Health check periódico (recurring job) varrendo instâncias `open` para detectar desconexões silenciosas entre Divulgações.
- QR expira em ~45s com regeneração; a UI precisa **atualizar o QR sozinha** (Turbo Stream + evento `qrcode.updated`), senão o admin escaneia um código morto.

**Warning signs:**
- Histórico com "enviado" mas o cliente jura que nada chegou.
- Nenhuma coluna de estado de conexão no schema — sinal de que o app assume "pareado para sempre".
- Instância em `connecting` por mais de ~30s.
- Volume do container Evolution não persistido → toda reinicialização perde todas as sessões de todos os clientes.

**Phase to address:** `EVO-PAREAMENTO` (estado + webhook + QR auto-refresh); guard de pré-envio em `DIVU-ENVIO`.

---

### Pitfall 5: A URL da mídia não é buscável pelo host do Evolution

**What goes wrong:**
O job monta o payload com `media: arte.media_file.url` e o Evolution responde erro ou envia um arquivo quebrado. Este é o motivo declarado da migração para S3 nesta milestone (INFRA-01), e ele tem **cinco modos de falha distintos** — resolver só o do S3 deixa quatro abertos.

**Why it happens:**
Quando `media` é uma URL, **quem faz o download é o host do Evolution**, não o Rails. Tudo que é verdade dentro da rede do Rails é irrelevante; o que importa é o que o container Evolution consegue alcançar.

| Modo de falha | Detalhe neste projeto |
|---|---|
| **URL de LAN / localhost** | O app roda em `192.168.3.203`. Qualquer URL derivada de `default_url_options` local é inalcançável de um Evolution público. Se o Evolution rodar no mesmo LAN, funciona em dev e quebra em prod — o pior tipo de bug. |
| **Signed URL expirada** | O default do Active Storage é `service_urls_expire_in = 5.minutes`. Uma Divulgação agendada gera a URL no enqueue e envia horas depois → 403 do S3. **Nunca gere a URL no momento do agendamento; gere dentro do job, no momento do envio.** |
| **`external_url` do Drive/Dropbox** | O sistema já aceita links externos (Drive/Dropbox) como fonte de mídia de uma Arte. Um link de compartilhamento do Google Drive retorna **uma página HTML de visualização**, não bytes de imagem. O Evolution vai baixar HTML e enviar lixo, ou falhar. **Artes com `external_url` de Drive/Dropbox precisam ser bloqueadas para Divulgação** ou convertidas para link direto — não existe conversão confiável para todos os provedores. Recomendação: exigir `media_file` anexado (Active Storage) para uma Arte ser divulgável. |
| **Arquivo grande demais** | O `Arte` model valida `size < 50.megabytes`, mas o WhatsApp entrega ~**16 MB** para imagem/vídeo/áudio como mídia. Existe uma janela de 16–50 MB que passa na validação do Rails e falha/degrada no WhatsApp. Adicionar validação específica de divulgação em 16 MB. |
| **Codec / mimetype divergente** | `mediatype` (`image`/`video`/`document`) e `mimetype` precisam bater com os bytes reais. `.mov` (QuickTime) — aceito pelo model — frequentemente não renderiza em todos os clientes WhatsApp; H.264/AAC em `.mp4` é o único combo consistentemente seguro. Issues como [#2056](https://github.com/EvolutionAPI/evolution-api/issues/2056) ("imagem falha ao carregar no app mobile") são desse gênero. |

**How to avoid:**
- **S3 com URL de vida longa gerada no job.** `arte.media_file.url(expires_in: 30.minutes)` chamado dentro do `perform`, nunca no enqueue.
- Alternativa mais robusta e recomendada para arquivos < ~10 MB: **enviar base64 em vez de URL**. Elimina de uma vez expiração, alcançabilidade e DNS. Custo: payload maior e uso de memória no worker. Para 10–30 clientes, isso é irrelevante e vale a robustez.
- **Preflight no job**: `HEAD` na URL antes de mandar ao Evolution, verificando status 200, `content-type` esperado e `content-length` ≤ 16 MB. Falhar cedo com mensagem acionável ("arquivo tem 23 MB, limite do WhatsApp é 16 MB") em vez de erro genérico do Evolution.
- Validar em `Divulgacao` (não só em `Arte`): mídia anexada via Active Storage, ≤ 16 MB, mimetype na lista curta (`image/jpeg`, `image/png`, `video/mp4`).
- Testar a alcançabilidade **de dentro do container Evolution** (`docker exec ... curl -I <url>`), não da máquina do dev.

**Warning signs:**
- A URL de mídia gerada contém `192.168.`, `localhost` ou a porta 3000.
- A URL é gerada fora do `perform` do job.
- Envio funciona em teste manual (imediato) e falha em agendado (horas depois) → sintoma clássico de URL assinada expirando.
- Grupo recebe um arquivo que não abre / preview quebrado.

**Phase to address:** `INFRA-S3` (host público, S3, `expires_in`); validação e preflight em `DIVU-ENVIO`; bloqueio de `external_url` em `DIVU-MODEL`.

---

### Pitfall 6: Segredo por cliente vazando via argumentos de job, logs e reporters

**What goes wrong:**
A apikey da instância Evolution do cliente é passada como argumento do job. O solid_queue **grava os argumentos serializados em JSON na tabela `solid_queue_jobs`, em texto claro**. A chave passa a existir em: um dump do banco, `solid_queue_failed_executions` (que sobrevive à falha e não é limpo pelo `clear_finished_in_batches` já configurado no `recurring.yml`), na UI do Mission Control Jobs, e no payload de qualquer exception reporter.

**Why it happens:**
Três mal-entendidos combinados:
1. Passar strings como argumento de job parece inofensivo.
2. **`config.filter_parameters` do Rails NÃO filtra argumentos de ActiveJob.** Ele filtra parâmetros de request. São caminhos completamente diferentes.
3. O filtro atual do projeto (`config/initializers/filter_parameter_logging.rb`) é `[:passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc]`. O matching é por **substring**: `:_key` casa com `instance_key`, mas **não casa com `apikey`** — que é exatamente o nome do header e do campo do Evolution API. `apikey` e `hash` (o nome do campo do token de instância retornado pelo Evolution) **passam batido hoje**.

**How to avoid:**
- **Regra absoluta: nenhum segredo como argumento de job.** Passe `divulgacao_id` (ou o GlobalID do record) e carregue a instância + credencial **dentro** do `perform`. Isto também é o que a documentação do solid_queue recomenda por outros motivos (manter args pequenos).
- Isso vale igualmente para a **URL assinada da mídia** — ela é uma credencial temporária. Gerá-la dentro do job resolve segurança e expiração de uma vez (Pitfall 5).
- Adicionar ao `filter_parameters`: `:apikey, :api_key, :instance_token, :hash, :qrcode, :base64, :pairing_code`.
- **Criptografia no banco** para a chave por cliente: `encrypts :api_key` (Active Record Encryption) na `WhatsappInstance`. Sem isso, um dump do Postgres entrega todas as instâncias WhatsApp de todos os clientes.
- **Nunca logar o corpo de request/response do Evolution cru.** O request carrega o header `apikey`; a resposta do `/instance/create` carrega o `hash` (token) e o QR base64 — que é literalmente uma credencial de pareamento visual. Logar só método, path, status e duração.
- O `qrcode`/`pairingCode` não deve ser persistido: é efêmero, renderize direto na resposta.
- **Chave global vs. por instância:** o `AUTHENTICATION_API_KEY` global do Evolution dá acesso a **todas** as instâncias. Ele é necessário para *criar* instâncias, mas o envio deve usar o **token por instância** (`hash`). Se o app usar a chave global para tudo, um bug de escopo vira acesso total (ver Pitfall 10). Guardar a global em credentials (prod) / `.env` (dev), e a por-instância criptografada na linha do cliente.

**Warning signs:**
- `grep -r "apikey" app/jobs` retorna algo em uma assinatura de `perform`.
- `SELECT arguments FROM solid_queue_jobs` mostra qualquer coisa que pareça uma chave ou uma URL assinada.
- `SELECT api_key FROM whatsapp_instances` retorna texto legível.
- Log de produção contém `apikey=` ou uma string base64 gigante.

**Phase to address:** `EVO-CLIENT` (encrypts + filter_parameters) e `DIVU-ENVIO` (assinatura do job); auditado em `HARDENING`.

---

### Pitfall 7: `sleep` longo dentro do job trava os workers

**What goes wrong:**
A implementação óbvia do delay aleatório é `groups.each { send; sleep rand(45..120) }`. Com 10 grupos isso segura uma thread por até 20 minutos. O `config/queue.yml` deste projeto tem **`threads: 3, processes: 1, queues: "*"`** — ou seja, **três** threads para o app inteiro. Duas Divulgações simultâneas consomem 2/3 da capacidade, e a terceira trava tudo: os broadcasts do ActionCable (v1.5), qualquer job futuro e a limpeza recorrente ficam na fila atrás de `sleep`.

**Why it happens:**
`sleep` no job é o jeito mais curto de escrever "delay entre grupos", e em dev com 2 grupos parece inofensivo.

**How to avoid:**
- **Um job por grupo, encadeado por `wait`.** `EnviarDivulgacaoItemJob.set(wait: delay).perform_later(item_id)` — o job envia para **um** grupo, calcula o próximo delay e enfileira o item seguinte. Zero sleep, worker livre entre envios, e cada item é retentável isoladamente.
- **Fila dedicada** para envio de WhatsApp, com o worker configurado separadamente, para que um pico de divulgações não afogue a fila `default` usada pelos broadcasts. Ajustar `config/queue.yml` para ter dois blocos de `workers` (ex.: `queues: "whatsapp"` e `queues: "default,*"`).
- Se por algum motivo houver `sleep`, tetá-lo em poucos segundos — nunca em minutos.

**Warning signs:**
- `sleep` presente em qualquer job.
- Toasts do ActionCable atrasando durante uma Divulgação.
- `solid_queue_ready_executions` crescendo com jobs antigos enquanto poucos jobs "rodam".
- `queues: "*"` sem fila dedicada, com envio de WhatsApp em produção.

**Phase to address:** `DIVU-ENVIO` (design do job) + `INFRA-S3`/deploy (config de workers).

---

### Pitfall 8: Retry duplica envios — a mesma arte postada duas vezes no mesmo grupo

**What goes wrong:**
O `sendMedia` chega ao WhatsApp, a mensagem é entregue, mas a resposta HTTP se perde (timeout, deploy no meio, worker morto). O ActiveJob faz retry, o job reenvia, e o grupo recebe a arte duas vezes. Em um grupo de divulgação isso não é um bug cosmético — é o comportamento que faz participantes denunciarem o número.

**Why it happens:**
- Solid Queue tem entrega **at-least-once**: "um deploy pode interromper a execução; um retry pode rodar o mesmo job de novo". Isso é documentado, não um defeito.
- O `ApplicationJob` do projeto tem `retry_on` e `discard_on` **comentados** — o default vai valer para o job novo sem ninguém decidir conscientemente.
- Os controles de concorrência do solid_queue **bloqueiam** duplicatas (elas esperam e depois rodam), mas **não existe forma de descartá-las** ([issue #176](https://github.com/rails/solid_queue/issues/176)). Confiar em "concurrency control evita duplicata" é um erro de leitura: ele *adia*, não *cancela*.

**How to avoid:**
- **Idempotência no banco, com o estado por grupo como fonte da verdade.** Modelar `DivulgacaoItem(divulgacao_id, group_jid, status, evolution_message_id, sent_at)` com **índice único em `(divulgacao_id, group_jid)`**.
- O job faz, em transação: `SELECT ... FOR UPDATE` no item → se `status != pendente`, **retorna sem enviar** → marca `enviando` → envia → grava `enviado` + `evolution_message_id`. Retry após entrega bem-sucedida encontra `enviado` e não faz nada.
- O estado intermediário `enviando` é essencial: um crash entre "enviei" e "gravei" deixa o item em `enviando`, que **não deve ser retentado automaticamente** — deve ir para revisão manual do admin ("pode ter sido enviado"). Retry cego a partir de `enviando` é exatamente a duplicata que se quer evitar.
- `retry_on` **explícito e estreito**: retentar só erros de rede/5xx do Evolution, com backoff. **`discard_on`** para 4xx de payload (arquivo inválido, grupo inexistente) — retentar não conserta.
- `discard_on ActiveJob::DeserializationError` para Divulgações apagadas.
- Botão de "reenviar item" na UI deve exigir confirmação e registrar quem reenviou.

**Warning signs:**
- Ausência de índice único em `(divulgacao_id, group_jid)`.
- Job de envio sem `retry_on` explícito.
- O job faz `update(status: :enviado)` antes ou depois da chamada HTTP sem transação/lock.
- Cliente relata post duplicado (sinal tardio — o dano já ocorreu).

**Phase to address:** `DIVU-ENVIO`; schema em `DIVU-MODEL`.

---

### Pitfall 9: Timezone — o post sai na hora errada (e este app tem uma armadilha específica)

**What goes wrong:**
O admin escolhe "18:00" e o post sai às 21:00, ou no dia seguinte. Para uma divulgação com hora comercial, isso destrói o valor do recurso.

**Why it happens — e por que é pior aqui:**
`config/application.rb` deste projeto tem:

```ruby
config.time_zone = "Brasilia"
config.active_record.default_timezone = :local   # ← linha 25
```

`default_timezone = :local` faz o Active Record **ler e gravar timestamps no fuso local do sistema operacional**, em vez de UTC. Consequências concretas:

- O `solid_queue_scheduled_executions.scheduled_at` é gravado pelo mesmo Active Record — o agendamento do job herda essa semântica.
- Se o servidor de produção tiver `TZ` diferente da máquina de dev (muito comum: containers rodam UTC), **os mesmos dados significam horas diferentes**. Isso muda silenciosamente entre dev e prod.
- O horário de verão brasileiro está suspenso desde 2019, o que mascara o problema — mas uma mudança de `TZ` do host o revela de uma vez.
- A decisão histórica do projeto de usar `scheduled_on :date` (não datetime) em `Arte` foi **tomada justamente para fugir disso**. A `Divulgacao` reintroduz um datetime, ou seja, reintroduz o problema que a v1.0 evitou.

**How to avoid:**
- **Decidir explicitamente** antes de escrever a migration: ou manter `:local` e fixar `TZ=America/Sao_Paulo` no ambiente de produção (documentado no deploy, verificado no boot), ou migrar para `default_timezone = :utc` (o default do Rails) — mas isso exige revisar os dados existentes e está fora do escopo de v1.7. **Recomendação: manter `:local` e travar `TZ` no deploy**, mais barato e menos arriscado.
- Armazenar `scheduled_at` como `datetime` e **sempre** construir a partir de `Time.zone.parse` / `Time.use_zone`, nunca `Time.parse` ou `DateTime.parse` (que ignoram o fuso do Rails).
- **Exibir o fuso na UI** ao lado do campo de hora ("18:00 — horário de Brasília"). Ambiguidade na UI vira ticket.
- Teste que fixa `Time.zone` e um `TZ` de sistema divergente e verifica que o `scheduled_at` persistido corresponde à hora pretendida.
- Validar `scheduled_at > Time.current` na criação (não aceitar agendamento no passado, que dispara imediatamente).
- Checagem de boot em produção que aborta se `Time.zone.name` ou `ENV["TZ"]` não forem o esperado.

**Warning signs:**
- `Time.parse` ou `DateTime.parse` em qualquer lugar do código de Divulgação.
- `Divulgacao.scheduled_at` sendo comparado com `Time.now` em vez de `Time.current`.
- `date` e `time` como dois campos separados combinados por concatenação de string.
- Diferença de 3h entre o esperado e o real (assinatura de UTC↔Brasília).

**Phase to address:** `DIVU-MODEL` (schema + parsing + UI); verificação de `TZ` em `INFRA-S3`/deploy.

---

### Pitfall 10: Vazamento cross-client — a arte do cliente A no grupo do cliente B

**What goes wrong:**
Três variantes, em ordem de gravidade:

1. **Envio cruzado:** a Divulgação do cliente A usa a instância/grupos do cliente B. A arte de um cliente aparece nos grupos de outro. Para uma agência, isso é um incidente de confidencialidade com dois clientes ao mesmo tempo — e é **irreversível**: a mensagem já foi entregue a dezenas de pessoas. Não há "desfazer".
2. **Exposição da lista de grupos:** o admin (ou a API) enumera grupos de outro cliente. A lista de grupos de WhatsApp de um cliente é informação comercial sensível.
3. **Sequestro de instância:** o `instance_name` do Evolution colide ou é adivinhável, e um cliente acaba operando a instância de outro.

**Why it happens:**
O invariante do projeto — "toda query escopada por `@client`" — foi aplicado consistentemente em `Arte` e `ApprovalResponse` porque essas entidades têm `belongs_to :client` e os controllers usam `@client.artes.find(...)`. As entidades novas de v1.7 têm **duas chaves de escopo que precisam concordar**: a Divulgação pertence a um cliente, **e** a Arte pertence a um cliente, **e** a instância pertence a um cliente, **e** os grupos pertencem à instância. Se qualquer um desses vínculos for validado por confiança em vez de por query escopada, abre a brecha.

O ponto exato de risco: os identificadores do Evolution (`instance_name`, `group_jid` `...@g.us`) são **strings vindas de fora do banco**, frequentemente vindas de um `params[:group_ids]` de formulário. Um `Divulgacao.create(group_jids: params[:group_jids])` sem validar que cada JID pertence à instância *daquele* cliente é o bug.

**How to avoid:**
- **Grupos como registros, não como strings soltas.** `WhatsappGroup belongs_to :whatsapp_instance`, `WhatsappInstance belongs_to :client`. A seleção do formulário resolve por `@client.whatsapp_instance.whatsapp_groups.where(id: params[:group_ids])` — cross-client vira `RecordNotFound` automaticamente, exatamente o padrão já usado em `set_arte` (`@client.artes.find`).
- **Nunca aceitar `group_jid` cru do formulário.** Aceitar `whatsapp_group_id` (PK interna) e derivar o JID do registro escopado.
- **Validação no model `Divulgacao`:** `validate` que `arte.client_id == client_id` **e** que todo `whatsapp_group.whatsapp_instance.client_id == client_id`. Redundante com o controller de propósito — defesa em profundidade, e é o único ponto que protege a API v1 e o console.
- **Reafirmar o escopo dentro do job**, não só no controller. O job recebe `divulgacao_id`; a primeira coisa que ele faz é `divulgacao.client` e derivar instância e grupos **daquele** cliente. Nunca aceitar `instance_name` como argumento do job.
- **`instance_name` único e não adivinhável:** `"cli-#{client.id}-#{SecureRandom.hex(6)}"`, com índice único, e **nunca** o nome do cliente (colisão entre clientes homônimos e enumerável no manager do Evolution).
- **Chave por instância, não a global, para enviar.** Se cada envio usa o token da própria instância, um erro de escopo falha com 401 em vez de postar no cliente errado. Isso transforma um vazamento silencioso em um erro ruidoso — é a mitigação mais valiosa da lista.
- **Verificação de `wuid` antes do envio:** comparar o número conectado com o esperado. Se divergir, abortar. Pega o caso de re-pareamento com o chip errado, que nenhuma validação de banco detecta.
- **Cliente inativo** (`client.active == false`) não pode ter Divulgação disparada — o job precisa checar, porque a Divulgação pode ter sido agendada antes da desativação.
- Testes de sistema explícitos: tentar criar Divulgação do cliente A com `arte_id` de B e com `whatsapp_group_id` de B; ambos devem falhar.

**Warning signs:**
- `params[:group_jids]` ou `params[:instance_name]` chegando a um model ou job.
- Qualquer query de grupo que comece em `WhatsappGroup.where(...)` em vez de `@client...`.
- Job de envio recebendo `instance_name`/apikey como argumento.
- Ausência de validação `arte.client_id == client_id` na `Divulgacao`.
- Uso da `AUTHENTICATION_API_KEY` global no caminho de envio.

**Phase to address:** `EVO-GRUPOS` (modelagem escopada) e `DIVU-MODEL` (validações cruzadas); testes em `HARDENING`.

---

### Pitfall 11: Jobs agendados para o futuro sobrevivem ao deploy e quebram

**What goes wrong:**
Uma Divulgação é agendada para daqui a 5 dias. A linha fica em `solid_queue_scheduled_executions` com a classe e os argumentos serializados. Nesses 5 dias há três deploys. Se a classe do job foi renomeada, removida, ou se a assinatura de `perform` mudou, o job **falha na desserialização** na hora H. O admin não é avisado — a Divulgação simplesmente não acontece.

**Why it happens:**
Jobs agendados são um contrato de compatibilidade entre o código de hoje e o de daqui a semanas, e ninguém pensa neles como contrato. Além disso: se o admin **editar ou cancelar** a Divulgação, o job agendado continua existindo e vai disparar mesmo assim, porque nada o cancela.

**How to avoid:**
- **A fonte da verdade é a tabela `divulgacoes`, não a fila.** O job agendado é só um gatilho: ao acordar, ele recarrega a Divulgação e checa `status == :agendada` e `scheduled_at` atual. Se foi cancelada → sai sem fazer nada. Se a hora mudou → reenfileira para a hora nova e sai. Isso resolve edição e cancelamento sem precisar cancelar jobs.
- **Alternativa mais robusta e recomendada para este porte:** não agendar com `wait_until` de dias. Usar um **recurring job de varredura** (o projeto já tem `config/recurring.yml` configurado) rodando a cada minuto, que pega `Divulgacao.agendada.where("scheduled_at <= ?", Time.current)` e dispara. Vantagens: imune a rename de classe, imune a deploy, edição/cancelamento funcionam de graça, e a fila nunca acumula milhares de linhas futuras. Custo: latência de até 1 minuto — irrelevante aqui.
- Manter **assinatura mínima e estável**: `perform(divulgacao_item_id)`. Um inteiro nunca quebra na desserialização.
- Se usar `config/recurring.yml`: a **chave da task é um identificador de banco**, não um rótulo. Renomear perde o rastreamento de execuções.
- **Alerta de "deveria ter enviado e não enviou":** varredura que sinaliza Divulgações com `scheduled_at` no passado ainda em `agendada`. Sem isso, a falha é 100% silenciosa.

**Warning signs:**
- `set(wait_until: divulgacao.scheduled_at).perform_later` com horizonte de dias.
- Editar a data/hora de uma Divulgação não altera nada na fila.
- Cancelar uma Divulgação não impede o envio.
- Nenhuma tela ou alerta mostrando Divulgações atrasadas.

**Phase to address:** `DIVU-ENVIO` (arquitetura de disparo); alerta em `HARDENING`.

---

### Pitfall 12: O webhook do Evolution é uma superfície pública nova e sem autenticação

**What goes wrong:**
Para receber `connection.update` e `qrcode.updated`, o app expõe `POST /webhooks/evolution`. Se esse endpoint não for autenticado, qualquer um na internet pode postar `{"event":"connection.update","instance":"cli-3-abc","data":{"state":"close"}}` e derrubar o estado das instâncias no app — ou, pior, se o handler criar/atualizar registros por `instance_name`, manipular dados de qualquer cliente.

**Why it happens:**
Webhooks são "só um callback" e frequentemente escapam da revisão de segurança. Além disso, um `ActionController::API`/controller normal exige `skip_forgery_protection`, e é fácil parar aí e esquecer de colocar *alguma* autenticação no lugar do CSRF que se removeu.

**How to avoid:**
- Segredo compartilhado no path ou header, comparado com `ActiveSupport::SecurityUtils.secure_compare` — o padrão que o projeto já usa nos três modos de auth da API v1.6.
- Resolver a instância **sempre** por `WhatsappInstance.find_by!(instance_name: ...)` e agir só sobre aquele registro; nunca criar registros a partir do webhook.
- Adicionar **throttle Rack::Attack** para o path do webhook — o `rack_attack.rb` atual cobre login, portal e `/api/v1/ai/`, mas não teria regra para uma rota nova.
- Tratar o webhook como **não confiável**: ele é um *hint* para atualizar a UI. Antes de qualquer envio, o app **reconsulta** `connectionState` (Pitfall 4). Estado de webhook nunca autoriza um envio.
- Responder 200 rápido e processar em job — o Evolution pode retentar e travar em handler lento.

**Warning signs:**
- Rota de webhook sem `before_action` de autenticação.
- Webhook fazendo `find_or_create_by`.
- Nenhuma regra no `rack_attack.rb` para o novo path.

**Phase to address:** `EVO-PAREAMENTO`; revisado em `HARDENING`.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| `sleep` no job para o delay entre grupos | 1 linha em vez de encadeamento de jobs | Trava 1 das 3 threads do worker por até 20 min; atrasa ActionCable e todo o resto | **Nunca** com esta config de `queue.yml`. Só com fila dedicada e sleep de poucos segundos |
| Passar `apikey`/URL assinada como argumento de job | Job autocontido, sem lookup | Segredo em texto claro em `solid_queue_jobs` e `failed_executions`, em dumps e no reporter | **Nunca** |
| `group_jid` como string no formulário | Dispensa modelar grupos | Perde o escopo por `@client`; abre envio cruzado irreversível | **Nunca** |
| Guardar a chave Evolution sem `encrypts` | Uma migration a menos | Dump do Postgres = todas as instâncias WhatsApp de todos os clientes | Só em dev/test |
| Usar a `AUTHENTICATION_API_KEY` global para enviar | Um segredo só, sem gerenciar tokens por instância | Erro de escopo posta no cliente errado silenciosamente em vez de dar 401 | Só para `/instance/create`, nunca para envio |
| Marcar item como "enviado" antes de confirmar a resposta | Código mais simples | Histórico mente; admin não sabe o que faltou entregar | **Nunca** |
| `wait_until` de dias em vez de varredura | Menos código | Quebra em rename de classe; edição/cancelamento não têm efeito | Aceitável se o job recarregar e revalidar a Divulgação ao acordar |
| Sem gate de warm-up para instância nova | Onboarding sem fricção | Ban do número do cliente na primeira semana | Aceitável só com aviso vermelho explícito na UI |
| Sem retry para falha de rede do Evolution | Sem risco de duplicata | Divulgação perdida por um blip de rede | Aceitável no MVP **se** houver reenvio manual por item na UI |
| Permitir Arte com `external_url` (Drive) em Divulgação | Reaproveita artes existentes | Evolution baixa HTML e envia lixo ao grupo do cliente | **Nunca** sem resolver para link direto verificado |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Evolution `sendMedia` | Achar que o param `delay` protege contra ban | `delay` é simulação de "digitando" antes de **um** envio. O pacing entre grupos é responsabilidade do Rails |
| Evolution `sendMedia` | Passar URL de `192.168.3.203` ou `localhost` | A URL é buscada **pelo host do Evolution**. Testar com `curl` de dentro do container Evolution |
| Evolution `sendMedia` | URL assinada gerada no enqueue | Gerar dentro do `perform`, com `expires_in` folgado; ou mandar base64 |
| Evolution `sendMedia` | `mediatype`/`mimetype` fora de sincronia com os bytes | Derivar ambos do blob do Active Storage; restringir a `image/jpeg`, `image/png`, `video/mp4` |
| Evolution `sendMedia` | Aceitar até 50 MB (limite do model `Arte`) | Validar 16 MB na `Divulgacao` — é o teto do WhatsApp para mídia |
| Evolution `/instance/create` | Persistir o QR/pairing code | QR é efêmero (~45s) e é credencial de pareamento. Renderizar, nunca gravar nem logar |
| Evolution `/instance/create` | `instance_name` = nome do cliente | `cli-<id>-<hex>` com índice único. Nomes colidem e são enumeráveis no manager |
| Evolution auth | Chave global para tudo | Global só para criar/deletar instância; envio com o token da instância (`hash`) |
| Evolution `connectionState` | Retry cego em qualquer desconexão | 401/403/402/406 **não** auto-reconectam — exigem novo QR. 408/428/500 sim |
| Webhook Evolution → Rails | Endpoint aberto, só com `skip_forgery_protection` | Segredo compartilhado + `secure_compare` + throttle Rack::Attack |
| Webhook Evolution → Rails | Confiar no estado do webhook para autorizar envio | Webhook é hint de UI; reconsultar `connectionState` antes de cada envio |
| Deploy do Evolution | Container sem volume persistente | Sessões Baileys vivem em disco/DB. Reiniciar sem volume desloga **todos** os clientes de uma vez |
| Active Storage → S3 | Manter `service_urls_expire_in` no default de 5 min | Gerar no job com `expires_in:` explícito, ou usar base64 |
| Grupos WhatsApp | Cachear a lista de grupos e nunca revalidar | O número pode ser removido de um grupo. Revalidar na criação da Divulgação e falhar cedo com mensagem clara |

---

## Performance Traps

Escala real: 10–30 clientes. A maioria dos gargalos aqui não é de CPU — é de **capacidade de worker** e de **limite social do WhatsApp**.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| `sleep` ocupando thread | Toasts do ActionCable atrasam; fila cresce com 3 jobs "rodando" | Um job por grupo com `wait` | **Já com 3 Divulgações simultâneas** (3 threads, 1 processo) |
| Fila `*` compartilhada | Envio de WhatsApp afoga broadcasts e limpeza | Fila `whatsapp` dedicada com worker próprio | Qualquer Divulgação concorrente com atividade do painel |
| Serialização por instância ausente | 2 Divulgações do mesmo cliente enviam em paralelo → burst → ban | Concurrency control com `key: "whatsapp-#{instance_id}"`, limite 1 | 2 Divulgações do mesmo cliente na mesma janela |
| Todas as Divulgações no mesmo horário redondo | 15 clientes agendam 09:00; 15 instâncias disparam juntas | Jitter no início (±5 min) além do delay entre grupos | ~10 clientes com hábito de horário comercial |
| Listar grupos no request | Página de Divulgação lenta/timeout; chamada ao Evolution a cada render | Cachear grupos em tabela; refresh explícito por botão + job | Cliente com muitos grupos, ou Evolution lento |
| Base64 de vídeo em memória | RSS do worker sobe; OOM | Base64 só até ~10 MB; acima disso, URL S3 | Vídeo > 10 MB com 3 threads simultâneas |
| `solid_queue_failed_executions` nunca limpo | Tabela cresce; segredos antigos persistem | O `recurring.yml` limpa **finished**, não **failed** — adicionar limpeza/retenção de failed | Meses de operação |
| Teto de envios por instância ausente | Volume cresce sem ninguém perceber até o ban | Contador por janela, com transbordo para a hora seguinte | Indeterminado — é o limite não publicado do WhatsApp |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Segredo como argumento de job | Chave em texto claro em `solid_queue_jobs`, em `failed_executions`, em dumps e no exception reporter | Só IDs como argumento; carregar credencial dentro do `perform` |
| `filter_parameters` sem `apikey` | O filtro atual (`:_key`) **não** casa com `apikey` nem com `hash` — vazam no log | Adicionar `:apikey, :api_key, :instance_token, :hash, :qrcode, :base64, :pairing_code` |
| Chave por cliente em texto claro no banco | Dump do Postgres entrega o controle do WhatsApp de todos os clientes | `encrypts :api_key` (Active Record Encryption) |
| Logar request/response cru do Evolution | Header `apikey` no request; `hash` e QR base64 na resposta | Logar só método, path, status, duração |
| `group_jid` vindo de `params` | Envio cruzado **irreversível** — arte de A no grupo de B | Aceitar só PK interna, resolver via `@client.whatsapp_instance.whatsapp_groups` |
| Sem validação `arte.client_id == client_id` na `Divulgacao` | Console, API v1 e bugs de controller passam direto | Validação no model, redundante ao controller, por design |
| Chave global usada no envio | Erro de escopo posta no cliente errado silenciosamente | Token por instância no envio; escopo errado vira 401 ruidoso |
| Webhook Evolution sem auth | Terceiro manipula estado de instâncias; possível DoS lógico | Segredo + `secure_compare` + throttle Rack::Attack |
| `instance_name` previsível | Enumeração/colisão entre clientes no manager do Evolution | `cli-<id>-<hex>` com índice único |
| QR Code persistido ou logado | Quem tiver o QR pareia o WhatsApp do cliente no próprio dispositivo | Efêmero, renderizado direto, nunca gravado |
| Sem checar `wuid` antes do envio | Re-pareamento com chip errado publica no número errado | Guardar `wuid` no pareamento e comparar antes de cada envio |
| Cliente inativo com Divulgação agendada | Post sai para cliente que já encerrou contrato | Job checa `client.active?` antes de enviar |
| Sem throttle nas rotas admin de WhatsApp | Loop acidental de "atualizar grupos" bate no Evolution e no WhatsApp | Estender `rack_attack.rb` para os novos paths |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Histórico só com "enviado / falhou" | Admin não distingue "falhou, tente de novo" de "pode ter enviado, não reenvie" | Estados: `pendente`, `enviando`, `enviado`, `falhou`, `pendente_reconexao`, `incerto` |
| Erro cru do Evolution na tela | "Request failed with status 400" não diz o que fazer | Traduzir: "O vídeo tem 23 MB; o WhatsApp aceita até 16 MB" |
| Nada avisa que a instância caiu | Divulgação de sexta às 18h não sai e ninguém sabe até segunda | Estado de conexão visível no painel + toast ActionCable (infra da v1.5 já existe) no `connection.update` |
| QR estático que expira em 45s | Admin escaneia e "não funciona"; tenta de novo; desiste | Auto-refresh do QR via Turbo Stream com o evento `qrcode.updated` + contador visível |
| Hora sem fuso indicado | Admin não sabe se "18:00" é o horário dele | "18:00 — horário de Brasília" ao lado do campo |
| Sem preview do que vai ser postado | Admin descobre a legenda errada depois de entregue — **sem desfazer** | Preview de mídia + legenda + lista de grupos, com confirmação, antes de agendar |
| Sem estimativa de duração | Admin agenda 09:00 e não entende por que o último grupo recebeu 10:20 | "12 grupos × 45–120s ≈ 9–24 min. Último envio previsto entre 09:09 e 09:24" |
| Sem cancelar / editar depois de agendado | Arte errada agendada = ligar para o cliente | Cancelar e editar até o primeiro envio; depois, cancelar o restante dos grupos |
| Nenhuma menção ao risco de ban no pareamento | Cliente é banido e não sabia do risco | Uma linha no fluxo do QR: o número pode ser banido pelo WhatsApp |
| Divulgação atrasada some silenciosamente | Falha 100% invisível | Faixa de alerta no dashboard: "N divulgações atrasadas" |

---

## "Looks Done But Isn't" Checklist

- [ ] **Envio de mídia:** costuma faltar o teste com **URL pública real, do host do Evolution** — verificar com `docker exec <evolution> curl -I <url>`, não do laptop.
- [ ] **Envio de mídia:** costuma faltar o caso **agendado** (URL assinada expira entre enqueue e envio) — verificar agendando para +1h, não testando imediato.
- [ ] **Envio de mídia:** costuma faltar o caso **Arte com `external_url` do Drive** — verificar que a Divulgação é bloqueada, não que "passa".
- [ ] **Envio de mídia:** costuma faltar o **vídeo entre 16 e 50 MB** — passa na validação do `Arte`, falha no WhatsApp.
- [ ] **Delay aleatório:** costuma faltar a **serialização por instância** — verificar com 2 Divulgações do mesmo cliente ao mesmo tempo e conferir timestamps.
- [ ] **Delay aleatório:** costuma faltar checar que **não é `sleep`** — verificar que as threads do worker ficam livres entre os envios.
- [ ] **Estado de conexão:** costuma faltar a **checagem imediatamente antes do envio** — verificar desconectando pelo celular (Dispositivos conectados) e disparando.
- [ ] **Estado de conexão:** costuma faltar distinguir **401 (exige QR) de 428 (reconecta)** — verificar que a UI pede novo QR no 401.
- [ ] **Idempotência:** costuma faltar o **índice único `(divulgacao_id, group_jid)`** — verificar no `schema.rb`, não na intenção.
- [ ] **Idempotência:** costuma faltar o teste de **retry após entrega bem-sucedida** — verificar que rodar o job duas vezes envia uma vez só.
- [ ] **Segredos:** costuma faltar inspecionar a tabela — verificar `SELECT arguments FROM solid_queue_jobs` e `SELECT api_key FROM whatsapp_instances`.
- [ ] **Segredos:** costuma faltar `apikey` no `filter_parameters` — verificar com `grep -i apikey log/production.log`.
- [ ] **Cross-client:** costuma faltar o **teste negativo** — verificar que criar Divulgação de A com `whatsapp_group_id` de B levanta `RecordNotFound`.
- [ ] **Cross-client:** costuma faltar a **validação no model** (só o controller) — verificar criando pelo console.
- [ ] **Agendamento:** costuma faltar **editar/cancelar depois de agendado** — verificar que o job acorda e respeita o novo estado.
- [ ] **Agendamento:** costuma faltar o **alerta de atrasado** — verificar com `scheduled_at` no passado e status `agendada`.
- [ ] **Timezone:** costuma faltar o teste com **`TZ` do sistema diferente** do fuso do Rails — o `default_timezone = :local` deste projeto torna isso obrigatório.
- [ ] **Webhook:** costuma faltar a **autenticação** — verificar com `curl` sem segredo; deve dar 401, não 200.
- [ ] **Deploy Evolution:** costuma faltar o **volume persistente** — verificar reiniciando o container e conferindo que as instâncias continuam `open`.

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Arte postada no grupo do cliente errado | **HIGH — irreversível** | Deletar a mensagem no WhatsApp (janela limitada, e "mensagem apagada" fica visível). Comunicar os dois clientes. Corrigir o escopo. É por isso que a prevenção do Pitfall 10 é prioritária sobre quase tudo |
| Número do cliente banido | **HIGH — geralmente irreversível** | Apelação raramente funciona para API não-oficial. Chip novo, warm-up do zero, refazer todos os grupos. Marcar a instância como `banned` e bloquear novas Divulgações |
| Post duplicado no grupo | MEDIUM | Deletar a duplicata. Adicionar o índice único e o lock. Auditar o histórico atrás de outras duplicatas |
| Sessão caiu e a Divulgação não saiu | LOW | Novo QR, reenviar os itens `pendente_reconexao`. O dano é atraso, não conteúdo errado — desde que o histórico não tenha mentido "enviado" |
| Chave Evolution vazada em log ou dump | MEDIUM | Rotacionar `AUTHENTICATION_API_KEY` e recriar tokens de instância. Purgar `solid_queue_failed_executions` e os logs afetados. Adicionar `encrypts` e o filtro |
| Divulgação agendada disparou na hora errada (timezone) | LOW–MEDIUM | Post fora de hora já entregue. Corrigir o parsing, fixar `TZ`, reagendar. Comunicar o cliente |
| Job agendado quebrado por rename de classe | LOW | Migrar para varredura por tabela (recomendação do Pitfall 11) e reprocessar as Divulgações atrasadas |
| Mídia entregue quebrada no grupo | LOW | Deletar, corrigir o arquivo, reenviar. Adicionar o preflight `HEAD` |
| Container Evolution reiniciado sem volume | MEDIUM | Todos os clientes precisam re-parear. Adicionar volume persistente. É um incidente coletivo — vale um runbook |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| 1. Burst / velocidade | `DIVU-ENVIO` | Teste com 2 Divulgações da mesma instância: timestamps sempre ≥ delay mínimo; concurrency key ativa |
| 2. Conteúdo idêntico | `DIVU-MODEL` + `DIVU-ENVIO` | Decisão registrada sobre variação; `mentionsEveryOne` ausente do payload |
| 3. Número novo sem warm-up | `EVO-PAREAMENTO` + `DIVU-MODEL` | `paired_at` no schema; UI bloqueia/avisa com instância < 14 dias |
| 4. Sessão caída | `EVO-PAREAMENTO` + `DIVU-ENVIO` | Desconectar pelo celular e disparar → item vira `pendente_reconexao`, nunca `enviado`; 401 pede novo QR |
| 5. URL de mídia | `INFRA-S3` + `DIVU-ENVIO` | `curl -I` de dentro do container Evolution; agendado para +1h entrega; Drive/Dropbox bloqueado; 20 MB rejeitado |
| 6. Segredos em job/log | `EVO-CLIENT` + `DIVU-ENVIO` | `solid_queue_jobs.arguments` só com inteiros; `api_key` ilegível no banco; `grep -i apikey log/` vazio |
| 7. `sleep` travando worker | `DIVU-ENVIO` + deploy | Zero `sleep` em `app/jobs`; fila `whatsapp` dedicada em `queue.yml` |
| 8. Retry duplicando | `DIVU-MODEL` + `DIVU-ENVIO` | Índice único `(divulgacao_id, group_jid)` no `schema.rb`; job rodado 2× envia 1× |
| 9. Timezone | `DIVU-MODEL` + deploy | Teste com `TZ` divergente; `Time.zone.parse` em todo lugar; `TZ` verificado no boot |
| 10. Cross-client | `EVO-GRUPOS` + `DIVU-MODEL` | Teste negativo A×B levanta `RecordNotFound`; validação no model; envio usa token de instância |
| 11. Jobs futuros / edição | `DIVU-ENVIO` | Editar hora reflete no disparo; cancelar impede o envio; alerta de atrasado no dashboard |
| 12. Webhook aberto | `EVO-PAREAMENTO` | `curl` sem segredo → 401; throttle no `rack_attack.rb` |
| 0. ToS / ban | Decisão de produto antes do roadmap | Consentimento do cliente registrado; aviso na UI de pareamento |

### Ordem sugerida e por quê

1. **`INFRA-S3`** primeiro — sem host público e S3, nada de mídia funciona, e o Pitfall 5 é o que mais gera retrabalho se descoberto tarde.
2. **`EVO-CLIENT`** — o modelo de segredos (encrypts + filter_parameters) precisa existir **antes** da primeira chave ser gravada, senão há migração de dados sensíveis depois.
3. **`EVO-PAREAMENTO`** — estado de conexão é pré-requisito de qualquer envio confiável (Pitfall 4).
4. **`EVO-GRUPOS`** — a modelagem escopada de grupos é o que fecha o Pitfall 10; precisa vir **antes** da `Divulgacao` que os referencia.
5. **`DIVU-MODEL`** — schema com índice único, validações cruzadas e timezone.
6. **`DIVU-ENVIO`** — concentra os pitfalls 1, 7, 8, 11; é a fase de maior densidade de risco e merece code review dedicado.
7. **`HARDENING`** — auditoria de segredos, testes negativos cross-client, alertas.

**Flags de pesquisa mais profunda:** `DIVU-ENVIO` é a única fase que provavelmente precisa de research adicional em tempo de planejamento — especificamente sobre a API de concurrency controls do solid_queue na versão instalada e sobre o formato exato de erro do `sendMedia` para mapear retry vs. discard.

---

## Sources

**Primárias / oficiais** (texto citado literalmente onde relevante):
- [WhatsApp Messaging Guidelines](https://www.whatsapp.com/legal/messaging-guidelines) — proibição de "unofficial clients, bulk messaging, auto-messaging... or automation"; enforcement
- [WhatsApp Terms of Service](https://www.whatsapp.com/legal/terms-of-service) — meios automatizados, engenharia reversa, direito de terminação
- [Meta — WhatsApp Groups API (Cloud API)](https://developers.facebook.com/documentation/business-messaging/whatsapp/groups) — requisitos OBA, limite de 8 participantes, 1 negócio por grupo
- [Meta — Group messaging](https://developers.facebook.com/documentation/business-messaging/whatsapp/groups/groups-messaging/)
- [Evolution API — Connection Management](https://mintlify.wiki/EvolutionAPI/evolution-api/whatsapp/connections) — estados, `statusReason`, auto-reconexão, webhook `connection.update`
- [Evolution API — Send Media](https://doc.evolution-api.com/v2/api-reference/message-controller/send-media) — parâmetros, `delay`, formatos de `media`
- [Evolution API — `.env.example`](https://github.com/EvolutionAPI/evolution-api/blob/main/.env.example) — `AUTHENTICATION_API_KEY`
- [rails/solid_queue README](https://github.com/rails/solid_queue/blob/main/README.md) — persistência de argumentos, ausência de retry próprio, dispatchers/scheduled_executions
- [rails/solid_queue issue #176 — Discard duplicate jobs](https://github.com/rails/solid_queue/issues/176) — concurrency control bloqueia, não descarta
- [rails/rails issue #32236 — Active Storage presigned URL expira](https://github.com/rails/rails/issues/32236) e [Rails 7 expiring URLs](https://blog.saeloun.com/2021/09/14/rails-7-adds-expiring-urls-to-active-storage/) — default de 5 minutos

**Issues de campo** (relatos, não conclusões de mantenedor):
- [evolution-api #2538 — Bulk messaging: rate limiting, queuing, ban risk](https://github.com/evolution-foundation/evolution-api/issues/2538) — **confirma ausência de rate limiter/fila/retry embutidos**
- [evolution-api #2228 — Ban risk ao checar múltiplos números](https://github.com/evolution-foundation/evolution-api/issues/2228)
- [evolution-api #2056 — sendMedia: imagem falha ao carregar no app mobile](https://github.com/EvolutionAPI/evolution-api/issues/2056)
- [Baileys #1869 — High number of bans on WhatsApp](https://github.com/WhiskeySockets/Baileys/issues/1869) — **anedótico; issue ficou stale sem resposta técnica**
- [Baileys #2075 — Repeated Number Bans](https://github.com/WhiskeySockets/Baileys/issues/2075) — **anedótico**

**Opinião de fornecedor / comunidade — todos os números aqui são heurísticos, não medidos:**
- [WasenderApi — Anti-ban strategy](https://wasenderapi.com/blog/stop-getting-banned-the-ultimate-whatsapp-anti-ban-strategy-for-unofficial-apis-in-2025) — warm-up semanal, 15–45s entre mensagens, pausa a cada 50
- [WasenderApi — Evolution API ban risks](https://wasenderapi.com/blog/evolution-api-ban-risks-how-to-architect-a-safe-high-volume-whatsapp-gateway) — concorrência 1–5 workers/sessão, token/leaky bucket
- [Unipile — WhatsApp Group API 2026](https://www.unipile.com/whatsapp-group-api/) — limitações da Groups API oficial
- [Solid Queue lifecycle — Honeybadger](https://www.honeybadger.io/blog/solid-queue-lifecycle/) — scheduled → ready executions
- [Alex Peattie — Simple unique jobs on Solid Queue](https://alexpeattie.com/blog/simple-unique-jobs-solid-queue/)

**Inspeção direta do codebase** (fatos verificados neste repositório, confiança HIGH):
- `config/application.rb:24-25` — `time_zone = "Brasilia"` + `active_record.default_timezone = :local`
- `config/queue.yml` — `threads: 3`, `processes: 1`, `queues: "*"` (fila única)
- `config/recurring.yml` — limpa apenas `finished`, não `failed`
- `config/initializers/filter_parameter_logging.rb` — filtro `:_key` **não** cobre `apikey` nem `hash`
- `app/models/arte.rb` — validação de tamanho em `50.megabytes` (vs. ~16 MB do WhatsApp); aceita `video/quicktime`
- `app/jobs/application_job.rb` — `retry_on` / `discard_on` comentados
- `config/initializers/rack_attack.rb` — sem cobertura para rotas novas de WhatsApp/webhook
- `app/controllers/admin/artes_controller.rb:74` — padrão `@client.artes.find(...)` a ser replicado nas entidades novas

---
*Pitfalls research for: WhatsApp group automation via Evolution API on Rails 8 + solid_queue*
*Researched: 2026-08-29*
