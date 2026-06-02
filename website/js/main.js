/*!
 * Numino Landing — minimal / secure
 * No analytics, no third-party trackers.
 */

(function () {
  'use strict';

  // ===== BURGER MENU =====
  var burgerBtn = document.getElementById('burgerBtn');
  var mainNav = document.getElementById('mainNav');
  if (burgerBtn && mainNav) {
    burgerBtn.addEventListener('click', function() {
      burgerBtn.classList.toggle('open');
      mainNav.classList.toggle('open');
    });
    mainNav.querySelectorAll('a').forEach(function(a) {
      a.addEventListener('click', function() {
        burgerBtn.classList.remove('open');
        mainNav.classList.remove('open');
      });
    });
  }

  // ===== SCROLL TO TOP =====
  var scrollBtn = document.createElement('button');
  scrollBtn.className = 'scroll-top';
  scrollBtn.innerHTML = '&#8593;';
  scrollBtn.setAttribute('aria-label', 'Наверх');
  scrollBtn.setAttribute('type', 'button');
  scrollBtn.addEventListener('click', function() { window.scrollTo({top:0,behavior:'smooth'}); });
  document.body.appendChild(scrollBtn);
  window.addEventListener('scroll', function() {
    scrollBtn.classList.toggle('visible', window.scrollY > 500);
  });
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

  // Focus trap
  modal.addEventListener('keydown', function(e) {
    if (e.key !== 'Tab' || !modal.classList.contains('active')) return;
    var focusable = modal.querySelectorAll('input,button,a');
    if (focusable.length === 0) return;
    var first = focusable[0], last = focusable[focusable.length - 1];
    if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
    if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
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
      document.getElementById('modalSub').textContent = 'Владелец автопарка';
      submitBtn.textContent = 'Зарегистрироваться';
      registerNameField = buildNameField();
      form.insertBefore(registerNameField, form.children[0]);
    } else {
      document.getElementById('modalTitle').textContent = 'Вход в кабинет';
      document.getElementById('modalSub').textContent = 'Владелец автопарка или водитель';
      submitBtn.textContent = 'Войти';
      if (registerNameField) { registerNameField.remove(); registerNameField = null; }
    }
  });

  // ===== LOGIN / REGISTER =====
  // Firebase Auth (основной метод). Без Firebase — редирект в кабинет.
  document.getElementById('loginForm').addEventListener('submit', async function (e) {
    e.preventDefault();
    var email = '', pass = '', name = '';
    var inputs = e.target.querySelectorAll('input');
    for (var i = 0; i < inputs.length; i++) {
      if (inputs[i].type === 'email') email = inputs[i].value.trim().toLowerCase();
      if (inputs[i].type === 'password') pass = inputs[i].value;
      if (inputs[i].type === 'text') name = inputs[i].value.trim();
    }
    if (!email || !pass) { msgEl.textContent = 'Заполните все поля'; msgEl.className = 'modal__msg error'; return; }
    if (!isValidEmail(email)) { msgEl.textContent = 'Неверный формат email'; msgEl.className = 'modal__msg error'; return; }
    if (pass.length < 6) { msgEl.textContent = 'Пароль минимум 6 символов'; msgEl.className = 'modal__msg error'; return; }

    var btn = e.target.querySelector('button[type="submit"]');
    if (btn) { btn.disabled = true; btn.textContent = 'Загрузка...'; }

    // Firebase Auth (основной метод — пароли не хранятся локально)
    if (window._firebaseReady && window._firebaseAuth) {
      try {
        if (isReg) {
          if (!name) { msgEl.textContent = 'Введите имя'; msgEl.className = 'modal__msg error'; if (btn) { btn.disabled = false; btn.textContent = isReg ? 'Зарегистрироваться' : 'Войти'; } return; }
          await createUserWithEmailAndPassword(window._firebaseAuth, email, pass);
        } else {
          await signInWithEmailAndPassword(window._firebaseAuth, email, pass);
        }
        msgEl.textContent = 'Вход выполнен! Переход в кабинет...';
        msgEl.className = 'modal__msg success';
        setTimeout(function () { window.location.href = 'admin/index.html'; }, 600);
        return;
      } catch (err) {
        msgEl.textContent = isReg ? 'Ошибка регистрации' : 'Неверный email или пароль';
        msgEl.className = 'modal__msg error';
        if (btn) { btn.disabled = false; btn.textContent = isReg ? 'Зарегистрироваться' : 'Войти'; }
        return;
      }
    }

    // Офлайн-режим: проверяем что пользователь существует (без сравнения паролей)
    var users = getUsers();
    if (isReg) {
      if (!name) { msgEl.textContent = 'Введите имя'; msgEl.className = 'modal__msg error'; if (btn) { btn.disabled = false; btn.textContent = isReg ? 'Зарегистрироваться' : 'Войти'; } return; }
      if (users[email]) { msgEl.textContent = 'Пользователь уже существует'; msgEl.className = 'modal__msg error'; if (btn) { btn.disabled = false; btn.textContent = isReg ? 'Зарегистрироваться' : 'Войти'; } return; }
      users[email] = { name: name, role: 'owner' };
      saveUsers(users);
      msgEl.textContent = 'Регистрация успешна! Выполните вход.';
      msgEl.className = 'modal__msg success';
      isReg = true; document.getElementById('showRegister').click();
      if (btn) { btn.disabled = false; btn.textContent = 'Войти'; }
      return;
    }

    var user = users[email];
    if (!user) {
      msgEl.textContent = 'Пользователь не найден. Зарегистрируйтесь.';
      msgEl.className = 'modal__msg error';
      if (btn) { btn.disabled = false; btn.textContent = 'Войти'; }
      return;
    }
    msgEl.textContent = 'Вход выполнен! Переход в кабинет...';
    msgEl.className = 'modal__msg success';
    setTimeout(function () { window.location.href = 'admin/index.html'; }, 600);
  });

  // ===== CONTACT FORM — отправляется через FormSubmit + сохраняет тикет локально =====
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

    // Сохраняем тикет в localStorage для админки
    contactForm.addEventListener('submit', function() {
      var name = contactForm.querySelector('[name="name"]')?.value || '';
      var email = contactForm.querySelector('[name="email"]')?.value || '';
      var msg = contactForm.querySelector('[name="message"]')?.value || '';
      if (name && email && msg) {
        var tickets = JSON.parse(localStorage.getItem('numino_tickets') || '[]');
        tickets.push({name: name, email: email, message: msg, status: 'new', createdAt: new Date().toISOString()});
        // SharedPreferences на Flutter Web использует префикс "flutter."
        localStorage.setItem('flutter.tickets', JSON.stringify(tickets));
      }
    });
  }

  // ===== DOWNLOAD APK — handled via direct href to GitHub releases =====

  // ===== CAROUSEL FACTORY =====
  var _carouselIntervals = [];
  window.addEventListener('pagehide', function() { _carouselIntervals.forEach(function(id) { clearInterval(id); }); _carouselIntervals = []; });
  window.addEventListener('beforeunload', function() { _carouselIntervals.forEach(function(id) { clearInterval(id); }); });

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

    function startAuto() { autoTimer = setInterval(function () { goTo(current + 1); }, INTERVAL); _carouselIntervals.push(autoTimer); }
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

  // ===== SCROLL ANIMATIONS =====
  (function() {
    var items = document.querySelectorAll('.feat-card, .step-card, .plan, .hero__text, .hero__img');
    items.forEach(function(el) {
      el.style.opacity = '0';
      el.style.transform = 'translateY(30px)';
      el.style.transition = 'opacity 0.6s ease, transform 0.6s ease';
    });
    function check() {
      var h = window.innerHeight;
      items.forEach(function(el) {
        var rect = el.getBoundingClientRect();
        if (rect.top < h - 80) {
          el.style.opacity = '1';
          el.style.transform = 'translateY(0)';
        }
      });
    }
    window.addEventListener('scroll', check, {passive: true});
    window.addEventListener('resize', check);
    check();
  })();

  // ===== SMOOTH SCROLL =====
  document.querySelectorAll('a[href^="#"]').forEach(function (a) {
    a.addEventListener('click', function (e) {
      var href = a.getAttribute('href');
      if (href === '#' || href === null) return;
      var t = document.querySelector(href);
      if (t) { e.preventDefault(); t.scrollIntoView({ behavior: 'smooth', block: 'start' }); }
    });
  });

  // ===== SANITIZE INPUTS (XSS prevention) =====
  function sanitize(s) {
    return String(s)
      .replace(/[<>]/g, '')
      .replace(/on\w+\s*=/gi, '')
      .replace(/javascript\s*:/gi, '')
      .replace(/eval\s*\(/gi, '')
      .replace(/data\s*:\s*text\/html/gi, '')
      .replace(/vbscript\s*:/gi, '')
      .replace(/&#[xX]?[0-9a-fA-F]+;?/g, '')
      .replace(/expression\s*\(/gi, '')
      .replace(/url\s*\(/gi, '');
  }
  document.querySelectorAll('input[type="text"], input[type="email"], input[type="tel"], textarea').forEach(function (el) {
    el.addEventListener('input', function () {
      el.value = sanitize(el.value);
    });
  });

  // ===== EMAIL VALIDATION =====
  function isValidEmail(email) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  }

  // ===== CLEANUP: prevent setInterval memory leaks =====
  window.addEventListener('beforeunload', function() {
    // Карусели очистятся при уходе со страницы
    var btns = document.querySelectorAll('.carousel__btn');
    btns.forEach(function(b) { b.replaceWith(b.cloneNode(true)); });
  });
})();
