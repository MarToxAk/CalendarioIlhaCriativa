---
phase: 26-inst-ncia-de-whatsapp-por-cliente-pareamento
verified: 2026-08-30T15:03:55Z
status: human_needed
score: 5/5 must-haves verified
behavior_unverified: 0
overrides_applied: 0
human_verification:
  - test: "Rodar bin/dev, autenticar como admin, abrir um cliente sem instância e clicar 'Criar instância' com o host Evolution real acessível. Confirmar que o QR Code aparece na tela e que ele continua escaneável enquanto rotaciona (~20-25s por ciclo) até o WhatsApp do celular concluir o pareamento."
    expected: "O QR renderiza a partir de last_qr_base64; o polling do qr_pairing_controller.js troca o <img> a cada ~20s sem quebrar; ao parear, a página recarrega sozinha e o card passa a mostrar o badge 'Conectada'."
    why_human: "Exige um round-trip real ao host Evolution (whatsapp.bomcustoilhabela.com.br) e o app publicado — indisponível neste ambiente (sem Docker, sem rede ao host, app não deployado). O comportamento de rotação em tempo real e a legibilidade visual do QR só um humano confirma."
  - test: "Com o app publicado em ilhacriativa.autopyweb.com.br, provocar um evento connection.update real do Evolution (parear/desconectar o número) e confirmar que POST Evolution -> /webhooks/evolution chega, autentica pelo X-Webhook-Secret e atualiza connection_state/last_checked_at/paired_at."
    expected: "O receiver responde 200, a linha whatsapp_instances reflete o novo estado sem o admin clicar em nada; um POST sem o header correto recebe 401."
    why_human: "A entrega inbound (host Evolution -> este app) não é testável aqui — o app não está deployado publicamente. A LÓGICA do receiver está coberta por test/controllers/webhooks/evolution_controller_test.rb (12 testes, verdes)."
  - test: "Inspeção visual em bin/dev (deferido pelo planejador em 26-05 Task 3): abrir um cliente com instância 'connected' recém-pareada (paired_at < 7 dias) e outro 'awaiting_qr'. Conferir: (1) o badge de estado usa a cor certa e não quebra o layout do card 'Informações' acima; (2) o banner de banimento aparece em âmbar, legível, acima do QR, sem caixa de seleção; (3) o texto de cautela de idade não estoura a largura do card; (4) no clients#index, a bolinha de conexão não quebra a linha da tabela em telas estreitas."
    expected: "Cores corretas, banner legível sem checkbox, sem overflow de texto, tabela do index estável no mobile."
    why_human: "Aparência visual, cor e responsividade — não verificável por grep/teste."
  - test: "OPERATOR paste-back (carregado da 26-01): rodar `grep -n EVOLUTION_WEBHOOK .env.example` no host real e conferir as 5 linhas de exemplo (ACTIVE_RECORD_ENCRYPTION_*, EVOLUTION_WEBHOOK_HMAC_KEY, EVOLUTION_WEBHOOK_BASE_URL)."
    expected: "As 5 chaves de exemplo estão presentes em .env.example com valores vazios (exceto EVOLUTION_WEBHOOK_BASE_URL=https://ilhacriativa.autopyweb.com.br)."
    why_human: "O sandbox nega leitura direta de .env.example; a escrita foi confirmada por delta de tamanho na 26-01 mas o conteúdo exato não pôde ser lido neste ambiente."
---

# Phase 26: Instância de WhatsApp por Cliente + Pareamento — Relatório de Verificação

**Objetivo da fase:** Cada cliente tem sua própria instância Evolution pareada pelo painel admin, com o token guardado criptografado desde a primeira gravação e o estado de conexão sempre visível.
**Verificado:** 2026-08-30T15:03:55Z
**Status:** human_needed
**Re-verificação:** Não — verificação inicial

## Resumo do Veredito

Os 5 critérios de sucesso do ROADMAP estão implementados no código e cobertos por testes que passam
(59 testes de fase 26: 0 falhas, 0 erros). A criptografia do token em repouso, o filter_parameters,
a autenticação HMAC do webhook antes de qualquer consulta ao banco, a verificação síncrona e a
adoção automática de instância existente foram todos confirmados diretamente no código e por execução
real (`bin/rails runner` / `bin/rails test`).

