# Спецификация: Админ-панель системы CargoProfi (Numino)

## 🎯 Зачем нужна админ-панель?

Сейчас `admin@numino.ru` — это просто владелец парка с именем "Администратор". Он видит **только свои данные** (свои машины, рейсы, расходы).

Настоящая **системная админ-панель** нужна для управления **всеми пользователями и парками** платформы.

---

## 1. 🏗️ Концепция ролей (новая модель)

| Роль | Описание | Доступ |
|---|---|---|
| **superadmin** | Администратор системы | Полный доступ ко всем данным |
| **owner** | Владелец автопарка | Только свой парк |
| **driver** | Водитель | Только свои рейсы |

### Таблица `admin_profiles` в Firestore:

```json
{
  "uid": "string (document ID = Firebase Auth UID)",
  "role": "superadmin",
  "displayName": "Администратор",
  "email": "admin@numino.ru",
  "permissions": ["manage_owners", "manage_tariffs", "view_system_stats", "manage_support"],
  "createdAt": "Timestamp"
}
```

### Обновлённая функция `getUserRole()` в Firestore Rules:

```javascript
function getUserRole() {
  let adminDoc = get(/databases/$(database)/documents/admin_profiles/$(request.auth.uid));
  let ownerDoc = get(/databases/$(database)/documents/owners/$(request.auth.uid));
  let driverDoc = get(/databases/$(database)/documents/drivers/$(request.auth.uid));
  return (
    (adminDoc != null && adminDoc.data.role == 'superadmin') ? 'superadmin' :
    (ownerDoc != null && ownerDoc.data.role == 'owner') ? 'owner' :
    (driverDoc != null && driverDoc.data.role == 'driver') ? 'driver' :
    null
  );
}
```

---

## 2. 📊 Дашборд админа

### Карточки статистики (глобальные):
- **Всего зарегистрированных парков** (количество owners)
- **Всего водителей** в системе
- **Всего машин** во всех парках
- **Всего рейсов** (за сегодня / неделю / месяц)
- **Общий доход** всех парков
- **Активные подписки** (по тарифам)

### Графики:
- Регистрация новых парков по месяцам
- Активность рейсов (график)
- Распределение по тарифам (диаграмма)

---

## 3. 👥 Управление владельцами парков (Owners)

### Таблица владельцев:

| Колонка | Описание |
|---|---|
| ID | Уникальный идентификатор |
| Компания | Название компании |
| Email | Email владельца |
| Телефон | Контактный телефон |
| Тариф | Старт / Бизнес / Корпоративный |
| Статус | Активен / Заблокирован |
| Машин | Количество машин в парке |
| Водителей | Количество водителей |
| Дата регистрации | Когда создан аккаунт |
| Последний вход | Дата последней авторизации |

### Действия:
- ✏️ **Редактировать** профиль владельца
- 🔒 **Заблокировать / Разблокировать** владельца
- 💰 **Изменить тариф** (Старт → Бизнес → Корпоративный)
- 👁️ **Посмотреть парк** — войти в режим просмотра дашборда владельца (read-only)
- 🗑️ **Удалить** парк (с подтверждением)

### Cloud Function для админа (пример):

```typescript
export const adminBlockOwner = functions.https.onCall(
  {
    enforceAppCheck: true,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Не авторизован");
    
    const adminDoc = await db.collection("admin_profiles").doc(uid).get();
    if (!adminDoc.exists || adminDoc.data()?.role !== "superadmin") {
      throw new HttpsError("permission-denied", "Только администратор");
    }
    
    const ownerId = request.data.ownerId as string;
    if (!ownerId) throw new HttpsError("invalid-argument", "Не указан ownerId");
    
    await db.collection("owners").doc(ownerId).update({
      isBlocked: request.data.blocked ?? true,
      blockedAt: Timestamp.now(),
      blockedBy: uid,
    });
    
    return { success: true };
  }
);
```

---

## 4. 💳 Управление тарифами и подписками

### Страница тарифов в админке:

**Просмотр:**
- Список всех подписок с фильтрацией по статусу
- Дата начала / окончания подписки
- История изменений тарифа

**Настройка тарифов:**
```json
{
  "tariffs": {
    "start": { "name": "Старт",   "price": 990,  "maxVehicles": 2,  "features": ["gps", "waybills", "expenses"] },
    "business": { "name": "Бизнес", "price": 1990, "maxVehicles": 5,  "features": ["gps", "waybills", "expenses", "salary"] },
    "enterprise": { "name": "Корпоративный", "price": null, "maxVehicles": null, "features": ["gps", "waybills", "expenses", "salary", "api", "1c"] }
  }
}
```

