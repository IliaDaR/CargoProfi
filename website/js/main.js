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
  // SharedPreferences на Flutter Web добавляет префикс "flutter." ко всем ключам
  function getUsers() {
    try { return JSON.parse(localStorage.getItem('flutter.numino_users')) || {}; } catch(_) { return {}; }
  }
  function saveUsers(u) { localStorage.setItem('flutter.numino_users', JSON.stringify(u)); }

  // Предустановленные аккаунты
  (function() {
    var u = getUsers();
    if (!u['admin@numino.ru']) {
      u['admin@numino.ru'] = { pass: 'admin123', name: 'Администратор', role: 'admin' };
      u['owner@numino.ru'] = { pass: 'owner123', name: 'Владелец парка', role: 'owner' };
      saveUsers(u);
    }
  })();

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

    // Firebase Auth (основной метод)
    if (window._firebaseReady && window._firebaseAuth) {
      try {
        if (isReg) {
          if (!name) { msgEl.textContent = 'Введите имя'; msgEl.className = 'modal__msg error'; if (btn) { btn.disabled = false; btn.textContent = isReg ? 'Зарегистрироваться' : 'Войти'; } return; }
          await createUserWithEmailAndPassword(window._firebaseAuth, email, pass);
        } else {
          await signInWithEmailAndPassword(window._firebaseAuth, email, pass);
        }
      } catch (err) {
        var msg = 'Ошибка входа';
        if (err.code) {
          if (err.code === 'auth/wrong-password' || err.code === 'auth/user-not-found') msg = 'Неверный email или пароль';
          else if (err.code === 'auth/too-many-requests') msg = 'Слишком много попыток. Попробуйте позже.';
          else if (err.code === 'auth/invalid-email') msg = 'Неверный формат email';
          else if (err.code === 'auth/email-already-in-use') msg = 'Email уже зарегистрирован';
          else if (err.code === 'auth/weak-password') msg = 'Пароль слишком простой (минимум 6 символов)';
          else if (err.code === 'auth/network-request-failed') msg = 'Ошибка сети. Проверьте подключение.';
          else msg = 'Ошибка: ' + (err.code || 'сервис недоступен');
        }
        msgEl.textContent = msg;
        msgEl.className = 'modal__msg error';
        if (btn) { btn.disabled = false; btn.textContent = isReg ? 'Зарегистрироваться' : 'Войти'; }
        return;
      }
    } else {
      // Резервный вход через localStorage
      var users = getUsers();
      if (isReg) {
        if (!name) { msgEl.textContent = 'Введите имя'; msgEl.className = 'modal__msg error'; if (btn) { btn.disabled = false; btn.textContent = isReg ? 'Зарегистрироваться' : 'Войти'; } return; }
        if (users[email]) { msgEl.textContent = 'Пользователь уже существует'; msgEl.className = 'modal__msg error'; if (btn) { btn.disabled = false; btn.textContent = isReg ? 'Зарегистрироваться' : 'Войти'; } return; }
        users[email] = { pass: pass, name: name, role: 'owner' };
        saveUsers(users);
        msgEl.textContent = 'Регистрация успешна! Выполните вход.';
        msgEl.className = 'modal__msg success';
        isReg = true; document.getElementById('showRegister').click();
        if (btn) { btn.disabled = false; btn.textContent = 'Войти'; }
        return;
      }
      var user = users[email];
      if (!user || user.pass !== pass) {
        msgEl.textContent = 'Неверный email или пароль';
        msgEl.className = 'modal__msg error';
        if (btn) { btn.disabled = false; btn.textContent = 'Войти'; }
        return;
      }
    }
    msgEl.textContent = 'Вход выполнен! Переход в кабинет...';
    msgEl.className = 'modal__msg success';
    setTimeout(function () { window.location.href = 'admin/index.html'; }, 600);
  });

  // ===== CONTACT FORM — отправляется через FormSubmit + сохраняет тикет локально =====
  var contactForm = document.getElementById('contactForm');
  if (contactForm) {
    // Honeypot в HTML (index.html), здесь только сохраняем тикет
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
      isDragging = false; track.classList.remove('dragging'); resetAuto();
      var diff = startX - e.pageX;
      if (Math.abs(diff) > 50) goTo(diff > 0 ? current + 1 : current - 1);
    });
    track.addEventListener('mouseleave', function () {
      if (isDragging) { isDragging = false; track.classList.remove('dragging'); resetAuto(); }
    });

    // Pause on hover
    track.addEventListener('mouseenter', function () { clearInterval(autoTimer); });
    track.addEventListener('mouseleave', function () { resetAuto(); });

    goTo(0);
  }

  // Init both carousels
  createCarousel('featuresTrack', 'carouselPrev', 'carouselNext', 'carouselDots');
  createCarousel('howTrack', 'howPrev', 'howNext', 'howDots');

  // ===== SCROLL ANIMATIONS (IntersectionObserver) =====
  (function() {
    var items = document.querySelectorAll('.feat-card, .step-card, .plan, .hero__text, .hero__img');
    items.forEach(function(el) {
      el.style.opacity = '0';
      el.style.transform = 'translateY(30px)';
      el.style.transition = 'opacity 0.6s ease, transform 0.6s ease';
    });
    if (window.IntersectionObserver) {
      var observer = new IntersectionObserver(function(entries) {
        entries.forEach(function(entry) {
          if (entry.isIntersecting) {
            entry.target.style.opacity = '1';
            entry.target.style.transform = 'translateY(0)';
            observer.unobserve(entry.target);
          }
        });
      }, { threshold: 0.1, rootMargin: '0px 0px -50px 0px' });
      items.forEach(function(el) { observer.observe(el); });
    }
    // Fallback: через 3 секунды показать все элементы
    setTimeout(function() {
      items.forEach(function(el) {
        el.style.opacity = '1';
        el.style.transform = 'translateY(0)';
      });
    }, 3000);
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

  // ===== XSS PROTECTION =====
  // Экранирует HTML-сущности при вставке в DOM.
  // Не удаляет символы — пользователь может вводить < и >.
  function escapeHtml(s) {
    var d = document.createElement('div');
    d.appendChild(document.createTextNode(s));
    return d.innerHTML;
  }

  // ===== EMAIL VALIDATION =====
  function isValidEmail(email) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  }

  // ===== CLEANUP =====
  window.addEventListener('pagehide', function() {
    _carouselIntervals.forEach(function(id) { clearInterval(id); });
    _carouselIntervals = [];
  });
})();
