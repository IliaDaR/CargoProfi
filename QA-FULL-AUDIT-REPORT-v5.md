# ОТЧЁТ ПОЛНОГО АУДИТА v5 — CargoProfi (Numino)

**Дата:** 03.06.2026  
**Аудитор:** QA-Инженер  
**Объём проверки:** Лендинг, Кабинеты владельца/суперадмина (Web), Приложение водителя (Flutter), Cloud Functions, Firestore/Storage Rules, Firebase Auth

---

## 1. СВОДКА

| Тип | Найдено всего | Исправлено с v4 | 🔴 Критических сейчас | 🟡 Средних сейчас | 🟢 Низких сейчас |
|-----|--------------|-----------------|----------------------|-------------------|------------------|
| **ИТОГО** | **22** | **6** | **4** | **8** | **4** |

---

## 2. ЧТО БЫЛО ИСПРАВЛЕНО (v4 → v5) — 6 проблем

| ID v4 | Описание | Статус |
|-------|----------|--------|
| V4-1 🔴 | CloudFunctionsService не интегрирован в driver_home_screen | ✅ **ИСПРАВЛЕНО** |
| V4-2 🟡 | checkIsOwner в expenses.ts не включает superadmin | ✅ **ИСПРАВЛЕНО** |
| V4-3 🟡 | trips.ts getMyTrips не обрабатывает cancelled trips | ✅ **ИСПРАВЛЕНО** |
| V4-4 🟡 | Нет проверки активного рейса перед startTrip | ✅ **ИСПРАВЛЕНО** |
| V4-5 🟢 | SyncQueue не очищается после облачной синхронизации | ✅ **ИСПРАВЛЕНО** |
| V4-6 🟢 | NotificationService.highExpense не вызывается | ✅ **ИСПРАВЛЕНО** |

---

## 3. ЧТО ИСПРАВЛЕНО ВНУТРИ v5 (дополнительно) — 4 проблемы

| Проблема | Описание | Статус |
|----------|----------|--------|
| V5-2 🔴 | Суперадмин не имеет доступа к Vehicles, SalaryRules, SalaryPayments в Firestore Rules | ✅ **ИСПРАВЛЕНО** — добавлены `|| isSuperAdmin()` |
| V5-3 🟡 | Storage Rules не учитывают superadmin/admin в getUserRole() | ✅ **ИСПРАВЛЕНО** — `getUserRole()` возвращает 'superadmin' |
| V5-5 🟡 | Неконсистентное использование TrackPoint (Map vs TrackPoint) | ✅ **ИСПРАВЛЕНО** — используется `List<TrackPoint>` |
| V5-6 🟡 | vehicles read не разрешает водителю читать назначенную машину | ✅ **ИСПРАВЛЕНО** — добавлен `activeDriverId == request.auth.uid` |

---

## 4. КРИТИЧЕСКИЕ ПРОБЛЕМЫ 🔴 (4 шт.)

### 🔴 C1: CloudFunctionsService — 3 copy-paste ошибки с именами функций

**Файл:** `cargo_app/lib/services/cloud_functions_service.dart`  
**Строки:** 131, 165, 203  
**Важность:** 🔴 **КРИТИЧЕСКАЯ** — любой вызов этих методов приведёт к ошибке

**addExpense() [строка 131] вызывает calculateSalary вместо addExpense:**
```dart
try {
  final result = await _functions.httpsCallable('calculateSalary').call({
    'driverId': driverId,      // <-- НЕ ОПРЕДЕЛЕНО! Нужны tripId, amount и т.д.
    'periodStart': periodStart, // <-- НЕ ОПРЕДЕЛЕНО!
    'periodEnd': periodEnd,    // <-- НЕ ОПРЕДЕЛЕНО!
  });
  return result.data as Map<String, dynamic>; // <-- возвращает Map вместо expenseId
} catch (_) { _useLocal = true; }
```

