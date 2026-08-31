# Phase 29: Motor de Envio - Pattern Map

**Mapped:** 2026-08-31
**Files analyzed:** 10
**Analogs found:** 9 / 10

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `app/jobs/divulgacoes/dispatch_job.rb` | job (trigger/fan-out) | event-driven | `app/jobs/whatsapp/sync_groups_job.rb` (structure) + `app/controllers/admin/divulgacoes_controller.rb#create` (enqueue site) | role-match |
| `app/jobs/whatsapp/send_to_group_job.rb` | job (worker) | request-response (outbound HTTP) | `app/jobs/whatsapp/sync_groups_job.rb` | exact (error-taxonomy shape) |
| `app/services/evolution/client.rb` (modified: `+send_text`, `+send_media`) | service (HTTP client) | request-response | same file, `create_instance`/`fetch_groups` methods | exact |
| `app/models/divulgacao.rb` (modified: status-transition helpers) | model | CRUD | same file, `#cancelar!` | exact |
| `app/models/divulgacao_grupo.rb` (modified: atomic claim scope) | model | CRUD | `app/services/whatsapp/group_synchronizer.rb` (`update_all` discipline) | role-match (SQL shape differs: claim vs deactivate) |
| `app/controllers/admin/divulgacoes_controller.rb#create` (modified: enqueue `DispatchJob`) | controller | request-response | same file (existing `#create`/`#cancel` actions) | exact |
| `config/queue.yml` (modified: dedicated worker for `whatsapp_sends`) | config | batch/dispatch config | same file (`default: &default` block) | exact |
| `app/jobs/application_job.rb` | job (base class) | — | same file (currently empty `retry_on`/`discard_on` comments) | exact — no change strictly required, taxonomy lives in concrete jobs |
| `test/jobs/whatsapp/send_to_group_job_test.rb` | test | event-driven | `test/jobs/whatsapp/sync_groups_job_test.rb` | exact |
| `test/jobs/divulgacoes/dispatch_job_test.rb` | test | event-driven | `test/jobs/whatsapp/sync_groups_job_test.rb` (ActiveJob::TestCase conventions) | role-match |
| `test/services/evolution/client_test.rb` (modified: `+send_text`/`+send_media` cases) | test | request-response | same file (`stubbed_post_connection` pattern) | exact |
| `test/models/divulgacao_test.rb` (modified) | test | CRUD | existing file (not read this pass — follow existing validation test conventions) | role-match |

## Pattern Assignments

### `app/jobs/whatsapp/send_to_group_job.rb` (job, request-response)

**Analog:** `app/jobs/whatsapp/sync_groups_job.rb` (full file read)

**Imports/class shell + queue_as** (lines 1-9):
```ruby
class Whatsapp::SyncGroupsJob < ApplicationJob
  queue_as :default # config/queue.yml: worker unico em queues: "*", sem fila dedicada nesta fase (INFRA-06 e fase 29)
```
For `SendToGroupJob`, use `queue_as :whatsapp_sends` (Pattern 7 in RESEARCH) and add `limits_concurrency`:
```ruby
limits_concurrency(to: 1, key: ->(group) { group.divulgacao.client.whatsapp_instance_id })
```

**Error-taxonomy declaration order — CRITICAL, copy verbatim structure** (lines 10-59):
```ruby
discard_on(StandardError) do |job, err|
  Rails.logger.error(
    "[Whatsapp::SyncGroupsJob] erro inesperado (fora da taxonomia Evolution::Errors): " \
    "#{err.class}: #{err.message}\n#{err.backtrace&.first(10)&.join("\n")}"
  )
  mark_error(job, "unexpected_error")
end

retry_on Evolution::Errors::Transient, wait: 30.seconds, attempts: 3 do |job, _err|
  mark_error(job, "transient")
end
retry_on Evolution::Errors::Unknown, wait: 30.seconds, attempts: 3 do |job, _err|
  mark_error(job, "transient")
end

discard_on(Evolution::Errors::Permanent)          { |job, _err| mark_error(job, "permanent") }
discard_on(Evolution::Errors::NotConnected)       { |job, _err| mark_error(job, "not_connected") }
discard_on(Evolution::Errors::ConfigurationError) { |job, _err| mark_error(job, "config_error") }
discard_on(ActiveJob::DeserializationError) # instancia deletada mid-flight -- sem efeito colateral
```
CONTEXT.md/RESEARCH deviate from this exact mapping for `SendToGroupJob` — the mapping is:
- `discard_on(StandardError)` catch-all — **declared first** (same as above; the ordering rule is verified via `ActiveSupport::Rescuable#rescue_handlers.reverse_each.detect`, RESEARCH Pitfall 3).
- `retry_on(Evolution::Errors::Transient, wait: :polynomially_longer, attempts: 5)` — nothing sent yet, safe retry.
- `discard_on(Evolution::Errors::Unknown)` → mark `:incerto` (Net::ReadTimeout case — never auto-retry).
- `discard_on(Evolution::Errors::Permanent)` → mark `:falhou`, truncated `error_code`.
- `discard_on(Evolution::Errors::NotConnected)` → mark `:falhou`, `"instancia_desconectada"`.
- `discard_on(ActiveJob::DeserializationError)`.

