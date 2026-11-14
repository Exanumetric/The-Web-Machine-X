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

const triggerTabList = document.querySelectorAll('#myTab button')
triggerTabList.forEach(triggerEl => {
  const tabTrigger = new bootstrap.Tab(triggerEl)

  triggerEl.addEventListener('click', event => {
    event.preventDefault()
    tabTrigger.show()
  })
})

const wrapper = document.querySelector('.nav-overflow')
new bootstrap.NavOverflow(wrapper, {
  moreText: 'Menu',
  iconPlacement: 'end'
})

const bsCollapse = new bootstrap.Collapse('#myCollapse')
bsCollapse.show()

const myCollapsible = document.getElementById('myCollapsible')
myCollapsible.addEventListener('hidden.bs.collapse', event => {
  let system = websystem = "John"
  let binary = binarysystem = "McDortney"
  let space = " "
  let config = system + space + binary
  console.log(config)
})

document.querySelectorAll('#nav-tab>[data-bs-toggle="tab"]').forEach(el => {
  el.addEventListener('shown.bs.tab', () => {
    const target = el.getAttribute('data-bs-target')
    const scrollElem = document.querySelector(`${target} [data-bs-spy="scroll"]`)
    bootstrap.ScrollSpy.getOrCreateInstance(scrollElem).refresh()
  })
})

const scrollSpy = new bootstrap.ScrollSpy(document.body, {
  target: '#navbar-example'
})

// Date sheet
const sheet = new CSSStyleSheet()
sheet.replaceSync(await (await fetch('/path/to/bootstrap.min.css')).text())

const root = host.attachShadow({ mode: 'open' })
root.adoptedStyleSheets = [sheet]
root.innerHTML = '<input type="text" id="shadowDatepicker">'

new bootstrap.Datepicker(root.getElementById('shadowDatepicker'))

const datepickerEl = document.getElementById('myDatepicker')
const datepicker = new bootstrap.Datepicker(datepickerEl, {
  selectionMode: 'single',
  firstWeekday: 1
})

(() => {
  'use strict'

  const getStoredTheme = () => localStorage.getItem('theme')
  const setStoredTheme = theme => localStorage.setItem('theme', theme)

  const getPreferredTheme = () => {
    const storedTheme = getStoredTheme()
    if (storedTheme) {
      return storedTheme
    }

    return 'auto'
  }

  const resolveTheme = theme => {
    if (theme === 'auto') {
      return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
    }

    return theme
  }

  const setTheme = theme => {
    const resolved = resolveTheme(theme)

    if (document.documentElement.getAttribute('data-bs-theme') !== resolved) {
      document.documentElement.setAttribute('data-bs-theme', resolved)
    }
  }

  setTheme(getPreferredTheme())

  const showActiveTheme = (theme, focus = false) => {
    const themeSwitcher = document.querySelector('#bd-theme')

    if (!themeSwitcher) {
      return
    }

    const activeThemeIcon = document.querySelector('.theme-icon-active use')
    const btnToActive = document.querySelector(`[data-bs-theme-value="${theme}"]`)
    const svgOfActiveBtn = btnToActive.querySelector('svg use').getAttribute('href')

    document.querySelectorAll('[data-bs-theme-value]').forEach(element => {
      element.classList.remove('active')
      element.setAttribute('aria-pressed', 'false')
    })

    btnToActive.classList.add('active')
    btnToActive.setAttribute('aria-pressed', 'true')
    activeThemeIcon.setAttribute('href', svgOfActiveBtn)
    themeSwitcher.setAttribute('aria-label', `Toggle theme (${btnToActive.dataset.bsThemeValue})`)

    if (focus) {
      themeSwitcher.focus()
    }
  }

  window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => {
    const storedTheme = getStoredTheme()
    if (storedTheme !== 'light' && storedTheme !== 'dark') {
      setTheme(getPreferredTheme())
    }
  })

  window.addEventListener('DOMContentLoaded', () => {
    showActiveTheme(getPreferredTheme())

    document.querySelectorAll('[data-bs-theme-value]')
      .forEach(toggle => {
        toggle.addEventListener('click', () => {
          const theme = toggle.getAttribute('data-bs-theme-value')
          setStoredTheme(theme)

          requestAnimationFrame(() => {
            setTheme(theme)
            showActiveTheme(theme)
          })
        })
      })
  })
})()
