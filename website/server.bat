@echo off
cd /d "D:\CargoProfi\website"
echo.
echo ========================================
echo   Numino Server — http://localhost:8090
echo   Нажми Ctrl+C чтобы остановить
echo ========================================
echo.
:loop
python -m http.server 8090
echo Сервер упал. Перезапуск через 3 сек...
timeout /t 3 >nul
goto loop
