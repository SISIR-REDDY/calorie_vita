# 🚀 Calorie Vita - Production Launch Script (Windows PowerShell)
# This script prepares the app for Play Store launch on Windows

Write-Host "🚀 Starting Calorie Vita Production Launch Process..." -ForegroundColor Cyan

# Check if Flutter is installed
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Flutter is not installed or not in PATH" -ForegroundColor Red
    exit 1
}

# Check Flutter version
Write-Host "`n📱 Flutter version:" -ForegroundColor Yellow
flutter --version

# Clean previous builds
Write-Host "`n🧹 Cleaning previous builds..." -ForegroundColor Yellow
flutter clean

# Get dependencies
Write-Host "`n📦 Getting dependencies..." -ForegroundColor Yellow
flutter pub get

# Run analysis
Write-Host "`n🔍 Running code analysis..." -ForegroundColor Yellow
flutter analyze

# Check if analysis passed
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️ Code analysis found issues. Continuing anyway..." -ForegroundColor Yellow
}

# Run tests
Write-Host "`n🧪 Running tests..." -ForegroundColor Yellow
flutter test

# Check if tests passed
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️ Some tests failed. Continuing anyway..." -ForegroundColor Yellow
}

# Check if keystore exists
$keyPropertiesPath = "android\key.properties"
$keystorePath = "android\calorie-vita-release.jks"

if (-not (Test-Path $keyPropertiesPath)) {
    Write-Host "`n⚠️ Production keystore not found!" -ForegroundColor Yellow
    Write-Host "   The app will be built with debug signing (not suitable for Play Store)" -ForegroundColor Yellow
    Write-Host "   To generate keystore, run: generate_keystore.ps1" -ForegroundColor Yellow
    Write-Host ""
    $continue = Read-Host "Continue with debug signing? (y/N)"
    if ($continue -ne "y" -and $continue -ne "Y") {
        Write-Host "Build cancelled." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "`n✅ Production keystore found!" -ForegroundColor Green
}

# Build release app bundle
Write-Host "`n🏗️ Building release app bundle..." -ForegroundColor Yellow
flutter build appbundle --release

# Check if build was successful
if ($LASTEXITCODE -eq 0) {
    $bundlePath = "build\app\outputs\bundle\release\app-release.aab"
    if (Test-Path $bundlePath) {
        $bundleSize = (Get-Item $bundlePath).Length / 1MB
        Write-Host "`n✅ Build successful!" -ForegroundColor Green
        Write-Host "📱 App bundle location: $bundlePath" -ForegroundColor Cyan
        Write-Host "📊 App bundle size: $([math]::Round($bundleSize, 2)) MB" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "🎉 Ready for Play Store upload!" -ForegroundColor Green
        Write-Host ""
        Write-Host "📋 Next steps:" -ForegroundColor Yellow
        Write-Host "1. Upload app-release.aab to Google Play Console"
        Write-Host "2. Complete store listing information"
        Write-Host "3. Add screenshots and feature graphic"
        Write-Host "4. Submit for review"
        Write-Host ""
    } else {
        Write-Host "❌ Build completed but bundle file not found!" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "❌ Build failed! Please check the errors above." -ForegroundColor Red
    exit 1
}

Write-Host "`n🚀 Production launch process completed!" -ForegroundColor Green

