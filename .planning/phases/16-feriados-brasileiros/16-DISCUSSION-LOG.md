# Phase 16: Feriados Brasileiros - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-04
**Phase:** 16-feriados-brasileiros
**Areas discussed:** Onde fica a lista, Visual nas células, Escopo da lista

---

## Onde fica a lista

| Option | Description | Selected |
|--------|-------------|----------|
| Module Ruby puro | app/lib/brazilian_holidays.rb — módulo com constante e método holidays_for(year). Fácil de testar, sem banco, sem gem extra. | ✓ |
| ApplicationHelper | Método direto no helper existente, junto com client_color. Mais simples, mas mistura responsabilidades. | |
| Initializer / constante global | config/initializers/holidays.rb — constante acessível em todo o app. Bom para dados estáticos puros. | |

**User's choice:** Module Ruby puro
**Notes:** Sem gem extra, sem banco.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Hardcoded por ano | Hash `{ 2026 => [...dates...], 2027 => [...] }` no módulo. Simples, previsível, sem algoritmo. Deve incluir 2025, 2026 e 2027. | ✓ |
| Algoritmo (só Páscoa) | Calcular Páscoa com algoritmo de Butcher (poucas linhas de Ruby), derivar Carnaval e Corpus automaticamente. Sem gem extra. | |
| Gem holidays | Gem específica para feriados por país. Mais abrangente mas adiciona dependência e configuração extra. | |

**User's choice:** Hardcoded por ano
**Notes:** Feriados móveis hardcoded por ano para 2025, 2026 e 2027.

---

## Visual nas células

| Option | Description | Selected |
|--------|-------------|----------|
| Texto abaixo do número do dia | Ex: «Tiradentes» em texto pequeno logo abaixo do número. Fácil de ler sem ocupar espaço extra. Funciona em ambos os calendários. | ✓ |
| Badge colorido topo da célula | Pill/badge com o nome do feriado acima das artes. Mais visível, consome mais espaço vertical. | |
| Fundo da célula destacado + texto | Toda a célula recebe fundo amarelo/laranja suave. Número do dia e nome do feriado aparecem normalmente. Mais chamativo. | |

**User's choice:** Texto abaixo do número do dia
**Notes:** Sem alterar fundo da célula.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Vermelho/rosa discreto | Ex: text-red-400 ou text-[#E11D48]. Remete visualmente a feriado (dia vermelho no calendário físico). Não conflita com os chips coloridos por cliente. | ✓ |
| Roxo/índigo neutro | Ex: text-purple-400. Cor que não confunde com status de arte nem com nenhuma cor de cliente. | |
| Você decide | Claude escolhe a cor que melhor harmoniza com o design system existente. | |

**User's choice:** Vermelho/rosa discreto (text-red-400)

---

## Escopo da lista

| Option | Description | Selected |
|--------|-------------|----------|
| Principais do varejo | Feriados nacionais + Dia das Mães, Namorados, Pais, Natal, Carnaval, Páscoa, Black Friday, Dia das Crianças. ~15–20 datas/ano. | ✓ |
| Só os nacionais oficiais | Apenas os 12 feriados nacionais previstos em lei. Sem comemorativos de marketing. | |
| Lista abrangente | Nacionais + comemorativos + datas sazonais (São João, Halloween, Dia do Amigo, etc.). 30+ datas/ano. | |

**User's choice:** Principais do varejo
**Notes:** ~15–20 datas/ano para 2025, 2026 e 2027.

---

## Claude's Discretion

- Nome do helper na view: `brazilian_holiday_for(date)` em ApplicationHelper
- Truncamento do nome com `truncate(name, length: 15)` para não quebrar layout
- Estrutura de testes unitários para o module BrazilianHolidays

## Deferred Ideas

- Feriados estaduais/municipais — fase futura se necessário
- Destaque de fundo de célula (mais chamativo) — possível refinamento visual
- Gerenciamento de feriados via interface admin (CRUD) — complexidade desnecessária agora
- Anos além de 2027 — adicionar quando necessário