**generateWaybill() [строка 165] вызывает addExpense вместо generateWaybill:**
```dart
try {
  final result = await _functions.httpsCallable('addExpense').call({
    'tripId': tripId, 'amount': amount,   // amount НЕ ОПРЕДЕЛЕНО!
    'category': category,                    // НЕ ОПРЕДЕЛЕНО!
    'latitude': latitude,                    // НЕ ОПРЕДЕЛЕНО!
    'longitude': longitude,                  // НЕ ОПРЕДЕЛЕНО!
    if (description != null) 'description': description,  // НЕ ОПРЕДЕЛЕНО!
    if (receiptUrl != null) 'receiptUrl': receiptUrl,    // НЕ ОПРЕДЕЛЕНО!
  });
  return (result.data as Map)['expenseId'] ?? '';  // <-- возвращает expenseId вместо waybillUrl
} catch (_) { _useLocal = true; }
```

**calculateSalary() [строка 203] вызывает generateWaybill вместо calculateSalary:**
```dart
try {
  final result = await _functions.httpsCallable('generateWaybill').call({
    'tripId': tripId,   // <-- НЕ ОПРЕДЕЛЕНО! Нужны driverId, periodStart, periodEnd
  });
  return (result.data as Map)['waybillUrl'];  // <-- возвращает waybillUrl вместо Map
} catch (_) { _useLocal = true; }
```

**Рекомендация:** Исправить имена вызываемых Cloud Functions:
- addExpense → должно вызывать `'addExpense'` с tripId, amount, category, latitude, longitude
- generateWaybill → должно вызывать `'generateWaybill'` с tripId
- calculateSalary → должно вызывать `'calculateSalary'` с driverId, periodStart, periodEnd

---

### 🔴 C2: V5-1 — CloudFunctionsService не переключается на LocalStorage при внезапном падении Firebase

**Файл:** `cargo_app/lib/services/cloud_functions_service.dart`  
**Строки:** 23-36  
**Важность:** 🔴 **КРИТИЧЕСКАЯ** — потеря данных при сетевых проблемах

**Проблема в логике `_tryCloud()`:**
```dart
Future<bool> _tryCloud() async {
  if (!_useLocal) return true;  // <-- Всегда true при первом вызове
  // Health-check выполняется ТОЛЬКО если _useLocal уже true
  ...
}
```

**Сценарий отказа:**
1. Firebase работает → `_useLocal = false`
2. Firebase отключается (сеть/сервис недоступен)
3. `_tryCloud()` возвращает `true` (health-check не делается)
4. Каждый вызов облачной функции ПАДАЕТ с исключением
5. Исключение ловится → `_useLocal = true`
6. **НО данные уже потеряны** — они не сохранились локально, т.к. метод уже упал

**Проблема для generateWaybill() [строка 174]:** После catch возвращает `null` — путевой лист не генерируется (ни облачно, ни локально)

**Проблема для addExpense() [строка 137-146]:** Есть дублирующийся код после catch, но он находится в `if (!_useLocal)` — то есть недостижим, т.к. `_useLocal` уже `true` после catch. Это **мёртвый код**.

**Рекомендация:** Убрать дублирование кода. После каждого catch просто падать на fallback. Структура должна быть:
```dart
if (await _tryCloud()) {
  try { cloudCall(); } catch (_) { _useLocal = true; }
}
// fallback
```

---

### 🔴 C3: checkIsOwner() в salary.ts не включает superadmin/admin

**Файл:** `functions/src/salary.ts`  
**Строки:** 237-239  
**Важность:** 🔴 **КРИТИЧЕСКАЯ** — суперадмин не может использовать calculateSalary

```typescript
async function checkIsOwner(uid: string): Promise<boolean> {
  const ownerDoc = await db.collection("owners").doc(uid).get();
  return ownerDoc.exists && ownerDoc.data()?.role === "owner";
  //                                                                  ^^^^^
  //  НЕ включает "superadmin" и "admin"!
}
```

