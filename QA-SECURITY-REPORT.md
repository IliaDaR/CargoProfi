# 🔐 Аудит безопасности — CargoProfi (Numino)
*Дата: 30.05.2026*

---

## 1. 🏗️ ТЕКУЩАЯ АРХИТЕКТУРА (что изменилось)

После доработок в проекте появились **3 роли** и **2 отдельные панели**:

| Роль | Панель | Файл |
|---|---|---|
| **superadmin** | Админ-панель | `superadmin_screen.dart` |
| **owner** | Кабинет владельца | `owner_dashboard_screen.dart` |
| **driver** | Кабинет водителя | `driver_home_screen.dart` |

**Механизм входа:**
1. Лендинг → любой email/пароль → редирект в `admin/index.html?role=...`
2. Flutter Web App → `AuthGate` парсит URL → если `role=admin` → `SuperadminScreen`, иначе → `OwnerDashboardScreen`
3. На Android → `RoleScreen` (выбор роли) → логин → свой дашборд

**Демо-аккаунты** (в `local_storage.dart`):
```dart
admin@numino.ru / admin123 → superadmin
owner@numino.ru / owner123 → owner  
driver@numino.ru / driver123 → driver
```

---

## 2. 🔴 КРИТИЧЕСКИЕ УЯЗВИМОСТИ (для продакшена)

### 🔴 CRITICAL: Firestore Rules не знают о superadmin
```javascript
function getUserRole() {
  // НЕТ проверки admin_profiles!
  let driverDoc = get(/databases/$(database)/documents/drivers/$(request.auth.uid));
  let ownerDoc = get(/databases/$(database)/documents/owners/$(request.auth.uid));
  return (driverDoc ... ? 'driver' : ownerDoc ... ? 'owner' : null);
}
```
- **Риск:** Администратор, войдя через Firebase Auth, не сможет читать данные других парков — Firestore Rules ему запретят.
- **Решение:** Добавить `admin_profiles` в `getUserRole()`.

### 🔴 CRITICAL: Пароли в SharedPreferences (Flutter)
```dart
users.add({'password': 'admin123', ...});  // plaintext!
SharedPreferences.setString('users', jsonEncode(users));
```
- **Риск:** Любое приложение с доступом к SharedPreferences может прочитать пароли. На рутированном устройстве или при бэкапе — утечка всех учёток.
- **Решение:** `flutter_secure_storage` (Keychain/Keystore).

### 🔴 CRITICAL: Любой email пускает в кабинет (лендинг)
```javascript
// main.js строка 98-106 — нет проверки пароля!
if (!isReg) { /* комментарий, но ничего не делает */ }
// Сразу редирект
window.location.href = 'admin/index.html?role=owner&email=...';
```
- **Риск:** Любой человек, вписав любой email (например `hacker@x.com`), попадает в кабинет владельца. Данные там демо, но **психологически** создаёт ложное ощущение безопасности.
- **Решение для прода:** Firebase Authentication вместо хардкода.

---

## 3. 🟠 ВЫСОКИЙ РИСК

### 🟠 HIGH: Отсутствие App Check в Cloud Functions
- Все Cloud Functions имеют `enforceAppCheck: false`
- Любой может вызывать функции Firebase проекта

### 🟠 HIGH: Пароли в коде (лендинг)
```javascript
if (email === 'admin@numino.ru' && pass === 'admin123') role = 'admin';
```
- Видно в DevTools любому посетителю

### 🟠 HIGH: Нет HTTPS
- В production без HTTPS все данные передаются в открытом виде

### 🟠 HIGH: Сессия через URL-параметры
```
admin/index.html?role=admin&email=admin@numino.ru&name=Администратор
```
- URL может быть сохранён в истории браузера, логах прокси
- Любой, кто получит эту ссылку, войдёт как администратор

### 🟠 HIGH: Нет content security policy
- Нет `Content-Security-Policy` заголовка
- Возможны XSS-атаки (хотя есть sanitize для `< >`)

---

## 4. 🟡 СРЕДНИЙ РИСК

### 🟡 MEDIUM: Нет CSP-заголовков
- В админке нет защиты от XSS через `style` и inline-скрипты

### 🟡 MEDIUM: Контактная форма — FormSubmit (сторонний сервис)
- Данные идут через `formsubmit.co` — третья сторона
- Нет шифрования, нет подтверждения доставки