**`perform` method shape** (lines 61-67, `sync_groups_job.rb`):
```ruby
def perform(instance)
  Whatsapp::GroupSynchronizer.new(instance).call
end

def self.mark_error(job, code)
  inst = job.arguments.first
  inst.update!(groups_sync_state: :sync_error, groups_sync_error: code) if inst.is_a?(WhatsappInstance)
end
```
`SendToGroupJob#perform` is materially different (RESEARCH Pattern 5 gives the full skeleton — reload group/divulgacao/arte/instance, atomic claim via `update_all`, revalidation, Evolution call) but the `mark_error`-style class helper for writing status/error_code from within a `discard_on`/`retry_on` block should mirror this `self.mark_error(job, code)` shape — `job.arguments.first` gives the `DivulgacaoGrupo` GlobalID-deserialized argument.

**Full target skeleton (from RESEARCH Pattern 5, already vetted against solid_queue 1.4.0 source):**
```ruby
class Whatsapp::SendToGroupJob < ApplicationJob
  queue_as :whatsapp_sends

  limits_concurrency(to: 1, key: ->(group) { group.divulgacao.client.whatsapp_instance_id })

  discard_on(StandardError) { |job, err| ... } # catch-all, DECLARADO PRIMEIRO

  retry_on(Evolution::Errors::Transient, wait: :polynomially_longer, attempts: 5) { |job, err| ... }
  discard_on(Evolution::Errors::Unknown)      { |job, err| mark_incerto(job, err) }
  discard_on(Evolution::Errors::Permanent)    { |job, err| mark_falhou(job, err) }
  discard_on(Evolution::Errors::NotConnected) { |job, err| mark_falhou(job, "instância desconectada") }
  discard_on(ActiveJob::DeserializationError)

  def perform(group)
    group.reload
    divulgacao = group.divulgacao.reload
    return if divulgacao.status_cancelada?

    claimed = DivulgacaoGrupo.where(id: group.id, status: :pendente)
                              .update_all(status: :enviado, sent_at: Time.current, updated_at: Time.current)
    return if claimed.zero? # outro worker/retry já tratou

    arte = divulgacao.arte.reload
    unless arte.approved?
      group.update!(status: :falhou, error_code: "arte_nao_aprovada")
      finalize_divulgacao_if_done(divulgacao)
      return
    end

    instance = divulgacao.client.whatsapp_instance
    unless instance&.connected?
      group.update!(status: :falhou, error_code: "instancia_desconectada")
      finalize_divulgacao_if_done(divulgacao)
      return
    end

    send_via_evolution(group, arte, instance) # levanta Evolution::Errors::* em falha
    finalize_divulgacao_if_done(divulgacao)
  end
end
```
(source: 29-RESEARCH.md Pattern 5, lines 333-381)

---

### `app/jobs/divulgacoes/dispatch_job.rb` (job, event-driven fan-out)

**Analog:** structural conventions from `sync_groups_job.rb` (queue_as, ApplicationJob base) + enqueue-site conventions from `Admin::DivulgacoesController#create`.

**Target skeleton (RESEARCH Pattern 2, lines 206-223):**
```ruby
class Divulgacoes::DispatchJob < ApplicationJob
  queue_as :whatsapp_sends

  def perform(divulgacao)
    divulgacao.reload
    return if divulgacao.status_cancelada?

    divulgacao.update!(status: :em_andamento) if divulgacao.status_agendada?

    offset = 0
    divulgacao.divulgacao_grupos.pendente.find_each do |group|
      Whatsapp::SendToGroupJob.set(wait: offset.seconds).perform_later(group)
      offset += rand(Divulgacao::SEND_DELAY_MIN..Divulgacao::SEND_DELAY_MAX)
    end
  end
end
```

