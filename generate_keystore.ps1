# 🔐 Calorie Vita - Keystore Generation Script (Windows PowerShell)
# This script generates a production keystore for Play Store signing

Write-Host "🔐 Calorie Vita - Production Keystore Generator" -ForegroundColor Cyan
Write-Host ""

# Check if Java/keytool is available
if (-not (Get-Command keytool -ErrorAction SilentlyContinue)) {
    Write-Host "❌ keytool not found. Please ensure Java JDK is installed and in PATH." -ForegroundColor Red
    Write-Host "   Download Java JDK from: https://adoptium.net/" -ForegroundColor Yellow
    exit 1
}

$keystorePath = "android\calorie-vita-release.jks"
$keyPropertiesPath = "android\key.properties"
$keyPropertiesTemplate = "android\key.properties.template"

# Check if keystore already exists
if (Test-Path $keystorePath) {
    Write-Host "⚠️ Keystore already exists at: $keystorePath" -ForegroundColor Yellow
    $overwrite = Read-Host "Overwrite existing keystore? (y/N)"
    if ($overwrite -ne "y" -and $overwrite -ne "Y") {
        Write-Host "Keystore generation cancelled." -ForegroundColor Red
        exit 1
    }
}

Write-Host "📝 Please provide the following information:" -ForegroundColor Yellow
Write-Host ""

# Get keystore information
$storePassword = Read-Host "Enter keystore password (min 6 characters)" -AsSecureString
$storePasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($storePassword))

if ($storePasswordPlain.Length -lt 6) {
    Write-Host "❌ Password must be at least 6 characters long!" -ForegroundColor Red
    exit 1
}

$keyPassword = Read-Host "Enter key password (or press Enter to use same as keystore password)" -AsSecureString
$keyPasswordPlain = if ($keyPassword.Length -eq 0) { 
    $storePasswordPlain 
} else { 
    [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($keyPassword))
}

$firstName = Read-Host "First and Last Name"
$organizationalUnit = Read-Host "Organizational Unit (e.g., Development)"
$organization = Read-Host "Organization (e.g., SISIR Labs)"
$city = Read-Host "City or Locality"
$state = Read-Host "State or Province"
$countryCode = Read-Host "Two-letter country code (e.g., US, IN)"

if ($countryCode.Length -ne 2) {
    Write-Host "❌ Country code must be exactly 2 letters!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "🔨 Generating keystore..." -ForegroundColor Yellow

# Generate keystore
# Construct DN string - values with spaces are fine, keytool handles them
$dname = "CN=$firstName, OU=$organizationalUnit, O=$organization, L=$city, ST=$state, C=$countryCode"

try {
    # Use & operator to call keytool directly for better argument handling
    $keytoolArgs = @(
        "-genkey",
        "-v",
        "-keystore", $keystorePath,
        "-keyalg", "RSA",
        "-keysize", "2048",
        "-validity", "10000",
        "-alias", "calorie-vita",
        "-storepass", $storePasswordPlain,
        "-keypass", $keyPasswordPlain,
        "-dname", $dname
    )
    
    $output = & keytool $keytoolArgs 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        Write-Host "✅ Keystore generated successfully!" -ForegroundColor Green
        Write-Host "   Location: $keystorePath" -ForegroundColor Cyan
    } else {
        Write-Host "❌ Keystore generation failed!" -ForegroundColor Red
        Write-Host $output
        exit 1
    }
} catch {
    Write-Host "❌ Error generating keystore: $_" -ForegroundColor Red
    exit 1
}

# Create key.properties file
Write-Host ""
Write-Host "📝 Creating key.properties file..." -ForegroundColor Yellow

if (Test-Path $keyPropertiesTemplate) {
    $templateContent = Get-Content $keyPropertiesTemplate -Raw
    
    # Replace placeholders
    $templateContent = $templateContent -replace "YOUR_STORE_PASSWORD_HERE", $storePasswordPlain
    $templateContent = $templateContent -replace "YOUR_KEY_PASSWORD_HERE", $keyPasswordPlain
    
    # Write key.properties
    $templateContent | Out-File -FilePath $keyPropertiesPath -Encoding UTF8 -NoNewline
    
    Write-Host "✅ key.properties created successfully!" -ForegroundColor Green
    Write-Host "   Location: $keyPropertiesPath" -ForegroundColor Cyan
} else {
    Write-Host "⚠️ Template file not found. Creating key.properties manually..." -ForegroundColor Yellow
    $keyPropertiesContent = @"
storePassword=$storePasswordPlain
keyPassword=$keyPasswordPlain
keyAlias=calorie-vita
storeFile=../calorie-vita-release.jks
"@
    $keyPropertiesContent | Out-File -FilePath $keyPropertiesPath -Encoding UTF8
    Write-Host "✅ key.properties created!" -ForegroundColor Green
}

Write-Host ""
Write-Host "🔒 IMPORTANT SECURITY NOTES:" -ForegroundColor Red
Write-Host "1. Keep your keystore file ($keystorePath) safe and backed up!" -ForegroundColor Yellow
Write-Host "2. Never commit key.properties or the keystore to version control!" -ForegroundColor Yellow
Write-Host "3. Store passwords securely - you'll need them for app updates!" -ForegroundColor Yellow
Write-Host "4. If you lose the keystore, you cannot update your app on Play Store!" -ForegroundColor Yellow
Write-Host ""
Write-Host "✅ Keystore setup complete! You can now build production releases." -ForegroundColor Green

