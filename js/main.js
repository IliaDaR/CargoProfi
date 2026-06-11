/*!
 * Numino Landing — minimal / secure
 * No analytics, no third-party trackers.
 */

(function () {
  'use strict';

  // ===== РЕФЕРАЛЬНЫЙ КОД =====
  var refCode = new URLSearchParams(window.location.search).get('ref');
  if (refCode) { localStorage.setItem('numino_ref', refCode); }

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
  // Модалка входа удалена — вход через отдельную страницу /login.html

  // ===== ХЭШ-ПАРОЛЬ (SHA-256, async) =====
  async function hashPassword(pass, salt) {
    if (window.crypto && window.crypto.subtle) {
      var buf = new TextEncoder().encode((salt || '') + pass);
      var hash = await window.crypto.subtle.digest('SHA-256', buf);
      return Array.from(new Uint8Array(hash)).map(function(b) { return b.toString(16).padStart(2, '0'); }).join('');
    }
    // Fallback без crypto — сохраняем как есть (демо-режим)
    return 'plain:' + pass;
  }

  function generateSalt() {
    var bytes = new Uint8Array(16);
    window.crypto.getRandomValues(bytes);
    return Array.from(bytes).map(function(b) { return b.toString(16).padStart(2,'0'); }).join('');
  }

  async function verifyPassword(pass, storedHash, storedSalt) {
    if (storedSalt) return await hashPassword(pass, storedSalt) === storedHash;
    return await hashPassword(pass, '') === storedHash;
  }

  // SharedPreferences на Flutter Web добавляет префикс "flutter." ко всем ключам
  function getUsers() {
    try { return JSON.parse(localStorage.getItem('flutter.numino_users')) || {}; } catch(_) { return {}; }
  }
  function saveUsers(u) { localStorage.setItem('flutter.numino_users', JSON.stringify(u)); }

  // Предустановленные аккаунты (пароли хэшируются)
  (async function() {
    var u = getUsers();
    if (!u['admin@numino.ru']) {
      u['admin@numino.ru'] = { pass: await hashPassword('admin123', 'fixed_salt_admin_01'), passSalt: 'fixed_salt_admin_01', name: 'Администратор', role: 'admin' };
      u['owner@numino.ru'] = { pass: await hashPassword('owner123', 'fixed_salt_owner_01'), passSalt: 'fixed_salt_owner_01', name: 'Владелец парка', role: 'owner' };
      saveUsers(u);
    }
  })();

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
        localStorage.setItem('flutter.tickets', JSON.stringify(tickets));
      }
      // Визуальная обратная связь
      var btn = contactForm.querySelector('button[type="submit"]');
      if (btn) { btn.textContent = 'Отправляется...'; btn.disabled = true;
        setTimeout(function() { if (btn) { btn.textContent = 'Отправить'; btn.disabled = false; } }, 3000); }
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
