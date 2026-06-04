import { Controller } from "@hotwired/stimulus"

const STATUS_MAP = {
  pending:          { label: "Pendente",        bg: "#FFFBEB", color: "#92400E" },
  approved:         { label: "Aprovada",         bg: "#F0FDF4", color: "#14A958" },
  change_requested: { label: "Alteração pedida", bg: "#FEF2F2", color: "#EE3537" },
  revised:          { label: "Revisada",         bg: "#F9FAFB", color: "#475569" },
}

export default class extends Controller {
  static targets = [
    "tooltip", "ttClient", "ttTitle", "ttMeta", "ttStatus", "ttImg",
    "modal", "mdClient", "mdTitle", "mdDate", "mdPlatform", "mdStatus", "mdLink",
    "mdPreview", "mdImg", "mdVideo", "mdExternal"
  ]

  connect() {
    this._onKeydown = (e) => { if (e.key === "Escape") this.closeModal() }
  }

  disconnect() {
    document.removeEventListener("keydown", this._onKeydown)
  }

  showTooltip(event) {
    const d = this._data(event.currentTarget)
    this.ttClientTarget.textContent = d.client
    this.ttTitleTarget.textContent  = d.title
    this.ttMetaTarget.textContent   = `${d.date} · ${d.platform}`
    this._applyStatus(this.ttStatusTarget, d.status)
    this._showTooltipImg(d.previewSource, d.previewUrl)
    this.tooltipTarget.classList.remove("hidden")
    this._positionTooltip(event.currentTarget)
  }

  hideTooltip() {
    this.tooltipTarget.classList.add("hidden")
  }

  openModal(event) {
    event.preventDefault()
    this.hideTooltip()
    const d = this._data(event.currentTarget)
    this.mdClientTarget.textContent   = d.client
    this.mdTitleTarget.textContent    = d.title
    this.mdDateTarget.textContent     = d.date
    this.mdPlatformTarget.textContent = d.platform
    this._applyStatus(this.mdStatusTarget, d.status)
    this.mdLinkTarget.href = d.url
    this._showModalPreview(d.previewSource, d.previewUrl)
    this.modalTarget.classList.remove("hidden")
    document.addEventListener("keydown", this._onKeydown)
  }

  closeModal() {
    this.mdVideoTarget.pause?.()
    this.modalTarget.classList.add("hidden")
    document.removeEventListener("keydown", this._onKeydown)
  }

  _data(el) {
    const ds = el.dataset
    return {
      client:        ds.arteClient        || "",
      title:         ds.arteTitle         || "Sem título",
      date:          ds.arteDate          || "",
      platform:      ds.artePlatform      || "",
      status:        ds.arteStatus        || "",
      url:           ds.arteUrl           || "#",
      previewSource: ds.artePreviewSource || "none",
      previewUrl:    ds.artePreviewUrl    || "",
    }
  }

  _applyStatus(el, status) {
    const s = STATUS_MAP[status] || { label: status, bg: "#F9FAFB", color: "#475569" }
    el.textContent = s.label
    el.style.backgroundColor = s.bg
    el.style.color = s.color
  }

  _showTooltipImg(source, url) {
    if (source === "image" && url) {
      this.ttImgTarget.src = url
      this.ttImgTarget.classList.remove("hidden")
    } else {
      this.ttImgTarget.src = ""
      this.ttImgTarget.classList.add("hidden")
    }
  }

  _showModalPreview(source, url) {
    this.mdImgTarget.classList.add("hidden")
    this.mdVideoTarget.classList.add("hidden")
    this.mdExternalTarget.classList.add("hidden")

    if (source === "image" && url) {
      this.mdImgTarget.src = url
      this.mdImgTarget.classList.remove("hidden")
      this.mdPreviewTarget.classList.remove("hidden")
    } else if (source === "video" && url) {
      this.mdVideoTarget.src = url
      this.mdVideoTarget.classList.remove("hidden")
      this.mdPreviewTarget.classList.remove("hidden")
    } else if (source === "external" && url) {
      this.mdExternalTarget.href = url
      this.mdExternalTarget.classList.remove("hidden")
      this.mdExternalTarget.style.display = "inline-flex"
      this.mdPreviewTarget.classList.remove("hidden")
    } else {
      this.mdPreviewTarget.classList.add("hidden")
    }
  }

  _positionTooltip(anchor) {
    const rect    = anchor.getBoundingClientRect()
    const tt      = this.tooltipTarget
    const scrollY = window.scrollY
    const scrollX = window.scrollX
    const ttH     = 160

    let top  = rect.bottom + scrollY + 8
    let left = rect.left   + scrollX

    if (rect.bottom + ttH > window.innerHeight) {
      top = rect.top + scrollY - ttH - 8
    }
    const maxLeft = window.innerWidth + scrollX - 220
    if (left > maxLeft) left = maxLeft

    tt.style.top  = `${top}px`
    tt.style.left = `${left}px`
  }
}