**Влияние:**
- Суперадмин не может вызвать `calculateSalary` (строка 33: `ownerDoc.data()?.role !== "owner"`)
- Суперадмин не может вызвать `getSalaryHistory`
- **В отличие от `expenses.ts`**, где `checkIsOwner` включает superadmin/admin

**Рекомендация:** Привести к единому виду с expenses.ts:
```typescript
return role === "owner" || role === "superadmin" || role === "admin";
```

---

### 🔴 C4: checkIsOwner() в salaryRules.ts не включает superadmin/admin

**Файл:** `functions/src/salaryRules.ts`  
**Строки:** 182-184  
**Важность:** 🔴 **КРИТИЧЕСКАЯ** — суперадмин не может управлять правилами зарплаты

Аналогичная проблема C3 — `checkIsOwner()` проверяет только `role === "owner"`.

**Влияние:**
- Суперадмин не может вызвать `setSalaryRule` (строка 27)
- Суперадмин не может вызвать `getSalaryRule`

**Рекомендация:** Аналогично C3 — добавить `"superadmin"` и `"admin"`.

---

## 5. СРЕДНИЕ ПРОБЛЕМЫ 🟡 (8 шт.)

### 🟡 C10: Пароли в plaintext в SharedPreferences [НЕ ИСПРАВЛЕНО]

**Файл:** `cargo_app/lib/services/local_storage.dart`  
**Строки:** 53-57, 89, 97

Пароли seed-пользователей хранятся в открытом виде:
```dart
users.add({'uid': 'admin', ..., 'password': 'admin123', ...});
users.add({'uid': 'owner1', ..., 'password': 'owner123', ...});
users.add({'uid': 'driver1', ..., 'password': 'driver123', ...});
```
Аутентификация — прямым сравнением строк (строка 89):
```dart
return users.where((u) => u['email'] == email && u['password'] == password).firstOrNull;
```
Регистрация сохраняет пароль в plaintext (строка 97):
```dart
final user = {...'password': password, ...};
```

**Риск:** При компрометации устройства злоумышленник получает все пароли.
**Рекомендация:** Хранить SHA-256 хэши, как на лендинге (main.js).

---

### 🟡 C15: dart:html блокирует компиляцию для мобильных платформ [НЕ ИСПРАВЛЕНО]

**Файл:** `cargo_app/lib/utils/navigation.dart`  
**Строка:** 3
```dart
import 'dart:html' as html;
```
`dart:html` доступен только в Flutter Web. Компиляция для Android/iOS упадёт.
**Рекомендация:** Заменить условным импортом или `universal_html`.

---

### 🟡 V5-7: Редактирование рейса владельцем — нет синхронизации с облаком [НЕ ИСПРАВЛЕНО]

**Файл:** `cargo_app/lib/screens/owner/trips_screen.dart`  
**Строки:** 120-132

При редактировании рейса изменения сохраняются только локально (`store.saveTrips()`). Нет вызова Cloud Function.
**Рекомендация:** Добавить вызов Cloud Function для обновления рейса в облаке.

---

### 🟡 V5-4: drivers write rule в Firestore — потенциально небезопасна [НЕ ИСПРАВЛЕНО]

**Файл:** `firestore.rules`  
**Строки:** 81-84
```
allow write: if isAuth() && isOwner() && (isSuperAdmin() || (isOwner() && hasAccessToDriver(driverId)));
```
Условие `isOwner()` внутри `(isOwner() && ...)` — избыточно (уже проверено выше).
**Рекомендация:** Упростить: `allow write: if isAuth() && (isSuperAdmin() || (isOwner() && hasAccessToDriver(driverId)));`

---

### 🟡 V5-8: Утечка внутренней информации в тестовых данных [НЕ ИСПРАВЛЕНО]

**Файл:** `cargo_app/lib/services/local_storage.dart`  
**Строки:** 53-57

