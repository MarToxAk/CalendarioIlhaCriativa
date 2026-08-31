# Phase 31: Instância WhatsApp Compartilhada entre Clientes - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-31
**Phase:** 31-Instância WhatsApp Compartilhada entre Clientes
**Areas discussed:** Caso de uso e escopo, Modelo de dados / trava de concorrência, Sincronização de grupos, Fluxo de UI

---

## Caso de uso e escopo real

Usuário descreveu diretamente, sem menu estruturado (após rejeitar duas tentativas de
AskUserQuestion): "Vai ser um numero de whatsapp de markting para mais de um cliente.
Seleciona os grupos na hora que nem faz hoje. mais gostaria da opção de conectar uma
conta ainda."

**Decisão:** número de marketing da agência, reutilizado por múltiplos clientes;
seleção de grupos permanece idêntica ao fluxo atual (GRUPO-03); fluxo de pareamento
via QR (PAIR-01/02) continua disponível ao lado da opção nova.
**Notas:** confirma que não há necessidade de uma etapa de "atribuir grupo a cliente" —
o admin já escolhe grupos manualmente por Divulgação hoje, e isso é suficiente mesmo
com pool compartilhado.

---

## Modelo de dados / trava de concorrência

| Opção | Descrição | Selecionada |
|--------|-------------|----------|
| Trocar chave do `limits_concurrency` de `whatsapp_instance.id` para `instance_name` | Mantém `Client has_one :whatsapp_instance`, menor blast radius, serializa por conexão física | ✓ |
| Consolidar numa única linha `WhatsappInstance` compartilhada (N-para-N) | Resolve o problema "de graça" mas exige redesenhar a relação usada em 32 arquivos + testes SEG-02/03/04 | |

**User's choice:** "Oque achar melhor" (delegado a Claude).
**Notes:** Claude escolheu a opção 1 pelo menor blast radius e por preservar
integralmente os testes de isolamento cross-client (SEG-04) sem alteração.

---

## Sincronização de grupos (decorre da anterior)

Decisão técnica de Claude (não apresentada como pergunta separada ao usuário, decorre
diretamente de manter `has_one` + instância física compartilhada): `GroupSynchronizer`
passa a sincronizar todas as instâncias-irmãs (mesmo `instance_name`) numa única
chamada Evolution, evitando repetir a mesma leitura lenta (~40s, confirmada
empiricamente nesta sessão) uma vez por cliente compartilhando o número.

---

## Fluxo de UI

Decisão direta do usuário ("gostaria da opção de conectar uma conta ainda" = manter o
fluxo QR existente) + decisão de design de Claude para a forma da nova opção: toggle
"Novo número (QR)" vs "Reutilizar conexão existente" na seção WhatsApp de
`admin/clients#show`, reaproveitando o padrão visual do toggle `media_source` já usado
em `admin/artes/_form.html.erb`.

---

## Claude's Discretion

- Nome do Stimulus controller do novo toggle.
- Texto pt-BR exato do aviso "isto é uma conexão compartilhada".
- Exigir `turbo_confirm` ao escolher reutilizar.
- Coluna auxiliar (`shared: boolean`?) vs inferir compartilhamento por `instance_name`
  duplicado entre linhas.
- Badge visual "compartilhada com N clientes" no admin.

## Deferred Ideas

- Revogação/rotação de token por cliente individual dentro de uma instância
  compartilhada.
- Badge/indicador visual de compartilhamento na listagem de clientes.
- Consolidação futura para modelo N-para-N de verdade, se a duplicação de token entre
  linhas-irmãs se provar dolorosa operacionalmente.
