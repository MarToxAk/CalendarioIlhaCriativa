# Phase 3: Art Management - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-25
**Phase:** 3-Art Management
**Areas discussed:** Ponto de entrada das artes, Upload vs link externo, Preview na listagem, Proteção de edição/exclusão

---

## Ponto de entrada das artes

| Option | Description | Selected |
|--------|-------------|----------|
| A partir do show do cliente | /admin/clients/:id com seção Artes + botão Nova arte | |
| Lista global /admin/artes | Rota dedicada com filtro por cliente | |
| As duas | Show do cliente + lista global | ✓ |

**User's choice:** As duas
**Notes:** Lista global usa tabela com filtros (mesma abordagem da lista de clientes). No show do cliente, seção abaixo dos dados de acesso (não tabs, não página separada).

---

## Upload vs link externo

| Option | Description | Selected |
|--------|-------------|----------|
| Radio toggle no formulário | Dois botões, campo do outro some via Stimulus | ✓ |
| Dois campos sempre visíveis | Validação no save | |
| Páginas separadas | Duas rotas distintas | |

**Armazenamento:**

| Option | Selected |
|--------|----------|
| Local (ActiveStorage disk) | ✓ |
| S3 / nuvem | |

**Limite de tamanho:** 50 MB

---

## Preview na listagem

| Option | Description | Selected |
|--------|-------------|----------|
| Thumbnail + informações | Thumbnail 60×60px para uploads, ícone de link para URLs | ✓ |
| Só informações textuais | Tabela limpa sem miniaturas | |
| Cards com preview grande | Grid de cards | |

**Show de arte:**

| Option | Selected |
|--------|----------|
| Preview completo + todos os metadados | ✓ |
| Mesmos dados do formulário sem render | |

---

## Proteção de edição/exclusão

| Option | Description | Selected |
|--------|-------------|----------|
| Permitir editar sempre | Status volta a pending automaticamente | |
| Bloquear edição de artes aprovadas | Controller nega edit/update se status != pending | ✓ |
| Bloquear só campos críticos | Legenda e prazo editáveis, arquivo/plataforma não | |

**Exclusão:**

| Option | Selected |
|--------|----------|
| Permitir sempre com confirmação | |
| Bloquear se há resposta do cliente | ✓ |

---

## Claude's Discretion

- Estrutura interna do Admin::ArtesController
- Mensagem de erro ao bloquear edição/exclusão (copywriting PT-BR)
- Responsividade mobile da tabela de artes
- MIME types aceitos para upload

## Deferred Ideas

None — discussão ficou dentro do escopo da fase.
