#!/bin/bash
# ====================================================================
# NUMINO — Деплой на Яндекс.Облако (Российский стек)
# ====================================================================
# Запускать по одному блоку за раз, проверяя вывод каждой команды.
# Требуется: yc CLI установлен и авторизован (yc init)
# ====================================================================

set -e

# ──────────────────────────────────────────────────
# 0. ПРОВЕРКА: установлен ли yc CLI?
# ──────────────────────────────────────────────────
if ! command -v yc &>/dev/null; then
  echo "❌ yc CLI не установлен. Выполни:"
  echo "   curl -sSL https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash"
  echo "   yc init"
  exit 1
fi

yc config list 2>/dev/null || { echo "❌ Сначала выполни: yc init"; exit 1; }

FOLDER_NAME="numino-production"
FOLDER_ID=$(yc resource-manager folder get "$FOLDER_NAME" --format=json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || echo "")

if [ -z "$FOLDER_ID" ]; then
  echo "Создаю каталог $FOLDER_NAME..."
  yc resource-manager folder create --name "$FOLDER_NAME" --description "Numino production"
  FOLDER_ID=$(yc resource-manager folder get "$FOLDER_NAME" --format=json | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
fi
echo "📁 Каталог: $FOLDER_NAME ($FOLDER_ID)"

# ──────────────────────────────────────────────────
# 1. СЕРВИСНЫЙ АККАУНТ
# ──────────────────────────────────────────────────
SA_NAME="numino-sa"
SA_ID=$(yc iam service-account get "$SA_NAME" --folder-id "$FOLDER_ID" --format=json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || echo "")

if [ -z "$SA_ID" ]; then
  echo "Создаю сервисный аккаунт..."
  yc iam service-account create --name "$SA_NAME" \
    --description "Numino backend service account" \
    --folder-id "$FOLDER_ID"
  SA_ID=$(yc iam service-account get "$SA_NAME" --folder-id "$FOLDER_ID" --format=json | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
fi

# Роли
for role in ydb.admin storage.admin serverless.functions.invoker; do
  yc resource-manager folder add-access-binding "$FOLDER_ID" \
    --role "$role" --subject "serviceAccount:$SA_ID" 2>/dev/null || true
done
echo "🔑 Сервисный аккаунт: $SA_NAME ($SA_ID)"

# Создать ключ доступа (сохранить!)
SA_KEY_FILE="sa-key.json"
if [ ! -f "$SA_KEY_FILE" ]; then
  yc iam access-key create --service-account-name "$SA_NAME" \
    --format json > "$SA_KEY_FILE"
  echo "⚠️  Ключ сохранён в $SA_KEY_FILE — НЕ КОММИТЬ В GIT!"
fi
echo "🔐 SA key в: $SA_KEY_FILE"

# ──────────────────────────────────────────────────
# 2. YDB Serverless (база данных)
# ──────────────────────────────────────────────────
DB_NAME="numino-db"
echo "Создаю YDB..."
yc ydb database create "$DB_NAME" --serverless --folder-id "$FOLDER_ID"

# Ждём создания
sleep 15

DB_ENDPOINT=$(yc ydb database get "$DB_NAME" --format=json | python3 -c "import sys,json; print(json.load(sys.stdin).get('endpoint',''))")
DB_PATH=$(yc ydb database get "$DB_NAME" --format=json | python3 -c "import sys,json; print(json.load(sys.stdin).get('database',''))")

echo "📊 YDB: $DB_ENDPOINT"
echo "📊 DB path: $DB_PATH"

# Применить схему
echo "Применяю схему базы..."
pip install ydb 2>/dev/null || pip3 install ydb 2>/dev/null || true
python3 -c "
import ydb, sys
with ydb.Driver(endpoint='${DB_ENDPOINT}', database='${DB_PATH}', credentials=ydb.AccessTokenCredentials('')) as driver:
    driver.wait(timeout=10)
    with open('functions-yandex/schema.sql', 'r') as f:
        sql = f.read()
    for stmt in sql.split(';'):
        stmt = stmt.strip()
        if stmt and not stmt.startswith('--'):
            driver.table_client.session().create().execute_scheme(stmt)
print('Schema applied')
" || echo "⚠️  Схему нужно применить вручную через консоль YDB"

# ──────────────────────────────────────────────────
# 3. OBJECT STORAGE (файлы + хостинг)
# ──────────────────────────────────────────────────
echo "Создаю Object Storage бакеты..."

yc storage bucket create --name numino-files --folder-id "$FOLDER_ID" 2>/dev/null || echo "  numino-files уже существует"
yc storage bucket create --name numino-website --folder-id "$FOLDER_ID" 2>/dev/null || echo "  numino-website уже существует"

# Настройка веб-сайта
yc storage bucket update --name numino-website \
  --website-index index.html \
  --website-error 404.html 2>/dev/null || true

# Публичный доступ
yc storage bucket update --name numino-website --grants read=allUsers 2>/dev/null || true

# Загрузка сайта
echo "Загружаю сайт в numino-website..."
yc storage s3cp --recursive website/ "s3://numino-website/" --exclude "*.py" --exclude "*.json" --exclude "*.bat" 2>/dev/null || echo "  Установи s3cmd: pip install s3cmd"

# ──────────────────────────────────────────────────
# 4. CLOUD FUNCTIONS
# ──────────────────────────────────────────────────
echo "Деплою Cloud Functions..."

cd functions-yandex
npm install 2>/dev/null || echo "⚠️  npm не установлен — установи Node.js 20"
npm run build 2>/dev/null || echo "⚠️  tsc не установлен"

yc serverless function create --name numino-api --folder-id "$FOLDER_ID" 2>/dev/null || echo "  numino-api уже существует"

yc serverless function version create \
  --function-name numino-api \
  --folder-id "$FOLDER_ID" \
  --runtime nodejs20 \
  --entrypoint index.handler \
  --source-path dist \
  --memory 256MB \
  --execution-timeout 60s \
  --service-account-id "$SA_ID" \
  --environment "YDB_ENDPOINT=$DB_ENDPOINT,YDB_PATH=$DB_PATH"

FUNCTION_URL=$(yc serverless function get numino-api --folder-id "$FOLDER_ID" --format=json | python3 -c "import sys,json; print(json.load(sys.stdin).get('http_invoke_url',''))")
echo "⚡ Cloud Function: $FUNCTION_URL"
cd ..

# ──────────────────────────────────────────────────
# 5. API GATEWAY
# ──────────────────────────────────────────────────
echo "Создаю API Gateway..."
yc serverless api-gateway create --name numino-gateway --folder-id "$FOLDER_ID" \
  --spec functions-yandex/api-gateway.yaml 2>/dev/null || \
yc serverless api-gateway update --name numino-gateway --folder-id "$FOLDER_ID" \
  --spec functions-yandex/api-gateway.yaml

GATEWAY_URL=$(yc serverless api-gateway get numino-gateway --folder-id "$FOLDER_ID" --format=json | python3 -c "import sys,json; print(json.load(sys.stdin).get('domain',''))")
echo "🌐 API Gateway: $GATEWAY_URL"

# ──────────────────────────────────────────────────
# 6. ЯНДЕКС ID (OAuth)
# ──────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  ДАЛЬШЕ — РУЧНЫЕ ШАГИ"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "📋 Запиши эти значения:"
echo "   YDB_ENDPOINT = $DB_ENDPOINT"
echo "   DB_PATH      = $DB_PATH"
echo "   FUNCTION_URL = $FUNCTION_URL"
echo "   GATEWAY_URL  = $GATEWAY_URL"
echo "   SA_ID        = $SA_ID"
echo ""
echo "✋ Шаг 7: Яндекс ID"
echo "   Открой https://oauth.yandex.ru"
echo "   Создай приложение:"
echo "     Название: Numino"
echo "     Redirect URI: https://numino.ru/callback"
echo "     Права: login:email, login:info"
echo "   Запиши Client ID: _____________________"
echo ""
echo "✋ Шаг 8: Яндекс.Касса (оплата тарифов)"
echo "   Открой https://kassa.yandex.ru"
echo "   Зарегистрируй магазин"
echo "   Запиши shopId: _____________________"
echo "   Запиши secretKey: _____________________"
echo ""
echo "✋ Шаг 9: DNS"
echo "   yc dns zone create --name numino-zone --zone numino.ru. --folder-id $FOLDER_ID"
echo "   Добавь A-запись: numino.ru → IP Object Storage"
echo ""
echo "✋ Шаг 10: TLS"
echo "   yc certificate-manager certificate create \\"
echo "     --name numino-cert --domains numino.ru,www.numino.ru"
echo ""
echo "✋ Шаг 11: Обнови CloudConfig в Flutter"
echo "   В cargo_app/lib/services/cloud/cloud_config.dart:"
echo "   yandexFunctionUrl = '$FUNCTION_URL'"
echo "   yandexStorageBucket = 'numino-files'"
echo "   yandexDbEndpoint = '$DB_ENDPOINT'"
echo "   yandexOAuthClientId = '<CLIENT_ID_ИЗ_ШАГА_7>'"
echo "   provider = CloudProvider.yandex"
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  ГОТОВО. После заполнения ручных шагов — пилот запущен."
echo "═══════════════════════════════════════════════════════"
