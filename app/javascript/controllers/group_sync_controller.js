import { Controller } from "@hotwired/stimulus"

// Poller de conclusão da sincronização de grupos (GRUPO-01/GRUPO-02, 27-02).
// Modelo: qr_pairing_controller.js (setInterval/disconnect teardown, Turbo.visit
// replace) -- mas sync_status NÃO tem efeito colateral: fetch é um GET puro,
// SEM X-CSRF-Token (o QR poller POSTa porque refresh_qr muta). O timer NUNCA
// sobrevive a uma navegação Turbo (mesmo teardown de toast_controller.js).
//
// NUNCA console.log de subject/remote_jid/payload de grupo (INFRA-04) -- o
// poller só olha para synced_at/error/count, nunca imprime o corpo cru.
export default class extends Controller {
  static targets = [ "error", "timeout", "status" ]
  static values = { statusUrl: String, since: String, active: Boolean }

  INTERVAL_MS = 3000
  MAX_CYCLES = 20

  // Só liga o poller quando há uma sincronização REALMENTE em andamento
  // (activeValue = @instance.groups_sync_syncing? no servidor). Sem esse gate,
  // uma visita normal à página dispararia MAX_CYCLES requests a sync_status e
  // depois mostraria o aviso "a sincronização está demorando" sem sync nenhum
  // rodando (27-UI-REVIEW.md BLOCKER).
  connect() {
    if (!this.activeValue) return

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
      const response = await fetch(this.statusUrlValue, {
        headers: { Accept: "application/json" }
      })
      const data = await response.json()

      if (this._announceStatus("Sincronizando grupos… isso pode levar alguns segundos.")) {
        // aria-live mirror -- sem payload de grupo, só o texto de status fixo.
      }

      if (data.synced_at && this._advancedPastSince(data.synced_at)) {
        clearInterval(this.timer)
        this._announceStatus("Grupos sincronizados.")
        this._toast("Grupos sincronizados.")
        Turbo.visit(window.location.href, { action: "replace" })
        return
      }

      if (data.error) {
        clearInterval(this.timer)
        this._toast("A sincronização de grupos falhou. Veja os detalhes na página de grupos.", "error")
        if (this.hasErrorTarget) this.errorTarget.classList.remove("hidden")
        return
      }
    } catch {
      // Falha de rede/fetch: silenciosa, o próximo ciclo tenta de novo.
    }

    if (this.cycles >= this.MAX_CYCLES) {
      clearInterval(this.timer)
      if (this.hasTimeoutTarget) this.timeoutTarget.classList.remove("hidden")
    }
  }

  // Private

  _advancedPastSince(syncedAt) {
    if (!this.hasSinceValue || this.sinceValue === "") return true

    return new Date(syncedAt) > new Date(this.sinceValue)
  }

  _announceStatus(text) {
    if (!this.hasStatusTarget) return false

    this.statusTarget.textContent = text
    return true
  }

  // Constrói um toast na forma exata de admin/shared/_approval_toast.html.erb
  // (data-controller="toast" reaproveita o auto-dismiss/limite existente),
  // mas via DOM direto -- este poller não tem canal de broadcast (Turbo
  // Stream) como os toasts server-driven do projeto, só o fetch síncrono.
  _toast(message, variant = "success") {
    const region = document.getElementById("admin-toast-region")
    if (!region) return

    const toast = document.createElement("div")
    toast.dataset.controller = "toast"
    toast.className = "bg-white border border-gray-200 shadow-lg rounded-lg px-4 py-3 flex items-start gap-3 w-80"

    const text = document.createElement("p")
    text.className = variant === "error"
      ? "text-sm font-medium text-[#EE3537] flex-1"
      : "text-sm font-medium text-slate-900 flex-1"
    text.textContent = message
    toast.appendChild(text)

    const dismiss = document.createElement("button")
    dismiss.dataset.action = "click->toast#dismiss"
    dismiss.className = "text-slate-400 hover:text-slate-600 shrink-0 leading-none"
    dismiss.setAttribute("aria-label", "Fechar notificação")
    dismiss.textContent = "×"
    toast.appendChild(dismiss)

    region.appendChild(toast)
  }
}
