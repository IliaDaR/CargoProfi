# QA-АУДИТ САЙТА Numino (Полный)

**Дата:** 31.05.2026  
**Аудитор:** QA Инженер  
**Объект:** Весь фронтенд сайта → папка `website/`  

---

## СОДЕРЖАНИЕ

1. [ЛЕНДИНГ — Полная проверка](#1-лендинг)
2. [CSS — Полный аудит](#2-css)
3. [JavaScript — Полный аудит](#3-javascript)
4. [АВТОРИЗАЦИЯ — Полный аудит потока](#4-авторизация)
5. [АДМИНКА Flutter Web — Итоги](#5-flutter-web-админка)
6. [ВЫВОДЫ И РЕКОМЕНДАЦИИ](#6-выводы)

---

## 1. ЛЕНДИНГ

### 1.1 Структура страницы (все секции)

| # | Секция | Строки | Статус | Примечание |
|---|---|---|---|---|
| 1 | Header | 17–31 | ✅ | Лого, нав, кнопка "Войти" |
| 2 | Hero | 34–53 | ✅ | Заголовок, описание, CTA, 3 stats |
| 3 | Features (карусель) | 56–169 | ✅ | 6 карточек возможностей |
| 4 | How (карусель) | 172–193 | ✅ | 4 шага |
| 5 | Pricing | 196–243 | ✅ | 3 тарифа |
| 6 | Download (APK) | 246–261 | ✅ | Ссылка на GitHub Releases |
| 7 | Testimonials | 264–274 | ✅ | 1 отзыв |
| 8 | Contact | 277–301 | ✅ | Форма + email/телефон |
| 9 | Footer | 304–314 | ✅ | Навигация, копирайт |
| 10 | Login Modal | 317–333 | ✅ | Форма входа/регистрации |

### 1.2 Битая или нерабочая ссылка

| Проблема | Расположение | Строка | Описание |
|---|---|---|---|
| 🔴 **Битая ссылка #login** | Футер | 311 | `<a href="#login" class="login-btn">` — на странице НЕТ элемента с `id="login"`. JS перехватывает клик по классу, но href битый. Скролл в никуда. |
| 🟡 **Пустой _next у формы** | Contact Form | 297 | `<input type="hidden" name="_next" value="">` — после отправки FormSubmit перенаправит на пустой URL. Лучше указать `window.location.href` или текущую страницу. |
| 🟡 **Лого ведёт на #** | Header | 19 | `<a href="#">` — не возвращает наверх. Лучше `href="/"` или `href="#top"`. |

### 1.3 SEO

| Критерий | Статус | Комментарий |
|---|---|---|
| Title | ✅ | `Numino — Рабочий кабинет перевозчика` |
| Meta description | ✅ | Описание есть (65+ слов) |
| Meta keywords | 🟡 | Отсутствуют (не критично для Google) |
| Open Graph (og:) | ❌ | **НЕТ** ни одного og-тега (og:title, og:description, og:image, og:url) |
| Twitter Card | ❌ | НЕТ |
| Canonical URL | ❌ | НЕТ |
| h1 на странице | ✅ | 1 h1 в Hero |
| Структура заголовков | 🟡 | h2 OK, но в card и li нет h3/h4 (используются class вместо семантики) |
| alt у изображений | 🟡 | Есть только у логотипа. У dashboard-preview.svg (строка 51) и app-mockup.svg (строка 249) alt пустые или отсутствуют |
| lang="ru" | ✅ | Есть |
| favicon | ✅ | Есть SVG |

### 1.4 Accessibility (A11y)

| Критерий | Статус | Комментарий |
|---|---|---|
| Атрибуты aria у модалки | ✅ | `role="dialog"`, `aria-modal="true"`, `aria-labelledby="modalTitle"` |
| aria-label у кнопок карусели | ✅ | `aria-label="Предыдущий/Следующий"` |
| Скрытый текст для скринридеров | ✅ | Класс `.sr-only` определён |
| Focus trap в модалке | ✅ | Реализован на строках 46–53 |
| Закрытие Escape | ✅ | На строке 41 |
| Tab index на honeypot | 🟡 | Строка 152: `hp.tabIndex = -1` — хорошо, но honeypot не скрыт от скринридера |
| Цветовой контраст | 🟡 | `color: rgba(255,255,255,.35)` в футере (строка 120 CSS) на фоне `#0a0f1a` — **очень низкий контраст** |
| Метки у полей формы в модалке | 🟡 | Используются `<label>`, но они не связаны с input через `for`/`id` |

### 1.5 Performance

| Критерий | Статус | Комментарий |
|---|---|---|
| Google Fonts preconnect | ✅ | Строки 10–12 |
| CSS в начале (head) | ✅ | Строка 13 |
| JS в конце (body) | ✅ | Строка 335 |
| Изображения SVG | ✅ | Все иконки/картинки в SVG (лёгкие) |
| Ленивая загрузка | ❌ | `loading="lazy"` не используется нигде |
| CSS минификация | ❌ | style.css в читаемом виде (164 строки) |
| JS минификация | ❌ | main.js в читаемом виде (281 строка) |

### 1.6 Security

| Критерий | Статус | Комментарий |
|---|---|---|
| FormSubmit CAPTCHA | ✅ | `_captcha = "true"` (строка 296) |
| Honey-pot | ✅ | Скрытое поле для ботов (строка 148–154) |
| Sanitize input | ✅ | Функция `sanitize()` удаляет `<>` (строка 273) |
| referrer policy | ✅ | `no-referrer` (строка 8) |
| Пароль minlength | ✅ | 6 символов в HTML |
| XSS в redirect | 🟡 | URL параметры кодируются через `encodeURIComponent` — хорошо |

### 1.7 Mobile Responsiveness

| Критерий | Статус | Комментарий |
|---|---|---|
| viewport meta | ✅ | `width=device-width, initial-scale=1.0` |
| Брейкпоинт 900px | ✅ | Hero/Download → 1 колонка |
| Брейкпоинт 800px | ✅ | Нав скрывается, тарифы → 1 колонка, контакт → 1 колонка |
| Брейкпоинт 500px | ✅ | Уменьшение шрифтов |
| Navigation на мобильных | ❌ | **НЕТ гамбургер-меню!** Навигация просто скрывается (`display:none`) |

---

## 2. CSS

### 2.1 Общее состояние

- ✅ Цветовая система через CSS-переменные — отлично
- ✅ 7 оттенков серого (от 50 до 900)
- ✅ Inter + резервные шрифты
- ✅ Анимации и transition
- ✅ Ховер-эффекты на карточках, кнопках, планах
- ✅ Стилизация модального окна с анимацией появления (keyframes `in`)
- ✅ Стилизация карусели (dots, кнопки навигации)

### 2.2 Найденные проблемы

| # | Проблема | Строка CSS | Серьёзность |
|---|---|---|---|
| 1 | `.gradient` использует `-webkit-text-fill-color: transparent` без fallback `color: transparent` | 18 | 🟡 Средняя |
| 2 | Контраст текста в футере `rgba(255,255,255,.35)` на `#0a0f1a` — коэффициент ~2.5:1 (нужно min 4.5:1) | 120 | 🟡 Средняя |
| 3 | Бургер-меню отсутствует — навигация просто `display:none` на <800px | 156 | 🔴 Высокая |
| 4 | Нет стилей для принта (print media query) | — | 🟢 Низкая |
| 5 | Нет `prefers-reduced-motion` для доступности | — | 🟢 Низкая |

---

## 3. JAVASCRIPT

### 3.1 Общее состояние

- ✅ Модальное окно работает (открытие/закрытие/Escape/focus trap)
- ✅ 2 карусели (фичи + шаги) с автопрокруткой, свайпом, драгом
- ✅ Scroll-анимации (появление элементов при скролле)
- ✅ Smooth scroll для якорных ссылок
- ✅ Санитизация ввода (удаление `<>`)
- ✅ Honey-pot для защиты от спама
- ✅ Registration flow (создание owner в localStorage)

### 3.2 Найденные проблемы и ошибки

#### 🔴 КРИТИЧЕСКАЯ: Несоответствие роли admin

| Файл | Роль admin |
|---|---|
| `main.js` строка 95 | `role: 'admin'` |
| Flutter `local_storage.dart` строка 53 | `role: 'superadmin'` |

**Последствия:** При логине с лендинга `main.js` передаёт в URL `role=admin`. Flutter Web на `AuthGate` (main.dart строка 98-99) проверяет `role == 'admin' || role == 'superadmin'` — это работает, но только если URL параметры корректно спарсятся.

Но: `_parseQueryParams()` в main.dart (строки 77-90) использует `Uri.base.query` — **на Flutter Web есть известный баг**, когда `Uri.base.queryParameters` возвращает пустой словарь после горячей перезагрузки или при определённых условиях.

**Текущий код парсинга на Flutter:**
```dart
Map<String, String> _parseQueryParams() {
    try {
      final search = Uri.base.query;
      if (search.isNotEmpty) return Uri.splitQueryString(search);
    } catch (_) {}
    try {
      final p = Uri.base.queryParameters;
      if (p.isNotEmpty) return Map<String, String>.from(p);
    } catch (_) {}
    return {};
}
```

**Рекомендация:** Нужно использовать `dart:html` (через conditional import) для надёжного получения query-строки на Flutter Web:
```dart
import 'dart:html' show window;
// ...
final params = Uri.splitQueryString(window.location.search);
```

#### 🟡 СРЕДНЯЯ: Регистрация после успеха — хак

Строка 123 main.js:
```javascript
isReg = true; document.getElementById('showRegister').click(); // переключаем на режим входа
```

После успешной регистрации код вручную переключает на страницу логина через имитацию клика. Это **хрупкий хак**: если кнопка `showRegister` изменит поведение, сломается.

**Рекомендация:** Рефакторинг: вынести переключение в отдельную функцию:
```javascript
function switchToLogin() { 
  isReg = false;
  // обновляем UI...
}
```

#### 🟡 СРЕДНЯЯ: Пароль не скрывается в логах/ошибках

Строка 128-129 в main.js: при ошибке логина сообщение 'Неверный email или пароль' — хорошая практика (не говорит, что именно неверно). ✅

Но: пароль передаётся в localStorage в открытом виде (строка 119 `pass: pass`), хотя это только клиентская демо-версия.

#### 🟢 НИЗКАЯ: Дублирование кода каруселей

Две карусели используют одну фабричную функцию `createCarousel` — ✅ хорошо.

#### 🟢 НИЗКАЯ: Нет обработки offline

Нет проверки `navigator.onLine` для форм.

---

## 4. АВТОРИЗАЦИЯ

### 4.1 Полный поток входа

```
ЛЕНДИНГ (index.html)
    │
    ├── Кнопка "Войти" → Модалка
    │   ├── Ввод email/пароля
    │   ├── main.js проверяет localStorage (numino_users)
    │   └── УСПЕХ: window.location.href = 'admin/index.html?role=...&email=...&name=...'
    │
    ├── ИЛИ "Зарегистрироваться" → Создаёт owner (role: 'owner')
    │
    └── ИЛИ кнопка "Скачать приложение" → GitHub Releases

ADMIN (Flutter Web)
    │
    ├── AuthGate (main.dart)
    │   ├── _parseQueryParams() — получает role, email, name из URL
    │   ├── findUserByEmail() — ищет в SharedPreferences (другое хранилище!)
    │   ├── setCurrentUser() — сохраняет сессию
    │   └── Проверка роли:
    │       ├── admin/superadmin → SuperadminScreen
    │       └── owner → OwnerDashboardScreen
    │
    └── Если URL пустой → RoleScreen (две кнопки: Владелец / Водитель)
```

### 4.2 Критические баги в потоке авторизации

| # | Баг | Где | Серьёзность | Описание |
|---|---|---|---|---|
| 1 | **URL парсинг может вернуть пустоту** | main.dart `_parseQueryParams()` | 🔴 | Известный баг Flutter Web — `Uri.base` часто теряет query params. В результате админ с лендинга попадает на RoleScreen, а не в кабинет. |
| 2 | **Несоответствие роли admin** | main.js (admin) vs local_storage.dart (superadmin) | 🔴 | main.js передаёт `role=admin`, Flutter определяет суперадмина как `role=superadmin`. Только костыль `role == 'admin' || role == 'superadmin'` спасает. |
| 3 | **Два независимых хранилища** | localStorage (браузер) vs SharedPreferences (Flutter) | 🟡 | Пользователи из браузера (`numino_users`) никак не связаны с пользователями в Flutter. При входе с лендинга Flutter ищет email в SharedPreferences — если там нет такого пользователя, данные берутся только из URL. |
| 4 | **Нет "Водителя" на сайте** | index.html | 🟢 | В модалке нет кнопки/выбора "войти как водитель". Водители заходят только через Android приложение. OK для текущей задачи, но нужно документировать. |

### 4.3 Детальный trace admin@numino.ru → SuperadminScreen

```
1. Пользователь вводит admin@numino.ru / admin123 в модалке
2. main.js строка 94: users['admin@numino.ru'] = {pass: 'admin123', name: 'Администратор', role: 'admin'}
3. main.js строка 95: role = 'admin'
   ✅ Пароль совпадает → УСПЕХ
4. main.js строка 140: redirect → admin/index.html?role=admin&email=admin%40numino.ru&name=%D0%90%D0%B4%D0%BC%D0%B8%D0%BD%D0%B8%D1%81%D1%82%D1%80%D0%B0%D1%82%D0%BE%D1%80
5. Flutter AuthGate._init() вызывается
6. _parseQueryParams() пытается прочитать URL
   ⚠️ ЕСЛИ успешно: params = {role: 'admin', email: 'admin@numino.ru', name: 'Администратор'}
      → findUserByEmail('admin@numino.ru') ищет в SharedPreferences
      → local_storage.dart строка 53: 'superadmin'
      → setCurrentUser c role='superadmin'
      → main.dart строка 99: role == 'admin' || role == 'superadmin' → true → SuperadminScreen
   ❌ ЕСЛИ ошибка: params = {} (пусто)
      → currentUser = null
      → main.dart строка 106: RoleScreen (выбор роли)
      → пользователь вручную выбирает "Владелец автопарка"
      → вводит admin@numino.ru/admin123
      → findUser возвращает {role: 'superadmin'}
      → role_screen.dart строка 100: widget.role == 'owner' (кнопка владельца) → true
      → OwnerDashboardScreen ❌❌❌ (должен быть SuperadminScreen!)
```

### 4.4 Итог по авторизации

| Пользователь | Ожидаемый экран | Фактический результат | Статус |
|---|---|---|---|
| admin@numino.ru / admin123 | SuperadminScreen (админка) | ✅ **SuperadminScreen** — если URL параметры спарсились | 🟡 |
|  |  | ❌ **OwnerDashboardScreen** — если URL пустой (надо вводить в RoleScreen) | 🔴 |
| owner@numino.ru / owner123 | OwnerDashboardScreen | ✅ Всегда OwnerDashboardScreen | ✅ |
| driver@numino.ru / driver123 | Только Android | ✅ На сайте нет входа для водителя | ✅ |

---

## 5. FLUTTER WEB АДМИНКА

### 5.1 Файловая структура admin/

```
website/admin/
├── index.html          ✅ (200 OK)
├── main.dart.js        ✅ (200 OK) ~9 MB
├── flutter_bootstrap.js ✅
├── flutter.js          ✅
├── manifest.json       ✅
├── version.json        ✅
├── flutter_service_worker.js ✅
├── favicon.png         ✅
├── assets/             ✅ (шрифты, MaterialIcons)
├── canvaskit/          ✅ (wasm, js)
└── icons/              ✅
```

Все файлы доступны по HTTP 200. ✅

### 5.2 Логи с сервера (зафиксированы)

```
09:26:40 GET /admin/index.html?role=admin&email=admin%40numino.ru&name=%D0%90%D0%B4%D0%BC%D0%B8%D0%BD%D0%B8%D1%81%D1%82%D1%80%D0%B0%D1%82%D0%BE%D1%80 → 200
09:26:40 GET /admin/main.dart.js → 200
09:26:41 GET /admin/assets/FontManifest.json → 200
09:26:41 GET /admin/assets/fonts/MaterialIcons-Regular.otf → 200
```

Flutter Web загружается и работает. ✅

---

## 6. ВЫВОДЫ

### 6.1 Что работает отлично ✅

| Компонент | Статус |
|---|---|
| Лендинг — все 9 секций | ✅ |
| Модальное окно входа/регистрации | ✅ |
| Карусели (фичи + шаги) | ✅ |
| Scroll-анимации | ✅ |
| Форма контактов (FormSubmit) | ✅ |
| Тарифы (3 плана) | ✅ |
| Скачать APK (GitHub) | ✅ |
| CSS — цвета, шрифты, адаптив | ✅ |
| Flutter Web админка загружается | ✅ |
| Защита от XSS (sanitize) | ✅ |

### 6.2 Что нужно исправить (критическое) 🔴

| # | Проблема | Приоритет | Рекомендация |
|---|---|---|---|
| 1 | **URL парсинг на Flutter Web** | 🔴 HIGH | Использовать `dart:html` `window.location.search` в main.dart `_parseQueryParams()` |
| 2 | **Несоответствие роли admin/superadmin** | 🔴 HIGH | Унифицировать: или везде `admin`, или везде `superadmin` |
| 3 | **Редирект после регистрации через хак** | 🟡 MED | Вынести переключение режимов в чистую функцию |

### 6.3 Что улучшить (среднее) 🟡

| # | Проблема | Приоритет | Рекомендация |
|---|---|---|---|
| 1 | **Нет бургер-меню на мобильных** | 🟡 MED | Добавить гамбургер и боковое меню для <800px |
| 2 | **Битая ссылка #login в футере** | 🟡 MED | Убрать href или заменить на `#` |
| 3 | **Нет og-тегов** | 🟡 MED | Добавить Open Graph и Twitter Card для шаринга |
| 4 | **Пустой _next в форме** | 🟡 MED | Указать `window.location.href` как _next |
| 5 | **alt у svq-изображений пустые** | 🟡 MED | Добавить описательные alt тексты |
| 6 | **Контраст футера** | 🟡 MED | Увеличить opacity текста в футере с .35 до .65+ |
| 7 | **gradient без fallback** | 🟡 MED | Добавить `color: transparent` для Firefox |

### 6.4 Рекомендации (низкие) 🟢

| # | Предложение |
|---|---|
| 1 | Добавить `loading="lazy"` на изображения |
| 2 | Добавить `prefers-reduced-motion` для доступности |
| 3 | Минифицировать CSS/JS перед продакшеном |
| 4 | Добавить print media query |

---

## Финальная оценка: **7.5/10**

Сайт функционально работает, лендинг красивый и современный. Основные проблемы — в авторизационном потоке между лендингом и Flutter Web админкой. После исправления URL-парсинга и унификации ролей сайт будет готов к продакшену.

---

*Аудит выполнен: 31.05.2026*
