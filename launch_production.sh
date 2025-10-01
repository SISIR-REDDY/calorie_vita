#!/bin/bash

# 🚀 Calorie Vita - Production Launch Script
# This script prepares the app for Play Store launch

echo "🚀 Starting Calorie Vita Production Launch Process..."

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed or not in PATH"
    exit 1
fi

# Check Flutter version
echo "📱 Flutter version:"
flutter --version

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Run analysis
echo "🔍 Running code analysis..."
flutter analyze

# Run tests
echo "🧪 Running tests..."
flutter test

# Build release app bundle
echo "🏗️ Building release app bundle..."
flutter build appbundle --release

# Check if build was successful
if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo "📱 App bundle location: build/app/outputs/bundle/release/app-release.aab"
    echo ""
    echo "🎉 Ready for Play Store upload!"
    echo ""
    echo "📋 Next steps:"
    echo "1. Upload app-release.aab to Google Play Console"
    echo "2. Complete store listing information"
    echo "3. Add screenshots and feature graphic"
    echo "4. Set up production signing keys"
    echo "5. Submit for review"
    echo ""
    echo "📊 App bundle size:"
    ls -lh build/app/outputs/bundle/release/app-release.aab
else
    echo "❌ Build failed! Please check the errors above."
    exit 1
fi

echo "🚀 Production launch process completed!"
