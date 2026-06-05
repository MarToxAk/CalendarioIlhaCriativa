import { Controller } from "@hotwired/stimulus"

const MAX_TOASTS = 3
const DISMISS_DELAY = 5000

export default class extends Controller {
  connect() {
    this._enforceLimit()
    this._timerId = setTimeout(() => this.dismiss(), DISMISS_DELAY)
  }

  dismiss() {
    clearTimeout(this._timerId)
    this.element.remove()
  }

  disconnect() {
    clearTimeout(this._timerId)
  }

  // Private

  // Removes the oldest toast if the region exceeds MAX_TOASTS.
  // Called on connect so that when Phase 18+ appends a new toast via Turbo Stream,
  // the region stays bounded. Users can also dismiss manually via data-action="toast#dismiss".
  _enforceLimit() {
    const region = document.getElementById("admin-toast-region")
    if (!region) return
    const toasts = Array.from(region.children)
    if (toasts.length > MAX_TOASTS) {
      toasts[0].remove()
    }
  }
}
