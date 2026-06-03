# QA-FULL-AUDIT-REPORT-v3 — Полный аудит CargoProfi (Numino)
**Дата:** 03.06.2026  
**Аудитор:** QA Инженер  
**Статус:** Проверка исправления 56 багов из v2 + поиск новых проблем

---

## Сводка

| Категория | Количество |
|---|---|
| ✅ Исправлено из v2 | 11 |
| ❌ НЕ исправлено из v2 | 7 |
| 🆕 Новые критические баги | 3 |
| 🆕 Новые высокие/средние | 10 |
| **Итого проблем** | **20** |

---

## 1. ПРОВЕРКА ИСПРАВЛЕНИЙ БАГОВ ИЗ v2

### ✅ Исправлено (11)

| ID | Баг | Файл | Статус |
|---|---|---|---|
| C1 | isActive vehicle mutation не сохранялся | `driver_home_screen.dart:103` | ✅ `store.saveVehicles()` добавлен |
| C2 | Удаление расходов не сохранялось | `expenses_screen.dart:90` | ✅ `saveExpenses()` добавлен |
| C3 | Редактирование рейса уничтожало GPS-трек | `trips_screen.dart:128` | ✅ `track: trip.track` добавлен |
| C4 | Batch addTrackPointsBatch терял все точки кроме последней | `trips.ts:243` | ✅ Использует `FieldValue.arrayUnion(...)` |
| C7 | _useLocal инициализирован как true | `cloud_functions_service.dart:15` | ✅ Теперь `_useLocal = false` |
| C8 | Retry logic сломан (2 минуты блокировки) | `cloud_functions_service.dart:23-24` | ✅ 30 секунд между попытками |
| C9 | getOwnerDriverIds возвращал null | `firestore.rules:43` | ✅ `.get('driverIds', [])` |
| C11 | Пароли в plaintext в localStorage (веб) | `website/js/main.js:131` | ✅ SHA-256 хэширование |
| C13 | CSV экспорт только 20 элементов | `expenses_screen.dart:60` | ✅ Использует `fullList` |
| C14 | Superadmin добавлял пользователя без пароля | `superadmin_screen.dart:111` | ✅ Поле пароля добавлено |
| H1 | _calculating не сбрасывался при trips.isEmpty | `salary_screen.dart:46-49` | ✅ `setState(() => false)` |

### ❌ НЕ Исправлено (7)

| ID | Баг | Описание | Файл |
|---|---|---|---|
| **C6** | **TrackPoint.fromMap крашится на SharedPreferences** | `(data['timestamp'] as dynamic).toDate()` вызывает `.toDate()` на String, что крашится | `models/trip.dart:110` |
| **C10** | **Пароли в plaintext в SharedPreferences** | Seed users и registerUser сохраняют пароль в JSON `{'password': 'admin123'}` | `local_storage.dart:53-57,97` |
| **C12** | **Нет защиты удаления машин в Firestore rules** | Нет `allow delete: if false` для vehicles | `firestore.rules:93-103` |
| **C15** | **dart:html блокирует мобильную компиляцию** | `import 'dart:html' as html;` в navigation.dart | `utils/navigation.dart:3` |
| C5* | **expenses.ts всё ещё использует !input.latitude** | `!input.latitude` отклоняет 0 (экватор/нулевой меридиан) | `functions/src/expenses.ts:35` |
| M11 | **DemoData: isActive не соответствует рейсам** | v1/v3 active но нет активных рейсов, v4 inactive но есть активный рейс | `models/demo_data.dart:13-43` |
| F3* | **getDriverExpensesReport не проверяет принадлежность водителя** | Любой owner может запросить расходы любого водителя | `functions/src/expenses.ts:215-261` |
| H* | **Отрицательный доход/расходы** | Нет валидации `income > 0`, `amount > 0` при редактировании | `trips_screen.dart:127` |

---

## 2. НОВЫЕ КРИТИЧЕСКИЕ БАГИ (v3)

### 🅲🆅3-1 [CRITICAL] CloudFunctionsService.ping к startTrip всегда падает → всегда локальный режим

**Где:** `cloud_functions_service.dart:27`
```dart
await _functions.httpsCallable('startTrip').call({'ping': true}).timeout(const Duration(seconds: 5));
```
**Проблема:** Cloud Function `startTrip` не обрабатывает `{'ping': true}`. Она проверяет `input.vehicleId` который равен `undefined` (falsy), и выбрасывает ошибку `"Не указаны обязательные поля: vehicleId, latitude, longitude"`.

