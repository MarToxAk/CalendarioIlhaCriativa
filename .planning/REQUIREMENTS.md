# Requirements — v1.3 Arte UI Polish

## Milestone Goal

Estilizar completamente as páginas de artes do admin usando Tailwind direto, eliminando os placeholders `form-input`/`btn` sem CSS definido e tornando o sistema visualmente consistente.

---

## v1.3 Requirements

### Form de Artes

- [ ] **FORM-01**: Admin vê os campos do form de artes (text, textarea, date, url, file, select) estilizados com classes Tailwind — border, focus ring verde, height uniforme, placeholder visível
- [ ] **FORM-02**: Admin vê os botões do form de artes (Criar/Atualizar e Cancelar) estilizados — verde para submit, neutro para cancelar
- [ ] **FORM-03**: Radio buttons de "Tipo de mídia" têm layout horizontal com gap e labels legíveis

### Páginas new/edit de Artes

- [ ] **PAGE-01**: Página "Nova Arte" envolve o form em card branco com link de voltar (padrão igual ao de clientes)
- [ ] **PAGE-02**: Página "Editar Arte" envolve o form em card branco com link de voltar com nome da arte

### Arte Index

- [ ] **IDX-01**: Tabela de artes tem thead com headers estilizados, td com padding e hover nas rows
- [ ] **IDX-02**: Botão "Nova Arte" e link "Ver" na index têm estilo visível

### Arte Show

- [ ] **SHOW-01**: Botões de ação no show (Editar, Excluir, Marcar Revisada, Voltar) têm estilos visíveis e semânticos (vermelho para excluir)

### Dashboard

- [ ] **DASH-01**: Link "Ver" no painel de respostas tem estilo visível

---

## Future Requirements

- Redesign completo do portal do cliente com componentes de UI refinados (v1.4+)
- Dark mode no painel admin (v2+)

## Out of Scope

- Novos componentes ou funcionalidades — este milestone é styling apenas
- Portal do cliente — já está bem estilizado
- Páginas de sessão/senha — já estão bem estilizadas

---

## Traceability

| REQ-ID  | Phase    | Status      |
|---------|----------|-------------|
| FORM-01 | Phase 10 | Pending     |
| FORM-02 | Phase 10 | Pending     |
| FORM-03 | Phase 10 | Pending     |
| PAGE-01 | Phase 10 | Pending     |
| PAGE-02 | Phase 10 | Pending     |
| IDX-01  | Phase 11 | Pending     |
| IDX-02  | Phase 11 | Pending     |
| SHOW-01 | Phase 12 | Pending     |
| DASH-01 | Phase 12 | Pending     |
