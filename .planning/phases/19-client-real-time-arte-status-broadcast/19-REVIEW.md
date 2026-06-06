---
phase: 19-client-real-time-arte-status-broadcast
reviewed: 2026-06-06T00:00:00Z
depth: standard
files_reviewed: 10
files_reviewed_list:
  - app/channels/client_calendar_channel.rb
  - app/models/arte.rb
  - app/views/client/home/_arte_calendar_chip.html.erb
  - app/views/client/home/_calendar_summary.html.erb
  - app/views/client/shared/_arte_revised_toast.html.erb
  - app/views/layouts/client.html.erb
  - app/views/client/home/index.html.erb
  - app/views/client/home/_month_calendar.html.erb
  - test/channels/client_calendar_channel_test.rb
  - test/models/arte_test.rb
findings:
  critical: 3
  warning: 2
  info: 1
  total: 6
status: issues_found
---

# Phase 19: Code Review Report

**Reviewed:** 2026-06-06
**Depth:** standard
**Files Reviewed:** 10
**Status:** issues_found

## Summary

A revisão cobre a infraestrutura de tempo real do cliente: `ClientCalendarChannel`,
o callback `after_update_commit` em `Arte`, partials Turbo Stream e o layout cliente.

O código tem um defeito de bloqueio funcional que torna o canal em tempo real inoperante
em produção, além de dois bugs de segurança/comportamento no canal e no modelo.
Os demais problemas são de qualidade/robustez.

---

## Critical Issues

### CR-01: WebSocket do cliente nunca autentica — broadcasts não chegam

**File:** `app/views/layouts/client.html.erb:15`

**Issue:**
`Connection#set_current_client` (em `app/channels/application_cable/connection.rb`)
exige que o token do cliente esteja presente em `request.params[:token]`. Para isso,
a URL do WebSocket precisa ser `/cable?token=TOKEN`.

Sem uma tag `<meta name="action-cable-url">` apontando para a URL com o token,
o turbo-rails usa a URL padrão `/cable` (sem parâmetros). Com isso:

1. `set_current_user` retorna `nil` (o cliente não tem `Session` model — apenas
   `session[:client_id]` no cookie HTTP, que a `Connection` não verifica).
2. `set_current_client` retorna `nil` (token ausente na URL do WebSocket).
3. `reject_unauthorized_connection` é invocado pelo framework.
4. `ClientCalendarChannel#subscribed` nunca executa.
5. Todo `ClientCalendarChannel.broadcast_to(client, …)` em `Arte#broadcasts_revised_to_all`
   é transmitido para uma stream que nenhum cliente jamais ouve.

A funcionalidade de tempo real do cliente está completamente inoperante em produção.

**Fix:** Injetar a URL do cabo com o token via `content_for(:head)` no layout:

```erb
<%# app/views/layouts/client.html.erb — dentro de <head>, após csrf_meta_tags %>
<% if @client %>
  <meta name="action-cable-url" content="<%= "#{Rails.application.config.action_cable.url || '/cable'}?token=#{@client.access_token}" %>">
<% end %>
```

Ou, alternativamente, gerar a meta tag com um helper dedicado no controller:

```ruby
# app/controllers/client_controller.rb — before_action
def set_cable_meta
  @cable_url = "#{ActionController::Base.helpers.root_url}cable?token=#{@client.access_token}"
end
```

e no layout:
```erb
<meta name="action-cable-url" content="<%= @cable_url %>">
```

---

### CR-02: `reject` sem `return` — `stream_for` executa mesmo em conexões rejeitadas

**File:** `app/channels/client_calendar_channel.rb:3-4`

**Issue:**
`ActionCable::Channel::Base#reject` apenas seta um flag (`@reject_subscription = true`).
Ele **não** interrompe a execução do método `subscribed`. Como resultado, quando
`current_client` é `nil`, tanto `reject` quanto `stream_for(nil)` são chamados.

Com `stream_for(nil)`:
- `Array(nil)` retorna `[]`.
- `broadcasting_for(["client_calendar_channel"])` registra um stream cujo nome é
  apenas o nome do canal — uma stream global não-cliente-específica.
- Toda conexão rejeitada fica inscrita nessa stream parasita, consumindo recursos
  do servidor e do Redis/SolidCable desnecessariamente.

O mesmo padrão existe em `AdminNotificationsChannel`.

**Fix:**
```ruby
# app/channels/client_calendar_channel.rb
def subscribed
  return reject unless current_client
  stream_for current_client
end
```

```ruby
# app/channels/admin_notifications_channel.rb
def subscribed
  return reject unless current_user
  stream_for current_user
end
```

---

### CR-03: Substituição do `calendar-summary` ignora o mês visualizado pelo cliente

**File:** `app/models/arte.rb:42-58`