**Действия:**
- Создать промо-период (бесплатный триал)
- Изменить стоимость тарифа
- Выставить счёт владельцу

---

## 5. 🎫 Управление заявками (Support)

### Страница обращений:
Сейчас форма обратной связи на лендинге **не отправляет данные**. В админ-панели нужен раздел:

- **Все сообщения** из формы обратной связи
- **Статус**: Новое / В работе / Решено / Закрыто
- **Ответить** прямо из админки (email-уведомление)
- **Прикрепить** заявку к владельцу парка

### Коллекция `support_tickets`:
```json
{
  "id": "ticket_001",
  "name": "Иван Петров",
  "email": "ivan@example.com",
  "message": "Не могу войти в кабинет",
  "status": "new",
  "assignedTo": "admin_uid",
  "ownerId": "owner_uid (если зарегистрирован)",
  "createdAt": "Timestamp",
  "resolvedAt": "Timestamp"
}
```

---

## 6. 📋 Системные логи и аудит

### Collection `system_logs`:
```json
{
  "id": "log_001",
  "action": "owner_blocked",
  "adminId": "admin_uid",
  "targetId": "owner_uid",
  "details": "Заблокирован за нарушение",
  "createdAt": "Timestamp"
}
```

**Должны логироваться:**
- Блокировка / разблокировка владельцев
- Изменение тарифов
- Вход администратора
- Удаление данных

---

## 7. 🗂️ Структура навигации админ-панели

```
📊 Дашборд (статистика)
├── Системная статистика
└── Графики и отчёты

👥 Владельцы парков
├── Список всех owners
├── Просмотр парка (read-only)
└── Управление (блокировка, тариф)

💳 Тарифы и подписки
├── Список подписок
├── Настройка тарифов
└── История платежей

🎫 Поддержка
├── Обращения (тикеты)
└── Ответы пользователям

📦 Системное
├── Логи аудита
├── Настройки системы
└── Управление администраторами
```

---

## 8. 🔧 Технические предложения

### Backend:
- **Новая коллекция** `admin_profiles` в Firestore
- **Cloud Functions** для операций администрирования (с проверкой роли `superadmin`)
- **Новый раздел Firestore Rules** для superadmin (чтение всех коллекций)

### Frontend:
- Отдельная страница `/admin-panel` (отдельная от `/admin` — это панель владельца)
- Можно реализовать как:
  - **Flutter Web** (отдельный entry point)
  - **Отдельное React/Vue приложение** (проще для админки)
  - **Расширение текущего Flutter Web App** с дополнительной ролью

### Пример Flutter Routes:
```dart
// main.dart — обновлённая маршрутизация
home: const AuthGate(),

class AuthGate extends StatefulWidget { ... }

class _AuthGateState extends State<AuthGate> {
  Widget build(BuildContext context) {
    if (!_ready) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final auth = context.watch<AuthProvider>();
    if (!auth.isLoggedIn) return const LoginScreen();
    if (auth.isAdmin) return const AdminDashboardScreen();   // <-- НОВОЕ
    if (auth.isOwner) return const OwnerDashboardScreen();
    return const DriverHomeScreen();
  }
}
```

---

## 9. 📊 Оценка трудозатрат

| Задача | Оценка |
|---|---|
| Создание коллекции `admin_profiles` + новая роль | 2-3 часа |
| Cloud Functions для администрирования | 4-6 часов |
| Обновление Firestore Rules (superadmin) | 1-2 часа |
| Админ-дашборд (Flutter Web экраны) | 8-12 часов |
| Страница управления владельцами | 6-8 часов |
| Страница тарифов и подписок | 4-6 часов |
| Система тикетов поддержки | 6-8 часов |
| Логи аудита | 3-4 часа |
| **ИТОГО** | **~35-50 часов** |

---

## 10. 🚀 Приоритет внедрения

### MVP (неделя 1):
1. ✅ Новая роль `superadmin` (коллекция + rules)
2. ✅ Cloud Functions: блокировка владельца, просмотр парка
3. ✅ Простой дашборд со статистикой
4. ✅ Обновлённая маршрутизация в Flutter

### Неделя 2:
5. Управление тарифами
6. Страница управления владельцами
7. Исправление формы обратной связи → связь с админкой

### Неделя 3:
8. Система тикетов
9. Логи аудита
10. Настройки системы

---

*Спецификация подготовлена QA-инженером 30.05.2026 на основе анализа текущей архитектуры проекта.*
