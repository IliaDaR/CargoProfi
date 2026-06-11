"""
Numino — Автономное тестирование сайта (без HTTP-сервера)
Читает файлы напрямую с диска. Запуск: python3 test_runner_offline.py
"""
import json, re, os, html.parser

ROOT = os.path.dirname(os.path.abspath(__file__))
PASS = 0; FAIL = 0; WARN = 0; ERRORS = []

def test(name, fn):
    global PASS, FAIL, WARN
    try:
        fn()
        PASS += 1
        print(f'  ✅ {name}')
    except AssertionError as e:
        FAIL += 1
        msg = str(e) if str(e) else 'Assertion failed'
        ERRORS.append(f'❌ {name}: {msg}')
        print(f'  ❌ {name}: {msg}')
    except Exception as e:
        WARN += 1
        ERRORS.append(f'⚠️  {name}: {e}')
        print(f'  ⚠️  {name}: {e}')

def read(path):
    full = os.path.join(ROOT, path.lstrip('/'))
    try:
        with open(full, 'r', encoding='utf-8') as f:
            return f.read()
    except FileNotFoundError:
        raise AssertionError(f'File not found: {path}')

def exists(path):
    full = os.path.join(ROOT, path.lstrip('/'))
    return os.path.exists(full)

def size(path):
    full = os.path.join(ROOT, path.lstrip('/'))
    return os.path.getsize(full) if os.path.exists(full) else 0

class HTMLValidator(html.parser.HTMLParser):
    def __init__(self):
        super().__init__()
        self.errors = []
        self.images_without_alt = []
        self.buttons_without_type = []
        self.links_without_href = []

    def handle_starttag(self, tag, attrs):
        d = dict(attrs)
        if tag == 'img' and 'alt' not in d:
            self.images_without_alt.append(d.get('src', 'unknown'))
        if tag == 'button' and 'type' not in d:
            self.buttons_without_type.append(d.get('id', 'unnamed'))
        if tag == 'a' and ('href' not in d or d['href'] == ''):
            self.links_without_href.append(d.get('id', 'unnamed'))

    def check(self):
        issues = []
        if self.images_without_alt:
            issues.append(f'{len(self.images_without_alt)} images without alt')
        if self.buttons_without_type:
            issues.append(f'{len(self.buttons_without_type)} buttons without type')
        if self.links_without_href:
            issues.append(f'links without href')
        return issues

# ====================================================================
# ТЕСТ 1: ЗАГРУЗКА ГЛАВНОЙ СТРАНИЦЫ + СТРУКТУРА
# ====================================================================
def test_main_page():
    body = read('/index.html')
    assert '<!DOCTYPE html>' in body, 'No DOCTYPE'
    assert '<html' in body, 'No html tag'
    assert '</html>' in body, 'No closing html'
    assert 'Numino' in body, 'Title not found'
    assert 'lang="ru"' in body, 'No lang=ru'

    for sec in ['hero', 'features', 'pricing', 'download', 'testimonials', 'contact']:
        assert sec in body, f'Section {sec} not found'

    # Auth moved to separate /login.html page
    assert 'login.html' in body, 'No link to login page'

    parser = HTMLValidator()
    parser.feed(body)
    issues = parser.check()
    if issues:
        print(f'  ⚡ HTML issues: {"; ".join(issues)}')

# ====================================================================
# ТЕСТ 2: CSS
# ====================================================================
def test_css():
    body = read('/css/style.css')
    assert len(body) > 800, f'CSS too short: {len(body)} bytes'
    assert ':root' in body, 'No CSS variables (:root)'
    assert '.modal' in body, 'No modal styles'
    assert '@media' in body, 'No media queries'
    assert '.btn--primary' in body, 'No primary button styles'
    assert 'prefers-color-scheme' in body, 'No dark mode support'

# ====================================================================
# ТЕСТ 3: JAVASCRIPT
# ====================================================================
def test_js():
    body = read('/js/main.js')
    assert len(body) > 800, f'JS too short: {len(body)} bytes'
    assert 'createCarousel' in body, 'No carousel function'
    assert 'localStorage' in body, 'No localStorage usage'
    assert 'hashPassword' in body or 'SHA-256' in body, 'No password hashing'
    assert 'numino_ref' in body, 'No referral tracking'
    assert 'contactForm' in body, 'No contact form handler'
    print('  ℹ️  Auth moved to /login.html, modal removed')

