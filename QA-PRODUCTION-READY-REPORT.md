# ✅ Финальный аудит готовности к продакшену — CargoProfi (Numino)
*30.05.2026*

---

## 1. 🏗️ ПОЛНАЯ КАРТА ПРОЕКТА

```
🌐 ЛЕНДИНГ (website/)
  ├── index.html          ← Публичная страница
  ├── js/main.js          ← Логика входа, карусели, форма
  ├── css/style.css       ← Стили
  ├── 404.html            ← Страница 404
  └── admin/              ← Flutter Web App (скомпилирован)

📱 FLUTTER APP (cargo_app/lib/)
  ├── main.dart           ← AuthGate: admin → Superadmin, owner → Dashboard, driver → Home
  ├── screens/
  │   ├── auth/
  │   │   ├── login_screen.dart        ← Только для Web (устарел)
  │   │   └── role_screen.dart         ← Только для Android (выбор роли)
  │   ├── owner/
  │   │   ├── owner_dashboard_screen.dart  ← 5 вкладок
  │   │   ├── superadmin_screen.dart       ← 4 вкладки
  │   │   ├── vehicles_screen.dart         ← + год, VIN 
  │   │   ├── trips_screen.dart            ← + кнопка "Путевой лист"
  │   │   ├── expenses_screen.dart
  │   │   └── salary_screen.dart
  │   └── driver/
  │       ├── driver_home_screen.dart      ← LocalStorage (НОВЫЙ)
  │       ├── active_trip_screen.dart      ← Firestore (СТАРЫЙ, .bak)
  │       ├── add_expense_screen.dart      ← Firestore (СТАРЫЙ, .bak)
  │       └── trip_history_screen.dart     ← Firestore (СТАРЫЙ, .bak)
  ├── providers/
  │   ├── auth_provider.dart
  │   ├── vehicle_provider.dart
  │   ├── trip_provider.dart               ← импортирует Firestore (без .bak!)
  │   └── expense_provider.dart            ← импортирует Firestore (без .bak!)
  ├── services/
  │   ├── local_storage.dart              ← Активно используется
  │   ├── firestore_service.dart.BAK      ← НЕ КОМПИЛИРУЕТСЯ
  │   └── location_service.dart.BAK       ← НЕ КОМПИЛИРУЕТСЯ
  └── models/ + utils/ + widgets/

⚙️ BACKEND (functions/src/)
  ├── index.ts           ← Экспорт всех функций
  ├── trips.ts           ← startTrip, addTrackPoint, endTrip, getMyTrips
  ├── expenses.ts        ← addExpense, getTripExpenses, getDriverExpensesReport
  ├── salary.ts          ← calculateSalary, getSalaryHistory
  ├── salaryRules.ts     ← setSalaryRule, getSalaryRule
  ├── pdf.ts             ← generateWaybill (PDF)
  ├── distance.ts        ← haversine formula
  └── types.ts           ← Все интерфейсы

🛡️ SECURITY
  ├── firestore.rules    ← owner/driver, НЕТ superadmin
  └── storage.rules      ← Чеки + PDF
```

---

## 2. 🔴 БЛОКИРУЮЩИЕ ПРОБЛЕМЫ (НЕЛЬЗЯ В ПРОДАКШЕН)

### 🔴 BLOCKER #1: Дублирование кабинета водителя — КОНФЛИКТ

В проекте **ДВА набора кода** для водителя:

| Файл | Хранилище | Статус |
|---|---|---|
| `driver_home_screen.dart` (НОВЫЙ, 247 строк) | LocalStorage | ✅ Работает, полный функционал |
| `active_trip_screen.dart` (СТАРЫЙ, 220 строк) | Firestore (.bak) | ❌ Сломан |
| `add_expense_screen.dart` (СТАРЫЙ) | Firestore (.bak) | ❌ Сломан |
| `trip_history_screen.dart` (СТАРЫЙ) | Firestore (.bak) | ❌ Сломан |

**Проблема:** В `driver_home_screen.dart` (строка 71) есть свой `ActiveTripScreen` (строки 108-247), а в `active_trip_screen.dart` (старый) — другой. Оба класса называются одинаково, но находятся в разных файлах. При компиляции — конфликт.

### 🔴 BLOCKER #2: .bak файлы НЕ КОМПИЛИРУЮТСЯ

```dart
// trip_provider.dart строка 5
import '../services/firestore_service.dart';  // firestore_service.dart НЕ СУЩЕСТВУЕТ
// Есть только firestore_service.dart.bak (с расширением .bak)
```

Файлы: `firestore_service.dart.bak`, `location_service.dart.bak`, `auth_service.dart.bak`

**Dart не видит файлы с расширением .bak.** Импорты ссылаются на несуществующие файлы.

### 🔴 BLOCKER #3: Два класса ActiveTripScreen

- `active_trip_screen.dart` (220 строк) — один класс
- `driver_home_screen.dart` (строки 108-247) — второй класс с тем же именем