**Enqueue site — copy `#create`'s existing `if @divulgacao.save` branch** (`app/controllers/admin/divulgacoes_controller.rb` lines ~53-60):
```ruby
if @divulgacao.save
  redirect_to admin_client_divulgacao_path(@client, @divulgacao),
              notice: "Divulgação agendada para #{helpers.divulgacao_datetime_label(@divulgacao.scheduled_for)}."
else
  ...
end
```
Add immediately after `@divulgacao.save` succeeds (RESEARCH Pattern 1, line 195-198):
```ruby
Divulgacoes::DispatchJob.set(wait_until: @divulgacao.scheduled_for).perform_later(@divulgacao)
```

---

### `app/services/evolution/client.rb` (service, request-response — modified)

**Analog:** same file, existing `create_instance`/`fetch_groups` methods (already read in full).

**Method-doc-comment + body convention** (existing `fetch_groups`, note the doc comment format referencing REQ ID, contract doc, and token source):
```ruby
# GET /group/fetchAllGroups/{instance}?getParticipants=false — leitura de
# grupos da instância (fase 27, GRUPO-01). `getParticipants` é OBRIGATÓRIO
# como string (senão 400 -> Evolution::Errors::Permanent). Usa o TOKEN DA
# INSTÂNCIA (api_key: whatsapp_instance.token), não a apikey global. Espelha
# fetch_instances, inclusive o guard WR-07.
def fetch_groups(instance_name, api_key:)
  body = request(:get, "/group/fetchAllGroups/#{instance_name}",
                 api_key: api_key,
                 query: { "getParticipants" => "false" },
                 read_timeout: Evolution::READ_TIMEOUT_FAST).body
  raise Evolution::Errors::Unknown, "resposta 2xx com corpo não-JSON do host Evolution" unless body.is_a?(Array)

  body
end
```

**New methods to add (RESEARCH Pattern 6, verified against evolution-contract.md):**
```ruby
# POST /message/sendText/{instance} — contrato verificado em evolution-contract.md
# (tag 2.3.7): { number, text, delay? }. `number` = JID de grupo (...@g.us).
def send_text(instance_name, number:, text:, api_key:)
  request(:post, "/message/sendText/#{instance_name}",
          api_key: api_key, body: { number: number, text: text }).body
end

# POST /message/sendMedia/{instance} — { number, mediatype, media, caption?, fileName?, mimetype?, delay? }.
# mediatype ∈ image|video|document|audio — só image/video são usados por esta fase (ENVIO-10).
def send_media(instance_name, number:, mediatype:, media:, api_key:, caption: nil)
  body = { number: number, mediatype: mediatype, media: media }
  body[:caption] = caption if caption.present?
  request(:post, "/message/sendMedia/#{instance_name}", api_key: api_key, body: body).body
end
```
Note: both go **inside `class << self`**, alongside `fetch_groups`/`create_instance` (not inside `private`) — the private `request`/`raise_for_status!`/`classify_timeout` block stays after `private` at the bottom (lines 155-227 of the file), unchanged. No new error-parsing logic needed — `raise_for_status!` (already generic, status-code-driven) handles the free-text 4xx body from `sendMedia`.

**Error handling pattern — already in the file, do not duplicate.** `request` (private, lines ~163-183) wraps all Faraday errors into `Evolution::Errors::*`; `raise_for_status!` (lines ~190-207) maps HTTP status → error class. No changes required to these — `send_text`/`send_media` reuse them automatically by going through `request`.

---

### `app/models/divulgacao.rb` (model, CRUD — modified)

**Analog:** same file, `#cancelar!` (lines ~38-44 in-file):
```ruby
# `patch :cancel` -> aqui. So flipa agendada -> cancelada; qualquer outro
# status atual (em_andamento/concluida/ja cancelada) e um no-op idempotente
# (T-28-15 — replay do cancel nao quebra nada, so nao muda nada). Nenhum
# param e lido — o unico jeito de mudar o status por esta via e este metodo.
def cancelar!
  return false unless status_agendada?
  update(status: :cancelada)
end
```
Follow this exact idiom for any new status-transition helper (e.g., a guarded `#concluir!`/`#iniciar!` if the planner decides to add explicit model methods instead of inline `update!` calls inside the jobs): guard on current-state predicate (`status_X?`), `update`/`update!` the new status, no side params read. `divulgacao.update!(status: :em_andamento) if divulgacao.status_agendada?` (used directly in `DispatchJob`, RESEARCH Pattern 2) is consistent with this style — a dedicated model method is optional, Claude's Discretion per CONTEXT.md.

