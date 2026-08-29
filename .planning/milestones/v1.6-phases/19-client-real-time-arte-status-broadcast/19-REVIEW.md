---
phase: 19-client-real-time-arte-status-broadcast
reviewed: 2026-06-06T00:00:00Z
depth: standard
files_reviewed: 10
files_reviewed_list:
  - app/channels/client_calendar_channel.rb
  - app/views/client/home/_arte_calendar_chip.html.erb
  - app/views/client/home/_calendar_summary.html.erb
  - app/views/client/shared/_arte_revised_toast.html.erb
  - test/channels/client_calendar_channel_test.rb
  - app/views/layouts/client.html.erb
  - app/views/client/home/index.html.erb
  - app/views/client/home/_month_calendar.html.erb
  - test/models/arte_test.rb
  - app/models/arte.rb
findings:
  critical: 2
  warning: 2
  info: 2
  total: 6
status: issues_found
---

# Phase 19: Code Review Report

**Reviewed:** 2026-06-06
**Depth:** standard
**Files Reviewed:** 10
**Status:** issues_found

## Summary

A fase implementa o broadcast em tempo real de mudanças de status de artes para o cliente via
ActionCable (`ClientCalendarChannel`) e Turbo Streams. O canal em si está correto; o callback
`after_update_commit` em `Arte` constrói e envia corretamente os streams; os testes cobrem os
caminhos principais. Foram encontrados dois bugs críticos: um de lógica no broadcast (dados do
mês errado sobrepõem a visão do cliente quando a arte revisada pertence a um mês diferente do
mês que o cliente está visualizando) e outro no `toast_controller.js` (limite de toasts nunca
enforçado na página do cliente por ID hardcoded errado). Há também duas advertências de
qualidade nos testes.

---

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Broadcast substitui `#calendar-summary` com dados do mês errado quando cliente visualiza mês diferente

**File:** `app/models/arte.rb:42-74`

**Issue:** Em `broadcasts_revised_to_all`, o resumo mensal é calculado usando
`scheduled_on.beginning_of_month` da arte revisada, e enviado com
`turbo_stream action="replace" target="calendar-summary"`. O elemento `#calendar-summary` está
presente em qualquer mês que o cliente visualize (definido em `_calendar_summary.html.erb:2`).

Cenário concreto de falha: arte A está agendada em Janeiro. O cliente está visualizando o
calendário de Março. O admin marca a arte A como revisada. O broadcast executa:

```ruby
current_month_start = scheduled_on.beginning_of_month  # 1 de Janeiro
artes_do_mes = client.artes.where(scheduled_on: current_month_start..current_month_end)
# summary calculado para Janeiro...
turbo_stream_tag("replace", "calendar-summary", summary_html)  # substitui o div na tela
```

O cliente passa a ver o resumo de Janeiro enquanto navega em Março. O chip replace para a arte
de Janeiro (`#calendar_chip_arte_X`) seria ignorado silenciosamente pelo Turbo (elemento não
existe no DOM de Março), mas o `#calendar-summary` **sempre existe** e é sobrescrito. O bug é
silencioso — a UI parece funcionar mas exibe dados incorretos até o cliente navegar.

**Fix:** Remover o replace do summary do broadcast global (ou tornar o target mês-específico).
A abordagem mais segura:

```ruby
# app/models/arte.rb — broadcasts_revised_to_all
# Enviar apenas chip e toast; summary fica sob responsabilidade da navegação normal
client_streams = [
  turbo_stream_tag("replace", chip_target,           chip_html),
  turbo_stream_tag("append",  "client-toast-region", toast_html)
].join
```

Se o summary em tempo real for necessário, incluir o mês no ID do elemento:

```erb
<%# _calendar_summary.html.erb %>
<div id="calendar-summary-<%= summary[:month_key] %>" ...>
```

```ruby
# arte.rb
month_key      = scheduled_on.strftime("%Y-%m")
summary_target = "calendar-summary-#{month_key}"
turbo_stream_tag("replace", summary_target, summary_html)
```

---

### CR-02: `toast_controller.js` — `_enforceLimit` usa ID `"admin-toast-region"` hardcoded; limite nunca é enforçado na página do cliente

**File:** `app/javascript/controllers/toast_controller.js:27`

**Issue:** O mesmo `toast_controller` é registrado para toasts de admin
(`_approval_toast.html.erb`) e de cliente (`_arte_revised_toast.html.erb`). Na página do
cliente, a região tem ID `"client-toast-region"` (definido em `layouts/client.html.erb:19`).
O método `_enforceLimit()` faz:

```javascript
const region = document.getElementById("admin-toast-region")
if (!region) return   // executa sempre em páginas de cliente
```

Em qualquer página do cliente, `getElementById("admin-toast-region")` retorna `null`, a guarda
dispara `return` imediatamente, e `MAX_TOASTS = 3` **nunca é aplicado**. Se o admin marcar
várias artes como revisadas em sequência, o cliente acumula toasts indefinidamente, sem remoção
dos mais antigos, podendo obstruir toda a interface.