O status é `human_needed` — não `passed` — porque três verificações dependem de comportamento em
tempo real / round-trip ao host Evolution real / aparência visual, que este ambiente não pode
exercer (sem Docker, sem rede ao host, app não deployado), somadas ao `<human-check>` que o próprio
planejador deferiu em 26-05 Task 3. Nenhuma dessas pendências é uma lacuna de implementação — são
confirmações de runtime/visual que exigem um humano com o ambiente completo.

## Alcance do Objetivo

### Verdades Observáveis (Critérios de Sucesso do ROADMAP)

| # | Verdade | Status | Evidência |
| --- | --- | --- | --- |
| 1 | Admin cria a instância de um cliente sem instância e vê o QR Code na tela; o código rotaciona (~25s) até parear | ✓ VERIFIED (mecanismo) | `whatsapp_instances` 1:1 (índice único em `client_id`); `Evolution::Client#create_instance` (POST `/instance/create`, `instanceName` no corpo); `InstanceProvisioner#call` persiste linha `awaiting_qr`/`created_by_app`; `Admin::WhatsappInstancesController#create` -> redirect com notice; `_panel.html.erb` empty-state + `button_to` na rota nested; `_qr.html.erb` `<img>` com `src=last_qr_base64`; `qr_pairing_controller.js` faz poll de `refresh_qr` a cada 20s, troca o `<img>`, para em `connected` (Turbo.visit reload), revela "Gerar novo QR" após 6 ciclos, `disconnect()` limpa o timer; `#refresh_qr` throttled 1×/15s via `Rails.cache`. Testes: `whatsapp_instances_controller_test.rb` (create sucesso/erro, refresh_qr throttle), `evolution_controller_test.rb`. **Rotação visual em tempo real -> verificação humana.** |
| 2 | Nome já existe no Evolution -> admin adota a instância existente em vez de erro; webhook reapontado no ato | ✓ VERIFIED | `InstanceProvisioner#call` faz `rescue Evolution::Errors::Permanent`; `name_collision?` casa prefixo `"403 "` + `/already in use/i`; `#adopt` resolve por match EXATO de nome via `fetch_instances.find`, chama `set_webhook` INCONDICIONALMENTE ANTES de `connection_state` (ordem garantida no código e assertada em teste), persiste `origin: adopted_existing`, `paired_at` write-once. Testes: "create com 403 already in use adota a instância existente" (assere `set_webhook_calls.size == 1`, `origin == adopted_existing`, token adotado, `paired_at` presente); "403 que NÃO é colisão não adota e re-propaga". |
| 3 | Admin vê o estado de conexão por cliente (conectada/desconectada/aguardando) e força a verificação por botão, sem depender do webhook | ✓ VERIFIED | enum `connection_state` + `connection_state_label` pt-BR; `_connection_badge.html.erb` com 4 variantes de cor (hex canônicos do UI-SPEC); `_panel.html.erb` mostra badge + última verificação; `clients#index` coluna "Conexão" + bolinha por estado (oca para zero) com `includes(:whatsapp_instance)` (guard N+1); `#verify` SÍNCRONO — chama `Evolution::Client.connection_state` direto (grep confirma: nenhum `perform_later`/`ActiveJob` em toda a fase), grava no banco ANTES de `assert_open!`, falha de transporte não avança o estado. Testes: 4 cenários de `#verify` (open atualiza+notice, close atualiza+alert, Transient não avança, sem instância -> alert). |
| 4 | A tela de pareamento avisa do risco de banimento antes do scan; depois de pareado informa há quanto tempo o número está ativo e recomenda cautela em números recentes, sem bloquear | ✓ VERIFIED (conteúdo) | `_qr.html.erb`: banner âmbar de risco de banimento SEMPRE acima do QR quando `awaiting_qr?`, sem `<input type="checkbox">` (copy verbatim confirmada por grep); `wa_paired_age_text` helper: texto de cautela para `< 7` dias deixando explícito que a contagem é local ao sistema; `_panel.html.erb` anexa o parágrafo de cautela quando `recently_paired?`. Nada bloqueia (sem gate). Teste: `whatsapp_instance_test.rb` cobre `paired_days`/`recently_paired?`; helper testado no 26-05. **Legibilidade/layout -> verificação humana.** |
| 5 | Token criptografado no banco, ausente de log e de argumento de job; POST ao webhook sem o segredo correto recusado ANTES de qualquer consulta ao banco | ✓ VERIFIED | `encrypts :token` não-determinístico — confirmado ao vivo: coluna crua é envelope JSON cifrado (`{"p":"...","h":{"iv":...}}`), difere do plaintext, decifra de volta. 3 chaves `active_record_encryption` presentes em credentials (confirmado ao vivo). `filter_parameters` cobre `apikey, hash, api_key, instance_token, qrcode, base64, pairing_code, pairingCode` (confirmado ao vivo). Nenhum job em toda a fase (grep). Os 4 `rescue` de controller logam só `e.class`, nunca `e.message`. `Webhooks::EvolutionController#create`: `valid_signature?` é a 1ª linha, `secure_compare` sobre dois digests SHA256, ANTES de `WhatsappInstance.find_by` — confirmado ao vivo: segredo errado + instância inexistente -> 401 (não 204). Throttle Rack::Attack `webhooks/evolution_by_ip` 120/60s (testes verdes). |

