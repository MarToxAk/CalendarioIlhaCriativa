# Phase 7: Art Upload & Client Scoping Fix - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-02
**Phase:** 7-art-upload-client-scoping-fix
**Areas discussed:** Bug de upload, client_id approach, Escopo de set_arte

---

## Bug de upload

| Option | Description | Selected |
|--------|-------------|----------|
| Erro na submissão do form | Form retorna erro ou exceção ao tentar salvar arte com arquivo | |
| Arquivo não é salvo | Arte é criada mas sem arquivo — media_file.attached? retorna false depois | ✓ (first answer) |
| Arquivo salvo mas não exibido | ActiveStorage salva o blob mas a view não consegue renderizar | |
| Não testei ainda | Suspeita de bug pela estrutura do código | |

**User's choice:** "Arquivo não é salvo" (refinado para: "Toda vez que mando o submit da some e não cria a nova arte")

**Follow-up — via qual caminho navega:**

| Option | Description | Selected |
|--------|-------------|----------|
| Pelo botão 'Nova Arte' na página do cliente | Link com ?client_id=X na URL | |
| Direto pela URL /admin/artes/new | Sem client_id na URL | ✓ |
| Não sei | Qualquer caminho deveria funcionar | |

**Diagnóstico:** Bug não é de upload. É o `client_id` nil → `validates :client, presence: true` falha para AMBOS upload e link externo. Arte nunca salva. Form re-exibe provavelmente sem mostrar erros visíveis.

---

## client_id approach

| Option | Description | Selected |
|--------|-------------|----------|
| Selector no form | `<select>` de clientes quando @client é nil | ✓ |
| Nested routes | /admin/clients/:client_id/artes/new | |
| Redirect com flash | Redirecionar para lista de clientes se client_id ausente | |

**User's choice:** Selector no form

**Follow-up — quando @client já existe, mostrar selector?**

| Option | Description | Selected |
|--------|-------------|----------|
| Não — manter hidden field quando @client já existe | Selector só quando sem contexto | ✓ |
| Sim — sempre mostrar selector | Admin pode trocar cliente sempre | |
| Claude decide | Sem preferência | |

**Notes:** Fluxo normal (via page do cliente com ?client_id=X) continua intacto.

---

## Escopo de set_arte

| Option | Description | Selected |
|--------|-------------|----------|
| Sim, mas só quando há contexto de cliente | Verificar @arte.client == @client quando @client presente | |
| Não — sistema single-admin, desnecessário | Manter simples | |
| Sim, sempre — verificar em toda action | Mais seguro | |

**User's choice:** "Sim, mas só quando há contexto de cliente"

**Follow-up — como admin navega para editar uma arte?**

| Option | Description | Selected |
|--------|-------------|----------|
| Sempre pelo dashboard ou cliente | Via links do admin | |
| Direto por /admin/artes/:id | URL direta | |
| Ambos os casos devem funcionar | | ✓ |

**Follow-up — o que set_arte deve fazer?**

| Option | Description | Selected |
|--------|-------------|----------|
| set_arte continua igual + @client = @arte.client | | ✓ |
| Arte.find restrito ao cliente quando client_id vem na URL | | |
| Claude decide | | |

**Notes:** Sistema single-admin — sem restrição de acesso. set_arte expõe @client para contexto de views.

---

## Claude's Discretion

- Estilo visual do `<select>` de clientes (usar padrão `form-input w-full`)
- Label do select (PT-BR: "Cliente" ou "Selecione o cliente")
- Ordenação dos clientes no select (alfabética por nome)

## Deferred Ideas

- Nested routes `/admin/clients/:client_id/artes` — solução mais estrutural, impacto alto, descartada para esta fase
- Relatório PDF/CSV (ADM2-01) — backlog v1.2
- Notificações por e-mail (NOTF-01/02) — backlog v1.2
