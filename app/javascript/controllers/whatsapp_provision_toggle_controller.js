import { Controller } from "@hotwired/stimulus"

// Fase 31 (D-06): toggle "Novo número (QR)" vs "Reutilizar conexão existente"
// no empty-state do painel de WhatsApp do cliente. Controller dedicado (não
// reusa media_type_toggle_controller.js — RESEARCH Pitfall 8, nomes de target
// semanticamente presos a mídia de arte). Comportamento extra em relação ao
// analog: mantém o submit de "Reutilizar" desabilitado enquanto o <select>
// não tiver opção escolhida.
export default class extends Controller {
  static targets = ["newField", "reuseField", "newRadio", "reuseRadio", "newLabel", "reuseLabel", "reuseSelect", "reuseSubmit"]

  connect() {
    this.toggleFields()
  }

  toggleFields() {
    if (this.newRadioTarget.checked) {
      this.newFieldTarget.classList.remove("hidden")
      this.reuseFieldTarget.classList.add("hidden")
    } else if (this.reuseRadioTarget.checked) {
      this.reuseFieldTarget.classList.remove("hidden")
      this.newFieldTarget.classList.add("hidden")
    }
    this.togglePills()
    this.toggleSubmitState()
  }

  togglePills() {
    const activeClasses   = ["border-[#0F7949]", "bg-green-50", "text-[#0F7949]"]
    const inactiveClasses = ["border-gray-200", "text-slate-700"]

    if (this.newRadioTarget.checked) {
      this.newLabelTarget.classList.add(...activeClasses)
      this.newLabelTarget.classList.remove(...inactiveClasses)
      this.reuseLabelTarget.classList.remove(...activeClasses)
      this.reuseLabelTarget.classList.add(...inactiveClasses)
    } else {
      this.reuseLabelTarget.classList.add(...activeClasses)
      this.reuseLabelTarget.classList.remove(...inactiveClasses)
      this.newLabelTarget.classList.remove(...activeClasses)
      this.newLabelTarget.classList.add(...inactiveClasses)
    }
  }

  // Só desabilita quando há select (branch "sem conexões disponíveis" não
  // renderiza reuseSelectTarget, então o target pode nem existir).
  toggleSubmitState() {
    if (!this.hasReuseSubmitTarget) return

    if (!this.hasReuseSelectTarget) {
      this.reuseSubmitTarget.disabled = true
      return
    }

    this.reuseSubmitTarget.disabled = this.reuseSelectTarget.value === ""
  }

  selectNew() {
    this.newRadioTarget.checked = true
    this.toggleFields()
  }

  selectReuse() {
    this.reuseRadioTarget.checked = true
    this.toggleFields()
  }
}
