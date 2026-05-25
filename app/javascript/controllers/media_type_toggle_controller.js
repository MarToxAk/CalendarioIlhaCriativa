import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["uploadField", "linkField", "uploadRadio", "linkRadio"]

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
