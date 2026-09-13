import { Controller } from "@hotwired/stimulus"

// One judgment picker (correct / wrong / differs) for one rule or criterion in the review form.
// Toggles the "how" textarea's visibility, label text, and required-ness based on the selection —
// see design_handoff_fogbell/README.md's "Your judgment" interaction.
export default class extends Controller {
  static targets = ["radio", "card", "howWrapper", "howLabel", "howInput"]
  static values = {
    wrongLabel: { type: String, default: "How is it wrong?" },
    differsLabel: { type: String, default: "How do auditors apply it differently?" }
  }

  connect() {
    this.update()
  }

  update() {
    const checked = this.radioTargets.find((r) => r.checked)
    const value = checked?.value

    this.cardTargets.forEach((card) => {
      const selected = card.dataset.verdictValue === value
      card.classList.toggle("border-ink", selected)
      card.classList.toggle("bg-window", selected)
      card.classList.toggle("border-rule", !selected)
    })

    if (value === "wrong" || value === "different") {
      this.howWrapperTarget.classList.remove("hidden")
      this.howLabelTarget.textContent = value === "wrong" ? this.wrongLabelValue : this.differsLabelValue
      this.howInputTarget.required = true
    } else {
      this.howWrapperTarget.classList.add("hidden")
      this.howInputTarget.required = false
    }
  }
}