**Score:** 5/5 verdades verificadas (mecanismo + testes). 0 present-behavior-unverified.

### Artefatos Requeridos

| Artefato | Esperado | Status | Detalhes |
| --- | --- | --- | --- |
| `db/migrate/20260830130934_create_whatsapp_instances.rb` + `db/schema.rb` | tabela `whatsapp_instances` (client_id único, instance_name único, token/last_qr_base64 text, enums int default 0) | ✓ VERIFIED | schema confere: `token` e `last_qr_base64` são `text`; índices únicos em `client_id` e `instance_name`; FK para `clients` |
| `app/models/whatsapp_instance.rb` | `encrypts :token`, `belongs_to :client`, enums, `evolution_name_for`, `webhook_secret_for`, `map_evolution_state`, `known_evolution_state?`, `paired_days`, `recently_paired?`, `connection_state_label` | ✓ VERIFIED | todos presentes; `EVOLUTION_STATE_MAP` é fonte única; `encrypts :token` sem `deterministic:` |
| `app/models/client.rb` | `has_one :whatsapp_instance, dependent: :destroy` | ✓ VERIFIED | presente na linha após `has_many :artes` |
| `app/services/evolution/client.rb` | `create_instance`, `connect` (guard HTTP 200 + `{error:true}`), `set_webhook` (events sempre explícito) | ✓ VERIFIED | os 3 métodos no mesmo `class << self`; `connect` levanta `Transient` em `body["error"]` antes de qualquer `.dig`; mensagens de erro estáticas, sem interpolar body |
| `app/services/evolution/instance_provisioner.rb` | `#call` create-ou-adota, `#adopt` (set_webhook antes de connection_state), `persist_new`, write-once de `paired_at` | ✓ VERIFIED | `NAME_IN_USE_MESSAGE` regex + checagem de prefixo `403 `; `adopt_qr` silencioso em falha do Evolution (WR-05) |
| `app/controllers/admin/whatsapp_instances_controller.rb` | `#create`, `#adopt`, `#verify` (síncrono), `#refresh_qr` (JSON throttled), `#reconnect`; `set_client` por `client_id` | ✓ VERIFIED | todos presentes; guards de nil-instance em `#verify`/`#reconnect` (WR-01); `pull_fresh_qr` com `Rails.cache.write unless_exist` |
| `app/controllers/webhooks/evolution_controller.rb` | `< ActionController::API`, `valid_signature?` primeiro, `secure_compare` sobre digests, normalização dotcase/UPPER_SNAKE, no-op em evento desconhecido | ✓ VERIFIED | `known_evolution_state?` guard impede rebaixar instância saudável (WR-06); nunca loga corpo cru |
| `app/javascript/controllers/qr_pairing_controller.js` | polling 20s, `MAX_CYCLES=6`, `disconnect(){clearInterval}`, não re-prefixa data-URI, POST com CSRF | ✓ VERIFIED | `fetch` com `method: "POST"` + `X-CSRF-Token` do meta (WR-02); `disconnect` limpa timer |
| `app/views/admin/whatsapp_instances/_panel.html.erb` + `_qr.html.erb` + `_connection_badge.html.erb` | card completo, banner de banimento, cautela de idade, badge 4 cores | ✓ VERIFIED | `clients/show.html.erb` renderiza `admin/whatsapp_instances/panel`; badge com os 4 hex canônicos |
| `app/helpers/admin/whatsapp_instances_helper.rb` | `wa_last_checked_label`, `wa_paired_age_text` | ✓ VERIFIED | copy pt-BR verbatim do UI-SPEC |
| `config/initializers/filter_parameter_logging.rb` | 6 símbolos novos de INFRA-04 | ✓ VERIFIED | confirmado ao vivo em `Rails.application.config.filter_parameters` |
| `config/initializers/rack_attack.rb` | throttle `webhooks/evolution_by_ip` 120/60s | ✓ VERIFIED | presente; testes de throttle do webhook verdes |
| credentials.yml.enc | 3 chaves `active_record_encryption` + `evolution.webhook_hmac_key`/`webhook_base_url` | ✓ VERIFIED | confirmado ao vivo; `evolution.base_url`/`global_api_key` preservados |