**Fix:** Usar o elemento pai do toast em vez do ID hardcoded:

```javascript
_enforceLimit() {
  const region = this.element.parentElement
  if (!region) return
  const toasts = Array.from(region.children)
  if (toasts.length > MAX_TOASTS) {
    toasts[0].remove()
  }
}
```

Isso funciona para ambas as regiões sem depender de nomes de ID específicos.

---

## Warnings

### WR-01: `AdminNotificationsChannel#subscribed` não usa `return reject` — `stream_for` executa mesmo após rejeição

**File:** `app/channels/admin_notifications_channel.rb:3-5`

**Issue:** `ClientCalendarChannel` (arquivo em escopo desta fase) usa corretamente
`return reject unless current_client`. Mas `AdminNotificationsChannel`, que recebe broadcasts de
`Arte#broadcasts_revised_to_all`, usa o padrão inconsistente:

```ruby
def subscribed
  reject unless current_user    # não interrompe o método
  stream_for current_user       # executa mesmo quando current_user é nil
end
```

Em ActionCable, `reject` apenas seta um flag interno e não levanta exceção. Quando
`current_user` é `nil`, `stream_for(nil)` é chamado, gerando um stream parasita com nome
mal-formado. Conexões rejeitadas ficam subscritas nesse stream, consumindo recursos
desnecessariamente. O AdminNotificationsChannel está fora do escopo formal de arquivos desta
fase, mas o bug introduz risco de comportamento inesperado nos broadcasts de `Arte`.

**Fix:**
```ruby
def subscribed
  return reject unless current_user
  stream_for current_user
end
```

---

### WR-02: Teste de broadcast depende implicitamente da fixture de `User` para `User.order(:id).first`

**File:** `test/models/arte_test.rb:41-66`

**Issue:** O teste `"revised! dispara broadcast..."` stuba `ClientCalendarChannel.broadcast_to`
e `AdminNotificationsChannel.broadcast_to`, mas não stuba `User.order(:id).first`. O callback
`broadcasts_revised_to_all` faz `admin = User.order(:id).first` e retorna cedo se `admin` for
`nil`. O teste depende silenciosamente que `fixtures :all` carregue `users.yml` para que haja
ao menos um `User` no banco de teste, sem expressar isso explicitamente no setup.

Se os fixtures de `User` forem removidos, o teste falha em `assert_equal 1, admin_calls.length`
com uma mensagem enganosa, e a causa (ausência de admin) não é óbvia.

**Fix:** Explicitar a dependência:
```ruby
test "revised! dispara broadcast para ClientCalendarChannel e AdminNotificationsChannel" do
  assert User.exists?, "Este teste requer ao menos um User (fixture users.yml)"
  # ...
end
```

Ou isolar completamente via stub:
```ruby
fake_admin = users(:one)
User.stub(:order, ->(*) { User.where(id: fake_admin.id) }) do
  # ...
end
```

---

## Info

### IN-01: Sem teste para o cenário "sem admin" em `broadcasts_revised_to_all`

**File:** `test/models/arte_test.rb`

**Issue:** A linha `return unless admin` em `arte.rb:39` é um guard silencioso: quando não há
nenhum `User` no banco, o broadcast do cliente (`ClientCalendarChannel`) também não ocorre,
pois o método retorna antes de construir qualquer stream. Não há teste verificando esse
comportamento. Se no futuro a lógica for reorganizada (ex.: separar o broadcast do cliente do
broadcast do admin), esse guard pode suprimir erroneamente o broadcast do cliente.

**Fix:** Adicionar um teste explícito:
```ruby
test "revised! nao dispara broadcast ao cliente quando nao ha admin" do
  # Stuba User.order para retornar relacao vazia
  User.stub(:order, ->(*) { User.none }) do
    client_calls = []
    ClientCalendarChannel.stub(:broadcast_to, ->(c, _) { client_calls << c }) do
      arte.revised!
    end
    assert_empty client_calls, "Sem admin, cliente tambem nao recebe broadcast (comportamento atual)"
  end
end
```

Isso documenta o comportamento atual e garante que futuras refatorações o mantenham ou o
alterem conscientemente.

---

### IN-02: `badge_count` conta artes de todos os clientes sem documentação da intenção

**File:** `app/models/arte.rb:41`

**Issue:** `badge_count = Arte.change_requested.count` conta artes de **todos** os clientes,
não apenas do cliente da arte revisada. Isso é provavelmente intencional (o badge admin mostra
o total global de artes aguardando revisão), mas não está documentado. Futuros mantenedores
podem assumir que o scope é por cliente e introduzir um filtro incorreto.

**Fix:** Adicionar comentário inline:
```ruby
# Contagem global (todos os clientes) — badge admin mostra pendências totais, não por cliente
badge_count = Arte.change_requested.count
```

---

_Reviewed: 2026-06-06_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
