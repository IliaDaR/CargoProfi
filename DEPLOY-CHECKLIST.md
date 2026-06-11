# NUMINO — Деплой на Яндекс.Облако: Чеклист

## ⚡ АВТОМАТИЧЕСКИ (запустить скрипт)
```bash
cd /opt/CargoProfi
bash deploy-yandex.sh
```

## ✋ РУЧНЫЕ ШАГИ (после скрипта)

### Шаг 7 — Яндекс ID (OAuth)
1. https://oauth.yandex.ru → Создать приложение
2. Название: `Numino`
3. Redirect URI: `https://numino.ru/callback`
4. Права: `login:email`, `login:info`
5. **Записать Client ID:** _______________

### Шаг 8 — Яндекс.Касса
1. https://kassa.yandex.ru → Зарегистрировать магазин
2. **Записать shopId:** _______________
3. **Записать secretKey:** _______________

### Шаг 9 — DNS
```bash
yc dns zone create --name numino-zone --zone numino.ru.
# Добавить A-запись → IP Object Storage
```

### Шаг 10 — TLS сертификат
```bash
yc certificate-manager certificate create \
  --name numino-cert \
  --domains numino.ru,www.numino.ru
```

### Шаг 11 — Переключить Flutter на Яндекс
В файле `cargo_app/lib/services/cloud/cloud_config.dart`:
```dart
static const provider = CloudProvider.yandex;           // ← поменять
static const yandexFunctionUrl = 'https://...';          // ← из вывода скрипта
static const yandexDbEndpoint = 'grpcs://...';           // ← из вывода скрипта
static const yandexOAuthClientId = '...';                // ← из шага 7
```

### Шаг 12 — Пересобрать Flutter Web и залить
```bash
cd cargo_app
flutter build web --release
cp -r build/web/* ../website/admin/
cd ..
# Залить на Object Storage:
yc storage s3cp --recursive website/ s3://numino-website/
```

---

## ✅ Проверка после деплоя

| Что проверить | URL |
|---|---|
| Лендинг | https://numino.ru |
| Вход | https://numino.ru/login.html |
| API health | https://api.numino.ru/ping |
| Проверка ПЛ | https://numino.ru/check?id=test |
