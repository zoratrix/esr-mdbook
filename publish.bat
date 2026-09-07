@echo off
chcp 65001 > nul
cd /d "%~dp0"

echo.
echo ========================================
echo   Публикация учебника
echo ========================================
echo.

echo --- Подтягиваем изменения с GitHub ---
git pull origin main --rebase

echo --- Текущее состояние (изменённые файлы) ---
git status

echo.
set /p confirm="Вы уверены, что хотите опубликовать эти изменения? (y/n): "
if /i not "%confirm%"=="y" (
    echo Отменено.
    pause
    exit /b
)

echo.
set /p commit_msg="Введите сообщение коммита (или оставьте пустым для автоматического): "
if "%commit_msg%"=="" (
    set commit_msg=Автоматическая публикация %date% %time%
)

echo.
echo Добавляем все изменения...
git add .

echo Коммитим с сообщением: "%commit_msg%"
git commit -m "%commit_msg%"

echo Отправляем на GitHub и школьный сервер...
git push all main --force

echo.
echo ✅ Готово! Учебник опубликован.
pause