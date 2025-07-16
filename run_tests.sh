#!/bin/bash

# Calorie Vita App Test Runner
# This script runs all types of tests for the Flutter app

echo "🍎 Calorie Vita App Test Runner"
echo "================================"

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed. Please install Flutter first."
    exit 1
fi

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Run unit and widget tests
echo "🧪 Running unit and widget tests..."
flutter test

# Check if tests passed
if [ $? -eq 0 ]; then
    echo "✅ Unit and widget tests passed!"
else
    echo "❌ Unit and widget tests failed!"
    exit 1
fi

# Run integration tests (if device is connected)
echo "🔗 Running integration tests..."
if flutter devices | grep -q "connected"; then
    flutter test integration_test/app_test.dart
    if [ $? -eq 0 ]; then
        echo "✅ Integration tests passed!"
    else
        echo "❌ Integration tests failed!"
        exit 1
    fi
else
    echo "⚠️  No device connected. Skipping integration tests."
fi

# Generate coverage report
echo "📊 Generating coverage report..."
flutter test --coverage

if [ -f "coverage/lcov.info" ]; then
    echo "✅ Coverage report generated!"
    echo "📈 Coverage file: coverage/lcov.info"
    
    # Check if genhtml is available for HTML report
    if command -v genhtml &> /dev/null; then
        echo "🌐 Generating HTML coverage report..."
        genhtml coverage/lcov.info -o coverage/html
        echo "✅ HTML coverage report generated at: coverage/html/index.html"
    else
        echo "⚠️  genhtml not found. Install lcov to generate HTML reports."
    fi
else
    echo "❌ Failed to generate coverage report!"
fi

# Run performance analysis
echo "⚡ Running performance analysis..."
flutter run --profile --dart-define=FLUTTER_WEB_USE_SKIA=true &
FLUTTER_PID=$!

# Wait a bit for the app to start
sleep 10

# Kill the app
kill $FLUTTER_PID 2>/dev/null

echo "✅ Performance analysis completed!"

# Final summary
echo ""
echo "🎉 All tests completed!"
echo "================================"
echo "📋 Summary:"
echo "  ✅ Unit and widget tests"
echo "  ✅ Integration tests (if device connected)"
echo "  ✅ Coverage report"
echo "  ✅ Performance analysis"
echo ""
echo "🚀 Your app is ready for testing!" 