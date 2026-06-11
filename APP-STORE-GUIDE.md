# RuStore APK Publication Guide for Numino

## 1. Подпись APK

### Создать keystore
```bash
keytool -genkey -v -keystore ~/numino-upload.keystore \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias numino -storepass NU0_MINO2026 -keypass NU0_MINO2026
```

### Добавить key.properties в android/
```properties
storePassword=NU0_MINO2026
keyPassword=NU0_MINO2026
keyAlias=numino
storeFile=/home/user/numino-upload.keystore
```

## 2. Сборка

### Release APK
```bash
cd cargo_app
flutter build apk --release --target-platform android-arm64
```

### Release App Bundle (для Google Play, опционально)
```bash
flutter build appbundle --release
```

Готовый APK: `build/app/outputs/flutter-apk/app-release.apk`

## 3. Публикация в RuStore

1. Зарегистрироваться на https://www.rustore.ru/developers
2. Загрузить APK (размер до 4 ГБ)
3. Заполнить:
   - Название: Numino — Рабочий кабинет перевозчика
   - Категория: Бизнес
   - Описание: автоматизация учёта рейсов, расходов,
     зарплаты и путевых листов для ИП-перевозчиков
   - Скриншоты (минимум 3, PNG/JPEG, 320-4096 px)
   - Иконка 512×512 px
   - Возрастное ограничение: 18+
   - Политика конфиденциальности: https://numino.ru/privacy.html
   - EULA: https://numino.ru/eula.html
4. Пройти модерацию (1-3 дня)

## 4. Прямая раздача APK

Добавить ссылку на лендинге:
```html
<a href="https://github.com/numino/numino/releases/latest/download/app-release.apk"
   class="btn btn--primary btn--download">
  Скачать APK
</a>
```

Загрузить APK как GitHub Release артефакт.

## 5. Версионирование

В cargo_app/pubspec.yaml:
```yaml
version: 1.0.0+1
  #      ^^^^^ ^^^
  #      name  code
```

Инкрементировать versionCode (+1) при каждом релизе.
