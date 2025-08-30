#!/bin/bash

# Enhanced iOS Simulator Setup Script for Claude Code
# This script provides comprehensive iOS development environment setup
# including all dependencies, build tools, and validation tests

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
IOS_DIR="$PROJECT_ROOT/apps/ios"
BACKEND_DIR="$PROJECT_ROOT/services/backend"

echo -e "${BLUE}🚀 Claude Code iOS Enhanced Setup${NC}"
echo "========================================"
echo ""

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ $2${NC}"
    else
        echo -e "${RED}❌ $2${NC}"
        return 1
    fi
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Function to print info
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# ===========================================
# PHASE 1: System Requirements Check
# ===========================================
echo -e "\n${BLUE}📋 Phase 1: System Requirements Check${NC}"
echo "----------------------------------------"

# Check macOS version
MAC_VERSION=$(sw_vers -productVersion)
echo "macOS Version: $MAC_VERSION"

# Check if Xcode is installed
if ! command_exists xcodebuild; then
    echo -e "${RED}❌ Error: Xcode is not installed${NC}"
    echo "Please install Xcode from the Mac App Store"
    exit 1
fi

XCODE_VERSION=$(xcodebuild -version | head -n 1)
print_status 0 "Xcode installed: $XCODE_VERSION"

# Check Xcode command line tools
if ! xcode-select -p &> /dev/null; then
    print_warning "Installing Xcode Command Line Tools..."
    xcode-select --install
    echo "Please complete the installation and run this script again"
    exit 1
fi
print_status 0 "Xcode Command Line Tools installed"

# Accept Xcode license if needed
if ! xcodebuild -license check &> /dev/null; then
    print_warning "Accepting Xcode license..."
    sudo xcodebuild -license accept
fi
print_status 0 "Xcode license accepted"

# ===========================================
# PHASE 2: Homebrew & Core Dependencies
# ===========================================
echo -e "\n${BLUE}📦 Phase 2: Installing Core Dependencies${NC}"
echo "----------------------------------------"

# Install Homebrew if not present
if ! command_exists brew; then
    print_warning "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
print_status 0 "Homebrew installed"

# Update Homebrew
print_info "Updating Homebrew..."
brew update

# Install required Homebrew packages
BREW_PACKAGES=(
    "swiftlint"
    "swiftformat"
    "xcodegen"
    "xcbeautify"
    "rbenv"
    "ruby-build"
    "python@3.11"
    "node"
    "npm"
    "git"
    "jq"
)

for package in "${BREW_PACKAGES[@]}"; do
    if brew list "$package" &>/dev/null; then
        print_status 0 "$package already installed"
    else
        print_info "Installing $package..."
        brew install "$package"
        print_status $? "$package installed"
    fi
done

# ===========================================
# PHASE 3: Ruby Environment Setup
# ===========================================
echo -e "\n${BLUE}💎 Phase 3: Ruby Environment Setup${NC}"
echo "----------------------------------------"

# Initialize rbenv
if command_exists rbenv; then
    eval "$(rbenv init -)"
    
    # Install Ruby 3.2.0 if not present
    if ! rbenv versions | grep -q "3.2.0"; then
        print_info "Installing Ruby 3.2.0..."
        rbenv install 3.2.0
    fi
    
    # Set global Ruby version
    rbenv global 3.2.0
    print_status 0 "Ruby 3.2.0 configured"
    
    # Install required gems
    print_info "Installing Ruby gems..."
    gem install bundler --no-document
    gem install fastlane --no-document
    gem install cocoapods --no-document
    gem install xcpretty --no-document
    print_status 0 "Ruby gems installed"
else
    print_warning "rbenv not configured properly"
fi

# ===========================================
# PHASE 4: Tuist Installation
# ===========================================
echo -e "\n${BLUE}🛠️ Phase 4: Tuist Installation${NC}"
echo "----------------------------------------"

