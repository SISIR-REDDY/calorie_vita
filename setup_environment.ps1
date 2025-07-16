# Flutter Environment Setup Script for Calorie Vita App
# Run this script as Administrator

Write-Host "🍎 Calorie Vita Environment Setup" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Green

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Host "❌ Please run this script as Administrator" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# 1. Check Flutter Installation
Write-Host "`n1. Checking Flutter installation..." -ForegroundColor Yellow
try {
    $flutterVersion = flutter --version
    Write-Host "✅ Flutter is installed" -ForegroundColor Green
    Write-Host $flutterVersion[0] -ForegroundColor Cyan
} catch {
    Write-Host "❌ Flutter is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Flutter from: https://flutter.dev/docs/get-started/install" -ForegroundColor Yellow
    Read-Host "Press Enter to continue after installing Flutter"
}

# 2. Run flutter doctor
Write-Host "`n2. Running flutter doctor..." -ForegroundColor Yellow
flutter doctor

# 3. Check for connected devices
Write-Host "`n3. Checking for connected devices..." -ForegroundColor Yellow
$devices = flutter devices
Write-Host $devices -ForegroundColor Cyan

if ($devices -match "No devices connected") {
    Write-Host "⚠️  No devices connected. You can:" -ForegroundColor Yellow
    Write-Host "   - Connect a physical device with USB debugging enabled" -ForegroundColor White
    Write-Host "   - Start an Android emulator" -ForegroundColor White
    Write-Host "   - Use web browser: flutter run -d chrome" -ForegroundColor White
}

# 4. Get dependencies
Write-Host "`n4. Getting project dependencies..." -ForegroundColor Yellow
flutter pub get

# 5. Check Firebase configuration
Write-Host "`n5. Checking Firebase configuration..." -ForegroundColor Yellow
if (Test-Path "android/app/google-services.json") {
    Write-Host "✅ google-services.json found in android/app/" -ForegroundColor Green
} else {
    Write-Host "❌ google-services.json not found" -ForegroundColor Red
    Write-Host "Please follow these steps:" -ForegroundColor Yellow
    Write-Host "1. Go to Firebase Console: https://console.firebase.google.com/" -ForegroundColor White
    Write-Host "2. Create a new project named 'calorie-vita'" -ForegroundColor White
    Write-Host "3. Add Android app with package name: com.example.calorie_vita" -ForegroundColor White
    Write-Host "4. Download google-services.json" -ForegroundColor White
    Write-Host "5. Place it in: android/app/google-services.json" -ForegroundColor White
    Write-Host "6. Enable Authentication, Firestore, and Storage services" -ForegroundColor White
    Write-Host "`n📖 See FIREBASE_SETUP.md for detailed instructions" -ForegroundColor Cyan
}

# 6. Check for test files
Write-Host "`n6. Checking test files..." -ForegroundColor Yellow
$testFiles = @(
    "test/auth_service_test.dart",
    "test/widget_test.dart", 
    "integration_test/app_test.dart"
)

foreach ($file in $testFiles) {
    if (Test-Path $file) {
        Write-Host "✅ $file" -ForegroundColor Green
    } else {
        Write-Host "❌ $file missing" -ForegroundColor Red
    }
}

# 7. Check Android configuration
Write-Host "`n7. Checking Android configuration..." -ForegroundColor Yellow
if (Test-Path "android/app/build.gradle.kts") {
    Write-Host "✅ Android configuration exists" -ForegroundColor Green
    
    # Check if Google Services plugin is configured
    $buildGradleContent = Get-Content "android/app/build.gradle.kts" -Raw
    if ($buildGradleContent -match "com\.google\.gms\.google-services") {
        Write-Host "✅ Google Services plugin configured" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Google Services plugin not configured" -ForegroundColor Yellow
    }
} else {
    Write-Host "❌ Android configuration missing" -ForegroundColor Red
    Write-Host "Run: flutter create --platforms android ." -ForegroundColor Yellow
}

# 8. Final verification
Write-Host "`n8. Final verification..." -ForegroundColor Yellow
Write-Host "Running flutter doctor one more time..." -ForegroundColor White
flutter doctor

Write-Host "`n🎉 Setup Complete!" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Configure Firebase (if not done) - see FIREBASE_SETUP.md" -ForegroundColor White
Write-Host "2. Connect a device or start emulator" -ForegroundColor White
Write-Host "3. Run: flutter run" -ForegroundColor White
Write-Host "4. Run tests: .\run_tests.bat" -ForegroundColor White

Read-Host "`nPress Enter to exit" 