**Последствие:** `_tryCloud()` ВСЕГДА возвращает `false`, `_useLocal` ВСЕГДА остаётся `true`. Cloud Functions НИКОГДА не вызываются, всё работает через localStorage fallback.

**Рекомендация:** Добавить обработчик ping в startTrip, либо использовать отдельную health-check функцию, либо снять ограничение.

---

### 🅲🆅3-2 [CRITICAL] _endTrip() не сохраняет изменённый рейс в SharedPreferences

**Где:** `driver_home_screen.dart:325-337`
```dart
store.trips[idx] = Trip(
  id: old.id, driverId: old.driverId, ...
  status: TripStatus.completed, ...
);
// ...
store.saveVehicles(); // Машину сохраняет
// НО НЕТ store.saveTrips() !!!
```
**Проблема:** Рейс модифицируется в памяти (`store.trips[idx] = Trip(...)`), но `store.saveTrips()` не вызывается. При перезапуске приложения изменения рейса ТЕРЯЮТСЯ.

**Последствие:** Рейс остаётся в статусе 'active' навсегда после перезагрузки приложения.

**Рекомендация:** Добавить `store.saveTrips()` после изменения `store.trips[idx]`.

---

### 🅲🆅3-3 [CRITICAL] Редактирование рейса владельцем не сохраняется в SharedPreferences

**Где:** `trips_screen.dart:118-130`
```dart
store.trips[idx] = Trip(
  id: trip.id, driverId: trip.driverId, ...
);
// НЕТ store.saveTrips() !!!
```
**Проблема:** Владелец редактирует рейс (меняет доход, пробег, маршрут), изменения применяются в памяти, но не сохраняются в SharedPreferences. При перезапуске все правки пропадают.

**Последствие:** Редактирование рейсов владельцем — пустая трата времени.

**Рекомендация:** Добавить `store.saveTrips()` после изменения рейса.

---

## 3. НОВЫЕ ВЫСОКИЕ И СРЕДНИЕ ПРОБЛЕМЫ (v3)

### 🅷🆅3-4 [HIGH] getUserRole не включает superadmin → superadmin не может читать Firestore

**Где:** `firestore.rules:15-23`
```firebase
function getUserRole() {
  return (
    (driverDoc != null && driverDoc.data.role == 'driver') ? 'driver' :
    (ownerDoc != null && ownerDoc.data.role == 'owner') ? 'owner' :
    null  // ← superadmin возвращает null!
  );
}
```
**Проблема:** Superadmin хранится в коллекции `owners` с `role: 'superadmin'`. `getUserRole()` проверяет только `'owner'`, поэтому superadmin получает `null` → все проверки `isAuth()` проходят, но `isOwner()` возвращает false.

**Последствие:** Superadmin не может читать/писать через Firestore rules (напрямую). Cloud Functions работают, но Firestore SDK — нет.

**Рекомендация:** Добавить проверку на superadmin/admin в getUserRole.

---

### 🅷🆅3-5 [HIGH] storage.rules: getOwnerDriverIds всё ещё крашится на null

**Где:** `storage.rules:29-31`
```firebase
function getOwnerDriverIds(ownerId) {
  return firestore.get(/databases/(default)/documents/owners/$(ownerId)).data.driverIds;
}
```
**Проблема:** В `firestore.rules` эта функция была исправлена (использует `.get('driverIds', [])`), но в `storage.rules` осталось старое обращение `.data.driverIds` которое возвращает null если поле отсутствует.

**Последствие:** `driverId in getOwnerDriverIds(...)` с null → краш правила → чтение чеков водителя владельцем невозможно.

**Рекомендация:** Синхронизировать исправление с firestore.rules.

---

### 🅷🆅3-6 [HIGH] Firebase Auth registration не устанавливает ownerId для водителя

**Где:** `firebase_auth_service.dart:36-43`
```dart
if (role == 'owner' || role == 'admin' || role == 'superadmin') {
  await _firestore.collection('owners').doc(uid).set(profile);
} else {
  await _firestore.collection('drivers').doc(uid).set(profile);
  // ownerId НЕ установлен!
}
```
**Проблема:** При регистрации водителя через Firebase Auth, профиль создаётся без поля `ownerId`. Водитель никогда не будет привязан к владельцу.

**Последствие:** Владелец не может назначать правила зарплаты этому водителю через Cloud Functions (salaryRules.ts line 70: `driverData?.ownerId !== uid`).

**Рекомендация:** Добавить параметр `ownerId` в метод register и передавать его при создании профиля водителя.

---

