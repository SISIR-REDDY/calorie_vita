# Android Setup Script for Phone Connection
Write-Host "📱 Setting up Android tools for phone connection..." -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green

# Check if Android SDK is already installed
$androidHome = $env:ANDROID_HOME
if ($androidHome -and (Test-Path $androidHome)) {
    Write-Host "✅ Android SDK found at: $androidHome" -ForegroundColor Green
} else {
    Write-Host "❌ Android SDK not found" -ForegroundColor Red
    Write-Host "Installing minimal Android tools..." -ForegroundColor Yellow
    
    # Create Android SDK directory
    $sdkPath = "C:\Android\Sdk"
    if (!(Test-Path $sdkPath)) {
        New-Item -ItemType Directory -Path $sdkPath -Force
        Write-Host "Created Android SDK directory: $sdkPath" -ForegroundColor Cyan
    }
    
    # Set environment variable
    $env:ANDROID_HOME = $sdkPath
    Write-Host "Set ANDROID_HOME to: $sdkPath" -ForegroundColor Cyan
}

# Check if phone is connected
Write-Host "`n🔍 Checking for connected devices..." -ForegroundColor Yellow

# Try to detect USB devices
$usbDevices = Get-PnpDevice | Where-Object {$_.Status -eq "OK" -and $_.Class -eq "USB"}
Write-Host "Found $($usbDevices.Count) USB devices:" -ForegroundColor Cyan
foreach ($device in $usbDevices) {
    Write-Host "  - $($device.FriendlyName)" -ForegroundColor White
}

# Check if phone is connected via USB
Write-Host "`n📱 Phone Connection Steps:" -ForegroundColor Yellow
Write-Host "1. Connect your phone via USB cable" -ForegroundColor White
Write-Host "2. Enable Developer Options on your phone:" -ForegroundColor White
Write-Host "   - Go to Settings → About phone" -ForegroundColor White
Write-Host "   - Tap 'Build number' 7 times" -ForegroundColor White
Write-Host "3. Enable USB debugging:" -ForegroundColor White
Write-Host "   - Go to Settings → Developer options" -ForegroundColor White
Write-Host "   - Enable 'USB debugging'" -ForegroundColor White
Write-Host "4. Allow USB debugging when prompted on phone" -ForegroundColor White

# Try to run flutter devices again
Write-Host "`n🔄 Checking Flutter devices..." -ForegroundColor Yellow
flutter devices

Write-Host "`n🎯 Next Steps:" -ForegroundColor Yellow
Write-Host "1. Install Android Studio for full Android development" -ForegroundColor White
Write-Host "2. Or use the web version on your phone: http://192.168.43.60:8080" -ForegroundColor White
Write-Host "3. For native app, you'll need Android SDK" -ForegroundColor White

Write-Host "`n📚 Resources:" -ForegroundColor Cyan
Write-Host "Android Studio: https://developer.android.com/studio" -ForegroundColor White
Write-Host "Flutter Android Setup: https://docs.flutter.dev/get-started/install/windows" -ForegroundColor White 