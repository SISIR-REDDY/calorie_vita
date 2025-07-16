# Firebase Setup Verification Script
Write-Host "🔍 Verifying Firebase Setup..." -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green

# Check if android/app directory exists
if (Test-Path "android/app") {
    Write-Host "✅ android/app directory exists" -ForegroundColor Green
} else {
    Write-Host "❌ android/app directory missing" -ForegroundColor Red
    Write-Host "Run: flutter create --platforms android ." -ForegroundColor Yellow
    exit 1
}

# Check if google-services.json exists
if (Test-Path "android/app/google-services.json") {
    Write-Host "✅ google-services.json found" -ForegroundColor Green
} else {
    Write-Host "❌ google-services.json missing" -ForegroundColor Red
    Write-Host "Please:" -ForegroundColor Yellow
    Write-Host "1. Go to Firebase Console: https://console.firebase.google.com/" -ForegroundColor White
    Write-Host "2. Create project 'calorie-vita'" -ForegroundColor White
    Write-Host "3. Add Android app with package: com.example.calorie_vita" -ForegroundColor White
    Write-Host "4. Download google-services.json" -ForegroundColor White
    Write-Host "5. Place it in: android/app/google-services.json" -ForegroundColor White
    Write-Host "`n📖 See FIREBASE_SETUP.md for detailed instructions" -ForegroundColor Cyan
}

# Check if build.gradle.kts has Google Services plugin
if (Test-Path "android/app/build.gradle.kts") {
    $content = Get-Content "android/app/build.gradle.kts" -Raw
    if ($content -match "com\.google\.gms\.google-services") {
        Write-Host "✅ Google Services plugin configured" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Google Services plugin not configured" -ForegroundColor Yellow
    }
}

Write-Host "`n🎯 Next Steps:" -ForegroundColor Yellow
Write-Host "1. Place your google-services.json in android/app/" -ForegroundColor White
Write-Host "2. Run: flutter run" -ForegroundColor White
Write-Host "3. Test your app!" -ForegroundColor White 