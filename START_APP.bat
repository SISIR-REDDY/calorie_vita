@echo off
echo 🍎 Starting Calorie Vita App Server...
echo ======================================

REM Check if Python is available
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Python not found. Please install Python first.
    pause
    exit /b 1
)

REM Build the web app
echo 📦 Building web app...
flutter build web --release

REM Start the server
echo 🌐 Starting server on port 8080...
echo.
echo 📱 Your app is now accessible at:
echo    http://192.168.43.60:8080
echo.
echo 📋 Instructions:
echo    1. Make sure your phone is on the same WiFi
echo    2. Open your phone's browser
echo    3. Go to: http://192.168.43.60:8080
echo    4. Test the app features
echo.
echo Press Ctrl+C to stop the server
echo.

cd build\web
python -m http.server 8080 --bind 0.0.0.0 