# Firebase Connection Status Check
Write-Host "🔥 Firebase Connection Status" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green

# Check if google-services.json exists
if (Test-Path "android/app/google-services.json") {
    Write-Host "✅ google-services.json found" -ForegroundColor Green
    
    # Read and display project info
    $jsonContent = Get-Content "android/app/google-services.json" | ConvertFrom-Json
    Write-Host "📋 Project ID: $($jsonContent.project_info.project_id)" -ForegroundColor Cyan
    Write-Host "📋 Project Number: $($jsonContent.project_info.project_number)" -ForegroundColor Cyan
    Write-Host "📋 Storage Bucket: $($jsonContent.project_info.storage_bucket)" -ForegroundColor Cyan
    
    # Check package name
    $packageName = $jsonContent.client[0].client_info.android_client_info.package_name
    Write-Host "📱 Package Name: $packageName" -ForegroundColor Cyan
    
} else {
    Write-Host "❌ google-services.json not found" -ForegroundColor Red
}

# Check if build.gradle.kts has correct package name
if (Test-Path "android/app/build.gradle.kts") {
    $buildContent = Get-Content "android/app/build.gradle.kts" -Raw
    if ($buildContent -match "com\.sisirlabs\.calorievita") {
        Write-Host "✅ Package name matches Firebase config" -ForegroundColor Green
    } else {
        Write-Host "❌ Package name mismatch in build.gradle.kts" -ForegroundColor Red
    }
    
    if ($buildContent -match "com\.google\.gms\.google-services") {
        Write-Host "✅ Google Services plugin configured" -ForegroundColor Green
    } else {
        Write-Host "❌ Google Services plugin not configured" -ForegroundColor Red
    }
}

# Check if MainActivity exists in correct location
if (Test-Path "android/app/src/main/kotlin/com/sisirlabs/calorievita/MainActivity.kt") {
    Write-Host "✅ MainActivity.kt in correct location" -ForegroundColor Green
} else {
    Write-Host "❌ MainActivity.kt not in correct location" -ForegroundColor Red
}

Write-Host "`n🎯 Next Steps:" -ForegroundColor Yellow
Write-Host "1. Enable Firebase services in Firebase Console:" -ForegroundColor White
Write-Host "   - Authentication (Email/Password)" -ForegroundColor White
Write-Host "   - Firestore Database" -ForegroundColor White
Write-Host "   - Storage" -ForegroundColor White
Write-Host "2. Test connection: flutter run" -ForegroundColor White
Write-Host "3. Check Firebase Console for data" -ForegroundColor White

Write-Host "`n🔗 Firebase Console:" -ForegroundColor Cyan
Write-Host "https://console.firebase.google.com/project/calorie-vita/overview" -ForegroundColor White 