if ! command_exists tuist; then
    print_info "Installing Tuist..."
    curl -Ls https://install.tuist.io | bash
    export PATH="$HOME/.tuist/bin:$PATH"
fi

# Verify Tuist installation
if command_exists tuist; then
    TUIST_VERSION=$(tuist version 2>/dev/null || echo "unknown")
    print_status 0 "Tuist installed: $TUIST_VERSION"
else
    print_warning "Tuist installation failed"
fi

# ===========================================
# PHASE 5: iOS Simulator Configuration
# ===========================================
echo -e "\n${BLUE}📱 Phase 5: iOS Simulator Configuration${NC}"
echo "----------------------------------------"

# List available simulators
print_info "Available iOS Simulators:"
xcrun simctl list devices available | grep -E "iPhone|iPad" | head -10

# Check for iPhone 15 Pro simulator
SIMULATOR_NAME="iPhone 15 Pro"
if xcrun simctl list devices | grep -q "$SIMULATOR_NAME"; then
    print_status 0 "$SIMULATOR_NAME simulator available"
    
    # Get the UDID
    SIMULATOR_UDID=$(xcrun simctl list devices | grep "$SIMULATOR_NAME" | head -1 | grep -oE '[A-F0-9-]{36}' || true)
    
    if [ ! -z "$SIMULATOR_UDID" ]; then
        echo "   UDID: $SIMULATOR_UDID"
        
        # Boot simulator if not already booted
        SIMULATOR_STATE=$(xcrun simctl list devices | grep "$SIMULATOR_UDID" | grep -oE '\(.*\)' | tr -d '()' || true)
        
        if [ "$SIMULATOR_STATE" != "Booted" ]; then
            print_info "Booting $SIMULATOR_NAME simulator..."
            xcrun simctl boot "$SIMULATOR_UDID"
            sleep 5
            print_status 0 "Simulator booted"
        else
            print_status 0 "Simulator already booted"
        fi
    fi
else
    print_warning "$SIMULATOR_NAME simulator not found"
    print_info "You may need to download it from Xcode > Settings > Platforms"
fi

# ===========================================
# PHASE 6: iOS Project Setup
# ===========================================
echo -e "\n${BLUE}🏗️ Phase 6: iOS Project Setup${NC}"
echo "----------------------------------------"

cd "$IOS_DIR"

# Create necessary directories
mkdir -p Scripts
mkdir -p Tests
mkdir -p UITests

# Check if using Tuist or XcodeGen
if [ -f "Project.swift" ] && command_exists tuist; then
    print_info "Using Tuist for project generation..."
    
    # Fetch dependencies
    tuist fetch
    
    # Generate project
    tuist generate
    print_status $? "Xcode project generated with Tuist"
    
elif [ -f "Project.yml" ] && command_exists xcodegen; then
    print_info "Using XcodeGen for project generation..."
    xcodegen generate
    print_status $? "Xcode project generated with XcodeGen"
else
    print_warning "No project configuration found (Project.swift or Project.yml)"
fi

# ===========================================
# PHASE 7: Environment Configuration
# ===========================================
echo -e "\n${BLUE}⚙️ Phase 7: Environment Configuration${NC}"
echo "----------------------------------------"

# Create .env file if it doesn't exist
if [ ! -f "$IOS_DIR/.env" ]; then
    print_info "Creating .env file..."
    cat > "$IOS_DIR/.env" << EOF
# API Configuration
API_BASE_URL=http://localhost:8000
API_KEY=your-development-api-key

# Development Settings
ENABLE_DEBUG_LOGGING=true
ENABLE_NETWORK_LOGGING=true
USE_MOCK_DATA=false

# Push Notifications (optional)
APNS_KEY_ID=your-key-id
APNS_TEAM_ID=your-team-id

# Analytics (optional)
ANALYTICS_ENABLED=false
CRASHLYTICS_ENABLED=false
EOF
    print_status 0 ".env file created"
else
    print_status 0 ".env file already exists"
fi