### 🅷🆅3-7 [HIGH] expenses.ts использует !input.latitude → отклоняет 0

**Где:** `functions/src/expenses.ts:35`
```typescript
if (!input.tripId || !input.amount || !input.category || !input.latitude || !input.longitude)
```
**Проблема:** trips.ts был исправлен (использует `== null`), но expenses.ts остался с `!` оператором. Расходы с GPS-координатами (0, 0) или на экваторе/нулевом меридиане будут отклонены.

**Последствие:** Водитель не может добавить расход если GPS вернул latitude=0 или longitude=0.

**Рекомендация:** Заменить на `input.latitude == null || input.longitude == null`.

---

### 🅼🆅3-8 [MEDIUM] NavigationRail ломает BottomNavigationBar на некоторых экранах

**Где:** `owner_dashboard_screen.dart:58-66`
```dart
body: LayoutBuilder(builder: (ctx, c) => c.maxWidth >= 800
  ? Row(children: [
      NavigationRail(...),
      Expanded(child: screens[_idx]),
    ])
  : screens[_idx]),
bottomNavigationBar: MediaQuery.of(context).size.width < 800
  ? NavigationBar(...)
  : null,
```
**Проблема:** На ширине >= 800 показывается NavigationRail, но BottomNavigationBar скрывается только при `width < 800`. Если ширина = 800, и NavigationRail, и BottomNavigationBar оба НЕ показываются. Условия не совпадают: `maxWidth >= 800` для Rail и `width < 800` для BottomBar.

**Последствие:** При ширине ровно 800px пользователь не видит ни навигационной панели снизу, ни rail сбоку — может застрять на одном экране.

**Рекомендация:** Использовать одинаковое условие: `constraints.maxWidth < 800` для BottomBar.

---

### 🅼🆅3-9 [MEDIUM] DriverHomeScreen не редиректит на роль-экран при activeTrip = null

**Где:** `driver_home_screen.dart:358-360`
```dart
if (trip == null || trip.status != TripStatus.active) {
  return DriverHomeScreen(driverId: widget.driverId);
}
```
**Проблема:** При потере активного рейса (например, после перезагрузки с багом C6/TrackPoint), ActiveTripScreen рекурсивно создаёт новый DriverHomeScreen. Это может привести к каскаду виджетов.

**Последствие:** Избыточное потребление памяти, потенциальный stack overflow при многократных перестроениях.

**Рекомендация:** Использовать `Navigator.pushReplacement` или `WidgetsBinding.instance.addPostFrameCallback`.

---

### 🅼🆅3-10 [MEDIUM] Waybill PDF font paths платформозависимые