### 🟡 MEDIUM: Нет rate limiting на форме входа
- Можно брутфорсить пароли бесконечно

### 🟡 MEDIUM: `_captcha = false` в форме
```html
<input type="hidden" name="_captcha" value="false">
```
- Защита от ботов отключена

### 🟡 MEDIUM: Нет `noindex` для админки
```
<meta name="robots" content="noindex">
```
- Поисковики могут проиндексировать `/admin/index.html`

---

## 5. 🟢 НИЗКИЙ РИСК / INFO

### 🟢 INFO: Демо-данные видны любому в SharedPreferences
- Но в демо-режиме это допустимо

### 🟢 INFO: `referrer: no-referrer` стоит
- Хорошо — не утекает URL с параметрами

### 🟢 INFO: Есть XSS-защита через sanitize `< >`
- Базовый уровень защиты от XSS

---

## 6. ✅ ЧТО УЖЕ ХОРОШО СДЕЛАНО

1. **Ролевая модель работает** — superadmin/owner/driver разведены
2. **Flutter App маршрутизация** — правильная: admin → SuperadminScreen, owner → OwnerDashboard, driver → DriverHomeScreen
3. **Firestore Rules** — грамотно разграничивают owner/driver
4. **Storage Rules** — чеки только image/*, до 10 MB
5. **Фокус-треппинг** в модалке
6. **XSS sanitize** — удаление `< >`
7. **honeypot** для ботов в контактной форме
8. **Нет трекеров** — ни аналитики, ни рекламы
9. **403/404** — без утечки информации через статусы
10. **SuperadminScreen** — полноценные 4 вкладки

---

## 7. 📋 ЧЕК-ЛИСТ ДЛЯ ПРОДАКШЕНА

| # | Приоритет | Что сделать | Где |
|---|---|---|---|
| 1 | 🔴 **Critical** | Firebase Auth вместо хардкода паролей | main.js + local_storage.dart |
| 2 | 🔴 **Critical** | `flutter_secure_storage` для паролей | local_storage.dart |
| 3 | 🔴 **Critical** | Добавить `admin_profiles` в Firestore Rules | firestore.rules |
| 4 | 🔴 **Critical** | `enforceAppCheck: true` на всех Cloud Functions | functions/src/*.ts |
| 5 | 🟠 High | HTTPS (Let's Encrypt / Cloudflare) | Сервер |
| 6 | 🟠 High | Убрать пароль из URL, передавать через сессионный токен | main.dart |
| 7 | 🟠 High | Добавить CSP-заголовки | web server config |
| 8 | 🟡 Medium | `noindex` для `/admin/` | admin/index.html |
| 9 | 🟡 Medium | Rate limiting на форму входа | main.js / backend |
| 10 | 🟡 Medium | `_captcha = true` для контактной формы | index.html |

---

## 8. 📊 ОЦЕНКА БЕЗОПАСНОСТИ

| Компонент | Оценка (1-10) | Комментарий |
|---|---|---|
| Лендинг (клиент) | 3/10 | Пароли в JS, нет проверки, нет HTTPS |
| Flutter App | 5/10 | Пароли в SharedPreferences, но роли разведены |
| Cloud Functions | 4/10 | App Check отключён |
| Firestore Rules | 6/10 | Нет superadmin, но owner/driver — хорошо |
| Storage Rules | 7/10 | Хорошо, но нет superadmin |
| **Общий балл** | **4.5/10** | **Требует доработки перед продакшеном** |

---

## 9. 🎯 РЕКОМЕНДАЦИИ (по шагам)

**Шаг 1 (1 час):** Добавить `noindex` в админку, включить `_captcha`, убрать пароль `admin123` из видимости (хотя бы закомментировать).

**Шаг 2 (4 часа):** Интегрировать Firebase Authentication вместо хардкода на лендинге.

**Шаг 3 (2 часа):** Обновить Firestore Rules — добавить `admin_profiles` и `isSuperadmin()`.

**Шаг 4 (2 часа):** Включить App Check на всех Cloud Functions.

**Шаг 5 (1 день):** Настроить HTTPS + CSP на production-сервере.

---

*Отчёт составлен QA-инженером 30.05.2026 после повторного аудита проекта.*
