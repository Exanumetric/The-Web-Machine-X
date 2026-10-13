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
