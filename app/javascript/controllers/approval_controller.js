import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["commentForm"]

  toggleComment() {
    this.commentFormTarget.classList.toggle("hidden")
  }

  hideComment() {
    this.commentFormTarget.classList.add("hidden")
  }
}