**Где:** `functions/src/pdf.ts:151-154`
```typescript
const fontPath = require.resolve("pdfkit");
const fontDir = fontPath.replace(/[\\/]pdfkit\.js$/, "") + "/fonts";
const regularFont = fontDir + "/Helvetica.ttf";
```
**Проблема:** Путь к шрифтам зависит от платформы (Windows `\` vs Unix `/`). В Cloud Functions (Node.js на Linux) путь будет `/layers/google.nodejs.functions-framework/functions-framework/node_modules/pdfkit/js/fonts/Helvetica.ttf` — но этот путь может не существовать если pdfkit установлен иначе.

**Последствие:** При деплое в Cloud Functions PDF может не сгенерироваться из-за отсутствия файла шрифта.

**Рекомендация:** Использовать встроенный PDFKit шрифт по умолчанию или загружать шрифты из buffer.

---

### 🅼🆅3-11 [MEDIUM] Кнопка "Показать ещё" в trips_screen показывает общее количество рейсов, а не отфильтрованных

**Где:** `trips_screen.dart:64-65`
```dart
if (store.trips.length > _pageSize)
  Padding(padding: ..., child: TextButton(onPressed: () => setState(() => _pageSize += 20),
    child: Text('Показать ещё (${_pageSize} из ${store.trips.length})')),
```
**Проблема:** Количество рейсов считается от `store.trips.length` (ВСЕ рейсы), а не от количества отфильтрованных. Если применён фильтр по статусу или поиск, пользователь видит некорректное общее количество.

**Последствие:** UI показывает "Показать ещё (20 из 50)" но по факту отфильтровано только 10.

**Рекомендация:** Заменить на отфильтрованное количество: `r.length` до `take()`.

---

### 🅼🆅3-12 [LOW] admin_logs — утечка памяти

**Где:** `superadmin_screen.dart:24,28-33`
```dart
_logs.addAll(s.adminLogs); // initState
if (_logs.length > 100) _logs.removeLast(); // обрезка
```
**Проблема:** Логи грузятся из SharedPreferences при каждой инициализации SuperadminScreen. Обрезка до 100 только на уровне UI, в SharedPreferences логи продолжают расти.

**Последствие:** При активном использовании админ-панели, размер SharedPreferences может неограниченно расти.

**Рекомендация:** Обрезать логи и в SharedPreferences: при сохранении оставлять только последние 100 записей.

---

### 🅻🆅3-13 [LOW] Honeypot поле отправляется в formsubmit.co

**Где:** `website/index.html:335`
```html
<input type="text" name="_honey" style="display:none" tabindex="-1" autocomplete="off">
```
**Проблема:** Поле `_honey` создано для ботов, но formsubmit.co ожидает поле с именем `_honeypot`, а не `_honey`. Боты не будут обмануты неправильным именем поля.

**Рекомендация:** Переименовать в `_honeypot` (стандартное имя для formsubmit.co).

---

### 🅻🆅3-14 [LOW] Проблемы с CSP заголовком

**Где:** `website/index.html:17`
```html
<meta http-equiv="Content-Security-Policy" content="...">
```
**Проблемы:**
1. `'unsafe-eval'` в script-src — позволяет eval(), что снижает защиту от XSS
2. `connect-src` не включает `https://identitytoolkit.googleapis.com` (Firebase Auth API)

**Последствие:** Firebase Auth на лендинге может не работать из-за CSP.

**Рекомендация:** Добавить `https://identitytoolkit.googleapis.com` в connect-src, убрать `'unsafe-eval'`.

---

## 4. A/B ТЕСТЫ

### Тест A: Редактирование рейса владельцем (expected vs actual)

**Expected:** После редактирования рейса, перезагрузки приложения, данные рейса обновлены.

**Actual:**  
1. Открыть TripsScreen → редактировать рейс → сохранить → SnackBar "Изменения сохранены"  
2. Перезагрузить приложение (горячая или холодная)  
3. **ALL edits LOST** — `saveTrips()` не вызывается (trips_screen.dart:130)  

**Вердикт: ❌ FAIL**

---

### Тест B: Завершение рейса водителем (expected vs actual)

**Expected:** После завершения рейса, статус рейса = "completed", данные GPS трека сохранены.

**Actual:**  
1. Водитель нажимает "Завершить рейс" → SnackBar "Рейс завершён!"  
2. В тот же сессии данные работают (in-memory cache)  
3. После перезагрузки → рейс снова "active", трек потерян  
4. `saveTrips()` не вызывается в `_endTrip()` (driver_home_screen.dart:325-337)

**Вердикт: ❌ FAIL**

---

### Тест C: Cloud Functions вызов из приложения

**Expected:** При активном Firebase, Cloud Functions вызываются для удалённых операций.

**Actual:**  
1. Приложение инициализируется с `_useLocal = false`  
2. При вызове `_tryCloud()`, `startTrip({'ping': true})` возвращает ошибку  
3. `_useLocal` становится true навсегда  
4. Все операции идут через localStorage, Cloud Functions никогда не вызываются  

**Вердикт: ❌ FAIL**

---

### Тест D: Завершённый рейс через Cloud Function (endTrip)

**Expected:** endTrip завершает рейс с пробегом по GPS-треку.

**Actual:**  
1. endTrip использует `calculateTotalDistance(finalTrack)`  
2. Если `autoMileage > 0` — использует авто-пробег  
3. Если нет — проверяет `input.manualMileage && input.manualMileage > 0`  
4. Если и этого нет — выбрасывает ошибку  

**Проблема:** `input.manualMileage` имеет тип `number | undefined`. `input.manualMileage > 0` при undefined → NaN → false. Всё корректно.  

**Вердикт: ✅ PASS** (логика endTrip корректна)

---

### Тест E: Driver registration через Firebase Auth не устанавливает ownerId

**Expected:** Водитель, зарегистрированный через Firebase Auth, должен иметь ownerId.

**Actual:**  
1. FirebaseAuthService.register() создаёт профиль водителя в `drivers/{uid}`  
2. Поля: uid, email, displayName, role, createdAt  
3. **Поле ownerId отсутствует** (firebase_auth_service.dart:39)  

**Вердикт: ❌ FAIL**

---

### Тест F: Firestore Rules — superadmin доступ

**Expected:** Superadmin может читать данные всех владельцев/водителей через Firestore SDK.

**Actual:**  
1. Superadmin имеет UID и документ в `owners/{uid}` с role='superadmin'  
2. `getUserRole()` в firestore.rules проверяет только 'driver' и 'owner'  
3. Superadmin получает null от getUserRole  
4. Все проверки isOwner() возвращают false  
5. Superadmin не может читать данные через Firestore SDK  

**Вердикт: ❌ FAIL**

---

### Тест G: storage.rules — чтение чеков владельцем

**Expected:** Владелец может читать чеки своих водителей из Firebase Storage.

**Actual:**  
1. Owner пытается прочитать `/receipts/{driverId}/{expenseId}`  
2. storage.rules вызывает `getOwnerDriverIds(request.auth.uid)`  
3. Владелец имеет поле `driverIds` → `[null]` или отсутствует  
4. `.data.driverIds` возвращает null  
5. `driverId in null` → CRASH правила → доступ запрещён  

**Вердикт: ❌ FAIL**

---

### Тест H: Экваториальные координаты (latitude = 0)

**Expected:** Расход с latitude=0, longitude=0 (экватор/нулевой меридиан) должен приниматься.

**Actual:**  
1. Код: `!input.latitude || !input.longitude`  
2. При latitude=0 → `!0` = `true`  
3. Выбрасывается ошибка "Обязательные поля..."  
4. Расход не может быть создан  

**Вердикт: ❌ FAIL**

---

### Тест I: Импорт dart:html на Android

**Expected:** Приложение компилируется для Android без ошибок.

**Actual:**  
1. `navigation.dart` импортирует `dart:html` (строка 3)  
2. `dart:html` недоступен на Android  
3. Компиляция падает с ошибкой "Target doesn't support dart:html"  

**Вердикт: ❌ FAIL**

---

## 5. БЕЗОПАСНОСТЬ

| ID | Проблема | Уровень | Статус |
|---|---|---|---|
| S1 | Пароли в plaintext в SharedPreferences | 🔴 HIGH | ❌ Не исправлено (C10) |
| S2 | Нет App Check на Cloud Functions | 🔴 HIGH | ❌ Все `enforceAppCheck: false` |
| S3 | Нет защиты удаления машин (Firestore rules) | 🟠 MEDIUM | ❌ Не исправлено (C12) |
| S4 | Пинг startTrip раскрывает ошибку валидации | 🟢 LOW | Незначительно |
| S5 | CSP 'unsafe-eval' ослабляет защиту | 🟢 LOW | Новая (V3-14) |
| S6 | getDriverExpensesReport без проверки ownerId | 🟠 MEDIUM | ❌ Не исправлено |

---

## 6. ВЫВОД

**После якобы полного исправления 56 багов, осталось/обнаружено 20 проблем:**

- **5 КРИТИЧЕСКИХ**: 
  - V3-1: Cloud Functions никогда не вызываются (ping к startTrip)
  - V3-2: _endTrip не сохраняет рейс в SharedPreferences (data loss)
  - V3-3: Редактирование рейса не сохраняется (data loss)
  - C6: TrackPoint.fromMap крашится на SharedPreferences
  - C10: Пароли в plaintext в SharedPreferences

- **7 ВЫСОКИХ**: getUserRole для superadmin, storage.rules краш, Firebase Auth без ownerId, expenses.ts lat=0, missing driver-owner verification, income без валидации

- **5 СРЕДНИХ**: NavigationRail/BottomBar race condition, PDF шрифты, pagination, admin_logs рост

- **3 НИЗКИХ**: Honeypot имя, CSP неполный, рекурсивный DriverHomeScreen

**Важнейшее замечание**: Cloud Functions полностью отключены из-за бага V3-1 (ping к startTrip вместо health-check). Вся работа идёт только через localStorage. Это означает, что ни один рейс, расход, зарплата или путевой лист не синхронизируются с Firebase.

---

## 7. ПРИОРИТЕТНЫЕ ИСПРАВЛЕНИЯ

1. **🔴 V3-1**: Исправить `_tryCloud()` — создать отдельную health-check функцию или убрать ping
2. **🔴 V3-2**: Добавить `store.saveTrips()` в `_endTrip()`
3. **🔴 V3-3**: Добавить `store.saveTrips()` при редактировании рейса
4. **🔴 C6**: Исправить `TrackPoint.fromMap` — использовать `_parseDate`
5. **🔴 C10**: Хэшировать пароли в local_storage.dart или не хранить совсем
6. **🟠 V3-4**: Добавить superadmin в `getUserRole()`
7. **🟠 V3-6**: Синхронизировать `getOwnerDriverIds` в storage.rules
8. **🟠 C5/expenses**: Исправить `!input.latitude` на `== null`
