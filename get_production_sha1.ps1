# 🔑 Get Production Keystore SHA-1 Fingerprint
# This script extracts the SHA-1 fingerprint from your production keystore
# You need this to add to Firebase Console for Google Sign-In to work in release builds

Write-Host "🔑 Production Keystore SHA-1 Fingerprint Generator" -ForegroundColor Cyan
Write-Host ""

$keystorePath = "android\calorie-vita-release.jks"
$keyPropertiesPath = "android\key.properties"

if (-not (Test-Path $keystorePath)) {
    Write-Host "❌ Keystore not found at: $keystorePath" -ForegroundColor Red
    Write-Host "   Please run generate_keystore.ps1 first" -ForegroundColor Yellow
    exit 1
}

# Load keystore password from key.properties if available
$storePassword = $null
if (Test-Path $keyPropertiesPath) {
    $keyProperties = Get-Content $keyPropertiesPath
    foreach ($line in $keyProperties) {
        if ($line -match "storePassword=(.+)") {
            $storePassword = $matches[1]
            break
        }
    }
}

if (-not $storePassword) {
    Write-Host "📝 Enter keystore password:" -ForegroundColor Yellow
    $securePassword = Read-Host "Password" -AsSecureString
    $storePassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))
}

Write-Host ""
Write-Host "🔍 Extracting SHA-1 fingerprint..." -ForegroundColor Yellow

try {
    # Get SHA-1 fingerprint
    $output = keytool -list -v -keystore $keystorePath -alias calorie-vita -storepass $storePassword 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        # Extract SHA1 line
        $sha1Line = $output | Select-String -Pattern "SHA1:|SHA-1:" | Select-Object -First 1
        
        if ($sha1Line) {
            # Extract the SHA-1 value (remove colons and spaces)
            $sha1 = ($sha1Line -split ":")[1].Trim() -replace " ", ""
            
            Write-Host ""
            Write-Host "✅ Production Keystore SHA-1 Fingerprint:" -ForegroundColor Green
            Write-Host ""
            Write-Host "   $sha1" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "📋 Next Steps:" -ForegroundColor Yellow
            Write-Host "1. Go to Firebase Console: https://console.firebase.google.com/" -ForegroundColor White
            Write-Host "2. Select your project: calorie-vita" -ForegroundColor White
            Write-Host "3. Go to: Project Settings → Your apps → Android app" -ForegroundColor White
            Write-Host "4. Click 'Add fingerprint' button" -ForegroundColor White
            Write-Host "5. Paste this SHA-1: $sha1" -ForegroundColor Cyan
            Write-Host "6. Click 'Save'" -ForegroundColor White
            Write-Host "7. Download the updated google-services.json" -ForegroundColor White
            Write-Host "8. Replace android/app/google-services.json with the new file" -ForegroundColor White
            Write-Host ""
            Write-Host "⚠️  Without this, Google Sign-In will fail in release builds!" -ForegroundColor Red
            Write-Host ""
            
            # Also extract SHA-256 for reference
            $sha256Line = $output | Select-String -Pattern "SHA256:" | Select-Object -First 1
            if ($sha256Line) {
                $sha256 = ($sha256Line -split ":")[1].Trim() -replace " ", ""
                Write-Host "📝 SHA-256 (for reference):" -ForegroundColor Gray
                Write-Host "   $sha256" -ForegroundColor Gray
                Write-Host ""
            }
        } else {
            Write-Host "❌ Could not extract SHA-1 from keystore output" -ForegroundColor Red
            Write-Host "   Output:" -ForegroundColor Yellow
            Write-Host $output
        }
    } else {
        Write-Host "❌ Failed to read keystore. Check your password." -ForegroundColor Red
        Write-Host "   Error output:" -ForegroundColor Yellow
        Write-Host $output
        exit 1
    }
} catch {
    Write-Host "❌ Error: $_" -ForegroundColor Red
    exit 1
}

