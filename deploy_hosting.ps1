# Firebase Hosting Deployment Script for Calorie Vita
# This script deploys privacy policy and terms of service pages

Write-Host "🚀 Deploying Privacy Policy & Terms of Service to Firebase Hosting..." -ForegroundColor Cyan
Write-Host ""

# Check if Node.js is installed
$nodeVersion = Get-Command node -ErrorAction SilentlyContinue
if (-not $nodeVersion) {
    Write-Host "❌ Node.js is not installed!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install Node.js first:" -ForegroundColor Yellow
    Write-Host "1. Download from: https://nodejs.org/" -ForegroundColor Yellow
    Write-Host "2. Install Node.js (includes npm)" -ForegroundColor Yellow
    Write-Host "3. Restart your terminal" -ForegroundColor Yellow
    Write-Host "4. Run this script again" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Or use manual deployment via Firebase Console:" -ForegroundColor Yellow
    Write-Host "1. Go to: https://console.firebase.google.com/project/calorie-vita/hosting" -ForegroundColor Yellow
    Write-Host "2. Click 'Get started' if hosting is not enabled" -ForegroundColor Yellow
    Write-Host "3. Upload the 'web' folder contents" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Node.js found: $(node --version)" -ForegroundColor Green
Write-Host ""

# Check if Firebase CLI is installed
$firebaseVersion = Get-Command firebase -ErrorAction SilentlyContinue
if (-not $firebaseVersion) {
    Write-Host "📦 Installing Firebase CLI..." -ForegroundColor Yellow
    npm install -g firebase-tools
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to install Firebase CLI" -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ Firebase CLI installed" -ForegroundColor Green
    Write-Host ""
}

# Login to Firebase (if not already logged in)
Write-Host "🔐 Checking Firebase login status..." -ForegroundColor Yellow
$loginCheck = firebase projects:list 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "🔑 Please login to Firebase..." -ForegroundColor Yellow
    firebase login
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Firebase login failed" -ForegroundColor Red
        exit 1
    }
}

# Deploy to Firebase Hosting
Write-Host ""
Write-Host "📤 Deploying to Firebase Hosting..." -ForegroundColor Yellow
firebase deploy --only hosting --project calorie-vita

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Deployment successful!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 Your URLs:" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    Write-Host "Home Page:" -ForegroundColor White
    Write-Host "  https://calorie-vita.web.app" -ForegroundColor Green
    Write-Host ""
    Write-Host "Privacy Policy:" -ForegroundColor White
    Write-Host "  https://calorie-vita.web.app/privacy-policy.html" -ForegroundColor Green
    Write-Host ""
    Write-Host "Terms of Service:" -ForegroundColor White
    Write-Host "  https://calorie-vita.web.app/terms-of-service.html" -ForegroundColor Green
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    Write-Host ""
    Write-Host "📝 Use these URLs in Google Cloud Console branding form:" -ForegroundColor Yellow
    Write-Host "  1. Application home page: https://calorie-vita.web.app" -ForegroundColor White
    Write-Host "  2. Privacy policy link: https://calorie-vita.web.app/privacy-policy.html" -ForegroundColor White
    Write-Host "  3. Terms of Service link: https://calorie-vita.web.app/terms-of-service.html" -ForegroundColor White
} else {
    Write-Host ""
    Write-Host "❌ Deployment failed. Please check the error messages above." -ForegroundColor Red
    Write-Host ""
    Write-Host "Alternative: Deploy manually via Firebase Console:" -ForegroundColor Yellow
    Write-Host "  https://console.firebase.google.com/project/calorie-vita/hosting" -ForegroundColor Cyan
}