### Verificação de Key Links

| De | Para | Via | Status | Detalhes |
| --- | --- | --- | --- | --- |
| `_panel.html.erb` (botão Criar instância) | `Admin::WhatsappInstancesController#create` | `button_to admin_client_whatsapp_instance_path(client), method: :post` | ✓ WIRED | rota `resource :whatsapp_instance, only: [:create]` nested em `clients` |
| `#create` | `InstanceProvisioner#call` | `Evolution::InstanceProvisioner.new(@client).call` | ✓ WIRED | |
| `InstanceProvisioner` | `WhatsappInstance` (INSERT) | `WhatsappInstance.create!` com `token:` do corpo do Evolution — `encrypts :token` cifra antes do INSERT | ✓ WIRED + FLOWING | ciphertext confirmado ao vivo via SELECT cru |
| `InstanceProvisioner#call` | `#adopt` | `rescue Evolution::Errors::Permanent` + `/already in use/i` + prefixo `403 ` | ✓ WIRED | teste assere desvio só na colisão de nome |
| `#adopt` | `Evolution::Client#set_webhook` | `@api.set_webhook(name, ...)` SEMPRE antes de `connection_state` | ✓ WIRED | ordem garantida no código e assertada em teste |
| `routes.rb` `post /webhooks/evolution` | `Webhooks::EvolutionController#create` | `to: "webhooks/evolution#create"` | ✓ WIRED | 401 ao vivo com segredo errado |
| `Webhooks::EvolutionController#valid_signature?` | `WhatsappInstance.webhook_secret_for` | `OpenSSL::HMAC.hexdigest("SHA256", Evolution.webhook_hmac_key, params[:instance])` — mesma fórmula do model | ✓ WIRED | `secure_compare` sobre dois SHA256 |
| `qr_pairing_controller.js` | `#refresh_qr` | `fetch(this.urlValue, { method: "POST" })` -> `{ state, qr_base64 }` | ✓ WIRED | rota `post :refresh_qr` (WR-02); controller responde `render json:` |
| `clients/index.html.erb` | `clients_controller#index` | `@clients = Client.includes(:whatsapp_instance)` | ✓ WIRED | guard N+1 confirmado por grep |

### Data-Flow Trace (Nível 4)

| Artefato | Variável | Fonte | Produz Dado Real | Status |
| --- | --- | --- | --- | --- |
| `_qr.html.erb` `<img src>` | `instance.last_qr_base64` | coluna do banco, populada por `InstanceProvisioner`/`#refresh_qr`/`#reconnect` (via `Evolution::Client#connect`) ou pelo webhook `qrcode.updated` | ✓ (populado por chamada real ao Evolution ou webhook — não testável ao vivo sem host) | ⚠️ STATIC até um round-trip real ao Evolution — ver verificação humana |
| `_connection_badge` / `_client_row` bolinha | `whatsapp_instance.connection_state` | enum gravado por `#verify` (síncrono), `#adopt`, ou webhook `connection.update` | ✓ FLOWING | testes gravam e leem o estado real |
| `_panel` "Última verificação" | `whatsapp_instance.last_checked_at` | gravado em `#verify`/`#adopt`/webhook | ✓ FLOWING | |
| `whatsapp_instances.token` (repouso) | atribuição Ruby -> `encrypts :token` | `InstanceProvisioner` (`resp["hash"]`) / `#adopt` (`existing["hash"]`) | ✓ FLOWING (cifrado) | envelope JSON cifrado confirmado ao vivo |

