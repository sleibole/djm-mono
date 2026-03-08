import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["systemRadio", "lightRadio", "darkRadio"]

  connect() {
    this.updateUI()
  }

  setSystem() {
    localStorage.removeItem("theme")
    document.documentElement.removeAttribute("data-theme")
    this.updateUI()
  }

  setLight() {
    localStorage.setItem("theme", "light")
    document.documentElement.setAttribute("data-theme", "light")
    this.updateUI()
  }

  setDark() {
    localStorage.setItem("theme", "dark")
    document.documentElement.setAttribute("data-theme", "dark")
    this.updateUI()
  }

  updateUI() {
    if (!this.hasSystemRadioTarget) return
    const saved = localStorage.getItem("theme")
    this.systemRadioTarget.checked = !saved
    this.lightRadioTarget.checked = saved === "light"
    this.darkRadioTarget.checked = saved === "dark"
  }
}
