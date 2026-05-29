# Инструкция по развёртыванию

## Предварительные требования

1. **Node.js** версии 20 (рекомендуется LTS)
2. **Firebase CLI**: `npm install -g firebase-tools`
3. **Аккаунт Firebase** и созданный проект в [Firebase Console](https://console.firebase.google.com/)
4. Включённые сервисы в проекте:
   - **Authentication** (email/пароль)
   - **Firestore Database** (в режиме Native)
   - **Storage**
   - **Cloud Functions** (требуется тариф Blaze — Pay as you go)

## Шаг 1. Клонирование и установка

```bash
cd CargoProfi
cd functions
npm install
cd ..
```

## Шаг 2. Вход в Firebase

```bash
firebase login
```

## Шаг 3. Привязка к проекту Firebase

Замени `YOUR_PROJECT_ID` на ID твоего Firebase-проекта:

```bash
firebase use --add YOUR_PROJECT_ID
```

Если файл `.firebaserc` отсутствует, создай его:

```json
{
  "projects": {
    "default": "YOUR_PROJECT_ID"
  }
}
```

## Шаг 4. Настройка Authentication

1. В Firebase Console → Authentication → Sign-in method
2. Включи **Email/Password**
3. При необходимости включи **Phone** (опционально)
4. При необходимости включи **Google**

## Шаг 5. Настройка Firestore

Файлы `firestore.rules` и `firestore.indexes.json` уже подготовлены.

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

## Шаг 6. Настройка Storage

```bash
firebase deploy --only storage
```

## Шаг 7. Развёртывание Cloud Functions

```bash
firebase deploy --only functions
```

## Шаг 8. Тестирование (опционально, через эмулятор)

```bash
firebase init emulators
firebase emulators:start
```

## Проверка работоспособности

После деплоя в консоли Firebase (Functions) появятся следующие Callable-функции:

| Функция | Назначение | Кто вызывает |
|---|---|---|
| `startTrip` | Начать рейс | driver |
| `addTrackPoint` | Добавить GPS-точку | driver |
| `addTrackPointsBatch` | Добавить массив GPS-точек | driver |
| `endTrip` | Завершить рейс | driver |
| `getMyTrips` | Список рейсов водителя | driver |
| `addExpense` | Добавить расход | driver |
| `getTripExpenses` | Расходы по рейсу | driver / owner |
| `getDriverExpensesReport` | Отчёт по расходам | owner |
| `generateWaybill` | PDF путевого листа | owner |
| `setSalaryRule` | Задать правило зарплаты | owner |
| `getSalaryRule` | Получить правило зарплаты | owner / driver |
| `calculateSalary` | Рассчитать зарплату | owner |
| `getSalaryHistory` | История расчётов зарплаты | owner / driver |

## Пример клиентского вызова (Flutter/Dart)

```dart
final functions = FirebaseFunctions.instance;

// Начать рейс
final result = await functions.httpsCallable('startTrip').call({
  'vehicleId': '...',
  'latitude': 55.7558,
  'longitude': 37.6173,
  'cargoDescription': 'Стройматериалы',
  'routeDescription': 'Москва – Казань',
});

// Добавить расход
await functions.httpsCallable('addExpense').call({
  'tripId': '...',
  'amount': 3500.0,
  'category': 'fuel',
  'description': 'Заправка',
  'latitude': 55.1234,
  'longitude': 37.5678,
  'receiptUrl': 'https://...',
});

// Сформировать путевой лист (владелец)
final waybill = await functions.httpsCallable('generateWaybill').call({
  'tripId': '...',
});

// Рассчитать зарплату (владелец)
final salary = await functions.httpsCallable('calculateSalary').call({
  'driverId': '...',
  'periodStart': '2026-05-01',
  'periodEnd': '2026-05-31',
});
```

## Структура проекта

```
CargoProfi/
  firebase.json              — Конфигурация Firebase
  firestore.rules            — Правила безопасности Firestore
  firestore.indexes.json     — Составные индексы Firestore
  storage.rules              — Правила безопасности Storage
  database-schema.md         — Схема базы данных
  DEPLOYMENT.md              — Этот файл
  functions/
    package.json             — Зависимости и скрипты
    tsconfig.json            — Конфигурация TypeScript
    src/
      index.ts               — Точка входа (экспорт всех функций)
      types.ts               — Типы и интерфейсы
      distance.ts            — Расчёт расстояния (формула гаверсинусов)
      trips.ts               — Управление рейсами
      expenses.ts            — Управление расходами
      pdf.ts                 — Генерация PDF путевого листа
      salary.ts              — Расчёт зарплаты
      salaryRules.ts         — Правила начисления зарплаты
```
