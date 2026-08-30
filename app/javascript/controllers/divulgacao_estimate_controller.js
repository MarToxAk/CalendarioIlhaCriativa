import { Controller } from "@hotwired/stimulus"

// Recomputa a estimativa de duração do disparo (DIVU-07) na seleção de grupos.
// Escopado ao <form>. min/max vêm de data-divulgacao-estimate-min-value /
// -max-value (injetados pelo servidor a partir de Divulgacao::SEND_DELAY_MIN /
// SEND_DELAY_MAX). Espelha exatamente o helper server-side
// divulgacao_duration_estimate, que é a fonte da verdade e o fallback sem-JS.
// SEM rede — só aritmética.
export default class extends Controller {
  static targets = ["text"]
  static values = { min: Number, max: Number }

  connect() {
    this.recompute()
  }

  recompute() {
    const n = this.element.querySelectorAll(
      'input[type="checkbox"][name="divulgacao[whatsapp_group_ids][]"]:checked'
    ).length

    if (!this.hasTextTarget) return

    if (n === 0) {
      this.textTarget.textContent = "—"
      return
    }

    const lo = Math.ceil((n * this.minValue) / 60)
    const hi = Math.ceil((n * this.maxValue) / 60)
    this.textTarget.textContent =
      lo === hi ? `≈ ${lo} min para ${n} grupos` : `≈ ${lo}–${hi} min para ${n} grupos`
  }
}
