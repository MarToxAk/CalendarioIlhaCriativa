# UI-SPEC — Fase 1: Fundação de Dados e Segurança
**Sistema:** Ilha Criativa — Plataforma de Aprovação de Conteúdo  
**Empresa:** Bom Custo Ilha Bela  
**Versão:** 1.1  
**Data:** 2026-05-24

---

## 1. Design Tokens

### 1.1 Paleta de Cores

> Distribuição: 60% neutros (#F9FAFB, #FFFFFF, #E5E7EB), 30% verde marca #0F7949 (sidebar, foco, botão admin), 10% coral de ação #EA580C (CTAs cliente, badges de destaque)

```css
/* === MARCA (extraídas da logo Bom Custo) === */
--color-brand-dark:   #0F7949;  /* Verde escuro — autoridade, identidade */
--color-brand-mid:    #14A958;  /* Verde médio — sucesso, aprovado */
--color-brand-yellow: #FAED23;  /* Amarelo logo — destaque pontual */
--color-brand-coral:  #EE3537;  /* Coral logo — alerta, rejeição */

/* === AÇÃO (escolha do usuário) === */
--color-accent:       #EA580C;  /* Coral ação — CTAs, energia, social media */
--color-accent-hover: #C2410C;  /* Coral escuro — hover/pressed */
--color-accent-light: #FFF7ED;  /* Coral claro — fundo de badges, chips */

/* === NEUTROS (60%) === */
--color-bg:           #F9FAFB;  /* Fundo geral — gray-50 */
--color-surface:      #FFFFFF;  /* Cards, painéis, modais */
--color-border:       #E5E7EB;  /* Bordas sutis — gray-200 */
--color-border-focus: #0F7949;  /* Borda de foco — verde marca */

/* === TEXTO === */
--color-text-primary:   #0F172A;  /* Títulos — slate-900 */
--color-text-secondary: #475569;  /* Rótulos, descrições — slate-600 */
--color-text-muted:     #94A3B8;  /* Placeholders, hints — slate-400 */
--color-text-inverse:   #FFFFFF;  /* Texto em fundos escuros */

/* === SEMÂNTICAS === */
--color-success:      #14A958;  /* Aprovado — verde médio logo */
--color-success-bg:   #F0FDF4;  /* Fundo badge aprovado */
--color-warning:      #F59E0B;  /* Atenção — amber-400 (melhor contraste que #FAED23) */
--color-warning-bg:   #FFFBEB;  /* Fundo badge pendente */
--color-error:        #EE3537;  /* Rejeitado, erro — coral logo */
--color-error-bg:     #FEF2F2;  /* Fundo badge rejeitado */

/* === ADMIN SIDEBAR (30%) === */
--color-sidebar-bg:         #0F7949;  /* Verde marca sólido */
--color-sidebar-text:       #FFFFFF;
--color-sidebar-text-muted: rgba(255,255,255,0.65);
--color-sidebar-item-hover: rgba(255,255,255,0.10);
--color-sidebar-item-active:#14A958;  /* Item ativo — verde médio */
--color-sidebar-border:     rgba(255,255,255,0.15);
```

### 1.2 Tipografia

```css
/* === FAMÍLIA === */
--font-sans: 'Inter', 'Helvetica Neue', Arial, sans-serif;
/* Inter via Google Fonts — modern, legível, profissional */

/* === ESCALA (4 tamanhos máximo) === */
--text-xs:   0.75rem;   /* 12px — labels, badges */
--text-sm:   0.875rem;  /* 14px — corpo, inputs, rótulos */
--text-2xl:  1.5rem;    /* 24px — títulos de seção e página */
--text-3xl:  1.875rem;  /* 30px — título de login, display */

/* === PESO (2 pesos máximo) === */
--font-medium:   500;   /* Texto corrente, rótulos, itens de nav */
--font-semibold: 600;   /* Títulos, botões, item ativo, destaques */

/* === ALTURA DE LINHA === */
--leading-tight:  1.25;
--leading-normal: 1.5;
```

### 1.3 Espaçamento

```css
/* Escala padrão 8-point — apenas múltiplos de 4px aprovados */
--space-1:  0.25rem;   /*  4px */
--space-2:  0.5rem;    /*  8px */
--space-4:  1rem;      /* 16px */
--space-6:  1.5rem;    /* 24px */
--space-8:  2rem;      /* 32px */
--space-12: 3rem;      /* 48px */
--space-16: 4rem;      /* 64px */
```

### 1.4 Bordas e Sombras

```css
--radius-sm:  0.25rem;   /* 4px — chips, badges */
--radius-md:  0.5rem;    /* 8px — inputs, cards pequenos */
--radius-lg:  0.75rem;   /* 12px — cards principais */
--radius-xl:  1rem;      /* 16px — modais, painéis */
--radius-full: 9999px;   /* pill — botões de status, avatares */

--shadow-sm:  0 1px 2px 0 rgba(0,0,0,0.05);
--shadow-md:  0 4px 6px -1px rgba(0,0,0,0.10), 0 2px 4px -2px rgba(0,0,0,0.10);
--shadow-lg:  0 10px 15px -3px rgba(0,0,0,0.10), 0 4px 6px -4px rgba(0,0,0,0.10);
--shadow-card: 0 1px 3px 0 rgba(0,0,0,0.08), 0 1px 2px -1px rgba(0,0,0,0.05);
```

### 1.5 Transições

```css
--transition-fast:   150ms ease;
--transition-normal: 200ms ease;
--transition-slow:   300ms ease-in-out;
```

---

## 2. Layout Admin

### 2.1 Estrutura Geral

```
┌─────────────────────────────────────────────────────┐
│  SIDEBAR (240px fixo)    │  MAIN AREA               │
│  bg: #0F7949             │  bg: #F9FAFB             │
│                          │                           │
│  [Logo Ilha Criativa]    │  ┌─ TOPBAR ─────────────┐│
│  ─────────────────────   │  │ Título página  [User] ││
│  Nav item                │  └───────────────────────┘│
│  Nav item ← ativo        │                           │
│  Nav item                │  ┌─ CONTENT ─────────────┐│
│                          │  │                       ││
│  ─────────────────────   │  │   (conteúdo da fase)  ││
│  [Avatar] Admin          │  │                       ││
│  [Sair]                  │  └───────────────────────┘│
└─────────────────────────────────────────────────────┘
```

### 2.2 Sidebar Admin — Especificação

**Dimensões:**
- Largura: 240px (desktop) / 0px colapsada (mobile, drawer)
- Altura: 100vh, position: fixed, left: 0, top: 0
- z-index: 40

**Anatomia:**

```
┌──────────────────────────┐
│  ██ Ilha Criativa        │  ← Logo/nome (py-6, px-4)
│  ─────────────────────── │  ← Divisor rgba(255,255,255,0.15)
│                          │
│  📊 Dashboard            │  ← item inativo
│  ✅ Aprovações     ←     │  ← item ATIVO (bg verde médio #14A958, font-semibold)
│  👥 Clientes             │
│  📅 Calendário           │
│  ⚙️  Configurações       │
│                          │
│  ─────────────────────── │  ← mt-auto, divisor
│  ○ Nome Admin            │  ← avatar circular 32px + nome
│  → Sair                  │  ← ação imediata, sem confirmação
└──────────────────────────┘
```

**Estilos dos itens de navegação:**
- Inativo: `px-4 py-2 rounded-md mx-2 text-white/90 hover:bg-white/10 transition-colors`
- Ativo: `px-4 py-2 rounded-md mx-2 bg-[#14A958] text-white font-semibold`
- Ícone: 20px, opacity 0.8 (inativo) / 1.0 (ativo)
- Fonte: text-sm (14px)

**Logo/nome no topo:**
- Texto "Ilha Criativa" — font-semibold, text-2xl (24px), text-white
- Subtexto "by Bom Custo" — text-xs (12px), text-white/60

**Ação "Sair":**
- Aciona logout imediatamente ao clicar — SEM diálogo de confirmação
- Redireciona para `/admin/login` após invalidar a sessão

### 2.3 Topbar Admin — Especificação

**Dimensões:** height 64px, bg-white, border-bottom 1px #E5E7EB, shadow-sm  
**Posição:** sticky top-0, left: 240px (desktop), z-index: 30

**Anatomia:**
```
┌─────────────────────────────────────────────────────┐
│  ☰ (mobile)  Título da Página        [🔔] [Admin ▾] │
└─────────────────────────────────────────────────────┘
```

- Botão hamburger: visível apenas em mobile (< 768px), `aria-label="Abrir menu de navegação"`, `aria-expanded="false|true"` conforme estado do drawer
- Título: text-2xl (24px), font-semibold, text-slate-900
- Ícone sino: `<button aria-label="Ver notificações">`, 40x40px, rounded-full, hover:bg-gray-100
- Avatar admin: 36px círculo, bg-brand-dark, iniciais em branco

---

## 3. Layout Cliente

### 3.1 Estrutura Geral

```
┌─────────────────────────────────────────────────────┐
│  HEADER (bg-white, shadow-sm)                        │
│  [Logo Ilha Criativa]              [Nome do Cliente] │
├─────────────────────────────────────────────────────┤
│                                                      │
│              CONTENT AREA                            │
│              bg: #F9FAFB                             │
│              max-w-4xl, mx-auto, px-4                │
│                                                      │
└─────────────────────────────────────────────────────┘
```

**Princípio:** Interface limpa, acolhedora. O cliente não é técnico. Zero jargão, zero complexidade visual. Foco total no conteúdo a aprovar.

### 3.2 Header Cliente — Especificação

**Dimensões:** height 64px, bg-white, border-bottom 1px #E5E7EB  
**Posição:** sticky top-0, z-index: 20

**Anatomia:**
```
┌──────────────────────────────────────────────────────┐
│  Ilha Criativa  ·  Bom Custo         Olá, [Cliente] │
└──────────────────────────────────────────────────────┘
```

- Logo texto: "Ilha Criativa" font-semibold text-[#0F7949] + "· Bom Custo" text-slate-400 text-sm (14px)
- Saudação direita: "Olá, João" — text-sm (14px) text-slate-600
- SEM sidebar, SEM navegação complexa — só o essencial

### 3.3 Content Cliente

- `max-w-4xl mx-auto px-4 sm:px-6 py-8`
- Cards com `bg-white rounded-xl shadow-card border border-gray-100`
- Hierarquia visual simples: título do post → imagem/mídia → botões de ação

---

## 4. Componentes da Fase 1

### 4.1 Formulário de Login — Admin

**Contexto:** Rota `/admin/login` — acesso restrito da equipe interna da agência.

**Layout:**
```
┌─────────────────────────────────────────┐  ← min-h-screen bg-gray-50
│                                         │
│    ┌─────────────────────────────────┐  │  ← card: bg-white, rounded-xl,
│    │   ██ Ilha Criativa              │  │     shadow-lg, max-w-md, w-full
│    │      Acesso da equipe           │  │     p-8, mx-auto, my-auto
│    │                                 │  │
│    │   E-mail                        │  │
│    │   ┌───────────────────────────┐ │  │
│    │   │ seu@email.com             │ │  │
│    │   └───────────────────────────┘ │  │
│    │                                 │  │
│    │   Senha                    [👁] │  │
│    │   ┌───────────────────────────┐ │  │
│    │   │ ••••••••••                │ │  │
│    │   └───────────────────────────┘ │  │
│    │                                 │  │
│    │   [  Esqueci minha senha  →  ]  │  │  ← link direita, text-sm (14px)
│    │                                 │  │
│    │   ┌───────────────────────────┐ │  │
│    │   │       Entrar              │ │  │  ← botão primário
│    │   └───────────────────────────┘ │  │
│    └─────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘
```

**Copywriting (PT-BR):**
- Título: "Ilha Criativa"
- Subtítulo: "Acesso da equipe"
- Label e-mail: "E-mail"
- Placeholder e-mail: "seu@agencia.com.br"
- Label senha: "Senha"
- Placeholder senha: "••••••••"
- Link: "Esqueci minha senha"
- Botão: "Entrar"
- Erro genérico: "E-mail ou senha incorretos. Tente novamente."
- Erro campo vazio: "Preencha este campo."

**Estilos dos elementos:**

*Card container:*
```css
background: #FFFFFF;
border-radius: 12px;  /* radius-xl */
box-shadow: var(--shadow-lg);
padding: 32px;        /* space-8 */
max-width: 448px;
width: 100%;
```

*Logotipo/header do card:*
```css
/* Ícone verde quadrado arredondado 48x48 com inicial "IC" */
background: #0F7949;
border-radius: 10px;
color: white;
font-size: 24px;      /* text-2xl — tamanho aprovado mais próximo */
font-weight: 600;     /* font-semibold */
margin-bottom: 16px;  /* space-4 */
```

*Labels:*
```css
font-size: 14px;       /* text-sm */
font-weight: 500;      /* font-medium */
color: #0F172A;        /* text-slate-900 */
margin-bottom: 6px;
```

*Inputs:*
```css
width: 100%;
height: 44px;
padding: 0 8px;        /* space-2 — 12px removido, usando 8px */
border: 1.5px solid #E5E7EB;
border-radius: 8px;    /* radius-md */
font-size: 14px;       /* text-sm */
color: #0F172A;
background: #FFFFFF;
transition: border-color 150ms ease, box-shadow 150ms ease;

/* Focus */
outline: none;
border-color: #0F7949;
box-shadow: 0 0 0 3px rgba(15, 121, 73, 0.12);

/* Error */
border-color: #EE3537;
box-shadow: 0 0 0 3px rgba(238, 53, 55, 0.10);

/* Placeholder */
color: #94A3B8;
```

*Botão primário admin:*
```css
width: 100%;
height: 44px;
background: #0F7949;       /* verde marca */
color: white;
font-size: 14px;           /* text-sm */
font-weight: 600;          /* font-semibold */
border-radius: 8px;
border: none;
cursor: pointer;
transition: background 150ms ease, transform 100ms ease;

/* Hover */
background: #0a5c37;

/* Active */
transform: scale(0.99);

/* Loading */
opacity: 0.75;
cursor: not-allowed;
/* spinner branco centralizado */
```

*Mensagem de erro:*
```css
/* Inline sob o campo com problema */
font-size: 12px;           /* text-xs */
color: #EE3537;
margin-top: 4px;           /* space-1 */
display: flex;
align-items: center;
gap: 4px;                  /* space-1 */
/* ícone: ⚠ 14px */
```

**Estados do formulário:**
1. **Vazio** — campos em branco, botão ativo porém sem hover especial
2. **Preenchendo** — foco visível com ring verde, label não some
3. **Erro de validação** — borda vermelha + mensagem inline
4. **Carregando** — botão mostra spinner, texto "Entrando...", campos desabilitados
5. **Erro de autenticação** — banner vermelho acima do formulário: "E-mail ou senha incorretos."
6. **Sucesso** — redirect automático para /admin/dashboard

**Segurança visual:**
- Botão de mostrar/ocultar senha (ícone olho) no campo de senha
- Após 5 tentativas falhas: "Muitas tentativas. Aguarde 30 segundos."

---

### 4.2 Formulário de Acesso — Cliente (via Link)

**Contexto:** Rota `/aprovacao/[token]` ou `/c/[slug]` — cliente recebe link por WhatsApp/e-mail.

**Filosofia:** O cliente NÃO tem login com senha complexa. Acessa via link mágico (magic link) ou PIN de 6 dígitos enviado por e-mail/WhatsApp. Interface máximo amigável.

**Fluxo primário — PIN por e-mail:**

**Tela 1: Identificação**
```
┌──────────────────────────────────────────────┐  ← bg-white min-h-screen
│  [Header: Ilha Criativa · Bom Custo]         │
├──────────────────────────────────────────────┤
│                                              │
│         ┌──────────────────────────────┐     │
│         │                              │     │  ← card max-w-sm
│         │   Bem-vindo(a)! 👋           │     │
│         │   Para ver seus conteúdos,   │     │
│         │   confirme seu e-mail:       │     │
│         │                              │     │
│         │   ┌──────────────────────┐   │     │
│         │   │ seu@email.com        │   │     │
│         │   └──────────────────────┘   │     │
│         │                              │     │
│         │   ┌──────────────────────┐   │     │
│         │   │   Enviar código →    │   │     │  ← coral #EA580C
│         │   └──────────────────────┘   │     │
│         │                              │     │
│         │   Você receberá um código    │     │
│         │   de 6 dígitos por e-mail.   │     │
│         └──────────────────────────────┘     │
└──────────────────────────────────────────────┘
```

**Tela 2: Inserir PIN**
```
│         ┌──────────────────────────────┐     │
│         │                              │     │
│         │   Código enviado! ✉️         │     │
│         │   Verifique seu@email.com    │     │
│         │                              │     │
│         │   [_][_][_]  [_][_][_]       │     │  ← 6 inputs PIN
│         │                              │     │
│         │   ┌──────────────────────┐   │     │
│         │   │    Confirmar acesso  │   │     │  ← coral
│         │   └──────────────────────┘   │     │
│         │                              │     │
│         │   Não recebeu? [Reenviar]    │     │  ← link após 60s
│         │   (disponível em 00:45)      │     │
│         └──────────────────────────────┘     │
```

**Copywriting (PT-BR) — tom acolhedor:**
- Tela 1 título: "Bem-vindo(a)!"
- Tela 1 corpo: "Para ver os conteúdos preparados para você, confirme seu e-mail abaixo."
- Label: "Seu e-mail"
- Placeholder: "nome@empresa.com.br"
- Botão tela 1: "Enviar código de acesso"
- Dica: "Você receberá um código de 6 dígitos. Verifique também a caixa de spam."
- Tela 2 título: "Código enviado!"
- Tela 2 corpo: "Enviamos um código para **{email}**. Digite abaixo para acessar."
- Label PIN: "Código de 6 dígitos"
- Botão tela 2: "Confirmar acesso"
- Reenvio: "Não recebeu o código? Reenviar" (ativo após 60s)
- Timer: "Reenviar disponível em 00:{ss}"
- Erro PIN: "Código incorreto. Verifique e tente novamente."
- Expirado: "Este código expirou. Solicite um novo."

**Estilos do botão de ação cliente:**
```css
/* Botão coral — ação principal do cliente */
background: #EA580C;
color: white;
font-weight: 600;      /* font-semibold */
border-radius: 8px;
height: 44px;
width: 100%;
transition: background 150ms ease;

/* Hover */
background: #C2410C;
```

**Inputs PIN (6 dígitos):**
```css
/* 6 inputs individuais de 44x52px */
width: 44px;
height: 52px;
border: 2px solid #E5E7EB;
border-radius: 8px;
font-size: 24px;       /* text-2xl */
font-weight: 600;      /* font-semibold */
text-align: center;
color: #0F172A;

/* Focus */
border-color: #EA580C;  /* coral — contexto cliente */
box-shadow: 0 0 0 3px rgba(234, 88, 12, 0.12);

/* Preenchido */
border-color: #0F7949;
background: #F0FDF4;

/* Erro */
border-color: #EE3537;
animation: shake 400ms ease;
```

**Agrupamento PIN:**
- 3 inputs + espaço/hífen visual + 3 inputs
- Auto-avança ao digitar um dígito
- Auto-retrocede ao pressionar Backspace com campo vazio
- Suporte a paste do código completo

---

## 5. Componentes Base Compartilhados

### 5.1 Botões

| Variante | Background | Texto | Uso |
|---|---|---|---|
| Primary Admin | `#0F7949` | branco | Ações principais admin |
| Primary Cliente | `#EA580C` | branco | Ações principais cliente |
| Secondary | `#FFFFFF` border `#E5E7EB` | `#0F172A` | Ações secundárias |
| Danger | `#EE3537` | branco | Rejeitar, excluir |
| Ghost | transparente | `#0F7949` | Terciárias, links |

**Tamanhos:**
- sm: `h-8 px-3 text-xs (12px) rounded-md`
- md: `h-10 px-4 text-sm (14px) rounded-lg` (padrão)
- lg: `h-11 px-6 text-sm (14px) rounded-lg`
- full: `h-11 w-full text-sm (14px) rounded-lg`

### 5.2 Badges de Status

```
Aprovado:  bg-[#F0FDF4] text-[#14A958] border-[#14A958]/20  → "Aprovado"
Pendente:  bg-amber-50   text-amber-700  border-amber-200   → "Aguardando"
Rejeitado: bg-[#FEF2F2] text-[#EE3537] border-[#EE3537]/20 → "Alteração solicitada"
Rascunho:  bg-gray-100   text-gray-600  border-gray-200     → "Rascunho"
```

Estilo base:
```css
display: inline-flex;
align-items: center;
gap: 4px;              /* space-1 */
padding: 4px 8px;      /* space-1 / space-2 */
border-radius: 9999px;  /* pill */
font-size: 12px;       /* text-xs */
font-weight: 500;      /* font-medium */
border: 1px solid;
```

### 5.3 Cards

```css
/* Card padrão */
background: #FFFFFF;
border: 1px solid #E5E7EB;
border-radius: 12px;
box-shadow: 0 1px 3px 0 rgba(0,0,0,0.08);
padding: 24px;         /* space-6 */

/* Card hover (clicável) */
transition: box-shadow 150ms ease, transform 150ms ease;
cursor: pointer;
/* hover: */
box-shadow: 0 4px 12px 0 rgba(0,0,0,0.10);
transform: translateY(-1px);
```

### 5.4 Mensagens de Feedback

**Toast (notificação temporária):**
- Posição: bottom-right, 16px (space-4) da borda
- Duração: 4s (sucesso), 6s (erro), manual (atenção)
- `rounded-lg shadow-lg px-4 py-3 flex items-center gap-3 text-sm font-medium`

**Banner inline:**
- Aparece acima do formulário, abaixo do título
- `rounded-lg px-4 py-3 border` com cores semânticas

---

## 6. Acessibilidade

### 6.1 Requisitos WCAG 2.1 AA

**Contraste de cores:**
| Elemento | Foreground | Background | Ratio | Status |
|---|---|---|---|---|
| Texto body | #0F172A | #FFFFFF | 19.2:1 | AA ✓ |
| Texto secundário | #475569 | #FFFFFF | 7.4:1 | AA ✓ |
| Botão admin | #FFFFFF | #0F7949 | 5.9:1 | AA ✓ |
| Botão cliente | #FFFFFF | #EA580C | 3.2:1 | AA* |
| Sidebar nav | #FFFFFF | #0F7949 | 5.9:1 | AA ✓ |
| Badge aprovado | #14A958 | #F0FDF4 | 3.1:1 | AA* |

*Nota: Botão coral e badge aprovado atendem AA para texto grande (≥18px bold ou ≥24px). Para texto menor, verificar no contexto real. Considerar #D25000 como fallback do coral se necessário.

**Foco visível:**
```css
/* Nunca remover outline — customizar com ring verde */
:focus-visible {
  outline: none;
  box-shadow: 0 0 0 3px rgba(15, 121, 73, 0.30);
  /* Em contexto cliente, usar coral: rgba(234, 88, 12, 0.30) */
}
```

### 6.2 Marcação Semântica

**Formulário de login admin:**
```html
<main aria-label="Acesso da equipe">
  <form aria-label="Formulário de login">
    <label for="email">E-mail</label>
    <input
      id="email"
      type="email"
      autocomplete="username"
      aria-required="true"
      aria-describedby="email-error"
    />
    <span id="email-error" role="alert" aria-live="polite"></span>

    <label for="senha">Senha</label>
    <input
      id="senha"
      type="password"
      autocomplete="current-password"
      aria-required="true"
      aria-describedby="senha-error"
    />
    <button type="button" aria-label="Mostrar senha" aria-pressed="false">
      <!-- ícone olho -->
    </button>

    <button type="submit" aria-busy="false">Entrar</button>
  </form>
</main>
```

**Topbar — botões de ícone:**
```html
<!-- Hamburger (mobile) -->
<button
  aria-label="Abrir menu de navegação"
  aria-expanded="false"
  aria-controls="sidebar-drawer"
>
  <!-- ícone ☰ -->
</button>

<!-- Notificações -->
<button aria-label="Ver notificações">
  <!-- ícone sino -->
</button>
```

**Inputs PIN:**
```html
<fieldset>
  <legend>Código de 6 dígitos</legend>
  <input aria-label="Dígito 1 de 6" maxlength="1" inputmode="numeric" />
  <!-- ... -->
</fieldset>
```

### 6.3 Comportamentos Acessíveis

- **Navegação por teclado:** Tab entre todos os campos e botões, Enter submete formulário
- **Screen readers:** `aria-live="polite"` para erros inline; `aria-busy="true"` durante loading
- **Autocomplete:** `autocomplete="username"` e `autocomplete="current-password"` no login admin
- **Idioma:** `<html lang="pt-BR">`
- **Texto alternativo:** Logo com `alt="Ilha Criativa"`
- **Movimento reduzido:** `@media (prefers-reduced-motion: reduce)` remove animações e transições

---

## 7. Responsividade

### 7.1 Breakpoints

```css
/* Mobile first */
--bp-sm:  640px;   /* sm: */
--bp-md:  768px;   /* md: */
--bp-lg:  1024px;  /* lg: */
--bp-xl:  1280px;  /* xl: */
```

### 7.2 Layout Admin — Breakpoints

**Mobile (< 768px):**
- Sidebar: oculta, abre como drawer via botão hamburger
- Drawer: slide-in da esquerda, overlay escuro `bg-black/50`
- Topbar: full-width, mostra botão hamburger à esquerda com `aria-label="Abrir menu de navegação"`
- Content: full-width com padding `px-4` (16px)

**Tablet (768px–1023px):**
- Sidebar: colapsada (64px de largura) — só ícones, sem texto
- Hover no ícone: tooltip com nome do item
- Content: ajusta margem-left para 64px

**Desktop (≥ 1024px):**
- Sidebar: expandida 240px, texto visível
- Content: margin-left 240px
- Topbar: left 240px, width calc(100% - 240px)

### 7.3 Layout Cliente — Breakpoints

**Mobile (< 640px):**
- Header: logo centralizado, saudação oculta
- Content: `px-4 py-6`
- Botões: full-width
- PIN inputs: `42x48px` (levemente menor)
- Cards: sem borda arredondada extrema, `rounded-lg`

**Tablet+ (≥ 640px):**
- Header: logo esquerda, saudação direita
- Content: `px-6 py-8`, max-w-4xl centralizado
- Card formulário: max-w-sm, centralizado com `mx-auto`

### 7.4 Formulários — Comportamento Mobile

**Login Admin:**
- Card: `mx-4` no mobile, `mx-auto max-w-md` no tablet+
- Inputs: `height: 48px` no mobile (área de toque maior)
- Botão: sempre full-width

**PIN Cliente:**
- 6 inputs: `gap-2` (8px) no mobile, `gap-4` (16px) no tablet
- Inputs: `40x48px` no mobile
- Legenda clara acima do fieldset

---

## 8. Animações e Micro-interações

**Princípio:** Discretas, propositais, acessíveis.

```css
/* Aparecer formulário */
@keyframes fadeInUp {
  from { opacity: 0; transform: translateY(8px); }
  to   { opacity: 1; transform: translateY(0); }
}
.form-card { animation: fadeInUp 250ms ease; }

/* PIN incorreto — shake */
@keyframes shake {
  0%, 100% { transform: translateX(0); }
  20%       { transform: translateX(-6px); }
  40%       { transform: translateX(6px); }
  60%       { transform: translateX(-4px); }
  80%       { transform: translateX(4px); }
}

/* Spinner de loading */
@keyframes spin {
  to { transform: rotate(360deg); }
}
.spinner {
  width: 18px;
  height: 18px;
  border: 2px solid rgba(255,255,255,0.3);
  border-top-color: white;
  border-radius: 50%;
  animation: spin 600ms linear infinite;
}
```

**Regra acessibilidade:**
```css
@media (prefers-reduced-motion: reduce) {
  * { animation-duration: 0.01ms !important; transition-duration: 0.01ms !important; }
}
```

---

## 9. Checklist de Implementação — Fase 1

### Admin Login
- [ ] Card centralizado bg-white, shadow-lg, max-w-md
- [ ] Ícone/logo "IC" verde 48x48 arredondado, font-size 24px font-semibold
- [ ] Input e-mail com autocomplete="username"
- [ ] Input senha com toggle mostrar/ocultar
- [ ] Botão submit verde #0F7949, full-width, font-semibold
- [ ] Estado loading com spinner
- [ ] Erros inline com aria-live
- [ ] Banner de erro de autenticação
- [ ] Link "Esqueci minha senha" com rota futura
- [ ] Responsivo mobile/desktop

### Cliente — Identificação e PIN
- [ ] Header simples com logo "Ilha Criativa"
- [ ] Tela 1: input e-mail + botão coral "Enviar código de acesso"
- [ ] Tela 2: 6 inputs PIN com agrupamento 3+3
- [ ] Auto-avanço entre inputs ao digitar
- [ ] Suporte a colar código completo
- [ ] Timer de reenvio (60s countdown)
- [ ] Botão reenviar ativo após timer
- [ ] Feedback de erro shake + mensagem
- [ ] Tom de voz acolhedor em todos os textos
- [ ] Responsivo mobile-first

### Componentes Base
- [ ] Design tokens em CSS custom properties ou Tailwind config
- [ ] Escala tipográfica: apenas 4 tamanhos (12, 14, 24, 30px) e 2 pesos (500, 600)
- [ ] Escala de espaçamento: apenas tokens aprovados (4, 8, 16, 24, 32, 48, 64px)
- [ ] Botões nas variantes: admin primary, cliente primary, secondary, danger
- [ ] Badges de status: aprovado, pendente, rejeitado, rascunho
- [ ] Cards com hover state
- [ ] Toasts de feedback
- [ ] Focus rings customizados (verde/coral por contexto)
- [ ] `prefers-reduced-motion` respeitado
- [ ] Hamburger com aria-label="Abrir menu de navegação" e aria-expanded
- [ ] Sino com aria-label="Ver notificações"
- [ ] Ação "Sair" na sidebar sem confirmação — logout imediato

---

*UI-SPEC Fase 1 — Ilha Criativa / Bom Custo — v1.1 — 2026-05-24*
