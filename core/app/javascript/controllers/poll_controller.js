import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    interval: { type: Number, default: 3000 },
    src: String,
    selector: String
  }

  connect() {
    this.timer = setInterval(() => this.poll(), this.intervalValue)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  async poll() {
    if (this.element.querySelector("dialog[open]")) return

    try {
      const resp = await fetch(this.srcValue, { headers: { "Accept": "text/html" } })
      if (!resp.ok) return
      const html = await resp.text()
      const doc = new DOMParser().parseFromString(html, "text/html")
      const fresh = doc.querySelector(this.selectorValue)
      if (fresh) this.element.innerHTML = fresh.innerHTML
    } catch (e) {
      // silently ignore network errors
    }
  }
}
