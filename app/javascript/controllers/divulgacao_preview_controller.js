import { Controller } from "@hotwired/stimulus"

// Toggle client-side da prévia da divulgação (DIVU-06). Escopado ao <form>.
// Mostra o único <div data-divulgacao-preview-target="pane"> pré-renderizado
// cujo data-arte-id casa com o valor do <select> de arte e esconde o resto
// (ou o placeholder quando o select está no prompt). connect() roda uma vez
// para o caso pré-selecionado / arte única. SEM rede — nenhuma pré-renderização
// é buscada aqui; só classes .hidden são trocadas.
export default class extends Controller {
  static targets = ["pane", "placeholder"]

  connect() {
    this.show()
  }

  show() {
    const select = this.element.querySelector('select[name="divulgacao[arte_id]"]')
    const value = select ? select.value : ""

    this.paneTargets.forEach((pane) => pane.classList.add("hidden"))
    if (this.hasPlaceholderTarget) this.placeholderTarget.classList.add("hidden")

    if (value) {
      const match = this.paneTargets.find((pane) => pane.dataset.arteId === value)
      if (match) {
        match.classList.remove("hidden")
        return
      }
    }

    if (this.hasPlaceholderTarget) this.placeholderTarget.classList.remove("hidden")
  }
}
