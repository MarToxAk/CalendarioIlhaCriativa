# Phase 4: Client Calendar Portal - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-25
**Phase:** 04-client-calendar-portal
**Areas discussed:** Layout do portal, Estrutura do grid mensal, Preview de arte, Navegação entre meses

---

## Layout do portal

| Opção | Descrição | Selecionada |
|-------|-----------|-------------|
| Sim, layout dedicado | Cria layouts/client.html.erb com header: nome do cliente + logout | ✓ |
| Não, HTML inline por view | Cada view tem seu próprio HTML completo (padrão atual da tela de login) | |

**Escolha do usuário:** Layout dedicado `layouts/client.html.erb`
**Notas:** Equivalente ao que o admin já tem (`layouts/admin.html.erb`). Tela de login migra para usar o novo layout.

---

| Opção | Descrição | Selecionada |
|-------|-----------|-------------|
| Nome do cliente + botão Sair | Header simples com logo, nome do cliente e link Sair | ✓ |
| Apenas logo/brand + Sair | Header mínimo sem nome do cliente | |
| Nome do cliente + mês atual + Sair | Header completo com mês também | |

**Escolha do usuário:** Nome do cliente + botão Sair
**Notas:** —

---

| Opção | Descrição | Selecionada |
|-------|-----------|-------------|
| Sim, migrar para layouts/client.html.erb | Elimina HTML inline duplicado | ✓ |
| Não, manter a tela de login como está | Layout distinto para login vs. app autenticado | |

**Escolha do usuário:** Migrar para o novo layout
**Notas:** —

---

| Opção | Descrição | Selecionada |
|-------|-----------|-------------|
| Fundo branco (bg-white) | Diferencia do admin (bg-gray-50) | ✓ |
| Mesmo fundo cinza do admin (bg-gray-50) | Consistência entre as áreas | |
| Claude decide | — | |

**Escolha do usuário:** bg-white
**Notas:** Consistente com a tela de login atual.

---

## Estrutura do grid mensal

| Opção | Descrição | Selecionada |
|-------|-----------|-------------|
| Grade 7 colunas Seg–Dom | Grid CSS clássico, visual familiar de calendário | ✓ |
| Lista de dias com artes | Feed vertical só com dias que têm conteúdo | |

**Escolha do usuário:** Grade 7 colunas
**Notas:** —

---

| Opção | Descrição | Selecionada |
|-------|-----------|-------------|
| Exibir vazio, só com o número do dia | Grade completa, todos os dias visíveis | |
| Opacidade reduzida nos dias vazios | Dias sem arte ficam esmaecidos | ✓ |

**Escolha do usuário:** Opacidade reduzida
**Notas:** Destaca quais dias têm conteúdo sem ocultar a estrutura do mês.

---

| Opção | Descrição | Selecionada |
|-------|-----------|-------------|
| Empilhadas (todas visíveis na célula) | Todas as artes do dia aparecem, célula cresce | ✓ |
| Primeira arte + contador +N mais | Mostra a primeira e indica quantas há | |

**Escolha do usuário:** Empilhadas
**Notas:** Sem truncamento — cliente vê todas as artes do dia diretamente na grade.

---

| Opção | Descrição | Selecionada |
|-------|-----------|-------------|
| Plataforma (ícone) + status (badge colorido) | Bloco compacto com ícone SVG + badge | ✓ |
| Thumbnail da imagem + plataforma | Preview visual pequeno | |

**Escolha do usuário:** Plataforma + status
**Notas:** Evita necessidade de ActiveStorage variant/resize; funciona para todos os tipos (image/video/caption_only).

---

## Preview de arte

| Opção | Descrição | Selecionada |
|-------|-----------|-------------|
| Página separada /c/:token/artes/:id | Nova rota e view, URL compartilhável | ✓ |
| Modal Stimulus in-page | Abre in-page sem mudar URL | |

**Escolha do usuário:** Página separada
**Notas:** Novo `Client::ArtesController#show`. URL compartilhável, botão Voltar do browser funciona naturalmente.

---

| Opção | Descrição | Selecionada |
|-------|-----------|-------------|
| Renderização por tipo (img/video/legenda) | Nativo do browser, sem deps externas | ✓ |
| Sempre link externo + thumbnail | Tratar uploads e links da mesma forma | |

**Escolha do usuário:** Renderização por tipo
**Notas:** image → `<img>`; video → `<video controls>`; caption_only → texto; external_url → botão "Abrir arquivo".

---

| Opção | Descrição | Selecionada |
|-------|-----------|-------------|
| Todos os metadados relevantes | Plataforma + data agendada + prazo + status + legenda | ✓ |
| Apenas prazo + status + legenda | Versão minimalista | |

**Escolha do usuário:** Todos os metadados relevantes
**Notas:** —

---

| Opção | Descrição | Selecionada |
|-------|-----------|-------------|
| Botão "Abrir arquivo" em nova aba | target="_blank" rel="noopener" | ✓ |
| Tentar embed em iframe com fallback | Mais integrado mas instável | |

**Escolha do usuário:** Botão "Abrir arquivo"
**Notas:** iframes do Drive/Dropbox bloqueados em contextos privados — botão é a abordagem segura.

---

## Navegação entre meses

| Opção | Descrição | Selecionada |
|-------|-----------|-------------|
| Parâmetro URL ?month=YYYY-MM | Funciona sem JS, permite bookmark | ✓ |
| Turbo Frame | Troca conteúdo sem recarregar, mais fluido | |

**Escolha do usuário:** Parâmetro URL
**Notas:** —

---

| Opção | Descrição | Selecionada |
|-------|-----------|-------------|
| Mês corrente | Date.today.beginning_of_month | ✓ |
| Mês com mais artes pendentes | Mais inteligente, mais complexo | |

**Escolha do usuário:** Mês corrente
**Notas:** —

---

| Opção | Descrição | Selecionada |
|-------|-----------|-------------|
| Sem limite, cliente navega livremente | Simples, sem risco de segurança extra | ✓ |
| Limitar a ±6 meses do mês atual | Validação extra no controller | |

**Escolha do usuário:** Sem limite
**Notas:** Queries já escopadas por @client — não há risco de cross-client.

---

| Opção | Descrição | Selecionada |
|-------|-----------|-------------|
| < Maio 2026 > no centro, botões laterais | Padrão clássico de calendário | ✓ |
| Título à esquerda + botões à direita | Mais alinhado com layout do admin | |

**Escolha do usuário:** Navegador centralizado `< Maio 2026 >`
**Notas:** —

---

## Claude's Discretion

- Estrutura interna do `Client::ArtesController` (before_action, escopo de segurança)
- Copywriting PT-BR dos estados e labels no portal
- Responsividade mobile da grade
- Estilo exato dos blocos de arte na grade (padding, border-radius, truncamento)
- Número de linhas de semana (5 ou 6 dependendo do mês)

## Deferred Ideas

- Aprovação e pedido de alteração — Fase 5
- Resumo de status no topo do calendário — v2 (CAL2-01)
- Notificações — Out of scope v1