**Issue:**
Em `broadcasts_revised_to_all`, o resumo do calendário é calculado com base no mês
de `scheduled_on` da **arte revisada** e enviado com `turbo_stream action="replace"
target="calendar-summary"`. O elemento `#calendar-summary` está presente em **todas**
as views mensais.

Se o cliente estiver visualizando o mês X e a arte revisada pertencer ao mês Y:
- O broadcast substitui `#calendar-summary` com dados do mês Y.
- O cliente passa a ver o resumo errado para o mês que está olhando.
- Nenhuma recarga ou navegação corrige isso até que o cliente mude de mês.

Esse bug é silencioso: o UI parece funcionar, mas exibe dados incorretos.

**Fix:**
A abordagem mais simples é não enviar o `summary` via broadcast indiscriminado.
O chip do calendário (replace) e o toast (append) são suficientes. O summary
poderia ser atualizado com um `morph` ou omitido do broadcast, deixando o cliente
recarregá-lo ao navegar. Se o summary for necessário em tempo real, o canal precisa
conhecer o mês atual do cliente (ex.: passando o mês como parâmetro de subscription):

```ruby
# Arte#broadcasts_revised_to_all — remover ou tornar condicional
# Opção conservadora: não substituir o summary via broadcast
client_streams = [
  turbo_stream_tag("replace", chip_target,          chip_html),
  turbo_stream_tag("append",  "client-toast-region", toast_html)
].join
```

---

## Warnings

### WR-01: XSS potencial — `turbo_stream_tag` interpola `template_html` sem escape

**File:** `app/models/arte.rb:85-87`

**Issue:**
O método `turbo_stream_tag` constrói HTML por interpolação direta de string:

```ruby
%(<turbo-stream action="#{action}" target="#{target}"><template>#{template_html}</template></turbo-stream>)
```

`template_html` provém de `ApplicationController.render`, que retorna uma `String`
não marcada como `html_safe`. Se `render` falhar silenciosamente e retornar conteúdo
parcial não-escapado, ou se o método for reutilizado com entrada controlada pelo
usuário no futuro, qualquer valor de `template_html` seria injetado diretamente no
stream HTML sem sanitização.

Atualmente os valores são gerados por partials ERB seguros, mas o método não protege
contra uso incorreto futuro.

**Fix:** Marcar o retorno como html_safe explicitamente ou usar `SafeBuffer`:

```ruby
def turbo_stream_tag(action, target, template_html = "")
  # action e target são constantes hardcoded; template_html vem de partials controlados
  # Garantir que template_html seja tratado como HTML já escapado
  content = template_html.respond_to?(:html_safe?) ? template_html : ERB::Util.html_escape(template_html.to_s)
  %(<turbo-stream action="#{action}" target="#{target}"><template>#{content}</template></turbo-stream>).html_safe
end
```

Melhor ainda: extrair para um helper ou usar `turbo_stream_action_tag` do turbo-rails.

---

### WR-02: N+1 de queries no cálculo do `summary` no callback

**File:** `app/models/arte.rb:44-50`

**Issue:**
`broadcasts_revised_to_all` executa 4 queries SQL separadas para construir o `summary`:

```ruby
artes_do_mes.count                                      # query 1
artes_do_mes.where(status: :approved).count             # query 2
artes_do_mes.where(status: [:pending, :revised]).count  # query 3
artes_do_mes.where(status: :change_requested).count     # query 4
```

Isso é 4 round-trips ao banco de dados em um callback `after_update_commit` que já
executa de forma síncrona dentro da stack de processamento da requisição/job.

**Fix:** Usar uma única query com `group`:

```ruby
counts = artes_do_mes.group(:status).count
# counts => {"approved" => 3, "pending" => 2, ...}
summary = {
  total:            counts.values.sum,
  approved:         counts.fetch("approved", 0),
  pending:          counts.fetch("pending", 0) + counts.fetch("revised", 0),
  change_requested: counts.fetch("change_requested", 0)
}
```

---

## Info

### IN-01: `test_block_destroy` usa variável de classe — não é thread-safe em parallelismo de testes

**File:** `app/models/arte.rb:9-19`

**Issue:**
O hook `test_block_destroy` usa `Arte.test_block_destroy` (variável de classe).
Se os testes rodarem em paralelo (processes ou threads), um teste que seta
`Arte.test_block_destroy = true` pode afetar outros testes concorrentes, causando
falhas intermitentes difíceis de diagnosticar.

**Fix:** Usar `Thread.current` para isolar o estado por thread:

```ruby
if Rails.env.test?
  class << self
    def test_block_destroy
      Thread.current[:arte_test_block_destroy] || false
    end
    def test_block_destroy=(val)
      Thread.current[:arte_test_block_destroy] = val
    end
  end
  # ...
end
```

---

_Reviewed: 2026-06-06_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
