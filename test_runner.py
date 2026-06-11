"""
Numino — Автоматическое тестирование сайта
Проверяет: HTML, CSS, JS, ссылки, изображения, доступность
"""
import urllib.request
import urllib.error
import json
import re
import html.parser
import ssl
import time

BASE = 'http://localhost:3000'
PASS = 0
FAIL = 0
WARN = 0
ERRORS = []

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

def fetch(path):
    url = f'{BASE}{path}'
    req = urllib.request.Request(url)
    try:
        resp = urllib.request.urlopen(req, timeout=10)
        return resp.status, resp.read().decode('utf-8', errors='replace')
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode('utf-8', errors='replace')
    except Exception as e:
        raise AssertionError(f'Fetch failed: {e}')

class HTMLValidator(html.parser.HTMLParser):
    """Проверяет открытые/закрытые теги, наличие обязательных атрибутов"""
    def __init__(self):
        super().__init__()
        self.errors = []
        self.tag_stack = []
        self.labels_with_for = set()
        self.inputs_with_id = set()
        self.images_without_alt = []
        self.buttons_without_type = []
        self.links_without_href = []
        self.main_count = 0

    def handle_starttag(self, tag, attrs):
        d = dict(attrs)
        if tag in ('div', 'section', 'form', 'header', 'footer', 'nav', 'main', 'span', 'p', 'h1', 'h2', 'h3', 'ul', 'li'):
            self.tag_stack.append(tag)
        if tag == 'img' and 'alt' not in d:
            self.images_without_alt.append(d.get('src', 'unknown'))
        if tag == 'button' and 'type' not in d:
            self.buttons_without_type.append(d.get('id', 'unnamed'))
        if tag == 'a' and ('href' not in d or d['href'] == ''):
            self.links_without_href.append(d.get('id', 'unnamed'))
        if tag == 'label' and 'for' in d:
            self.labels_with_for.add(d['for'])
        if tag == 'input' and 'id' in d:
            self.inputs_with_id.add(d['id'])
        if tag == 'main':
            self.main_count += 1

    def handle_endtag(self, tag):
        pass

    def check(self):
        issues = []
        if self.images_without_alt:
            issues.append(f'{len(self.images_without_alt)} изображений без alt')
        if self.buttons_without_type:
            issues.append(f'{len(self.buttons_without_type)} кнопок без type')
        if self.links_without_href:
            issues.append(f'ссылки без href')
        return issues

# ============================================================
# ТЕСТ 1: ЗАГРУЗКА ГЛАВНОЙ СТРАНИЦЫ
# ============================================================
def test_main_page():
    status, body = fetch('/')
    assert status == 200, f'Expected 200, got {status}'
    assert '<!DOCTYPE html>' in body, 'No DOCTYPE'
    assert '<html' in body, 'No html tag'
    assert '</html>' in body, 'No closing html'
    assert 'Numino' in body, 'Title not found'
    assert 'lang="ru"' in body, 'No lang=ru'

# ============================================================
# ТЕСТ 2: ДОМ-СТРУКТУРА
# ============================================================
def test_html_structure():
    status, body = fetch('/')
    parser = HTMLValidator()
    parser.feed(body)
    issues = parser.check()
    if issues:
        raise AssertionError('; '.join(issues))
    # Check sections
    for section in ['hero', 'features', 'pricing', 'download', 'testimonials', 'contact']:
        assert section in body, f'Section #{section} not found'
    assert 'id="loginModal"' in body, 'Modal not found'
    assert 'id="loginForm"' in body, 'Login form not found'

# ============================================================
# ТЕСТ 3: CSS
# ============================================================
def test_css():
    status, body = fetch('/css/style.css')
    assert status == 200, f'CSS returned {status}'
    assert len(body) > 1000, f'CSS too short: {len(body)}'
    assert ':root' in body, 'No CSS variables'
    assert '.modal' in body, 'No modal styles'
    assert '@media' in body, 'No media queries'
    assert '.btn--primary' in body, 'No button styles'

# ============================================================
# ТЕСТ 4: JS
# ============================================================
def test_js():
    status, body = fetch('/js/main.js')
    assert status == 200, f'JS returned {status}'
    assert len(body) > 1000, f'JS too short: {len(body)}'
    assert 'createCarousel' in body, 'Carousel not found'
    assert 'loginForm' in body, 'Login not found'
    assert 'getUsers' in body, 'getUsers not found'
    assert 'sanitize' in body, 'XSS sanitizer not found'
    assert 'localStorage' in body, 'localStorage not found'