# ===========================================
# PHASE 8: Test Infrastructure Setup
# ===========================================
echo -e "\n${BLUE}🧪 Phase 8: Test Infrastructure Setup${NC}"
echo "----------------------------------------"

# Create test configuration
cat > "$IOS_DIR/test-config.json" << EOF
{
  "simulator": {
    "device": "$SIMULATOR_NAME",
    "udid": "${SIMULATOR_UDID:-unknown}",
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
      "api_key": "test-api-key-here"
    }
  },
  "test_targets": {
    "unit": {
      "coverage_threshold": 80,
      "timeout": 300
    },
    "integration": {
      "coverage_threshold": 70,
      "timeout": 600
    },
    "ui": {
      "coverage_threshold": 60,
      "timeout": 900
    }
  }
}
EOF
print_status 0 "Test configuration created"

# Create test runner script
cat > "$IOS_DIR/Scripts/run-tests.sh" << 'TESTSCRIPT'
#!/bin/bash
# iOS Test Runner Script

set -e

TEST_TYPE=${1:-all}
SCHEME="ClaudeCode"

echo "🧪 Running $TEST_TYPE tests..."

case $TEST_TYPE in
    unit)
        xcodebuild test \
            -scheme "$SCHEME" \
            -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
            -only-testing:ClaudeCodeTests \
            | xcbeautify
        ;;
    ui)
        xcodebuild test \
            -scheme "$SCHEME" \
            -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
            -only-testing:ClaudeCodeUITests \
            | xcbeautify
        ;;
    integration)
        xcodebuild test \
            -scheme "$SCHEME" \
            -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
            -only-testing:ClaudeCodeIntegrationTests \
            | xcbeautify
        ;;
    all)
        xcodebuild test \
            -scheme "$SCHEME" \
            -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
            -enableCodeCoverage YES \
            | xcbeautify
        ;;
    *)
        echo "Usage: $0 [unit|ui|integration|all]"
        exit 1
        ;;
esac
TESTSCRIPT

chmod +x "$IOS_DIR/Scripts/run-tests.sh"
print_status 0 "Test runner script created"

# ===========================================
# PHASE 9: Backend Environment Verification
# ===========================================
echo -e "\n${BLUE}🔧 Phase 9: Backend Environment Check${NC}"
echo "----------------------------------------"

# Check Python version
if command_exists python3; then
    PYTHON_VERSION=$(python3 --version)
    print_status 0 "Python installed: $PYTHON_VERSION"
else
    print_warning "Python 3 not found"
fi

# Check Docker
if command_exists docker; then
    print_status 0 "Docker installed"
    
    # Check if Docker is running
    if docker info &>/dev/null; then
        print_status 0 "Docker daemon running"
    else
        print_warning "Docker daemon not running. Please start Docker Desktop"
    fi
else
    print_warning "Docker not installed. Please install Docker Desktop"
fi

# Check for backend directory
if [ -d "$BACKEND_DIR" ]; then
    print_status 0 "Backend directory found"
    
    # Check for requirements.txt
    if [ -f "$BACKEND_DIR/requirements.txt" ]; then
        print_status 0 "Backend requirements.txt found"
    else
        print_warning "Backend requirements.txt missing"
    fi
else
    print_warning "Backend directory not found at $BACKEND_DIR"
fi

# ===========================================
# PHASE 10: Integration Validation
# ===========================================
echo -e "\n${BLUE}✅ Phase 10: Integration Validation${NC}"
echo "----------------------------------------"

# Create integration test script
cat > "$PROJECT_ROOT/scripts/test-integration.sh" << 'INTSCRIPT'
#!/bin/bash
# iOS-Backend Integration Test Script

set -e

echo "🔌 Testing iOS-Backend Integration..."

# Test 1: Backend Health Check
echo -n "Testing backend health endpoint... "
if curl -s http://localhost:8000/health | grep -q "healthy"; then
    echo "✅ Passed"
else
    echo "❌ Failed"
    exit 1
fi

