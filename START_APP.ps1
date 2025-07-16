Write-Host "🍎 Starting Calorie Vita App Server..." -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green

# Check if Python is available
try {
    $pythonVersion = python --version 2>&1
    Write-Host "✅ Python found: $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Python not found. Please install Python first." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Build the web app
Write-Host "📦 Building web app..." -ForegroundColor Yellow
flutter build web --release

# Start the server
Write-Host "🌐 Starting server on port 8080..." -ForegroundColor Yellow
Write-Host ""
Write-Host "📱 Your app is now accessible at:" -ForegroundColor Cyan
Write-Host "   http://192.168.43.60:8080" -ForegroundColor White
Write-Host ""
Write-Host "📋 Instructions:" -ForegroundColor Cyan
Write-Host "   1. Make sure your phone is on the same WiFi" -ForegroundColor White
Write-Host "   2. Open your phone's browser" -ForegroundColor White
Write-Host "   3. Go to: http://192.168.43.60:8080" -ForegroundColor White
Write-Host "   4. Test the app features" -ForegroundColor White
Write-Host ""
Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Yellow
Write-Host ""

Set-Location build\web
python -m http.server 8080 --bind 0.0.0.0 