import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  toggle() {
    this.menuTarget.classList.toggle("hidden")
    const expanded = !this.menuTarget.classList.contains("hidden")
    this.element.querySelector("[aria-expanded]").setAttribute("aria-expanded", expanded)
  }

  // Close on outside click
  hide(event) {
    if (!this.element.contains(event.target)) {
      this.menuTarget.classList.add("hidden")
      this.element.querySelector("[aria-expanded]")?.setAttribute("aria-expanded", false)
    }
  }

  connect() {
    this.outsideClickHandler = this.hide.bind(this)
    document.addEventListener("click", this.outsideClickHandler)
  }

  disconnect() {
    document.removeEventListener("click", this.outsideClickHandler)
  }
}