Seed-данные содержат реально выглядящие номера телефонов (`+79183951315`, `+79161234567`).
**Рекомендация:** Заменить на заведомо тестовые (`+79990000001`).

---

### 🟡 V5-10: Средний чек рассчитывается некорректно при наличии рейсов с income=0 [НЕ ИСПРАВЛЕНО]

**Файл:** `cargo_app/lib/screens/owner/superadmin_screen.dart`  
**Строки:** 137-138

```dart
final avgCheck = s.trips.where((t) => t.status == TripStatus.completed)
    .map((t) => t.income ?? 0).toList();
final avg = avgCheck.isEmpty ? 0.0 : avgCheck.reduce((a, b) => a + b) / avgCheck.length;
```
**Проблема:** Рейсы с `income = null` учитываются как 0, занижая средний чек.
**Рекомендация:** Фильтровать `t.income != null && t.income > 0`.

---

### 🟡 V5-11: Нет обработчика для cancelled-рейсов в статистике суперадмина [НЕ ИСПРАВЛЕНО]

**Файл:** `cargo_app/lib/screens/owner/superadmin_screen.dart`  
**Строки:** 135, 137

Статистика учитывает только `TripStatus.completed`. Отменённые рейсы не отображаются.
**Рекомендация:** Добавить счётчик отменённых рейсов.

---

### 🟡 getMyTrips не фильтрует cancelled рейсы [НОВАЯ]

**Файл:** `functions/src/trips.ts`  
**Строка:** 397
```typescript
if (status && (status === "active" || status === "completed")) {
```
Параметр `status = "cancelled"` игнорируется — cancelled рейсы нельзя отфильтровать.
**Рекомендация:** Добавить `status === "cancelled"` в условие.

---

## 6. НИЗКИЕ ПРОБЛЕМЫ 🟢 (4 шт.)

### 🟢 V5-9: Отсутствует валидация mileageSource в Trip модели [НЕ ИСПРАВЛЕНО]

**Файл:** `cargo_app/lib/models/trip.dart`  
**Строки:** 63-65

Все значения, отличные от `'manual'`, интерпретируются как `MileageSource.auto`.
**Рекомендация:** Явная проверка всех значений enum.

---

### 🟢 V5-12: CloudFunctionsService дублирует код — мёртвый блок в addExpense() [НОВАЯ]

**Файл:** `cargo_app/lib/services/cloud_functions_service.dart`  
**Строки:** 137-146

После catch на строке 135 `_useLocal` устанавливается в `true`. Затем на строке 138:
```dart
if (!_useLocal) {
  // правильный код addExpense
}
```
Этот блок **НИКОГДА не выполнится**, т.к. `_useLocal` уже `true`. Это мёртвый код.
**Рекомендация:** Убрать мёртвый блок. Структура: try-cloud → catch(switch to local) → fallback.

---

### 🟢 V5-13: Navigation Rail при ширине > 800 используется с VerticalDivider, но навигация дублируется

**Файл:** `cargo_app/lib/screens/owner/owner_dashboard_screen.dart`  
**Строки:** 58-65

При `maxWidth > 800` показывается `NavigationRail`, при `≤ 800` — `NavigationBar` (BottomNavigationBar). На больших экранах и rail и title отображаются, что нормально, но функционал дублируется.
**Рекомендация:** Косметическое улучшение, не влияет на работу.

---

### 🟢 V5-14: storage.rules — нет доступа суперадмина к waybills другой папки

**Файл:** `storage.rules`  
**Строки:** 53-59

Хотя `getUserRole()` теперь возвращает `'superadmin'`, правило для waybills использует `isOwner()` (только owner), а не `isSuperAdmin()`.
```javascript
allow read: if isAuth() && (isOwner() && request.auth.uid == ownerId);
```
**Влияние:** Суперадмин не может читать путевые листы владельцев.
**Рекомендация:** Добавить `|| isSuperAdmin()`.

---

## 7. A/B ТЕСТИРОВАНИЕ — РЕЗУЛЬТАТЫ

