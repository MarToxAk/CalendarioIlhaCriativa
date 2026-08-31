---
phase: quick/260831-gai-preciso-corrigir-a-quest-o-de-grupos-do-
plan: 1
type: execute
wave: 1
depends_on: []
files_modified:
  - app/services/evolution.rb
  - app/services/evolution/client.rb
  - test/services/evolution/client_test.rb
autonomous: true
requirements: [GRUPO-01, GRUPO-02]

must_haves:
  truths:
    - "Um admin que clica 'Sincronizar grupos' numa instância real e ocupada (dezenas de grupos) recebe a lista de grupos em vez de um erro de timeout."
    - "Evolution::Client.fetch_groups usa um orçamento de tempo próprio, maior que o das leituras de status rápidas (connectionState/fetchInstances), porque fetchAllGroups é estruturalmente mais lento (profilePicture por grupo)."
  artifacts:
    - "app/services/evolution.rb define Evolution::READ_TIMEOUT_GROUPS"
    - "app/services/evolution/client.rb#fetch_groups usa Evolution::READ_TIMEOUT_GROUPS, não READ_TIMEOUT_FAST"
  key_links:
    - "Whatsapp::SyncGroupsJob -> Whatsapp::GroupSynchronizer#call -> Evolution::Client.fetch_groups -> novo timeout"
---

<objective>
Corrigir a sincronização de grupos do WhatsApp, que está falhando em produção com
`Net::ReadTimeout` para instâncias reais com muitos grupos.

**Causa raiz confirmada empiricamente nesta sessão** (não é suposição): rodei
`Evolution::Client.fetch_groups` ao vivo contra a instância real e conectada
`livia_client_31` (WhatsappInstance id 20, cliente com 24.581 mensagens / 2.465 chats —
número de produção genuíno, não dado de teste). Com o timeout atual (15s,
`Evolution::READ_TIMEOUT_FAST`), a chamada estoura em `Net::ReadTimeout`. Repeti a MESMA
chamada com um timeout de 90s: o host respondeu em **~40 segundos** com 64 grupos — a
query real, o shape (`{"id","subject","announce",...}`) e o token da instância estão
TODOS corretos; só o timeout de 15s é curto demais. Isso bate exatamente com o estado já
persistido no banco para essa instância antes desta sessão: `groups_sync_state:
"sync_error"`, `groups_sync_error: "transient"`, `groups_synced_at: nil` — três
tentativas de retry (`retry_on Evolution::Errors::Unknown, wait: 30.seconds, attempts:
3`), todas com o mesmo timeout de 15s, todas fadadas a estourar.

`READ_TIMEOUT_FAST = 15` foi desenhado para leituras de status genuinamente rápidas
(`connectionState`/`fetchInstances`, medidas em ~654ms em produção — ver
`.planning/notes/evolution-contract.md`), mas `fetchAllGroups` foi erroneamente
agrupado com elas. O próprio Evolution API 2.3.7 faz uma chamada
`profilePicture(group.id)` **por grupo** dentro do loop do servidor
(`.planning/research/FEATURES.md:243`), então o tempo de resposta escala com o número
de grupos da instância — 15s nunca foi suficiente para uma conta madura.

Purpose: dar a `fetchAllGroups` seu próprio orçamento de tempo, generoso o bastante para
contas reais, mantendo os outros reads (`connectionState`/`fetchInstances`) rápidos como
já são.
Output: `Evolution::Client.fetch_groups` usando um timeout dedicado
(`Evolution::READ_TIMEOUT_GROUPS`, default 60s, configurável por ENV como os irmãos
`EVOLUTION_OPEN_TIMEOUT`/`EVOLUTION_WRITE_TIMEOUT`/`EVOLUTION_READ_TIMEOUT`), com
cobertura de teste que trava esse valor.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@app/services/evolution.rb
@app/services/evolution/client.rb
@app/services/whatsapp/group_synchronizer.rb
@app/jobs/whatsapp/sync_groups_job.rb
@test/services/evolution/client_test.rb
@.planning/notes/evolution-contract.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Dar a fetchAllGroups um timeout próprio (fix da causa raiz)</name>
  <files>app/services/evolution.rb, app/services/evolution/client.rb</files>
  <action>