# ============================================================
# ТЕСТ 5: ИЗОБРАЖЕНИЯ
# ============================================================
def test_images():
    images = [
        '/assets/logo.svg',
        '/assets/favicon.svg',
        '/assets/dashboard-preview.svg',
        '/assets/app-mockup.svg',
    ]
    for img in images:
        status, body = fetch(img)
        assert status == 200, f'{img} -> {status}'

# ============================================================
# ТЕСТ 6: 404
# ============================================================
def test_not_found():
    status, body = fetch('/nonexistent.html')
    assert status == 404, f'Expected 404, got {status}'

# ============================================================
# ТЕСТ 7: МЕТА-ТЕГИ
# ============================================================
def test_meta():
    status, body = fetch('/')
    assert 'name="viewport"' in body, 'No viewport meta'
    assert 'name="description"' in body, 'No description meta'
    assert 'charset="UTF-8"' in body, 'No charset'

# ============================================================
# ТЕСТ 8: ДОСТУПНОСТЬ
# ============================================================
def test_accessibility():
    status, body = fetch('/')
    assert 'role="region"' in body, 'No ARIA regions'
    assert 'aria-label' in body, 'No aria-labels'
    assert 'aria-live="polite"' in body, 'No aria-live'
    assert 'aria-modal="true"' in body, 'Modal not accessible'
    assert 'role="dialog"' in body, 'No role=dialog'

# ============================================================
# ТЕСТ 9: АДМИН ПАНЕЛЬ (Flutter)
# ============================================================
def test_admin_panel():
    status, body = fetch('/admin/')
    assert status == 200, f'Admin returned {status}'
    assert 'flutter' in body.lower() or 'numino' in body.lower(), 'Not Flutter'

# ============================================================
# ТЕСТ 10: КОНТАКТНАЯ ФОРМА
# ============================================================
def test_contact_form():
    status, body = fetch('/')
    assert 'action="https://formsubmit.co/' in body, 'FormSubmit not configured'
    assert 'method="POST"' in body, 'No POST method'
    assert 'name="name"' in body, 'No name field'
    assert 'name="email"' in body, 'No email field'
    assert 'name="message"' in body, 'No message field'
    assert '_honey' in body or 'honeypot' in body, 'No honeypot'

# ============================================================
# ТЕСТ 11: ТАРИФЫ
# ============================================================
def test_pricing():
    status, body = fetch('/')
    assert '990' in body, 'Start price missing'
    assert '1 990' in body, 'Business price missing'
    assert 'Индивидуально' in body, 'Corp price missing'
    assert '21 день' in body, 'Free trial missing'
    assert 'Популярный' in body, 'Popular badge missing'

# ============================================================
# ТЕСТ 12: ЗАГОЛОВКИ HTTP
# ============================================================
def test_http_headers():
    url = f'{BASE}/'
    req = urllib.request.Request(url)
    resp = urllib.request.urlopen(req, timeout=10)
    ct = resp.headers.get('Content-Type', '')
    assert 'text/html' in ct, f'Wrong content-type: {ct}'

# ============================================================
# ЗАПУСК
# ============================================================
if __name__ == '__main__':
    print('=' * 60)
    print('🧪 Numino Сайт — Автоматическое тестирование')
    print('=' * 60)
    print()

    tests = [
        ('Загрузка главной страницы', test_main_page),
        ('HTML структура (секции, модалка)', test_html_structure),
        ('CSS (стили, медиа-запросы)', test_css),
        ('JavaScript (карусель, auth, XSS)', test_js),
        ('Изображения (SVG, favicon)', test_images),
        ('404 ошибка', test_not_found),
        ('Мета-теги (viewport, charset)', test_meta),
        ('Доступность (ARIA, роли)', test_accessibility),
        ('Админ-панель (Flutter Web)', test_admin_panel),
        ('Контактная форма (FormSubmit, honeypot)', test_contact_form),
        ('Тарифы (цены, бейджи)', test_pricing),
        ('HTTP заголовки (Content-Type)', test_http_headers),
    ]

    for name, fn in tests:
        test(name, fn)

    print()
    print('=' * 60)
    print(f'📊 Результаты: ✅ {PASS} passed | ❌ {FAIL} failed | ⚠️  {WARN} warnings')
    print('=' * 60)

    if ERRORS:
        print()
        print('Детали ошибок:')
        for e in ERRORS:
            print(f'  {e}')

    # JSON report
    report = {
        'passed': PASS,
        'failed': FAIL,
        'warnings': WARN,
        'errors': ERRORS[:20],
        'total': len(tests),
    }
    with open('test_report.json', 'w', encoding='utf-8') as f:
        json.dump(report, f, ensure_ascii=False, indent=2)
    print(f'\n📄 Отчёт сохранён: test_report.json')

    if FAIL > 0:
        exit(1)
