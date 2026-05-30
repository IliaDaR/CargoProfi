/*!
 * Numino Landing — minimal / secure
 * No analytics, no third-party trackers.
 */

(function () {
  'use strict';

  // ===== HEADER SHADOW ON SCROLL =====
  var hdr = document.getElementById('header');
  window.addEventListener('scroll', function () {
    hdr.classList.toggle('scrolled', window.scrollY > 8);
  });

  // ===== MODAL =====
  var modal = document.getElementById('loginModal');
  var msgEl = document.getElementById('loginMessage');

  function openModal() {
    modal.classList.add('active');
    document.body.style.overflow = 'hidden';
  }

  function closeModal() {
    modal.classList.remove('active');
    document.body.style.overflow = '';
    msgEl.textContent = '';
    msgEl.className = 'modal__msg';
  }

  // Focus trap for modal
  modal.addEventListener('keydown', function(e) {
    if (e.key !== 'Tab' || !modal.classList.contains('active')) return;
    var focusable = modal.querySelectorAll('input,button,a');
    if (focusable.length === 0) return;
    var first = focusable[0], last = focusable[focusable.length - 1];
    if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
    if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
  });

  document.querySelectorAll('.login-btn').forEach(function (b) {
    b.addEventListener('click', function (e) {
      e.preventDefault();
      openModal();
    });
  });

  document.getElementById('closeModal').addEventListener('click', closeModal);
  modal.querySelector('.modal__bg').addEventListener('click', closeModal);

  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && modal.classList.contains('active')) closeModal();
  });

  // ===== LOGIN / REGISTER TOGGLE =====
  var isReg = false;
  var registerNameField = null;

  function buildNameField() {
    var g = document.createElement('div');
    g.style.cssText = 'display:flex;flex-direction:column;gap:6px;margin-top:2px';
    g.innerHTML = '<label>Имя</label><input type="text" placeholder="Иван Петров" required autocomplete="name">';
    return g;
  }

  document.getElementById('showRegister').addEventListener('click', function (e) {
    e.preventDefault();
    isReg = !isReg;
    var form = document.getElementById('loginForm');
    var submitBtn = document.getElementById('modalSubmit');

    if (isReg) {
      document.getElementById('modalTitle').textContent = 'Регистрация';
      document.getElementById('modalSub').textContent = 'Для владельцев парка';
      submitBtn.textContent = 'Зарегистрироваться';
      registerNameField = buildNameField();
      form.insertBefore(registerNameField, form.children[0]);
    } else {
      document.getElementById('modalTitle').textContent = 'Вход в кабинет';
      document.getElementById('modalSub').textContent = 'Для владельцев парка';
      submitBtn.textContent = 'Войти';
      if (registerNameField) { registerNameField.remove(); registerNameField = null; }
    }
  });

  // ===== LOGIN FORM — демо-режим =====
  // В production: заменить на Firebase Authentication
  // Демо-аккаунты существуют только для тестирования UI.
  document.getElementById('loginForm').addEventListener('submit', function (e) {
    e.preventDefault();
    var inputs = e.target.querySelectorAll('input');
    var email = '';
    var pass = '';
    for (var i = 0; i < inputs.length; i++) {
      if (inputs[i].type === 'email') email = inputs[i].value.trim();
      if (inputs[i].type === 'password') pass = inputs[i].value;
    }
    var accounts = {
      'admin@numino.ru':  { pass: 'admin123',  role: 'owner', name: 'Администратор' },
      'owner@numino.ru':  { pass: 'owner123',  role: 'owner', name: 'Владелец парка' },
    };

    if (isReg) {
      msgEl.textContent = 'Демо-режим. Аккаунт создан! Теперь войдите.';
      msgEl.className = 'modal__msg success';
      // Switch back to login mode
      isReg = true;
      document.getElementById('showRegister').click();
      return;
    }

    var acc = accounts[email];
    if (acc && pass === acc.pass) {
      msgEl.textContent = 'Добро пожаловать, ' + acc.name + '! Переход в кабинет...';
      msgEl.className = 'modal__msg success';
      setTimeout(function () {
        window.location.href = 'admin/index.html';
      }, 1000);
    } else {
      msgEl.textContent = 'Неверный email или пароль.';
      msgEl.className = 'modal__msg error';
      // Demo hint
      var hint = document.createElement('p');
      hint.style.cssText = 'text-align:center;font-size:.78rem;color:#64748b;margin-top:6px';
      hint.textContent = 'Демо: admin@numino.ru / admin123';
      msgEl.appendChild(hint);
    }
  });

  // ===== CONTACT FORM — отправляется через FormSubmit =====
  var contactForm = document.getElementById('contactForm');
  if (contactForm) {
    // Bot honey-pot
    var hp = document.createElement('input');
    hp.type = 'text';
    hp.name = '_honey';
    hp.style.cssText = 'position:absolute;left:-9999px;opacity:0;height:0;width:0';
    hp.tabIndex = -1;
    hp.autocomplete = 'off';
    contactForm.appendChild(hp);
  }

  // ===== DOWNLOAD APK — handled via direct href to GitHub releases =====

  // ===== CAROUSEL FACTORY =====
  function createCarousel(trackId, prevId, nextId, dotsId) {
    var track = document.getElementById(trackId);
    var prevBtn = document.getElementById(prevId);
    var nextBtn = document.getElementById(nextId);
    var dotsContainer = document.getElementById(dotsId);
    if (!track || !prevBtn || !nextBtn || !dotsContainer) return;

    var slides = track.querySelectorAll('.feat-card, .step-card');
    var totalSlides = slides.length;
    var current = 0;
    var autoTimer = null;
    var INTERVAL = 5000;

    for (var i = 0; i < totalSlides; i++) {
      var dot = document.createElement('button');
      dot.className = 'carousel__dot';
      dot.setAttribute('aria-label', 'Слайд ' + (i + 1));
      dot.addEventListener('click', (function (idx) {
        return function () { goTo(idx); };
      })(i));
      dotsContainer.appendChild(dot);
    }
    var dots = dotsContainer.querySelectorAll('.carousel__dot');

    function goTo(idx) {
      if (idx < 0) idx = totalSlides - 1;
      if (idx >= totalSlides) idx = 0;
      current = idx;
      track.style.transform = 'translateX(-' + (current * 100) + '%)';
      dots.forEach(function (d, i) { d.classList.toggle('active', i === current); });
      resetAuto();
    }

    nextBtn.addEventListener('click', function () { goTo(current + 1); });
    prevBtn.addEventListener('click', function () { goTo(current - 1); });

    function startAuto() { autoTimer = setInterval(function () { goTo(current + 1); }, INTERVAL); }
    function resetAuto() { clearInterval(autoTimer); startAuto(); }

    // Touch swipe
    var touchStartX = 0;
    track.addEventListener('touchstart', function (e) { touchStartX = e.changedTouches[0].screenX; }, { passive: true });
    track.addEventListener('touchend', function (e) {
      var diff = touchStartX - e.changedTouches[0].screenX;
      if (Math.abs(diff) > 50) goTo(diff > 0 ? current + 1 : current - 1);
    }, { passive: true });

    // Mouse drag
    var isDragging = false, startX = 0;
    track.addEventListener('mousedown', function (e) {
      isDragging = true; startX = e.pageX;
      track.classList.add('dragging'); clearInterval(autoTimer);
    });
    track.addEventListener('mousemove', function (e) {
      if (!isDragging) return;
      e.preventDefault();
    });
    track.addEventListener('mouseup', function (e) {
      if (!isDragging) return;
      isDragging = false; track.classList.remove('dragging'); startAuto();
      var diff = startX - e.pageX;
      if (Math.abs(diff) > 50) goTo(diff > 0 ? current + 1 : current - 1);
    });
    track.addEventListener('mouseleave', function () {
      if (isDragging) { isDragging = false; track.classList.remove('dragging'); startAuto(); }
    });

    // Pause on hover
    track.addEventListener('mouseenter', function () { clearInterval(autoTimer); });
    track.addEventListener('mouseleave', function () { startAuto(); });

    goTo(0);
    startAuto();
  }

  // Init both carousels
  createCarousel('featuresTrack', 'carouselPrev', 'carouselNext', 'carouselDots');
  createCarousel('howTrack', 'howPrev', 'howNext', 'howDots');

  // ===== SMOOTH SCROLL =====
  document.querySelectorAll('a[href^="#"]').forEach(function (a) {
    a.addEventListener('click', function (e) {
      var href = a.getAttribute('href');
      if (href === '#' || href === null) return;
      var t = document.querySelector(href);
      if (t) { e.preventDefault(); t.scrollIntoView({ behavior: 'smooth', block: 'start' }); }
    });
  });

  // ===== SANITIZE INPUTS =====
  function sanitize(s) {
    return String(s).replace(/[<>]/g, '');
  }
  document.querySelectorAll('input[type="text"], input[type="email"], input[type="tel"], textarea').forEach(function (el) {
    el.addEventListener('input', function () {
      el.value = sanitize(el.value);
    });
  });
})();