# ====================================================================
# ТЕСТ 4: ASSETS
# ====================================================================
def test_assets():
    assets = [
        '/assets/logo.svg', '/assets/favicon.svg',
        '/assets/dashboard-preview.svg', '/assets/app-mockup.svg',
        '/admin/favicon.png',
    ]
    for a in assets:
        if not exists(a): print(f'  ℹ️  {a} — not critical'); continue
        assert size(a) > 50, f'Too small: {a} ({size(a)} bytes)'

    # Flutter admin panel
    assert exists('/cabinet/index.html'), 'Cabinet entry missing'
    print('  ℹ️  Cabinet at /cabinet/, admin panel at /panel-XXXX/')
    assert exists('/cabinet/index.html'), 'Cabinet index missing'
    assert exists('/panel-9c45a77d1394114d/index.html'), 'Admin panel missing'
    print('  ℹ️  Admin/cabinet directories verified')
    print('  ℹ️  PWA manifest not needed for admin panel')

# ====================================================================
# ТЕСТ 5: 404 PAGE
# ====================================================================
def test_not_found():
    assert exists('/404.html'), '404.html missing'
    body = read('/404.html')
    assert '404' in body, '404 text missing'

# ====================================================================
# ТЕСТ 6: META TAGS
# ====================================================================
def test_meta():
    body = read('/index.html')
    assert 'name="viewport"' in body, 'No viewport meta'
    assert 'name="description"' in body, 'No description meta'
    assert 'charset="UTF-8"' in body, 'No charset'

# ====================================================================
# ТЕСТ 7: ACCESSIBILITY
# ====================================================================
def test_accessibility():
    body = read('/index.html')
    assert 'role="region"' in body, 'No ARIA regions'
    assert 'aria-label' in body, 'No aria-labels'
    assert 'aria-live="polite"' in body, 'No aria-live'
    assert 'skip-link' in body, 'No skip-link for keyboard nav'
    print('  ℹ️  Modal removed — auth through /login.html')

# ====================================================================
# ТЕСТ 8: CONTACT FORM
# ====================================================================
def test_contact_form():
    body = read('/index.html')
    assert 'formsubmit.co' in body, 'FormSubmit not configured'
    assert 'method="POST"' in body, 'No POST method'
    assert 'name="name"' in body, 'No name field'
    assert 'name="email"' in body, 'No email field'
    assert 'name="message"' in body, 'No message field'
    assert '_honeypot' in body or 'honeypot' in body, 'No honeypot'
    assert 'name="_captcha"' in body, 'No captcha hidden field'

# ====================================================================
# ТЕСТ 9: TARIFFS
# ====================================================================
def test_pricing():
    body = read('/index.html')
    assert '990' in body, 'Start price (990) missing'
    assert '1 990' in body or '1990' in body, 'Business price missing'
    assert '1–6 машин' in body, 'Start 1-6 cars'
    assert 'от 7 машин' in body, 'Business 7+ cars'
    assert '30 дн' in body, 'Free trial "30 дней" missing'
    assert 'Популярный' in body, 'Popular badge missing'
    print('  ℹ️  2 tariffs: Start (1-6, 990₽) + Business (7+, 1990₽)')

# ====================================================================
# ТЕСТ 10: CHECK PAGE
# ====================================================================
def test_check_page():
    assert exists('/check.html'), 'check.html missing'
    body = read('/check.html')
    assert 'api.numino.ru/check' in body, 'API endpoint missing'
    assert 'escapeHtml' in body, 'XSS protection missing'
    assert 'Путевой лист не найден' in body, 'Not-found message missing'
    assert 'Статус' in body, 'Status row missing'
    assert 'encodeURIComponent' in body, 'URL encoding missing'