Em `app/services/evolution.rb`: adicionar uma nova constante `READ_TIMEOUT_GROUPS`
logo abaixo de `READ_TIMEOUT_FAST`, seguindo exatamente o mesmo padrão ENV-first das
três constantes de timeout que já existem ali (`Integer(ENV.fetch("EVOLUTION_...",
"<default>"))`). Nome da variável de ambiente: `EVOLUTION_READ_TIMEOUT_GROUPS`, default
`"60"` (string, igual às demais). Comentário inline explicando: fetchAllGroups faz uma
chamada profilePicture por grupo no servidor Evolution (cite FEATURES.md:243), e que
15s medido empiricamente estourou contra uma instância real de produção com 64 grupos
(~40s de resposta real) nesta sessão de correção — 60s dá margem folgada sem se
aproximar do teto de ~100s do Cloudflare já documentado no cabeçalho do arquivo. Também
editar o comentário inline já existente ao lado de `READ_TIMEOUT_FAST` (hoje lista
"connectionState / fetchInstances / fetchAllGroups") removendo "fetchAllGroups" dessa
lista, já que passa a ter timeout próprio.

Em `app/services/evolution/client.rb`, método `fetch_groups`: trocar o argumento
`read_timeout: Evolution::READ_TIMEOUT_FAST` (o único ponto onde `fetch_groups` usa a
constante rápida) para `read_timeout: Evolution::READ_TIMEOUT_GROUPS`. Atualizar o
comentário do método (linhas imediatamente acima de `def fetch_groups`) removendo a
frase "Espelha fetch_instances, inclusive o guard WR-07" na parte de timeout — manter a
frase sobre o guard WR-07 (ainda válida), mas deixar explícito que o timeout NÃO espelha
mais `fetch_instances`/`connection_state` porque fetchAllGroups não é uma leitura rápida
para contas com muitos grupos.

Não tocar em `connect`, `fetch_instances` ou `connection_state` — esses três continuam
com `Evolution::READ_TIMEOUT_FAST` (15s), que está correto para eles (latência real
medida ~654ms em produção, per evolution-contract.md). Não tocar em `retry_on`/
`discard_on` de `Whatsapp::SyncGroupsJob` — a política de retry (3 tentativas, 30s de
espera) continua adequada como rede de segurança para hiccups de rede reais; o problema
era o timeout por-tentativa, não o número de tentativas.

Se `.env.example` na raiz do projeto já listar outras variáveis `EVOLUTION_*`
(`EVOLUTION_OPEN_TIMEOUT` etc.), adicionar `EVOLUTION_READ_TIMEOUT_GROUPS=60` na mesma
seção para consistência — best-effort, não bloqueia a task se o arquivo não for
acessível ou não seguir esse padrão.
  </action>
  <verify>
    <automated>POSTGRES_HOST=/var/run/postgresql TZ=America/Sao_Paulo bin/rails runner 'raise "fail" unless Evolution::READ_TIMEOUT_GROUPS == 60; raise "fail" if Evolution::READ_TIMEOUT_GROUPS == Evolution::READ_TIMEOUT_FAST; puts "OK"'</automated>
  </verify>
  <done>
`Evolution::READ_TIMEOUT_GROUPS` existe, vale 60 por default, é distinto de
`READ_TIMEOUT_FAST` (15), e `Evolution::Client.fetch_groups` passa
`Evolution::READ_TIMEOUT_GROUPS` como `read_timeout:` na chamada HTTP —
`connect`/`fetch_instances`/`connection_state` continuam usando `READ_TIMEOUT_FAST`.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Travar o timeout novo com teste + regressão dos existentes</name>
  <files>test/services/evolution/client_test.rb</files>
  <behavior>
    - Teste 1 (novo): usando o MESMO padrão já usado no teste "fetch_groups api_key: per
      call overrides the memoized global apikey header" (stub que inspeciona o `env`
      dentro do bloco `Faraday::Adapter::Test::Stubs.new`), montar um stub para
      `GET /group/fetchAllGroups/livia_client_1?getParticipants=false` cujo bloco lê
      `env.request.read_timeout` (comportamento confirmado nesta sessão via rails
      runner: o Faraday::Env exposto ao stub carrega o valor setado por
      `req.options.read_timeout = read_timeout` dentro de `Evolution::Client#request`)
      e devolve um Array vazio. Chamar `Evolution::Client.fetch_groups("livia_client_1",
      api_key: "test-api-key")` e então `assert_equal Evolution::READ_TIMEOUT_GROUPS,
      <valor capturado do env.request.read_timeout>` — capturar o valor numa variável
      de closure antes do `assert_equal`, no mesmo estilo dos testes vizinhos que
      capturam `env.request_headers["apikey"]`. Adicionar um segundo assert:
      `refute_equal Evolution::READ_TIMEOUT_FAST, <valor capturado>` para deixar
      explícito que a regressão original (usar o timeout de 15s) não pode voltar.
    - Regressão: rodar a suíte inteira de `fetch_groups` já existente no arquivo
      (linhas ~347-469: os 7 testes já cobrindo Array/Hash/HTML/JSON malformado/400/
      query string/api_key override) — nenhum deles depende do valor exato de
      `READ_TIMEOUT_FAST`/`READ_TIMEOUT_GROUPS`, então devem continuar passando sem
      alteração.
  </behavior>
  <action>
