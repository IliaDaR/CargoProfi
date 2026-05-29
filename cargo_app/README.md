# Flutter-приложение «Рабочий кабинет перевозчика»

## Архитектура

Единый Flutter-проект с условной маршрутизацией по ролям:

- **Driver** — мобильный интерфейс (Android): GPS-трекинг, рейсы, расходы
- **Owner** — веб-панель (Flutter Web): дашборд, автопарк, путевые листы, зарплата

State management: **Provider** (ChangeNotifier)  
Бэкенд: **Firebase** (Firestore, Auth, Storage, Cloud Functions)

```
cargo_app/
  lib/
    main.dart                     # Точка входа, инициализация Firebase, AuthGate
    models/                        # Модели данных
      trip.dart, expense.dart, vehicle.dart,
      user_profile.dart, salary_rule.dart, salary_payment.dart
    services/
      auth_service.dart            # Firebase Auth + профиль
      firestore_service.dart       # Firestore, Storage, Cloud Functions
      location_service.dart        # GPS-трекинг (geolocator)
    providers/
      auth_provider.dart           # Состояние входа / регистрации
      trip_provider.dart           # Управление рейсами + локальный GPS-трек
      expense_provider.dart        # Расходы
      vehicle_provider.dart        # Автопарк (owner)
      salary_provider.dart         # Зарплата (owner)
    screens/
      auth/                        # login_screen, register_screen
      driver/                      # driver_home, active_trip, add_expense, trip_history
      owner/                       # dashboard, vehicles, trips, expenses, salary
    widgets/
      common_widgets.dart          # StatCard, LoadingButton, showError/Success
    utils/
      constants.dart               # Enum-ы, label-функции
      distance.dart                # Формула гаверсинусов (локальный расчёт)
```

## Предварительные требования

1. **Flutter SDK** 3.4+ ([установка](https://docs.flutter.dev/get-started/install))
2. **Firebase-проект** с развёрнутыми Cloud Functions (см. корневую папку `functions/`)
3. **Android Studio** / **VS Code** с Flutter-плагином

## Быстрый старт

### 1. Клонируй и сгенерируй Flutter-проект

```bash
cd cargo_app
flutter create --platforms=android,web .
```

### 2. Установи зависимости

```bash
flutter pub get
```

### 3. Настрой Firebase

#### Способ А: Через FlutterFire CLI (рекомендуется)

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=YOUR_PROJECT_ID
```

Это сгенерирует `lib/firebase_options.dart`. Затем раскомментируй строки в `lib/main.dart`:

```dart
import 'firebase_options.dart';
// ...
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

И удали заглушку `FirebaseOptions(...)`.

#### Способ Б: Вручную

1. В [Firebase Console](https://console.firebase.google.com/) → Настройки проекта → Добавить приложение
2. Для **Android**: скачай `google-services.json` в `cargo_app/android/app/`
3. Для **Web**: скопируй конфиг в `web/index.html` или в `main.dart`
4. Вставь реальные ключи в `FirebaseOptions(...)` в `main.dart`

### 4. Запуск

```bash
# Мобильное приложение водителя (Android)
flutter run -d android

# Веб-панель владельца (Chrome)
flutter run -d chrome
```

### 5. Сборка

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# Web
flutter build web --release
```

## Настройка разрешений Android

В `android/app/src/main/AndroidManifest.xml` добавь:

```xml
<!-- Геолокация -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<!-- Камера (для фото чеков) -->
<uses-permission android:name="android.permission.CAMERA"/>
<!-- Интернет -->
<uses-permission android:name="android.permission.INTERNET"/>
```

## Проверка работоспособности

### Сценарий водителя (Android):
1. Зарегистрируйся как **driver** (в поле «ID владельца» введи UID owner-а из Firebase)
2. Нажми «Начать рейс» → предоставь доступ к геолокации
3. На экране активного рейса: таймер, пробег по GPS, счётчик точек
4. Нажми «Добавить расход» → выбери категорию, сумму, сфотографируй чек
5. Нажми «Завершить рейс» → пробег рассчитается автоматически
6. История рейсов доступна по кнопке в AppBar

### Сценарий владельца (Web):
1. Зарегистрируйся как **owner**
2. Дашборд: статистика автопарка, быстрые действия
3. Вкладка «Рейсы»: таблица, кнопка «Путевой лист» → откроется PDF
4. Вкладка «Расходы»: выбери водителя, период → сводка с фото чеков
5. Вкладка «Зарплата»: задай правило (15% от дохода), выбери период, нажми «Рассчитать» → ведомость

## Важные замечания

- На вебе **GPS-трекинг работает через браузерный Geolocation API**. Geolocator поддерживает это.
- На вебе **камера/галерея ограничены браузерными возможностями** (image_picker работает).
- PDF путевого листа открывается через `url_launcher` во внешнем приложении или новой вкладке.
- Для production-сборки Android добавь **proguard rules** для Firebase.
- Если тебе нужен **background location tracking** на Android, добавь пакет `background_location` и настрой foreground service (требует дополнительной конфигурации).