При компиляции Flutter выдаст: `Duplicate class name: ActiveTripScreen`

### 🔴 BLOCKER #4: Нет маршрута '/' для logout

```dart
// owner_dashboard_screen.dart строка 34
Navigator.pushReplacementNamed(context, '/');
// driver_home_screen.dart строка 76
Navigator.pushReplacementNamed(context, '/');
```

**В MaterialApp нет именованного маршрута '/'.** При выходе — чёрный экран / ошибка.

---

## 3. 🟠 ВЫСОКИЙ ПРИОРИТЕТ (ДОЛЖНО БЫТЬ ИСПРАВЛЕНО)

### 🟠 #5: Firebase не подключён к Flutter App
- `google-services.json` / `GoogleService-Info.plist` отсутствуют
- Firebase Auth не инициализирован
- Cloud Functions недоступны из приложения

### 🟠 #6: TripProvider и ExpenseProvider импортируют несуществующий Firestore
```dart
import '../services/firestore_service.dart'; // ЭТОГО ФАЙЛА НЕТ
```
TripProvider/ExpenseProvider — мёртвый код без работающего сервиса.

### 🟠 #7: LocalStorage vs Firestore — два параллельных мира
- Owner → LocalStorage (демо-данные)
- Driver (новый) → LocalStorage
- Driver (старый) → Firestore (сломан)
- Владелец НЕ ВИДИТ рейсы, созданные водителем

### 🟠 #8: Нет `flutter_secure_storage`
Все пароли в plaintext в SharedPreferences

### 🟠 #9: Firestore Rules не знают о superadmin
```javascript
function getUserRole() {
  // НЕТ admin_profiles! superadmin = null → запрещено всё
}
```

### 🟠 #10: Пароль admin123 в JS на клиенте
```javascript
if (email === 'admin@numino.ru' && pass === 'admin123') role = 'admin';
```
Виден любому через DevTools.

### 🟠 #11: Сессия через URL-параметры
```
admin/index.html?role=admin&email=admin@numino.ru&name=Администратор
```
URL сохраняется в истории браузера. Любой может подделать `?role=admin`.

### 🟠 #12: Любой email пускает на лендинге
```javascript
if (!isReg) { /* комментарий, проверки нет */ }
// сразу редирект
setTimeout(function () { window.location.href = 'admin/index.html?...'; }, 500);
```

---

## 4. 🟡 СРЕДНИЙ ПРИОРИТЕТ

### 🟡 #13: Нет кэширования/обновления при изменении данных
- OwnerDashboard использует `context.watch<LocalStorage>()`, но список trips не обновляется
- После добавления рейса нужно перезаходить

### 🟡 #14: Нет валидации VIN и года в форме машины
```dart
year: int.tryParse(yearCtrl.text)  // может быть null
vin: vinCtrl.text.isEmpty ? null : vinCtrl.text  // не проверяется длина 17
```

### 🟡 #15: Нет конфигурации Firebase для Flutter Web
- admin/index.html — Flutter Web App, но Firebase не инициализирован
- Реальная авторизация не работает

### 🟡 #16: `_captcha = false` на форме
```html
<input type="hidden" name="_captcha" value="false">
```
Форма без капчи — спам-боты завалят.

### 🟡 #17: Нет Content-Security-Policy
Уязвимость к XSS-атакам.

### 🟡 #18: Нет `noindex` для /admin/
```html
<meta name="robots" content="noindex">
```
Не добавлен в admin/index.html.

### 🟡 #19: Нет 5xx ошибки при падении сервера
При ошибке сервера — пустой экран, не informative.

---

## 5. 🟢 НИЗКИЙ ПРИОРИТЕТ / УЛУЧШЕНИЯ

### 🟢 #20: Общая статистика для superadmin
- Показывает только локальные демо-данные
- В production должен показывать данные всех парков

### 🟢 #21: Кнопка "Путевой лист" — заглушка
```dart
onPressed: () {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Путевой лист сформирован! (PDF доступен в production-режиме)')),
  );
},
```
Вместо реального вызова Cloud Function generateWaybill.

### 🟢 #22: Нет обработки ошибок сети
Нет try-catch для Cloud Functions. Если Firebase недоступен — краш без сообщения.

### 🟢 #23: Нет авто-обновления данных
Нет Stream/subscription для real-time обновлений.

---

## 6. ✅ ЧТО УЖЕ ХОРОШО И ГОТОВО

| Компонент | Статус |
|---|---|
| **Ролевая модель** | ✅ superadmin / owner / driver разведены |
| **Superadmin панель** | ✅ 4 вкладки: владельцы, тарифы, статистика, тикеты |
| **Owner Dashboard** | ✅ 5 вкладок + дашборд |
| **Лендинг** | ✅ 8 секций, карусели, контактная форма |
| **404.html** | ✅ Создан |
| **Кабинет водителя (новый)** | ✅ Полноценный: начало/завершение рейса, расходы, история |
| **VIN + год в форме авто** | ✅ Добавлены (исправлено) |
| **Кнопка "Путевой лист" в trips** | ✅ Добавлена |
| **Accessibility** | ✅ aria-live у каруселей |
| **honeypot для ботов** | ✅ Есть |
| **XSS-защита (sanitize)** | ✅ Удаление `< >` |
| **Фокус-треппинг** | ✅ В модалке |