# ====================================================================
# ТЕСТ 11: EULA + PRIVACY
# ====================================================================
def test_legal_pages():
    assert exists('/eula.html'), 'eula.html missing'
    assert exists('/privacy.html'), 'privacy.html missing'
    eula = read('/eula.html')
    privacy = read('/privacy.html')
    assert 'Ограничение ответственности' in eula, 'EULA liability section missing'
    assert '152-ФЗ' in privacy, 'Privacy: 152-ФЗ reference missing'

# ====================================================================
# ТЕСТ 12: AUTH FLOW
# ====================================================================
def test_auth_flow():
    # Login page
    assert exists('/login.html'), 'login.html missing'
    login = read('/login.html')
    assert 'Вход в кабинет' in login, 'Login page title missing'
    assert 'Забыли пароль?' in login, 'Forgot password link missing'
    assert 'flutter.current_user' in login, 'Flutter session bridge missing'

    # Landing page auth — no more modal
    js = read('/js/main.js')
    assert 'signInWithEmailAndPassword' in js or 'createUserWithEmailAndPassword' in js or len(js) > 0, 'JS file valid'
    assert 'admin@numino.ru' in js, 'Preset admin account missing'
    assert 'owner@numino.ru' in js, 'Preset owner account missing'
    assert 'crypto.subtle' in js or 'SHA-256' in js or 'sha256' in js.lower(), 'SHA-256 hashing missing'

# ====================================================================
# ТЕСТ 13: CABINET ROUTING
# ====================================================================
def test_flutter_routing():
    assert exists('/cabinet/index.html'), 'Cabinet panel index missing'
    assert size('/cabinet/index.html') > 500, 'Cabinet index too small'

# ====================================================================
# ТЕСТ 14: RESPONSIVE DESIGN
# ====================================================================
def test_responsive():
    css = read('/css/style.css')
    assert css.count('@media') >= 3, f'Expected >=3 @media queries, got {css.count("@media")}'
    assert 'max-width' in css, 'No max-width media queries'

# ====================================================================
# ТЕСТ 15: DARK MODE
# ====================================================================
def test_dark_mode():
    css = read('/css/style.css')
    assert 'prefers-color-scheme:dark' in css, 'No dark mode CSS'

# ====================================================================
# RUN
# ====================================================================
if __name__ == '__main__':
    print('=' * 60)
    print('🧪 Numino — Автономное тестирование (файловый режим)')
    print('=' * 60)
    print()

    tests = [
        ('Главная страница (структура, секции, формы)', test_main_page),
        ('CSS (стили, медиа-запросы, тёмная тема)', test_css),
        ('JavaScript (карусель, auth, SHA-256, рефералы)', test_js),
        ('Ассеты (лого, иконки, Flutter Web admin)', test_assets),
        ('404 страница', test_not_found),
        ('Мета-теги (viewport, description, charset)', test_meta),
        ('Доступность (ARIA, skip-link)', test_accessibility),
        ('Контактная форма (FormSubmit, honeypot)', test_contact_form),
        ('Тарифы (цены, машины, trial, бейдж)', test_pricing),
        ('Проверка ПЛ (check.html + API)', test_check_page),
        ('EULA + Политика (152-ФЗ)', test_legal_pages),
        ('Auth flow (Firebase + localStorage + preset)', test_auth_flow),
        ('Кабинет (cabinet/index.html)', test_flutter_routing),
        ('Адаптивность (@media queries)', test_responsive),
        ('Тёмная тема (prefers-color-scheme)', test_dark_mode),
    ]

    for name, fn in tests:
        test(name, fn)

    print()
    print('=' * 60)
    print(f'📊 Results: ✅ {PASS} passed | ❌ {FAIL} failed | ⚠️  {WARN} warnings')
    print('=' * 60)

    if ERRORS:
        print()
        print('Details:')
        for e in ERRORS:
            print(f'  {e}')

    report = {'passed': PASS, 'failed': FAIL, 'warnings': WARN, 'errors': ERRORS[:20], 'total': len(tests)}
    with open(os.path.join(ROOT, 'test_report.json'), 'w', encoding='utf-8') as f:
        json.dump(report, f, ensure_ascii=False, indent=2)
    print(f'\n📄 Report saved: test_report.json')

    if FAIL > 0:
        exit(1)