### Spot-Checks Comportamentais

| Comportamento | Comando | Resultado | Status |
| --- | --- | --- | --- |
| Token cifrado em repouso | `bin/rails runner` — cria WhatsappInstance, SELECT token cru | coluna = `{"p":"...","h":{"iv":...}}`, difere do plaintext, decifra de volta | ✓ PASS |
| Chaves de encryption presentes | `bin/rails runner` — `Rails.application.credentials.dig(:active_record_encryption, ...)` | primary_key/deterministic_key/salt todos present | ✓ PASS |
| filter_parameters INFRA-04 | `bin/rails runner` — `Rails.application.config.filter_parameters` | 8 símbolos (apikey, hash, api_key, instance_token, qrcode, base64, pairing_code, pairingCode) todos present | ✓ PASS |
| Webhook: segredo errado antes do banco | `bin/rails runner` — POST `/webhooks/evolution` instância inexistente + segredo errado | HTTP 401 (não 204) | ✓ PASS |
| Sem job na fase | `grep -rn "perform_later\|ActiveJob"` nos arquivos da fase | nenhum resultado | ✓ PASS |
| Suíte de testes da fase 26 | `bin/rails test` (4 arquivos de fase 26) | 59 runs, 196 assertions, 0 failures, 0 errors | ✓ PASS |
| Throttle do webhook | `bin/rails test test/integration/rack_attack_test.rb` | testes do webhook (120 sem 429, 121ª com 429) verdes; 1 falha pré-existente em `:52` (namespace AI, fase 24) não relacionada | ✓ PASS (falha documentada) |
| QR rotativo ao vivo / entrega inbound do webhook | — | não executável (sem host Evolution, app não deployado) | ? SKIP -> verificação humana |

### Cobertura de Requisitos

| Requisito | Plano(s) | Descrição | Status | Evidência |
| --- | --- | --- | --- | --- |
| EVO-04 | 26-01 | Token de cada instância persistido criptografado (`encrypts`), chaves antes da 1ª gravação | ✓ SATISFIED | `encrypts :token` + ciphertext confirmado ao vivo; ordem de chaves garantida pelo passo 1 do 26-01 |
| INFRA-04 | 26-01 | Segredos do Evolution nunca em log; sem segredo como argumento de job | ✓ SATISFIED | `filter_parameters` (8 símbolos, confirmado); nenhum job na fase; rescues logam só `e.class` |
| PAIR-01 | 26-01 | Admin cria instância para cliente sem uma | ✓ SATISFIED | `#create` -> `InstanceProvisioner` -> linha `awaiting_qr` (testes verdes) |
| PAIR-02 | 26-02 | Admin adota instância já existente em vez de falhar | ✓ SATISFIED | `#call` rescue `/already in use/i` -> `#adopt` (automático dentro do mesmo clique); webhook reapontado sempre (testes verdes). Sem botão dedicado (decisão de design documentada; `#adopt` action/rota existem mas sem entrada de UI — IN-01) |
| PAIR-03 | 26-01/02/03/04/05 | QR na tela, escaneável enquanto rotaciona (~25s) | ✓ SATISFIED (mecanismo) | `_qr.html.erb` + `qr_pairing_controller.js` (poll 20s) + `#refresh_qr` throttled; rotação visual ao vivo -> verificação humana |
| PAIR-04 | 26-01/05 | Admin vê o estado de conexão por cliente | ✓ SATISFIED | badge 4 cores no show + bolinha no index sem N+1 |
| PAIR-05 | 26-04 | Verificação manual sem depender do webhook | ✓ SATISFIED | `#verify` síncrono (sem job), grava antes de decidir a mensagem, falha de transporte não avança (testes verdes) |
| PAIR-06 | 26-03 | Webhook autenticado, segredo por `secure_compare` antes de qualquer consulta ao banco | ✓ SATISFIED | `valid_signature?` 1ª linha, `secure_compare` sobre digests, 401 ao vivo antes do `find_by`; throttle 120/60s |
| PAIR-07 | 26-05 | Aviso de risco de banimento no momento do scan | ✓ SATISFIED | banner âmbar sempre acima do QR quando `awaiting_qr?`, sem checkbox (copy verbatim) |
| PAIR-08 | 26-01/02/03/04/05 | UI informa há quanto tempo pareado e recomenda cautela em número recente, sem bloquear | ✓ SATISFIED | `wa_paired_age_text` (cautela < 7 dias, contagem local ao sistema explícita); `paired_at` write-once em todos os caminhos (adopt/verify/webhook) |

