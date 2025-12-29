#!/bin/bash

# Flutter Clean and Run Script
# This script helps prevent "Failed to halt process" and cache errors

echo "🧹 Cleaning Flutter processes..."
pkill -f "flutter" 2>/dev/null || true
sleep 1

echo "🧹 Cleaning build cache..."
flutter clean

echo "📦 Getting dependencies..."
flutter pub get

echo "🍎 Cleaning iOS pods..."
cd ios
pod deintegrate 2>/dev/null || true
pod install
cd ..

echo "✅ Clean complete! You can now run: flutter run -d <device-id>"
echo ""
echo "To run on your iPhone, use:"
echo "flutter run -d 69263628f6e4d0630cb28f81ee6bf623ccef4554"

