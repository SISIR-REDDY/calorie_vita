@echo off
REM Calorie Vita App Test Runner for Windows
REM This script runs all types of tests for the Flutter app

echo 🍎 Calorie Vita App Test Runner
echo ================================

REM Check if Flutter is installed
where flutter >nul 2>nul
if %errorlevel% neq 0 (
    echo ❌ Flutter is not installed. Please install Flutter first.
    pause
    exit /b 1
)

REM Get dependencies
echo 📦 Getting dependencies...
flutter pub get

REM Run unit and widget tests
echo 🧪 Running unit and widget tests...
flutter test

REM Check if tests passed
if %errorlevel% equ 0 (
    echo ✅ Unit and widget tests passed!
) else (
    echo ❌ Unit and widget tests failed!
    pause
    exit /b 1
)

REM Run integration tests (if device is connected)
echo 🔗 Running integration tests...
flutter devices | findstr "connected" >nul
if %errorlevel% equ 0 (
    flutter test integration_test/app_test.dart
    if %errorlevel% equ 0 (
        echo ✅ Integration tests passed!
    ) else (
        echo ❌ Integration tests failed!
        pause
        exit /b 1
    )
) else (
    echo ⚠️  No device connected. Skipping integration tests.
)

REM Generate coverage report
echo 📊 Generating coverage report...
flutter test --coverage

if exist "coverage\lcov.info" (
    echo ✅ Coverage report generated!
    echo 📈 Coverage file: coverage\lcov.info
) else (
    echo ❌ Failed to generate coverage report!
)

REM Final summary
echo.
echo 🎉 All tests completed!
echo ================================
echo 📋 Summary:
echo   ✅ Unit and widget tests
echo   ✅ Integration tests (if device connected)
echo   ✅ Coverage report
echo.
echo 🚀 Your app is ready for testing!
pause 