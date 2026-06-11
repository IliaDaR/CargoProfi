# Yandex Cloud Infrastructure for Numino (Russian Stack)
# Без Firebase — только Яндекс.Облако
# Разворачивается через yc CLI

# ====================================================================
# 1. YDB Serverless — хранение данных
# ====================================================================
# yc ydb database create numino-db --serverless
# yc ydb database update numino-db --description "Numino production DB"
# ydb -e grpc://... -d /ru-central1/.../numino-db scripting yql -f schema.sql

# ====================================================================
# 2. Cloud Functions — бизнес-логика
# ====================================================================
# yc serverless function create --name=numino-api --description="Numino API"
# cd functions-yandex && npm run build
# yc serverless function version create \
#   --function-name=numino-api \
#   --runtime=nodejs20 \
#   --entrypoint=index.handler \
#   --source-path=dist \
#   --memory=256MB \
#   --execution-timeout=60s \
#   --environment=YDB_ENDPOINT=grpc://...,GOSKLUCH_API_URL=

# ====================================================================
# 3. Object Storage — файлы + хостинг сайта
# ====================================================================
# Создать бакеты:
# yc storage bucket create --name numino-files    # файлы (waybill PDF, фото)
# yc storage bucket create --name numino-website  # хостинг лендинга + Flutter Web

# Настроить веб-сайт:
# yc storage bucket update --name numino-website --website-index index.html --website-error 404.html

# Копировать сайт:
# yc storage s3cp --recursive website/ s3://numino-website/

# Публичный доступ:
# yc storage bucket update --name numino-website --grants read=allUsers

# ====================================================================
# 4. Заголовки безопасности (Object Storage)
# ====================================================================
# yc storage bucket update --name numino-website \
#   --response-headers "\
#     Strict-Transport-Security: max-age=31536000; includeSubDomains,\
#     X-Content-Type-Options: nosniff,\
#     X-Frame-Options: DENY,\
#     Referrer-Policy: strict-origin-when-cross-origin,\
#     Permissions-Policy: camera=(), microphone=(), geolocation=()"

# ====================================================================
# 5. API Gateway — роутинг API
# ====================================================================
# yc serverless api-gateway create --name=numino-gateway --spec=api-gateway.yaml
# yc serverless api-gateway update --name=numino-gateway --spec=api-gateway.yaml

# ====================================================================
# 6. Яндекс ID (OAuth) — авторизация
# ====================================================================
# https://oauth.yandex.ru — создать приложение
# Client ID для Android и Web (отдельно)
# Redirect URI: https://numino.ru/callback
# Scope: login:email login:info

# ====================================================================
# 7. Яндекс.Касса — оплата тарифов
# ====================================================================
# https://kassa.yandex.ru — зарегистрировать магазин
# Получить shopId + secretKey
# Вписать в Cloud Functions environment

# ====================================================================
# 8. TLS — сертификаты
# ====================================================================
# yc certificate-manager certificate create \
#   --name=numino-cert \
#   --domains=numino.ru,www.numino.ru,api.numino.ru

# ====================================================================
# 9. DNS
# ====================================================================
# yc dns zone create --name=numino-zone --zone=numino.ru.
# A-запись: numino.ru → IP Object Storage / API Gateway

# ====================================================================
# 10. Что НЕ нужно — всё Firebase выпиливается:
# ====================================================================
# ❌ firebase.json
# ❌ firestore.rules / firestore.indexes.json
# ❌ storage.rules
# ❌ Firebase Auth
# ❌ Firebase Hosting
# ❌ Cloud Firestore
# ❌ Firebase Storage
# ✅ Всё на Яндекс.Облаке — YDB + Object Storage + Cloud Functions + API Gateway + Яндекс ID
