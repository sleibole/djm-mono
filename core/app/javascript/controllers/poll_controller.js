import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    interval: { type: Number, default: 10000 },
    src: String
  }

  connect() {
    this.timer = setInterval(() => {
      const frame = this.element.tagName === "TURBO-FRAME" ? this.element : this.element.closest("turbo-frame")
      if (frame && this.hasSrcValue) {
        frame.src = this.srcValue
      }
    }, this.intervalValue)
  }

  disconnect() {
    clearInterval(this.timer)
  }
}
