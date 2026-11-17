import {
  Toast,
  Tooltip,
  Collapse,
  Dialog,
  Popover,
  Tab,
  Menu,
  ScrollSpy,
  Datepicker
} from 'bootstrap';

'use strict';

document.addEventListener('DOMContentLoaded', () => {

  // ==========================================
  // WEB MACHINE X
  // ==========================================

  const system = 'John';
  const binary = 'McDortney';

  console.log("It's me Exanumetric!");
  console.log(`${system} ${binary}`);


  // ==========================================
  // TOAST
  // ==========================================

  const toastButton = document.getElementById('liveToastBtn');
  const toastElement = document.getElementById('liveToast');

  if (toastButton && toastElement) {
    const toast = Toast.getOrCreateInstance(toastElement);

    toastButton.addEventListener('click', () => {
      toast.show();
    });
  }


  // ==========================================
  // TOOLTIP
  // ==========================================

  document.querySelectorAll('[data-bs-toggle="tooltip"]').forEach(element => {
    Tooltip.getOrCreateInstance(element);
  });


  // ==========================================
  // TOGGLER
  // ==========================================

  document.querySelectorAll('[data-bs-toggle="toggler"]').forEach(button => {
    button.addEventListener('click', () => {
      const selector =
        button.getAttribute('data-bs-target') ||
        button.getAttribute('aria-controls');

      if (!selector) return;

      const target = document.querySelector(selector);

      if (!target) return;

      const isHidden = target.hasAttribute('hidden');

      target.toggleAttribute('hidden', !isHidden);

      button.setAttribute('aria-expanded', String(isHidden));
    });
  });


  // ==========================================
  // ACCORDION
  // ==========================================

  const accordion = document.getElementById('accordionExpandCollapse');
  const accordionButton = document.getElementById('btnAccordionToggleAll');

  if (accordion && accordionButton) {
    const panels = accordion.querySelectorAll('.accordion-collapse');

    accordionButton.addEventListener('click', () => {
      const expand =
        accordionButton.getAttribute('aria-expanded') !== 'true';

      panels.forEach(panel => {
        const instance = Collapse.getOrCreateInstance(panel, {
          toggle: false
        });

        if (expand) {
          instance.show();
        } else {
          instance.hide();
        }
      });

      accordionButton.setAttribute('aria-expanded', String(expand));
      accordionButton.textContent = expand ? 'Collapse all' : 'Expand all';
    });
  }


  // ==========================================
  // DIALOG
  // ==========================================

  const dialogElement = document.getElementById('myDialog');
  const openDialogButton = document.getElementById('openDialog');

  if (dialogElement && openDialogButton) {
    const dialog = Dialog.getOrCreateInstance(dialogElement);

    openDialogButton.addEventListener('click', () => {
      dialog.show();
    });
  }


  // ==========================================
  // COLLAPSE
  // ==========================================

  document.querySelectorAll('.collapse').forEach(element => {
    Collapse.getOrCreateInstance(element, {
      toggle: false
    });
  });

  const myCollapse = document.getElementById('myCollapse');

  if (myCollapse) {
    Collapse.getOrCreateInstance(myCollapse).show();
  }

  const myCollapsible = document.getElementById('myCollapsible');

  if (myCollapsible) {
    myCollapsible.addEventListener('hidden.bs.collapse', () => {
      console.log('1');
      console.log('2');
    });
  }


  // ==========================================
  // POPOVER
  // ==========================================

  document.querySelectorAll('.example-popover').forEach(element => {
    Popover.getOrCreateInstance(element, {
      container: 'body'
    });
  });


  // ==========================================
  // TABS
  // ==========================================

  const profileTab = document.querySelector(
    '#myTab button[data-bs-target="#profile"]'
  );

  if (profileTab) {
    Tab.getOrCreateInstance(profileTab).show();
  }

  document.querySelectorAll('#myTab button').forEach(button => {
    button.addEventListener('click', event => {
      event.preventDefault();
      Tab.getOrCreateInstance(button).show();
    });
  });


  // ==========================================
  // MENU
  // ==========================================

  document.querySelectorAll('[data-bs-toggle="menu"]').forEach(element => {
    Menu.getOrCreateInstance(element);
  });

  const menuToggle = document.getElementById('myMenuToggle');

  if (menuToggle) {
    const menu = Menu.getOrCreateInstance(menuToggle);

    document.getElementById('showMenu')?.addEventListener('click', () => {
      menu.show();
    });

    document.getElementById('hideMenu')?.addEventListener('click', () => {
      menu.hide();
    });

    const toggleButton = document.getElementById('toggleMenu');

    toggleButton?.addEventListener('click', () => {
      menu.toggle();
    });
  }


  // ==========================================
  // ALERT
  // ==========================================

  const alertPlaceholder = document.getElementById('liveAlertPlaceholder');

  const appendAlert = (message, type = 'success') => {
    if (!alertPlaceholder) return;

    const wrapper = document.createElement('div');
    wrapper.className = `alert theme-${type}`;
    wrapper.setAttribute('role', 'alert');

    const paragraph = document.createElement('p');
    paragraph.textContent = message;

    const closeButton = document.createElement('button');
    closeButton.type = 'button';
    closeButton.className = 'btn-close ms-auto';
    closeButton.setAttribute('data-bs-dismiss', 'alert');
    closeButton.setAttribute('aria-label', 'Close');

    wrapper.append(paragraph, closeButton);
    alertPlaceholder.append(wrapper);
  };

  document.getElementById('liveAlertBtn')?.addEventListener('click', () => {
    appendAlert('Hi! You got that alert right?', 'success');
  });


  // ==========================================
  // RANGE
  // ==========================================

  document.querySelectorAll('.form-range').forEach(input => {
    input.addEventListener('input', event => {
      const inputElement = event.currentTarget;

      const rangeValue = inputElement.value;

      console.log('Value:', rangeValue);

      const output = document.querySelector(
        `[data-range-output="${inputElement.id}"]`
      );

      if (output) {
        output.textContent = `${rangeValue}%`;
      }
    });
  });


  // ==========================================
  // NAV OVERFLOW
  // ==========================================

  document.querySelectorAll('.nav-overflow').forEach(element => {
    element.classList.add('webmachine-nav');
  });


  // ==========================================
  // SCROLLSPY
  // ==========================================

  const navbarExample = document.getElementById('navbar-example');

  if (navbarExample) {
    const scrollSpy = ScrollSpy.getOrCreateInstance(document.body, {
      target: '#navbar-example'
    });

    document.querySelectorAll(
      '#nav-tab > [data-bs-toggle="tab"]'
    ).forEach(tabButton => {
      tabButton.addEventListener('shown.bs.tab', () => {
        scrollSpy.refresh();
      });
    });
  }


  // ==========================================
  // DATEPICKER
  // ==========================================

  const datepickerElement = document.getElementById('myDatepicker');

  if (datepickerElement) {
    Datepicker.getOrCreateInstance(datepickerElement, {
      selectionMode: 'single',
      firstWeekday: 1
    });
  }


  // ==========================================
  // THEME SWITCHER
  // ==========================================

  const getStoredTheme = () => {
    try {
      return localStorage.getItem('theme');
    } catch {
      return null;
    }
  };

  const setStoredTheme = selectedTheme => {
    try {
      localStorage.setItem('theme', selectedTheme);
    } catch {
      console.warn('Theme preference could not be saved.');
    }
  };

  const getPreferredTheme = () => {
    return getStoredTheme() || 'auto';
  };

  const resolveTheme = selectedTheme => {
    if (selectedTheme === 'auto') {
      return window.matchMedia('(prefers-color-scheme: dark)').matches
        ? 'dark'
        : 'light';
    }

    return selectedTheme;
  };

  const setTheme = selectedTheme => {
    document.documentElement.setAttribute(
      'data-bs-theme',
      resolveTheme(selectedTheme)
    );
  };

  const showActiveTheme = selectedTheme => {
    document.querySelectorAll('[data-bs-theme-value]').forEach(button => {
      const buttonTheme = button.getAttribute('data-bs-theme-value');
      const isActive = buttonTheme === selectedTheme;

      button.classList.toggle('active', isActive);
      button.setAttribute('aria-pressed', String(isActive));
    });
  };

  setTheme(getPreferredTheme());
  showActiveTheme(getPreferredTheme());

  document.querySelectorAll('[data-bs-theme-value]').forEach(button => {
    button.addEventListener('click', () => {
      const selectedTheme = button.getAttribute('data-bs-theme-value');

      if (selectedTheme === null) return;

      setStoredTheme(selectedTheme);
      setTheme(selectedTheme);
      showActiveTheme(selectedTheme);
    });
  });

  window.matchMedia('(prefers-color-scheme: dark)')
    .addEventListener('change', () => {
      if (getStoredTheme() === null) {
        setTheme('auto');
        showActiveTheme('auto');
      }
    });


  // ==========================================
  // LOGIN DEMO
  // ==========================================

  const email = document.getElementById('email');
  const password = document.getElementById('password');
  const login = document.getElementById('login');
  const information = document.getElementById('infomation');

  if (login && email && password && information) {
    login.addEventListener('click', event => {
      event.preventDefault();

      const emailField = email.value.trim();
      const passwordField = password.value.trim();

      if (emailField === '' || passwordField === '') {
        information.textContent =
          'Email or password should not be empty';
      } else if (
        emailField === 'name@gmail.com' &&
        passwordField === '10100101'
      ) {
        information.textContent = 'Login completed';
      } else {
        information.textContent = 'Email or password incorrect';
      }
    });
  }
});