**Enum + prefix convention** (lines ~19-20):
```ruby
enum :status, { agendada: 0, em_andamento: 1, concluida: 2, cancelada: 3 }, prefix: :status
```
Any new predicate reads as `divulgacao.status_em_andamento?`, `divulgacao.status_concluida?`, etc.

---

### `app/models/divulgacao_grupo.rb` (model, CRUD — modified)

**Analog (SQL discipline, not literal method):** `app/services/whatsapp/group_synchronizer.rb` `update_all` usage (RESEARCH Pitfall 5, lines ~550-558):
```ruby
# GRUPO-05: escopado pela associacao (nunca toca outra instancia), "<"
# estrito, updated_at explicito (update_all nao auto-toca). Roda MESMO
# com rows vazio ...
@instance.whatsapp_groups
         .where(active: true)
         .where("synced_at < ?", batch_started_at)
         .update_all(active: false, updated_at: Time.current)
```
**Applied to the atomic claim in `SendToGroupJob` (not a `DivulgacaoGrupo` model method per RESEARCH Pattern 5, but could be extracted as a class method on the model at Claude's Discretion):**
```ruby
DivulgacaoGrupo.where(id: group.id, status: :pendente)
               .update_all(status: :enviado, sent_at: Time.current, updated_at: Time.current)
```
Key discipline carried over: **always pass `updated_at: Time.current` explicitly** in any `update_all` (RESEARCH Pitfall 5 — `update_all` never auto-touches timestamps, and this repo's established convention is to set it explicitly every time).

**Existing enum/validations (unchanged, for reference)**:
```ruby
enum :status, { pendente: 0, enviado: 1, falhou: 2, incerto: 3 }
validates :whatsapp_group_id, uniqueness: { scope: :divulgacao_id }
validates :group_name, :remote_jid, presence: true
```

---

### `config/queue.yml` (config — modified)

**Analog:** same file, current content (verified in full):
```yaml
default: &default
  dispatchers:
    - polling_interval: 1
      batch_size: 500
  workers:
    - queues: "*"
      threads: 3
      processes: <%= ENV.fetch("JOB_CONCURRENCY", 1) %>
      polling_interval: 0.1

development:
  <<: *default

test:
  <<: *default

production:
  <<: *default
```

**Target change (RESEARCH Pattern 7, add second worker, don't touch the `"*"` worker):**
```yaml
default: &default
  dispatchers:
    - polling_interval: 1
      batch_size: 500
  workers:
    - queues: "*"
      threads: 3
      processes: <%= ENV.fetch("JOB_CONCURRENCY", 1) %>
      polling_interval: 0.1
    - queues: whatsapp_sends
      threads: 2
      polling_interval: 0.1
```
Edit only inside `default: &default` — all three environments inherit via the YAML anchor `<<: *default`, no per-environment duplication needed (RESEARCH Pitfall 4).

---

### `test/jobs/whatsapp/send_to_group_job_test.rb` (test)

**Analog:** `test/jobs/whatsapp/sync_groups_job_test.rb` (full file read — the only ActiveJob test in the repo, establishes every convention to copy).

**Setup pattern** (lines ~20-33):
```ruby
def setup
  @client = Client.create!(
    name: "SyncJob Test",
    password: "senha1234",
    password_confirmation: "senha1234"
  )
  @instance = WhatsappInstance.create!(
    client: @client,
    instance_name: WhatsappInstance.evolution_name_for(@client),
    token: "SEGREDO",
    connection_state: :connected
  )
end
```
For `SendToGroupJobTest`, extend with `Divulgacao`/`Arte`/`WhatsappGroup`/`DivulgacaoGrupo` fixtures/factories following the same explicit `.create!` style (no FactoryBot in this repo — plain ActiveRecord `.create!`).

**DI-via-stub pattern for external calls** (avoids real network, lines ~35-49):
```ruby
class FakeSynchronizer
  attr_reader :calls
  def initialize(error_class: nil)
    @error_class = error_class
    @calls = 0
  end
  def call
    @calls += 1
    raise @error_class, "fake" if @error_class
    true
  end
end
...
Whatsapp::GroupSynchronizer.stub(:new, ->(instance) { assert_equal @instance, instance; fake }) do
  Whatsapp::SyncGroupsJob.new(@instance).perform_now
end
```
For `SendToGroupJob`, `Evolution::Client.stub(:send_text, ...)` / `.stub(:send_media, ...)` (class-method stub, since `Evolution::Client` uses `class << self`) is the equivalent — raise `Evolution::Errors::*` classes from the stub body to test each `retry_on`/`discard_on` branch, exactly as done here for `Transient`/`Unknown`/`Permanent`/`NotConnected`.

**Retry-vs-discard assertions** (lines ~51-95):
```ruby
test "retry_on Transient reenfileira em vez de descartar (GET idempotente)" do
  fake = FakeSynchronizer.new(error_class: Evolution::Errors::Transient)
  Whatsapp::GroupSynchronizer.stub(:new, ->(*) { fake }) do
    assert_enqueued_with(job: Whatsapp::SyncGroupsJob, args: [ @instance ]) do
      Whatsapp::SyncGroupsJob.perform_now(@instance)
    end
  end
  assert_nil @instance.reload.groups_sync_error
end

test "discard_on Permanent grava groups_sync_error=permanent e state=error, sem reenfileirar" do
  fake = FakeSynchronizer.new(error_class: Evolution::Errors::Permanent)
  Whatsapp::GroupSynchronizer.stub(:new, ->(*) { fake }) do
    assert_no_enqueued_jobs do
      Whatsapp::SyncGroupsJob.perform_now(@instance)
    end
  end
  @instance.reload
  assert_equal "sync_error", @instance.groups_sync_state
  assert_equal "permanent", @instance.groups_sync_error
end
```
Same shape for `SendToGroupJob`: `assert_enqueued_with`/`assert_no_enqueued_jobs` bracketing `perform_now`, then assert on `divulgacao_grupo.reload.status`/`.error_code`.

**Exhaustion-of-retry test** (final attempt actually discards, lines ~155-171):
```ruby
test "retry_on Transient chama mark_error na tentativa final (exhaustion), sem reenfileirar de novo" do
  fake = FakeSynchronizer.new(error_class: Evolution::Errors::Transient)
  job = Whatsapp::SyncGroupsJob.new(@instance)
  job.exception_executions = { "[Evolution::Errors::Transient]" => 3 }

  Whatsapp::GroupSynchronizer.stub(:new, ->(*) { fake }) do
    assert_no_enqueued_jobs do
      job.perform_now
    end
  end
  ...
end
```
Set `job.exception_executions` directly to simulate the final attempt without waiting for real `wait:` backoff.

**Order-of-declaration regression test** (catch-all doesn't steal specific handlers, lines ~144-153):
```ruby
test "discard_on StandardError (catch-all) nao rouba Transient do retry_on mais especifico" do
  ...
  assert_enqueued_with(job: Whatsapp::SyncGroupsJob, args: [ @instance ]) do
    Whatsapp::SyncGroupsJob.perform_now(@instance)
  end
  ...
end
```
Must-have equivalent test for `SendToGroupJob` given RESEARCH Pitfall 3 explicitly calls out this exact regression risk.

**GlobalID/token-leak regression test** (lines ~184-189):
```ruby
test "perform_later serializa via GlobalID -- o token nunca entra nos argumentos do job" do
  job = Whatsapp::SyncGroupsJob.new(@instance)
  serialized = job.serialize
  refute_includes serialized["arguments"].to_s, "SEGREDO"
end
```
Copy for `SendToGroupJob` — same sensitivity for `whatsapp_instance.token`.

---

### `test/services/evolution/client_test.rb` (test — modified: add `send_text`/`send_media` cases)

**Analog:** same file, `stubbed_post_connection` + `assert_raises_for` helpers (already established for `create_instance`, lines 1-41 read in full):
```ruby
def stubbed_post_connection(status, body, headers = { "Content-Type" => "application/json" }, path: "/instance/create")
  stubs = Faraday::Adapter::Test::Stubs.new do |s|
    s.post(path) { [ status, headers, body ] }
  end
  Faraday.new do |f|
    f.request :json
    f.response :json, content_type: /\bjson$/
    f.adapter :test, stubs
  end
end
```
For `send_text`/`send_media` tests: either reuse `stubbed_post_connection(status, body, path: "/message/sendText/foo")` directly against `Evolution::Client.connection` (stub `Evolution::Client.stub(:connection, stubbed_post_connection(...))`), or (simpler, matching existing `assert_raises_for` style) stub at the `raise_for_status!` level for taxonomy assertions and add one or two integration-style tests that stub `connection` and call `Evolution::Client.send_text(...)`/`.send_media(...)` end-to-end to assert the request body shape (`number`, `text`/`mediatype`/`media`/`caption`).

**Existing taxonomy assertion pattern to reuse for the new endpoints** (lines 45-70):
```ruby
test "401 and 403 classify as Permanent" do
  assert_raises_for(Evolution::Errors::Permanent, 401,
                    '{"status":401,"error":"Unauthorized","response":{"message":"Unauthorized"}}')
  assert_raises_for(Evolution::Errors::Permanent, 403, "{}")
end
```
No new taxonomy branches are needed — `send_text`/`send_media` reuse `raise_for_status!` verbatim; tests should confirm the new methods correctly propagate `Evolution::Errors::Permanent`/`Transient`/`Unknown` end-to-end (stub `connection`, not just `raise_for_status!` directly), not re-test the classification matrix already covered above.

---

## Shared Patterns

### Error taxonomy + discard/retry declaration order
**Source:** `app/jobs/whatsapp/sync_groups_job.rb` (full file), reinforced by `29-RESEARCH.md` Pitfall 3 (verified against `activesupport-8.1.3/lib/active_support/rescuable.rb:129`)
**Apply to:** `app/jobs/whatsapp/send_to_group_job.rb`
Rule: `discard_on(StandardError)` catch-all must be the **first** handler declared in the class body; all `retry_on`/`discard_on` for specific `Evolution::Errors::*` subclasses come after. `rescue_handlers.reverse_each.detect` means later-declared handlers win.

### `update_all` timestamp discipline
**Source:** `app/services/whatsapp/group_synchronizer.rb` (comment + call site)
**Apply to:** the atomic claim in `SendToGroupJob#perform` (`DivulgacaoGrupo.where(...).update_all(status: :enviado, sent_at: ..., updated_at: Time.current)`) and any other `update_all` in this phase.
Always pass `updated_at: Time.current` explicitly — `update_all` never auto-touches it.

### Evolution client error propagation (single seam)
**Source:** `app/services/evolution/client.rb` `request`/`raise_for_status!`/`classify_timeout` (private, unchanged)
**Apply to:** `send_text`/`send_media` — no new error-handling code needed in these methods; they inherit the full taxonomy by calling the existing private `request`.

### Namespace convention
**Source:** `Whatsapp::SyncGroupsJob`, `Whatsapp::GroupSynchronizer`
**Apply to:** `Whatsapp::SendToGroupJob` (module `Whatsapp::`), `Divulgacoes::DispatchJob` (module `Divulgacoes::`, per CONTEXT.md naming decision — no existing `Divulgacoes::` namespace precedent in the repo, first use).

### Controller enqueue-on-save convention
**Source:** `app/controllers/admin/divulgacoes_controller.rb#create` (`if @divulgacao.save ... else ...`)
**Apply to:** insert `Divulgacoes::DispatchJob.set(wait_until: @divulgacao.scheduled_for).perform_later(@divulgacao)` immediately inside the `if @divulgacao.save` success branch, before the `redirect_to`.

### ActiveJob test conventions (setup, stubs, enqueue assertions)
**Source:** `test/jobs/whatsapp/sync_groups_job_test.rb` (full file)
**Apply to:** `test/jobs/whatsapp/send_to_group_job_test.rb`, `test/jobs/divulgacoes/dispatch_job_test.rb`
Plain `ActiveRecord.create!` fixtures (no FactoryBot), fake/stub collaborators via `SomeClass.stub(:method, ...)`, `assert_enqueued_with`/`assert_no_enqueued_jobs` to assert retry vs discard, `job.exception_executions = {...}` to simulate retry exhaustion without waiting on real backoff.

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `app/jobs/divulgacoes/dispatch_job.rb` | job | event-driven fan-out | First job in a new `Divulgacoes::` namespace — no direct analog for "read pending children, enqueue N staggered child jobs" pattern in the repo; composed from `sync_groups_job.rb` structural conventions + RESEARCH Pattern 2 (already source-verified against solid_queue 1.4.0, not just inferred). |

## Metadata

**Analog search scope:** `app/jobs/`, `app/services/evolution/`, `app/services/whatsapp/`, `app/models/divulgacao*.rb`, `app/controllers/admin/divulgacoes_controller.rb`, `config/queue.yml`, `test/jobs/whatsapp/`, `test/services/evolution/`
**Files scanned:** 9 (all read in full or targeted, no file > 300 lines, no offset/limit paging needed)
**Pattern extraction date:** 2026-08-31
