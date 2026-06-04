# Phase 14: Calendário Admin - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-04
**Phase:** 14-Calendário Admin
**Areas discussed:** Cores por cliente, Navegação entre meses, Chip de arte na célula, Overflow de artes por dia

---

## Cores por cliente

| Option | Description | Selected |
|--------|-------------|----------|
| Paleta automática por índice | 6–10 cores pré-definidas; cliente 1 pega cor 0, etc. Sem migration. | ✓ |
| Campo color na tabela clients | Migration para adicionar coluna color (string hex). Admin escolhe manualmente. | |
| Derivado do nome (hash) | Hash do nome mapeia para cor da paleta. Muda a cor se mudar o nome. | |

**User's choice:** Paleta automática por índice
**Notes:** Sem migration necessária. Determinístico por id.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Helper no ApplicationHelper | client_color(client) retorna classes Tailwind. Fácil de usar em qualquer view. | ✓ |
| Constante no model Client | Client::COLORS = [...]; client.color_class. Mais encapsulado. | |

**User's choice:** Helper no ApplicationHelper

---

| Option | Description | Selected |
|--------|-------------|----------|
| Fundo suave + texto escuro | Estilo dos badges existentes. Legibilidade alta, padrão do design system. | ✓ |
| Fundo sólido + texto branco | Mais contraste visual. Ex: bg-[#0F7949] text-white. | |

**User's choice:** Fundo suave + texto escuro

---

## Navegação entre meses

| Option | Description | Selected |
|--------|-------------|----------|
| Turbo Frame | Setas e título ficam fora; turbo-frame envolve a grade. Padrão Phase 6/13. | ✓ |
| Link normal com Turbo Drive | Navegação SPA-like via Turbo Drive. Mais simples de implementar. | |

**User's choice:** Turbo Frame

---

| Option | Description | Selected |
|--------|-------------|----------|
| Cabeçalho da página com título | [← seta] [Mês Ano] [seta →] acima do turbo-frame. Padrão do calendário do cliente. | ✓ |
| Dentro do calendário | Setas nas laterais da grade, estilo widget. | |

**User's choice:** Cabeçalho da página com título

---

## Chip de arte na célula

| Option | Description | Selected |
|--------|-------------|----------|
| Iniciais do cliente (2 chars) | Chip colorido com 'IL', 'MV', etc. Compacto para múltiplas artes por dia. | ✓ |
| Nome do cliente truncado | 'Ilha Li...' — mais informativo, ocupa mais espaço. | |
| Somente a cor (sem texto) | Chip mínimo. Menos informativo sem hover. | |

**User's choice:** Iniciais do cliente (2 chars)

---

| Option | Description | Selected |
|--------|-------------|----------|
| Só iniciais | Chip limpo: cor + iniciais. Sem sobrecarga visual. | ✓ |
| Iniciais + plataforma (icon) | Iniciais + ícone Instagram/Facebook/LinkedIn. | |
| Iniciais + título truncado | Chip com 2 linhas. Mais info mas chip maior. | |

**User's choice:** Só iniciais

---

## Overflow de artes por dia

| Option | Description | Selected |
|--------|-------------|----------|
| Mostrar 3 chips + '+N' | 3 primeiros chips + contador estático em cinza. Célula com altura controlada. | ✓ |
| Mostrar tudo (sem limite) | Célula cresce verticalmente. Dias cheios deformam o grid. | |
| Scroll interno na célula | Altura fixa + overflow-y-auto. Scroll dentro da célula é incomum. | |

**User's choice:** Mostrar 3 chips + '+N'

---

| Option | Description | Selected |
|--------|-------------|----------|
| Nada por enquanto | '+N' é texto estático, não clicável nesta fase. | ✓ |
| Link para listagem filtrada do dia | Clique vai para /admin/artes?date=YYYY-MM-DD. Sai do calendário. | |

**User's choice:** Nada por enquanto

---

## Claude's Discretion

- Nome do controller: `Admin::CalendarController`, rota `resources :calendar, only: [:index]`
- Altura mínima das células: `min-h-[80px]`
- Ordenação dos chips por dia: por `id` (insertion order)

## Deferred Ideas

- Clique no `+N` para expandir (modal) — fase futura
- Admin escolher cor manualmente (campo `color` na tabela) — fase futura
- Chips com ícone de plataforma — fase futura
