#!/bin/bash

# iOS Simulator Setup Script for Claude Code
# This script automates the iOS development environment setup

set -e

echo "🚀 Claude Code iOS Simulator Setup"
echo "=================================="
echo ""

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Error: Xcode is not installed"
    echo "Please install Xcode from the Mac App Store"
    exit 1
fi

echo "✅ Xcode is installed"
XCODE_VERSION=$(xcodebuild -version | head -n 1)
echo "   Version: $XCODE_VERSION"

# Check Xcode command line tools
if ! xcode-select -p &> /dev/null; then
    echo "⚠️  Installing Xcode Command Line Tools..."
    xcode-select --install
    echo "Please complete the installation and run this script again"
    exit 1
fi

echo "✅ Xcode Command Line Tools installed"

# Accept Xcode license if needed
if ! xcodebuild -license check &> /dev/null; then
    echo "⚠️  Please accept the Xcode license agreement:"
    sudo xcodebuild -license accept
fi

echo "✅ Xcode license accepted"

# Install xcrun if needed
if ! command -v xcrun &> /dev/null; then
    echo "❌ Error: xcrun not found"
    exit 1
fi

# List available simulators
echo ""
echo "📱 Available iOS Simulators:"
echo "----------------------------"
xcrun simctl list devices available | grep -E "iPhone|iPad" | head -20

# Check for iPhone 15 Pro simulator (iOS 17.0+)
SIMULATOR_NAME="iPhone 15 Pro"
if xcrun simctl list devices | grep -q "$SIMULATOR_NAME"; then
    echo ""
    echo "✅ $SIMULATOR_NAME simulator is available"
    
    # Get the UDID of the iPhone 15 Pro simulator
    SIMULATOR_UDID=$(xcrun simctl list devices | grep "$SIMULATOR_NAME" | head -1 | grep -oE '[A-F0-9-]{36}')
    
    if [ ! -z "$SIMULATOR_UDID" ]; then
        echo "   UDID: $SIMULATOR_UDID"
        
        # Boot the simulator if not already booted
        SIMULATOR_STATE=$(xcrun simctl list devices | grep "$SIMULATOR_UDID" | grep -oE '\(.*\)' | tr -d '()')
        
        if [ "$SIMULATOR_STATE" != "Booted" ]; then
            echo ""
            echo "🔄 Booting $SIMULATOR_NAME simulator..."
            xcrun simctl boot "$SIMULATOR_UDID"
            sleep 5
            echo "✅ Simulator booted"
        else
            echo "✅ Simulator is already booted"
        fi
        
        # Open Simulator app
        echo "🖥️  Opening Simulator app..."
        open -a Simulator
        
    fi
else
    echo "⚠️  $SIMULATOR_NAME simulator not found"
    echo "   You may need to download it from Xcode > Settings > Platforms"
fi

# Navigate to iOS project directory
cd "$(dirname "$0")/apps/ios"

# Check if XcodeGen is installed
if ! command -v xcodegen &> /dev/null; then
    echo ""
    echo "📦 Installing XcodeGen..."
    brew install xcodegen
fi

echo "✅ XcodeGen is installed"

# Generate Xcode project
echo ""
echo "🔨 Generating Xcode project..."
if [ -f "Project.yml" ]; then
    xcodegen generate
    echo "✅ Xcode project generated"
else
    echo "⚠️  Project.yml not found, skipping project generation"
fi

# Install SwiftLint if not installed
if ! command -v swiftlint &> /dev/null; then
    echo ""
    echo "📦 Installing SwiftLint..."
    brew install swiftlint
fi

echo "✅ SwiftLint is installed"

# Open Xcode project if it exists
if [ -f "ClaudeCode.xcodeproj/project.pbxproj" ]; then
    echo ""
    echo "📂 Opening Xcode project..."
    open ClaudeCode.xcodeproj
    
    echo ""
    echo "🎯 Next Steps in Xcode:"
    echo "1. Select 'ClaudeCode' scheme"
    echo "2. Select '$SIMULATOR_NAME' as target device"
    echo "3. Press Cmd+R to build and run"
    echo "4. Configure Settings > Base URL to 'http://localhost:8000'"
    echo "5. Add your Anthropic API key in Settings"
else
    echo "⚠️  Xcode project not found. Run the bootstrap script first:"
    echo "   ./Scripts/bootstrap.sh"
fi

# Setup backend reminder
echo ""
echo "🔧 Backend Setup Reminder:"
echo "1. cd to project root"
echo "2. Copy .env.example to .env"
echo "3. Set ANTHROPIC_API_KEY in .env"
echo "4. Run 'make up' or 'docker compose up'"
echo "5. Verify backend at http://localhost:8000/health"

echo ""
echo "✨ iOS Simulator setup complete!"
echo ""

# Create test configuration file
cat > test-config.json << EOF
{
  "simulator": {
    "device": "$SIMULATOR_NAME",
    "udid": "$SIMULATOR_UDID",
    "ios_version": "17.0+",
    "status": "ready"
  },
  "backend": {
    "url": "http://localhost:8000",
    "health_check": "/health",
    "api_version": "v1"
  },
  "test_accounts": {
    "default": {
      "api_key": "YOUR_ANTHROPIC_API_KEY_HERE"
    }
  }
}
EOF

echo "📝 Test configuration saved to apps/ios/test-config.json"
echo ""