---

## 7. 🚨 ЧЕК-ЛИСТ ДЛЯ ПРОДАКШЕНА

### 🔴 КРИТИЧЕСКИЕ (блокируют запуск):

| # | Действие | Ответственный |
|---|---|---|
| 1 | **Удалить дублирование** — оставить один `driver_home_screen.dart` (LocalStorage) или перейти на Firestore | Разработчик |
| 2 | **Переименовать .bak → .dart** или удалить импорты несуществующих файлов | Разработчик |
| 3 | **Переименовать/удалить** старый `active_trip_screen.dart` (конфликт имён) | Разработчик |
| 4 | **Добавить маршрут '/'** в `MaterialApp` для logout | Разработчик |
| 5 | **Подключить Firebase** к Flutter App (конфиги + инициализация) | Разработчик |
| 6 | **Заменить SharedPreferences** на `flutter_secure_storage` | Разработчик |
| 7 | **Обновить Firestore Rules** — добавить `admin_profiles` и `isSuperadmin()` | Разработчик |
| 8 | **Убрать пароль из URL** — передавать сессию через токен/Firebase Auth | Разработчик |

### 🟠 ВАЖНЫЕ (до или сразу после запуска):

| # | Действие |
|---|---|
| 9 | Настроить Firebase Authentication на лендинге (вместо хардкода) |
| 10 | Включить App Check на Cloud Functions |
| 11 | Настроить HTTPS (Let's Encrypt / Cloudflare) |
| 12 | Добавить CSP-заголовки |
| 13 | Добавить `noindex` в `/admin/index.html` |
| 14 | Включить `_captcha = true` на контактной форме |
| 15 | Связать LocalStorage и Firestore — owner видит рейсы из Firebase |

### 🟡 ЖЕЛАТЕЛЬНЫЕ (в первые недели):

| # | Действие |
|---|---|
| 16 | Real-time обновления через Stream |
| 17 | Обработка ошибок сети (graceful degradation) |
| 18 | Валидация VIN (17 символов) |
| 19 | Подключить реальный вызов generateWaybill |
| 20 | Настроить CI/CD для сборки APK и Flutter Web |

---

## 8. 📊 ОЦЕНКА ГОТОВНОСТИ К ПРОДАКШЕНУ

| Компонент | Готовность | Комментарий |
|---|---|---|
| 🌐 Лендинг (HTML/CSS) | 85% | Не хватает CSP, noindex, HTTPS |
| 🔐 Безопасность лендинга | 30% | Пароль в JS, любой email пускает |
| 🖥️ Superadmin панель | 80% | Работает на локальных данных |
| 🚛 Owner Dashboard | 85% | Работает на локальных данных |
| 👤 Кабинет водителя | 70% | Класс дублируется, конфликт имён |
| 🗄️ Хранилище данных | 40% | LocalStorage vs Firestore — не консолидировано |
| ⚙️ Cloud Functions | 90% | Код отличный, но не используется из UI |
| 🛡️ Firebase Rules | 60% | Нет superadmin |
| 🔧 Сборка проекта | **20%** | **НЕ КОМПИЛИРУЕТСЯ** (.bak файлы) |
| **ОБЩИЙ** | **40%** | **НЕ ГОТОВ К ПРОДАКШЕНУ** |

---

## 9. 🎯 ПЛАН ДЕЙСТВИЙ (по часам)

### Шаг 1 — Сделать чтобы компилировалось (2-3 часа):
- Удалить/переименовать .bak файлы
- Удалить дублирующийся ActiveTripScreen
- Добавить маршрут '/'
- Исправить импорты

### Шаг 2 — Настроить Firebase (4-6 часов):
- Добавить google-services.json
- Инициализировать Firebase в Flutter
- Настроить Firebase Auth
- Включить App Check

### Шаг 3 — Консолидировать данные (4 часа):
- Решить: LocalStorage (демо) или Firestore (продакшен)
- Связать owner/ driver через одно хранилище
- Если Firestore — удалить LocalStorage из UI

### Шаг 4 — Безопасность (3 часа):
- Обновить Firestore Rules (superadmin)
- Убрать пароли из JS
- Настроить HTTPS + CSP
- Добавить noindex

### Шаг 5 — Функционал (4 часа):
- Подключить реальный generateWaybill
- Подключить calculateSalary из Cloud Function
- Добавить Stream для real-time обновлений

**Всего: ~17-20 часов до production-ready.**

---

*Отчёт составлен QA-инженером 30.05.2026 на основе полного аудита кода.*