### 7.1 Лендинг (index.html)

| Тест | Ожидание | Реальность | Вердикт |
|------|----------|------------|---------|
| CSP заголовок | Защита от XSS | `'unsafe-inline'` для script-src и style-src | ⚠️ Ослабленная защита |
| Honeypot в форме | Скрыт от ботов | `style="display:none"` — обнаруживается ботами | ⚠️ |
| Firebase config | Placeholder | ✅ Корректно скрыт | ✅ OK |
| local пароли | SHA-256 хэши | ✅ Хэши через `crypto.subtle.digest` | ✅ OK |
| Fallback crypto | Без crypto.subtle | ⚠️ `'plain:' + pass` | ⚠️ |
| Валидация email | Проверка | ✅ `isValidEmail` | ✅ OK |
| Адаптивность | Mobile-first | ✅ Burger menu, карусели | ✅ OK |
| ARIA-атрибуты | Доступность | ✅ `role="dialog"`, `aria-label` | ✅ OK |
| SEO | meta-теги | ✅ Open Graph, Twitter Cards, JSON-LD | ✅ OK |
| Скорость | preconnect, preload | ✅ Google Fonts preload | ✅ OK |

### 7.2 Кабинет владельца (Flutter Web)

| Тест | Ожидание | Реальность | Вердикт |
|------|----------|------------|---------|
| Дашборд | Статистика | ✅ Все карточки, активные рейсы | ✅ OK |
| Машины | CRUD | ✅ Добавление, просмотр | ✅ OK |
| Рейсы | Поиск, фильтр, пагинация | ✅ `_totalFiltered` | ✅ OK |
| Рейсы | Редактирование | ✅ Есть, без облачной синхронизации (V5-7) | ⚠️ |
| Расходы | По категориям | ✅ Реализован | ✅ OK |
| Зарплата | Расчёт % и фикс | ✅ Реализован | ✅ OK |
| Зарплата | Экспорт CSV | ✅ Реализован | ✅ OK |
| Выход | Очистка currentUser | ✅ `storage.setCurrentUser(null)` | ✅ OK |

### 7.3 Кабинет суперадмина (Flutter Web)

| Тест | Ожидание | Реальность | Вердикт |
|------|----------|------------|---------|
| Управление владельцами | Блокировка/разблокировка | ✅ С подтверждением | ✅ OK |
| Добавление владельца | Валидация | ✅ Проверки email, имени, пароля | ✅ OK |
| Тарифы | Назначение плана | ✅ Реализовано | ✅ OK |
| Статистика | Выручка, подписки | ✅ Реализовано, avg чек с null (V5-10) | ⚠️ |
| Тикеты | Просмотр, закрытие | ✅ Реализовано | ✅ OK |
| Логи | История | ✅ До 100 записей | ✅ OK |
| График выручки | По месяцам | ✅ Столбчатая диаграмма | ✅ OK |

### 7.4 Приложение водителя (Flutter)

| Тест | Ожидание | Реальность | Вердикт |
|------|----------|------------|---------|
| Старт рейса | Выбор машины, GPS | ✅ Реализовано | ✅ OK |
| Старт рейса | Проверка активного | ✅ `_hasActiveTrip` check | ✅ OK |
| GPS-трекинг | Каждые 30 сек | ✅ Офлайн-буфер | ✅ OK |
| GPS-трекинг | Синхронизация | ✅ CloudFunctionsService | ✅ OK |
| Расход | Категория, сумма, фото | ✅ Реализовано | ✅ OK |
| Крупный расход >= 10000 | Уведомление | ✅ NotificationService | ✅ OK |
| Завершение рейса | Пробег, доход | ✅ Реализовано | ✅ OK |
| История рейсов | Просмотр | ✅ Реализовано | ✅ OK |
| **addExpense()** | Вызов addExpense | ❌ **Вызывает calculateSalary!** | 🔴 C1 |
| **generateWaybill()** | Вызов generateWaybill | ❌ **Вызывает addExpense!** | 🔴 C1 |
| **calculateSalary()** | Вызов calculateSalary | ❌ **Вызывает generateWaybill!** | 🔴 C1 |

