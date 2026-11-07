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

const dialog = new bootstrap.Dialog('#myDialog', { modal: false })
dialog.show()

const collapseElementList = document.querySelectorAll('.collapse')
const collapseList = [...collapseElementList].map(collapseEl => new bootstrap.Collapse(collapseEl))

const popover = new bootstrap.Popover('.example-popover', {
  container: 'body'
})

console.log("It's me Exanumetric!")

const triggerEl = document.querySelector('#myTab button[data-bs-target="#profile"]')
bootstrap.Tab.getInstance(triggerEl).show()

const triggerFirstTabEl = document.querySelector('#myTab li:first-child button')
bootstrap.Tab.getInstance(triggerFirstTabEl).show()

const menuElementList = document.querySelectorAll('[data-bs-toggle="menu"]')
const menuList = [...menuElementList].map(menuToggleEl => new bootstrap.Menu(menuToggleEl))

const menuToggleEl = document.querySelector('#myMenuToggle')
const menu = bootstrap.Menu.getOrCreateInstance(menuToggleEl)

menu.show()
menu.hide()
menu.toggle()

const alertPlaceholder = document.getElementById('liveAlertPlaceholder')
const appendAlert = (message, type) => {
  const wrapper = document.createElement('div')
  wrapper.innerHTML = [
    `<div class="alert theme-${type}" role="alert">`,
    `   <p>${message}</p>`,
    '   <button type="button" class="btn-close ms-auto" data-bs-dismiss="alert" aria-label="Close"></button>',
    '</div>'
  ].join('')

  alertPlaceholder.append(wrapper)
}

const alertTrigger = document.getElementById('liveAlertBtn')
if (alertTrigger) {
  alertTrigger.addEventListener('click', () => {
    appendAlert('Hi! You got that alert right?', 'For yourself')
  })
}

const element = document.querySelector('.form-range')
const range = new bootstrap.Range(element, {
  bubble: true,
  formatter: value => `${value}%`
})

const input = document.querySelector('.form-range-input')

input.addEventListener('changed.bs.range', event => {
  console.log('Value:', event.value)
})
