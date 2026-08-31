---
status: complete
---

# Legenda no WhatsApp (investigação) + WhatsApp como plataforma da Arte

**Tasks:** 1/1

**Parte 1 — legenda não enviada (investigação, sem mudança de código):**
código revisado ponta a ponta (form → strong params → `SendToGroupJob` →
`Evolution::Client.send_media`) confirma que `caption` é corretamente incluído
no corpo da requisição sempre que `arte.caption` tem valor, batendo com o
contrato documentado em `.planning/research/FEATURES.md:269-273`. Evidência
decisiva: o único envio real já confirmado pela Evolution
(`evolution_message_id` presente, `DivulgacaoGrupo#1`, 2026-08-31 12:56:22)
foi da Arte #4 ("Dia do Feriado"), cujo `caption` está `""` no banco. Usuário
confirmou que esqueceu de preencher o campo "Legenda". Nenhuma mudança de
código nesta parte — comportamento já correto.

**Parte 2 — WhatsApp como plataforma da Arte (implementado):**
adicionado `whatsapp: 3` ao enum `Arte#platform` (antes só instagram/facebook/
linkedin), com ícone SVG próprio (`#25D366`) em `_platform_icon.html.erb` e
rótulo de marca "WhatsApp" em `client/artes/show.html.erb`. As demais telas
que exibem `platform` (`admin/artes/index`, `_arte_row`, `admin/clients/show`,
`admin_calendar_chip`, `_arte_revised_toast`) usam `.humanize`/`.capitalize`
genérico e já funcionam sem alteração para o novo valor. O `<select>` do
formulário admin já é gerado dinamicamente a partir de `Arte.platforms.keys`,
então "whatsapp" aparece automaticamente ali.

O fluxo real de envio (Divulgacao/DivulgacaoGrupo/Evolution) **não foi
alterado** — este pedido era só sobre o campo `platform` da Arte para fins de
categorização/exibição no calendário, não sobre como o WhatsApp de fato
dispara mensagens.

**Verificação:**
- `Arte.platforms` = `{"instagram"=>0, "facebook"=>1, "linkedin"=>2, "whatsapp"=>3}`.
- Partial `_platform_icon.html.erb` renderizada de verdade para `platform: whatsapp` → ícone correto.
- Rótulo simulado do case em `client/artes/show.html.erb` → "WhatsApp" (grafia de marca).
- `bin/rails test test/models/arte_test.rb` e `test/controllers/client/artes_controller_test.rb` rodados — sem regressão nova (1 falha pré-existente e não relacionada, confirmada reproduzindo idêntica com `git stash`).

**Arquivos alterados:**
- `app/models/arte.rb`
- `app/views/client/shared/_platform_icon.html.erb`
- `app/views/client/artes/show.html.erb`

**Commit:** `16f9277`