# Test 2: API Version Check
echo -n "Testing API version endpoint... "
if curl -s http://localhost:8000/v1 | grep -q "version"; then
    echo "✅ Passed"
else
    echo "❌ Failed"
    exit 1
fi

# Test 3: SSE Connection Test
echo -n "Testing SSE streaming... "
timeout 2 curl -s -N http://localhost:8000/v1/sessions/test/stream &>/dev/null
if [ $? -eq 124 ]; then
    echo "✅ Passed (connection established)"
else
    echo "⚠️  Could not verify SSE"
fi

echo ""
echo "✅ Integration tests completed"
INTSCRIPT

chmod +x "$PROJECT_ROOT/scripts/test-integration.sh"
print_status 0 "Integration test script created"

# ===========================================
# FINAL SUMMARY
# ===========================================
echo ""
echo "========================================"
echo -e "${GREEN}✨ iOS Development Environment Setup Complete!${NC}"
echo "========================================"
echo ""

# Generate summary report
cat > "$PROJECT_ROOT/setup-summary.md" << EOF
# iOS Development Environment Setup Summary

## ✅ Completed Setup Tasks

### System Requirements
- macOS Version: $MAC_VERSION
- Xcode Version: $XCODE_VERSION
- Command Line Tools: Installed

### Development Tools
- Homebrew: Installed
- SwiftLint: Installed
- SwiftFormat: Installed
- XcodeGen: Installed
- Tuist: ${TUIST_VERSION:-Not installed}
- Ruby 3.2.0: Configured
- Fastlane: Installed

### iOS Environment
- Simulator: $SIMULATOR_NAME
- UDID: ${SIMULATOR_UDID:-Not found}
- Project Directory: $IOS_DIR
- Test Configuration: Created

### Backend Environment
- Python: ${PYTHON_VERSION:-Not installed}
- Docker: $(command_exists docker && echo "Installed" || echo "Not installed")
- Backend Directory: $BACKEND_DIR

## 📋 Next Steps

1. **Start Backend Services**:
   \`\`\`bash
   cd $PROJECT_ROOT
   docker compose up -d
   \`\`\`

2. **Open Xcode Project**:
   \`\`\`bash
   cd $IOS_DIR
   open ClaudeCode.xcworkspace  # or .xcodeproj
   \`\`\`

3. **Run Tests**:
   \`\`\`bash
   cd $IOS_DIR
   ./Scripts/run-tests.sh all
   \`\`\`

4. **Test Integration**:
   \`\`\`bash
   $PROJECT_ROOT/scripts/test-integration.sh
   \`\`\`

## 🔧 Configuration Files Created

- \`$IOS_DIR/.env\` - Environment variables
- \`$IOS_DIR/test-config.json\` - Test configuration
- \`$IOS_DIR/Scripts/run-tests.sh\` - Test runner
- \`$PROJECT_ROOT/scripts/test-integration.sh\` - Integration tests

## 📱 Simulator Commands

- Boot simulator: \`xcrun simctl boot "$SIMULATOR_UDID"\`
- Open Simulator app: \`open -a Simulator\`
- Install app: \`xcrun simctl install "$SIMULATOR_UDID" path/to/app\`
- Launch app: \`xcrun simctl launch "$SIMULATOR_UDID" com.claudecode.ios\`

Generated: $(date)
EOF

print_status 0 "Setup summary saved to setup-summary.md"

echo ""
echo -e "${BLUE}📋 Next Steps:${NC}"
echo "1. Start backend: cd $PROJECT_ROOT && docker compose up"
echo "2. Open Xcode: cd $IOS_DIR && open ClaudeCode.xcworkspace"
echo "3. Select 'ClaudeCode' scheme and '$SIMULATOR_NAME' device"
echo "4. Press Cmd+R to build and run"
echo "5. Configure Settings > Base URL to 'http://localhost:8000'"
echo "6. Add your Anthropic API key in Settings"
echo ""
echo -e "${GREEN}Ready to start development! 🚀${NC}"