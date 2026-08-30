import { Controller } from "@hotwired/stimulus"

// Liga o select-all e o contador do _picker.html.erb — marcadores DOM que a
// fase 27 shipou inertes e que ficam vivos aqui (fase 28). Escopado ao wrapper
// do picker dentro do form de Divulgacao. SEM rede.
//
// Qualquer `change` no wrapper chama refresh(). Se veio do checkbox
// [data-picker-select-all], replica o estado para todas as caixas de grupo e
// re-dispara um `change` borbulhante para o divulgacao-estimate recomputar com o
// novo total (o estimate roda ANTES do picker no data-action, então sem esse
// re-dispatch a estimativa ficaria atrasada um evento no select-all). O evento
// sintético tem target = o wrapper (não o select-all), então não re-toggla —
// sem loop.
export default class extends Controller {
  connect() {
    this.refresh()
  }

  refresh(event) {
    const selectAll = this.element.querySelector("[data-picker-select-all]")
    const counter = this.element.querySelector("[data-picker-counter]")
    const boxes = this.groupCheckboxes()

    if (event && selectAll && event.target === selectAll) {
      boxes.forEach((cb) => { cb.checked = selectAll.checked })
      this.element.dispatchEvent(new Event("change", { bubbles: true }))
    }

    const total = boxes.length
    const checked = boxes.filter((cb) => cb.checked).length

    if (counter) counter.textContent = `${checked} de ${total} grupos selecionados`
    if (selectAll && (!event || event.target !== selectAll)) {
      selectAll.checked = total > 0 && checked === total
    }
  }

  groupCheckboxes() {
    return Array.from(
      this.element.querySelectorAll('input[type="checkbox"][name="divulgacao[whatsapp_group_ids][]"]')
    )
  }
}
