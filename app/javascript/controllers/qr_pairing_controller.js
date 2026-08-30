import { Controller } from "@hotwired/stimulus"

// Polling do QR Code de pareamento (PAIR-03). Espelha o teardown de
// toast_controller.js (disconnect -> clearInterval, Pitfall 10) — o timer
// NUNCA pode sobreviver a uma navegação Turbo.
//
// O `qr_base64` recebido de refresh_qr JÁ é o data-URI completo
// (data:image/png;base64,...) — NUNCA re-prefixar aqui.
export default class extends Controller {
  static targets = ["image", "regenerate"]
  static values = { url: String }

  INTERVAL_MS = 20000
  MAX_CYCLES = 6

  connect() {
    this.cycles = 0
    this.poll()
    this.timer = setInterval(() => this.poll(), this.INTERVAL_MS)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  async poll() {
    this.cycles += 1

    try {
      const response = await fetch(this.urlValue, { headers: { Accept: "application/json" } })
      const data = await response.json()

      if (data.state === "connected") {
        clearInterval(this.timer)
        Turbo.visit(window.location.href, { action: "replace" })
        return
      }

      if (data.qr_base64) {
        this.imageTarget.src = data.qr_base64
      }
    } catch {
      // Falha de rede/fetch: silenciosa, o próximo ciclo tenta de novo.
    }

    if (this.cycles >= this.MAX_CYCLES) {
      clearInterval(this.timer)
      if (this.hasRegenerateTarget) this.regenerateTarget.classList.remove("hidden")
    }
  }
}
