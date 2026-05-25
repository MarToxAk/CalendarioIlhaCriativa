import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { value: String }

  execute() {
    const text = this.valueValue
    if (navigator.clipboard) {
      navigator.clipboard.writeText(text).then(() => this.#showCopied())
    } else {
      const label = this.element.querySelector("[data-copy-label]")
      if (label) {
        const original = label.textContent
        label.textContent = "Selecione e copie"
        setTimeout(() => { label.textContent = original }, 3000)
      }
    }
  }

  #showCopied() {
    const label = this.element.querySelector("[data-copy-label]")
    const originalText = label ? label.textContent : null
    const originalIcon = this.element.querySelector("[data-copy-icon]")
    const originalIconHTML = originalIcon ? originalIcon.innerHTML : null

    // Swap to "copied" state
    this.element.classList.remove("text-slate-600", "border-gray-200", "bg-white")
    this.element.classList.add("text-[#14A958]", "border-[#14A958]/30", "bg-[#F0FDF4]")

    if (label) label.textContent = "Copiado!"
    if (originalIcon) {
      originalIcon.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5" aria-hidden="true"><path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" /></svg>`
    }

    setTimeout(() => this.#resetLabel(originalText, originalIconHTML), 2000)
  }

  #resetLabel(originalText, originalIconHTML) {
    this.element.classList.remove("text-[#14A958]", "border-[#14A958]/30", "bg-[#F0FDF4]")
    this.element.classList.add("text-slate-600", "border-gray-200", "bg-white")

    const label = this.element.querySelector("[data-copy-label]")
    const icon = this.element.querySelector("[data-copy-icon]")
    if (label && originalText) label.textContent = originalText
    if (icon && originalIconHTML) icon.innerHTML = originalIconHTML
  }
}
