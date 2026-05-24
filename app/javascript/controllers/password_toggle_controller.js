import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["field", "toggle"]

  toggle() {
    const field = this.fieldTarget
    const button = this.toggleTarget
    const isPassword = field.type === "password"

    field.type = isPassword ? "text" : "password"
    button.setAttribute("aria-pressed", isPassword ? "true" : "false")
    button.setAttribute("aria-label", isPassword ? "Ocultar senha" : "Mostrar senha")
  }
}