Adicionar o novo teste descrito no bloco `behavior` acima na seção "--- fetch_groups
(fase 27, GRUPO-01) ---" de `test/services/evolution/client_test.rb`, logo após o teste
"fetch_groups api_key: per call overrides the memoized global apikey header" (linha
~469), seguindo o mesmo padrão de `ensure Evolution::Client.instance_variable_set(:
@connection, nil)` usado por todos os testes vizinhos nesse arquivo (reset do singleton
memoizado). Não alterar nenhum dos 7 testes de `fetch_groups` já existentes — eles
continuam válidos e não fazem asserção sobre o valor do timeout.
  </action>
  <verify>
    <automated>POSTGRES_HOST=/var/run/postgresql TZ=America/Sao_Paulo bin/rails test test/services/evolution/client_test.rb -n "/fetch_groups/"</automated>
  </verify>
  <done>
`bin/rails test test/services/evolution/client_test.rb -n "/fetch_groups/"` passa com 0
falhas/erros, incluindo o novo teste que trava `fetch_groups` usando
`Evolution::READ_TIMEOUT_GROUPS` (e não `READ_TIMEOUT_FAST`) como `read_timeout` da
requisição HTTP.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|--------------|
| App -> host Evolution (agência) | requisição HTTP autenticada por `apikey` (token da instância); resposta de terceiro não confiável tratada pela taxonomia `Evolution::Errors::*` já existente — este fix não adiciona nenhuma superfície nova de entrada não confiável, só ajusta um timeout numa chamada já existente. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-quick-01 | Denial of Service | `Evolution::Client.fetch_groups` (timeout mais longo) | low | accept | 60s ainda está bem abaixo do teto de ~100s do Cloudflare já documentado (`evolution-contract.md`); `SyncGroupsJob` roda em background (nunca no request/thread do browser), então um timeout mais longo não trava a UI nem o request HTTP do admin — só o worker fica ocupado por mais tempo numa única tentativa, dentro do mesmo pool de 3 threads já dimensionado para isso. |

No mitigate-severity findings — esta é uma correção de um único valor de configuração numa chamada de leitura já existente e já coberta pela taxonomia de erro/retry da fase 27; nenhuma superfície de auth, autorização ou parsing de payload muda.
</threat_model>

<verification>
1. `Evolution::READ_TIMEOUT_GROUPS` existe em `app/services/evolution.rb`, é distinto de
   `READ_TIMEOUT_FAST`, e é configurável por `EVOLUTION_READ_TIMEOUT_GROUPS` (mesmo
   padrão ENV-first dos irmãos).
2. `Evolution::Client.fetch_groups` usa `Evolution::READ_TIMEOUT_GROUPS` como
   `read_timeout:` — confirmado por teste automatizado que inspeciona o
   `Faraday::Env` da requisição stubada.
3. `connect`/`fetch_instances`/`connection_state` continuam usando
   `READ_TIMEOUT_FAST` (15s) — nenhuma regressão de latência nas leituras de status.
4. Suíte completa de `fetch_groups` (7 testes pré-existentes + 1 novo) passa:
   `POSTGRES_HOST=/var/run/postgresql TZ=America/Sao_Paulo bin/rails test test/services/evolution/client_test.rb -n "/fetch_groups/"`.
</verification>

<success_criteria>
- Um admin que clica "Sincronizar grupos" numa instância real, paga e ocupada (dezenas
  de grupos) deixa de receber `groups_sync_error: "transient"` por timeout — o
  orçamento de tempo agora comporta a latência real medida (~40s para 64 grupos, com
  margem até 60s).
- Nenhuma mudança de comportamento para `connectionState`/`fetchInstances`/`connect`
  (continuam com o timeout rápido de 15s).
- Nenhum teste pré-existente quebra.

Nota operacional (não é uma task — não requer ação de código): a instância real
`livia_client_31` (WhatsappInstance id 20) já está com `groups_sync_state: sync_error`
no banco por causa deste bug. Nenhum backfill é necessário — o próximo clique em
"Sincronizar grupos" nessa instância, já rodando com o fix, resolve o estado sozinho
(o synchronizer sempre sobrescreve `groups_sync_state`/`groups_sync_error` a cada
tentativa, sucedida ou não).
</success_criteria>

<output>
Create `.planning/quick/260831-gai-preciso-corrigir-a-quest-o-de-grupos-do-/260831-gai-SUMMARY.md` when done
</output>
