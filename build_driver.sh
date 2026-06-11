#!/bin/bash
# Numino Driver APK — Build Script
# Запускать на ПК с Android Studio и Flutter SDK

echo "=== Numino Driver APK Build ==="
echo ""

# 1. Get dependencies
echo "[1/3] flutter pub get..."
flutter pub get

# 2. Build APK (driver entry point)
echo "[2/3] flutter build apk --release..."
flutter build apk --release --target lib/main_driver.dart

# 3. Show output
echo ""
echo "[3/3] Done! APK location:"
ls -lh build/app/outputs/flutter-apk/app-release.apk 2>/dev/null || echo "Build failed. Check errors above."

echo ""
echo "Copy APK to server:"
echo "  scp build/app/outputs/flutter-apk/app-release.apk root@YOUR_SERVER:/opt/CargoProfi/website/downloads/numino-driver.apk"
echo ""
echo "Then update landing page download button to:"
echo "  /downloads/numino-driver.apk"