### 7.5 Cloud Functions

| Функция | Тест | Результат | Вердикт |
|---------|------|-----------|---------|
| startTrip | Валидация | ✅ Все проверки | ✅ OK |
| startTrip | Активный рейс | ✅ limit 1 | ✅ OK |
| addTrackPoint | Проверка владельца | ✅ `trip.driverId !== uid` | ✅ OK |
| addTrackPointsBatch | Батчевая отправка | ✅ Реализована | ✅ OK |
| endTrip | Расчёт пробега | ✅ haversine | ✅ OK |
| addExpense | Валидация категории | ✅ 8 категорий | ✅ OK |
| addExpense | Только активный рейс | ✅ `trip.status === 'active'` | ✅ OK |
| getTripExpenses | Права owner/driver | ✅ includes superadmin | ✅ OK |
| **calculateSalary** | **Права owner** | ❌ **Не включает superadmin!** | 🔴 C3 |
| **setSalaryRule** | **Права owner** | ❌ **Не включает superadmin!** | 🔴 C4 |
| getSalaryRule | Права owner | ❌ **Не включает superadmin!** | 🔴 C4 |

---

## 8. ПРОВЕРКА БЕЗОПАСНОСТИ

| № | Уязвимость | Статус |
|---|------------|--------|
| 1 | **Plaintext пароли** в SharedPreferences (local_storage.dart) | 🟡 C10 |
| 2 | **dart:html** — только Web | 🟡 C15 |
| 3 | Cloud Functions без App Check | ⚠️ `enforceAppCheck: false` |
| 4 | Отсутствует rate limiting | ⚠️ Нет защиты от DDoS |
| 5 | CSP с `'unsafe-inline'` | 🟢 Низкий (статический сайт) |
| 6 | Storage Rules waybills — isSuperAdmin() не добавлен | 🟢 V5-14 |
| 7 | localStorage fallback plaintext | 🟢 Низкий |

---

## 9. ИТОГОВЫЕ РЕКОМЕНДАЦИИ

### Критические (исправить немедленно):
1. **C1 🔴** — Исправить 3 copy-paste ошибки в CloudFunctionsService (addExpense, generateWaybill, calculateSalary)
2. **C2 🔴** — Переделать graceful degradation в CloudFunctionsService для всех методов
3. **C3 🔴** — Добавить `"superadmin"` и `"admin"` в checkIsOwner salary.ts
4. **C4 🔴** — Добавить `"superadmin"` и `"admin"` в checkIsOwner salaryRules.ts

### Средние (в ближайшее время):
5. **C10 🟡** — Хранить хэши паролей вместо plaintext
6. **C15 🟡** — Убрать `dart:html`, использовать условные импорты
7. **V5-7 🟡** — Добавить Cloud Function для синхронизации редактирования рейсов
8. **V5-4 🟡** — Упростить drivers write rule
9. **V5-10 🟡** — Фильтровать income != null при расчёте avg
10. **V5-11 🟡** — Добавить cancelled рейсы в статистику
11. **getMyTrips 🟡** — Добавить фильтрацию cancelled рейсов
12. **V5-8 🟡** — Заменить seed-данные на тестовые

### Низкие (по возможности):
13. **V5-9 🟢** — Явная валидация enum в Trip
14. **V5-12 🟢** — Убрать мёртвый код в CloudFunctionsService.addExpense
15. **V5-14 🟢** — Добавить isSuperAdmin() в storage.rules для waybills

---

*Отчёт сформирован: 03.06.2026 18:15 MSK*  
*Всего найдено: 22 проблемы (4 критические, 8 средних, 4 низких + остальные)*  
*Исправлено с v4: 6 проблем*  
*Исправлено внутри v5: 4 проблемы*
