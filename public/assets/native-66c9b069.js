// Entry point for the Hotwire Native shell (app/views/layouts/native.html.erb).
//
// Only the native app loads this module, so the regular website keeps working
// with full page loads and no Turbo, while the native app gets instant visits,
// native transitions and the back/forward stack.
import "turbo"

// Turbo swaps the <body> on every visit, so anything bound to elements (rather
// than to document) has to be re-applied after each render.
document.addEventListener("turbo:load", boot)
document.addEventListener("DOMContentLoaded", boot)

function boot() {
  renderNativeLists(document)
  dispatchPageLoad()
}

// Lets the legacy scripts (site.js) re-run their initialisers on every visit
// instead of only on the first document ready.
function dispatchPageLoad() {
  window.dispatchEvent(new CustomEvent("qm:page-load"))
}

// Turns every data table into a native-looking card list: each cell picks up
// its column heading as a label, the first cell becomes the row title and the
// action cell becomes a button row. Rows that contain a link become tappable,
// which is how a list behaves in a real iOS/Android app. Tables without a
// header (or with no links) keep their normal markup, so this can only ever
// improve a screen, never break it.
function renderNativeLists(scope) {
  scope.querySelectorAll("table.table").forEach((table) => {
    if (table.classList.contains("qm-native-cards")) return

    const headings = Array.from(table.querySelectorAll("thead th")).map((th) =>
      th.textContent.replace(/\s+/g, " ").trim()
    )
    if (headings.length === 0) return

    let linked = false

    table.querySelectorAll("tbody tr").forEach((row) => {
      const cells = row.querySelectorAll("td")
      cells.forEach((cell, index) => {
        if (!cell.dataset.label && headings[index]) cell.dataset.label = headings[index]
      })

      const link = row.querySelector("a[href]")
      if (link && cells.length > 1) {
        linked = true
        row.classList.add("qm-row-link")
        row.addEventListener("click", (event) => {
          if (event.target.closest("a, button, form, input, select, textarea, label")) return
          link.click()
        })
      }
    })

    table.classList.add("qm-native-cards")
    if (linked) table.setAttribute("data-qm-tappable", "true")
  })
}
