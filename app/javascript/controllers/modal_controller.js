import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay"]

  connect() {
    this.boundKeydown = (e) => {
      if (e.key === "Escape") this.close()
    }
  }

  open() {
    this.overlayTarget.classList.remove("hidden")

    // Focus the cancel button (data-modal-cancel) for accessibility —
    // prevents accidental confirmation of destructive action
    const cancelBtn = this.overlayTarget.querySelector("[data-modal-cancel]")
    cancelBtn?.focus()

    // Listen for Escape key
    document.addEventListener("keydown", this.boundKeydown)

    // Focus trap: cycle Tab within overlay
    this.overlayTarget.addEventListener("keydown", this.boundFocusTrap)
  }

  close() {
    this.overlayTarget.classList.add("hidden")
    document.removeEventListener("keydown", this.boundKeydown)
    this.overlayTarget.removeEventListener("keydown", this.boundFocusTrap)
  }

  get boundFocusTrap() {
    if (!this._boundFocusTrap) {
      this._boundFocusTrap = (e) => {
        if (e.key !== "Tab") return

        const focusable = Array.from(
          this.overlayTarget.querySelectorAll(
            'a[href], button:not([disabled]), input:not([disabled]), textarea:not([disabled]), select:not([disabled]), [tabindex]:not([tabindex="-1"])'
          )
        ).filter(el => !el.hidden && el.offsetParent !== null)

        if (focusable.length === 0) return

        const first = focusable[0]
        const last = focusable[focusable.length - 1]

        if (e.shiftKey) {
          if (document.activeElement === first) {
            e.preventDefault()
            last.focus()
          }
        } else {
          if (document.activeElement === last) {
            e.preventDefault()
            first.focus()
          }
        }
      }
    }
    return this._boundFocusTrap
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKeydown)
  }
}
