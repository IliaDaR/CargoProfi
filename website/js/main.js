// ===== HEADER SCROLL EFFECT =====
const header = document.getElementById('header');
window.addEventListener('scroll', () => {
  if (window.scrollY > 10) {
    header.classList.add('scrolled');
  } else {
    header.classList.remove('scrolled');
  }
});

// ===== LOGIN MODAL =====
const modal = document.getElementById('loginModal');
const closeModal = document.getElementById('closeModal');
const modalBackdrop = modal.querySelector('.modal__backdrop');
const loginMessage = document.getElementById('loginMessage');

function openModal() {
  modal.classList.add('active');
  document.body.style.overflow = 'hidden';
}

function closeModalFn() {
  modal.classList.remove('active');
  document.body.style.overflow = '';
  loginMessage.textContent = '';
  loginMessage.className = 'modal__info';
}

document.querySelectorAll('.login-btn').forEach(btn => {
  btn.addEventListener('click', (e) => {
    e.preventDefault();
    openModal();
  });
});

closeModal.addEventListener('click', closeModalFn);
modalBackdrop.addEventListener('click', closeModalFn);

// Escape key
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape' && modal.classList.contains('active')) {
    closeModalFn();
  }
});

// ===== LOGIN / REGISTER FORM =====
const loginForm = document.getElementById('loginForm');
const showRegister = document.getElementById('showRegister');
const modalTitle = modal.querySelector('.modal__title');
const modalSubtitle = modal.querySelector('.modal__subtitle');
const submitBtn = loginForm.querySelector('button[type="submit"]');
const modalLink = modal.querySelector('.modal__link');
let isRegisterMode = false;

showRegister.addEventListener('click', (e) => {
  e.preventDefault();
  isRegisterMode = !isRegisterMode;
  if (isRegisterMode) {
    modalTitle.textContent = 'Регистрация';
    modalSubtitle.textContent = 'Для владельцев парка';
    submitBtn.textContent = 'Зарегистрироваться';
    modalLink.innerHTML = 'Уже есть аккаунт? <a href="#" class="modal__switch" id="showRegister">Войти</a>';
    // Add name field if in register mode
    const form = document.getElementById('loginForm');
    if (!form.querySelector('.register-name')) {
      const nameGroup = document.createElement('div');
      nameGroup.className = 'modal__form-group register-name';
      nameGroup.innerHTML = '<label class="modal__label">Имя</label><input type="text" class="modal__input" placeholder="Иван Петров" required>';
      form.insertBefore(nameGroup, form.children[0]);
    }
  } else {
    modalTitle.textContent = 'Вход в кабинет';
    modalSubtitle.textContent = 'Для владельцев парка';
    submitBtn.textContent = 'Войти';
    modalLink.innerHTML = 'Нет аккаунта? <a href="#" class="modal__switch" id="showRegister">Зарегистрироваться</a>';
    const nameField = loginForm.querySelector('.register-name');
    if (nameField) nameField.remove();
  }
  // Re-bind the switch link
  const newSwitch = modalLink.querySelector('.modal__switch');
  if (newSwitch) {
    newSwitch.addEventListener('click', (ev) => {
      ev.preventDefault();
      showRegister.click();
    });
  }
});

loginForm.addEventListener('submit', (e) => {
  e.preventDefault();
  const inputs = loginForm.querySelectorAll('input');
  const email = inputs[inputs.length - 2]?.value?.trim();
  const password = inputs[inputs.length - 1]?.value?.trim();

  // This is a demo landing page — in production, call Firebase Auth
  loginMessage.textContent = 'Демо-режим. В production здесь будет вход через Firebase Auth.';
  loginMessage.className = 'modal__info modal__info--success';

  // Redirect would go here in production:
  // setTimeout(() => { window.location.href = '/dashboard'; }, 1500);
});

// ===== CONTACT FORM =====
const contactForm = document.getElementById('contactForm');
contactForm.addEventListener('submit', (e) => {
  e.preventDefault();
  const btn = contactForm.querySelector('button');
  const originalText = btn.textContent;
  btn.textContent = 'Отправлено!';
  btn.style.background = '#22c55e';
  setTimeout(() => {
    btn.textContent = originalText;
    btn.style.background = '';
    contactForm.reset();
  }, 2000);
});

// ===== DOWNLOAD APK =====
document.getElementById('downloadApk').addEventListener('click', (e) => {
  e.preventDefault();
  // Placeholder: in production, link to real APK
  alert('APK будет доступен после сборки приложения.\nСм. инструкцию в cargo_app/README.md');
});

// ===== SMOOTH SCROLL FOR ALL ANCHOR LINKS =====
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
  anchor.addEventListener('click', function(e) {
    const href = this.getAttribute('href');
    if (href === '#') return;
    const target = document.querySelector(href);
    if (target) {
      e.preventDefault();
      target.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
  });
});