**Todos os 10 IDs do frontmatter dos planos (EVO-04, INFRA-04, PAIR-01..08) estão em REQUIREMENTS.md
(traceability, todos "Complete") e são respaldados por código. Nenhum ID órfão — REQUIREMENTS.md não
mapeia nenhum outro ID para a Phase 26 além destes 10.**

### Anti-Padrões Encontrados

| Arquivo | Linha | Padrão | Severidade | Impacto |
| --- | --- | --- | --- | --- |
| `app/models/whatsapp_instance.rb` | 9 | grep casou "TODOS" (comentário pt-BR, "todos chamam este método") | ℹ️ Info | Falso positivo — não é um marcador `TODO` |

Nenhum marcador de dívida (`TODO`/`FIXME`/`XXX`), nenhuma implementação stub, nenhum dado hardcoded
vazio nos arquivos da fase.

### Info (do 26-REVIEW, carregado — não bloqueante)

- **IN-01:** `#adopt` action + rota `post :adopt` sem entrada de UI (adoção acontece automática dentro do `#create`). Funcionalmente PAIR-02 fechado.
- **IN-02:** migração adiciona `qr_expires_at` e `last_error` que nenhum código da fase 26 usa (reservados).
- **IN-03:** `_qr.html.erb` emite `src=""` quando ainda não há QR em cache (overlay "Gerando QR Code…" cobre visualmente).
- **IN-04:** `whatsapp_instances.token` sem NOT NULL / sem validação de presença.
- **IN-05:** bolinha de conexão só na tabela desktop; lista de cards mobile omite (discrição do executor, permitido pelo plano).
- **IN-06:** `qr_pairing_controller.js` não checa `response.ok` antes de `.json()`.
- **IN-07:** webhook responde 200 (instância conhecida) vs 204 (desconhecida) — enumerável por quem tem a chave HMAC.
- **IN-08:** throttle do webhook agrupa todo o tráfego Evolution sob um IP de origem.
- **IN-09:** `#verify` mapeia estado Evolution desconhecido para `awaiting_qr` (residual do WR-06; operator-initiated e imediatamente visível).
- **COVERAGE.md** menciona uma rota `destroy` para `resource :whatsapp_instance` que não existe (apenas `only: [:create]`). Deleção da linha local não é requisito v1.7; `dependent: :destroy` no `has_one` cobre o cascade. Inconsistência de documentação, não lacuna de objetivo.

### Verificação Humana Necessária

Ver o frontmatter `human_verification`. Resumo:

1. **QR rotativo ao vivo** — criar instância com host Evolution real acessível; confirmar QR renderiza, rotaciona a cada ~20s e para em `connected` com recarga automática. (Round-trip ao host + app publicado — indisponível aqui.)
2. **Entrega inbound do webhook** — provocar `connection.update` real e confirmar que o receiver atualiza o estado sem clique do admin; POST sem header -> 401. (Lógica coberta por 12 testes verdes; entrega real exige app deployado.)
3. **Inspeção visual (deferido pelo planejador em 26-05 Task 3)** — cor do badge, legibilidade do banner de banimento sem checkbox, ausência de overflow do texto de cautela, estabilidade da bolinha no index em telas estreitas.
4. **OPERATOR paste-back do `.env.example`** — conferir as 5 linhas de exemplo no host (sandbox nega leitura de `.env.example`).

### Resumo de Lacunas

Nenhuma lacuna de implementação. Todas as 5 verdades do ROADMAP estão codificadas e cobertas por
testes que passam. As 4 pendências acima são confirmações de runtime/visual que exigem o ambiente
completo (host Evolution + app deployado + olho humano) — explicitamente fora do alcance deste
ambiente de verificação e, em parte, já deferidas pelo planejador.

---

_Verificado: 2026-08-30T15:03:55Z_
_Verificador: Claude (gsd-verifier)_
