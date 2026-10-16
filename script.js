const toastTrigger = document.getElementById('liveToastBtn')
const toastLiveExample = document.getElementById('liveToast')

if (toastTrigger) {
  const toastBootstrap = bootstrap.Toast.getOrCreateInstance(toastLiveExample)
  toastTrigger.addEventListener('click', () => {
    toastBootstrap.show()
  })
}

const tooltipTriggerList = document.querySelectorAll('[data-bs-toggle="tooltip"]')
const tooltipList = [...tooltipTriggerList].map(tooltipTriggerEl => new bootstrap.Tooltip(tooltipTriggerEl))

var togglerElementList = Array.prototype.slice.call(document.querySelectorAll('[data-bs-toggle="toggler"]'))
var togglerList = togglerElementList.map(function (togglerEl) {
  return new bootstrap.Toggler(togglerEl)
})

var myToggler = document.getElementById('myToggler')
var bsToggler = new bootstrap.Toggler(myToggler)

const accordion = document.getElementById('accordionExpandCollapse')
const toggleBtn = document.getElementById('btnAccordionToggleAll')

if (accordion && toggleBtn) {
  const items = accordion.querySelectorAll('.accordion-item')
  const groupName = 'accordionExpandCollapse'
  toggleBtn.addEventListener('click', () => {
    const expand = toggleBtn.getAttribute('aria-expanded') !== 'true'
    for (const item of items) {
      if (expand) {
        item.removeAttribute('name')
        item.open = true
      } else {
        item.open = false
        item.setAttribute('name', groupName)
      }
    }
    toggleBtn.setAttribute('aria-expanded', String(expand))
    toggleBtn.textContent = expand ? 'Collapse all' : 'Expand all'
  })
}
