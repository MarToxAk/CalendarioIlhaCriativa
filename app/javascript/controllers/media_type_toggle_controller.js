import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["uploadField", "linkField", "uploadRadio", "linkRadio", "uploadLabel", "linkLabel"]

  connect() {
    this.toggleFields()
  }

  toggleFields() {
    if (this.uploadRadioTarget.checked) {
      this.uploadFieldTarget.classList.remove("hidden")
      this.linkFieldTarget.classList.add("hidden")
    } else if (this.linkRadioTarget.checked) {
      this.linkFieldTarget.classList.remove("hidden")
      this.uploadFieldTarget.classList.add("hidden")
    }
    this.togglePills()
  }

  togglePills() {
    const activeClasses   = ["border-[#0F7949]", "bg-green-50", "text-[#0F7949]"]
    const inactiveClasses = ["border-gray-200", "text-slate-700"]

    if (this.uploadRadioTarget.checked) {
      this.uploadLabelTarget.classList.add(...activeClasses)
      this.uploadLabelTarget.classList.remove(...inactiveClasses)
      this.linkLabelTarget.classList.remove(...activeClasses)
      this.linkLabelTarget.classList.add(...inactiveClasses)
    } else {
      this.linkLabelTarget.classList.add(...activeClasses)
      this.linkLabelTarget.classList.remove(...inactiveClasses)
      this.uploadLabelTarget.classList.remove(...activeClasses)
      this.uploadLabelTarget.classList.add(...inactiveClasses)
    }
  }

  selectUpload() {
    this.uploadRadioTarget.checked = true
    this.toggleFields()
  }

  selectLink() {
    this.linkRadioTarget.checked = true
    this.toggleFields()
  }
}
