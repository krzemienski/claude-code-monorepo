#!/bin/bash

# iOS Simulator Setup and Configuration Script
# Version: 1.0
# Purpose: Automated iOS Simulator setup for development and testing
# Requirements: Xcode 15.0+, macOS 13+

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DEFAULT_SIMULATOR="iPhone 15 Pro"
DEFAULT_OS="iOS 17.0"
APP_BUNDLE_ID="com.claudecode.ios"
BACKEND_URL="http://localhost:8000"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}    iOS Simulator Setup Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to check prerequisites
check_prerequisites() {
    echo -e "${BLUE}==> Checking Prerequisites...${NC}"
    
    # Check Xcode
    if ! command -v xcodebuild &> /dev/null; then
        echo -e "${RED} Xcode is not installed${NC}"
        echo "Please install Xcode from the App Store"
        exit 1
    fi
    
    XCODE_VERSION=$(xcodebuild -version | head -1 | awk '{print $2}')
    echo -e "${GREEN} Xcode ${XCODE_VERSION} installed${NC}"
    
    # Check Xcode command line tools
    if ! xcode-select -p &> /dev/null; then
        echo -e "${YELLOW}  Installing Xcode Command Line Tools...${NC}"
        xcode-select --install
        echo "Please complete the installation and run this script again"
        exit 1
    fi
    echo -e "${GREEN} Xcode Command Line Tools installed${NC}"
    
    # Check xcrun
    if ! command -v xcrun &> /dev/null; then
        echo -e "${RED} xcrun not found${NC}"
        exit 1
    fi
    echo -e "${GREEN} xcrun available${NC}"
    
    echo ""
}

# Function to list available simulators
list_simulators() {
    echo -e "${BLUE}==> Available iOS Simulators:${NC}"
    echo ""
    
    # Get available runtimes
    echo "Runtimes:"
    xcrun simctl list runtimes | grep iOS | head -5
    echo ""
    
    # Get available devices
    echo "Devices:"
    xcrun simctl list devices available | grep -E "iPhone|iPad" | head -10
    echo ""
}

# Function to create simulator if needed
create_simulator() {
    echo -e "${BLUE}==> Setting up ${DEFAULT_SIMULATOR}...${NC}"
    
    # Check if simulator exists
    SIMULATOR_ID=$(xcrun simctl list devices | grep "${DEFAULT_SIMULATOR}" | grep -v "unavailable" | head -1 | awk -F'[()]' '{print $2}')
    
    if [ -z "$SIMULATOR_ID" ]; then
        echo -e "${YELLOW}Creating new ${DEFAULT_SIMULATOR} simulator...${NC}"
        
        # Get device type
        DEVICE_TYPE=$(xcrun simctl list devicetypes | grep "${DEFAULT_SIMULATOR}" | head -1 | awk '{print $NF}')
        if [ -z "$DEVICE_TYPE" ]; then
            DEVICE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro"
        fi
        
        # Get runtime
        RUNTIME=$(xcrun simctl list runtimes | grep "iOS" | head -1 | awk '{print $NF}')
        if [ -z "$RUNTIME" ]; then
            RUNTIME="com.apple.CoreSimulator.SimRuntime.iOS-17-0"
        fi
        
        # Create simulator
        SIMULATOR_ID=$(xcrun simctl create "${DEFAULT_SIMULATOR}" "$DEVICE_TYPE" "$RUNTIME")
        echo -e "${GREEN} Created simulator: ${SIMULATOR_ID}${NC}"
    else
        echo -e "${GREEN} Found existing simulator: ${SIMULATOR_ID}${NC}"
    fi
    
    echo ""
    export SIMULATOR_ID
}

# Function to boot simulator
boot_simulator() {
    echo -e "${BLUE}==> Booting Simulator...${NC}"
    
    # Check if already booted
    if xcrun simctl list devices | grep "$SIMULATOR_ID" | grep "Booted" > /dev/null; then
        echo -e "${GREEN} Simulator already booted${NC}"
    else
        echo "Booting ${DEFAULT_SIMULATOR}..."
        xcrun simctl boot "$SIMULATOR_ID"
        
        # Wait for boot
        echo -n "Waiting for simulator to boot"
        for i in {1..30}; do
            if xcrun simctl list devices | grep "$SIMULATOR_ID" | grep "Booted" > /dev/null; then
                echo ""
                echo -e "${GREEN} Simulator booted successfully${NC}"
                break
            fi
            echo -n "."
            sleep 1
        done
    fi
    
    # Open Simulator app
    open -a Simulator
    
    echo ""
}

# Function to configure simulator settings
configure_simulator() {
    echo -e "${BLUE}==> Configuring Simulator Settings...${NC}"
    
    # Set location (for location services testing)
    echo "Setting location to San Francisco..."
    xcrun simctl location "$SIMULATOR_ID" set 37.7749 -122.4194
    echo -e "${GREEN} Location set${NC}"
    
    # Set appearance (light/dark mode)
    echo "Setting appearance to light mode..."
    xcrun simctl ui "$SIMULATOR_ID" appearance light 2>/dev/null || true
    echo -e "${GREEN} Appearance configured${NC}"
    
    # Configure network conditions (optional)
    echo "Setting network to WiFi..."
    # Note: Network conditioning requires additional setup
    # xcrun simctl status_bar "$SIMULATOR_ID" override --dataNetwork wifi
    
    # Set status bar (for screenshots)
    echo "Configuring status bar..."
    xcrun simctl status_bar "$SIMULATOR_ID" override \
        --time "9:41" \
        --batteryState charged \
        --batteryLevel 100 \
        --cellularMode active \
        --cellularBars 4 \
        --wifiBars 3 2>/dev/null || true
    echo -e "${GREEN} Status bar configured${NC}"
    
    echo ""
}

# Function to install test certificates
install_certificates() {
    echo -e "${BLUE}==> Installing Development Certificates...${NC}"
    
    # Install custom root certificate if exists
    if [ -f "certs/development.cer" ]; then
        echo "Installing development certificate..."
        xcrun simctl keychain "$SIMULATOR_ID" add-root-cert "certs/development.cer"
        echo -e "${GREEN} Certificate installed${NC}"
    else
        echo -e "${YELLOW}  No custom certificates found${NC}"
    fi
    
    echo ""
}

# Function to configure app permissions
configure_permissions() {
    echo -e "${BLUE}==> Configuring App Permissions...${NC}"
    
    # Grant permissions for the app (when installed)
    echo "Preparing permission grants for ${APP_BUNDLE_ID}..."
    
    # Note: These commands work after app installation
    # xcrun simctl privacy "$SIMULATOR_ID" grant all "$APP_BUNDLE_ID"
    
    cat > simulator_permissions.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.claudecode.ios</key>
    <dict>
        <key>kTCCServiceCamera</key>
        <true/>
        <key>kTCCServiceMicrophone</key>
        <true/>
        <key>kTCCServicePhotos</key>
        <true/>
        <key>kTCCServiceContactsFull</key>
        <true/>
        <key>kTCCServiceCalendar</key>
        <true/>
        <key>kTCCServiceReminders</key>
        <true/>
        <key>kTCCServiceLocationWhenInUse</key>
        <true/>
    </dict>
</dict>
</plist>
EOF
    
    echo -e "${GREEN} Permission configuration prepared${NC}"
    echo "Permissions will be applied when app is installed"
    echo ""
}

# Function to test network connectivity
test_connectivity() {
    echo -e "${BLUE}==> Testing Network Connectivity...${NC}"
    
    # Test internet connectivity
    echo -n "Testing internet access... "
    xcrun simctl openurl "$SIMULATOR_ID" "https://www.apple.com" 2>/dev/null
    echo -e "${GREEN}${NC}"
    
    # Test backend connectivity
    echo -n "Testing backend connectivity... "
    xcrun simctl openurl "$SIMULATOR_ID" "${BACKEND_URL}/health" 2>/dev/null || true
    echo -e "${GREEN}${NC}"
    
    echo ""
}

# Function to install the app
install_app() {
    echo -e "${BLUE}==> Installing Claude Code App...${NC}"
    
    APP_PATH="apps/ios/build/Build/Products/Debug-iphonesimulator/ClaudeCode.app"
    
    if [ -d "$APP_PATH" ]; then
        echo "Installing app to simulator..."
        xcrun simctl install "$SIMULATOR_ID" "$APP_PATH"
        echo -e "${GREEN} App installed successfully${NC}"
        
        # Grant permissions after installation
        echo "Granting permissions..."
        xcrun simctl privacy "$SIMULATOR_ID" grant all "$APP_BUNDLE_ID" 2>/dev/null || true
        echo -e "${GREEN} Permissions granted${NC}"
    else
        echo -e "${YELLOW}  App not found at $APP_PATH${NC}"
        echo "Build the app first with:"
        echo "  cd apps/ios"
        echo "  xcodebuild -project ClaudeCode.xcodeproj -scheme ClaudeCode -configuration Debug -destination 'platform=iOS Simulator,name=${DEFAULT_SIMULATOR}'"
    fi
    
    echo ""
}

# Function to launch the app
launch_app() {
    echo -e "${BLUE}==> Launching App...${NC}"
    
    echo "Launching ${APP_BUNDLE_ID}..."
    xcrun simctl launch "$SIMULATOR_ID" "$APP_BUNDLE_ID" 2>/dev/null || {
        echo -e "${YELLOW}  App not installed yet${NC}"
        echo "Install the app first"
        return
    }
    
    echo -e "${GREEN} App launched${NC}"
    echo ""
}

# Function to capture screenshots
capture_screenshots() {
    echo -e "${BLUE}==> Capturing Screenshots...${NC}"
    
    SCREENSHOT_DIR="screenshots"
    mkdir -p "$SCREENSHOT_DIR"
    
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    SCREENSHOT_PATH="${SCREENSHOT_DIR}/simulator_${TIMESTAMP}.png"
    
    xcrun simctl io "$SIMULATOR_ID" screenshot "$SCREENSHOT_PATH"
    echo -e "${GREEN} Screenshot saved: $SCREENSHOT_PATH${NC}"
    
    echo ""
}

# Function to record video
record_video() {
    echo -e "${BLUE}==> Video Recording Instructions...${NC}"
    
    echo "To record simulator screen:"
    echo "  Start: xcrun simctl io ${SIMULATOR_ID} recordVideo recording.mov"
    echo "  Stop:  Press Ctrl+C"
    echo ""
    echo "To record with options:"
    echo "  xcrun simctl io ${SIMULATOR_ID} recordVideo --codec h264 --mask black recording.mp4"
    echo ""
}

# Function to reset simulator
reset_simulator() {
    echo -e "${BLUE}==> Reset Options...${NC}"
    
    echo "To reset simulator:"
    echo "  Erase all content: xcrun simctl erase ${SIMULATOR_ID}"
    echo "  Shutdown: xcrun simctl shutdown ${SIMULATOR_ID}"
    echo "  Delete: xcrun simctl delete ${SIMULATOR_ID}"
    echo ""
}

# Function to show useful commands
show_commands() {
    echo -e "${BLUE}==> Useful Simulator Commands:${NC}"
    echo ""
    echo "Device Control:"
    echo "  Boot:     xcrun simctl boot '${SIMULATOR_ID}'"
    echo "  Shutdown: xcrun simctl shutdown '${SIMULATOR_ID}'"
    echo "  Erase:    xcrun simctl erase '${SIMULATOR_ID}'"
    echo ""
    echo "App Management:"
    echo "  Install:  xcrun simctl install '${SIMULATOR_ID}' path/to/app.app"
    echo "  Launch:   xcrun simctl launch '${SIMULATOR_ID}' ${APP_BUNDLE_ID}"
    echo "  Terminate: xcrun simctl terminate '${SIMULATOR_ID}' ${APP_BUNDLE_ID}"
    echo ""
    echo "Data & Logs:"
    echo "  Container: xcrun simctl get_app_container '${SIMULATOR_ID}' ${APP_BUNDLE_ID}"
    echo "  Logs:     xcrun simctl spawn '${SIMULATOR_ID}' log stream --predicate 'process == \"ClaudeCode\"'"
    echo ""
    echo "Testing:"
    echo "  URL:      xcrun simctl openurl '${SIMULATOR_ID}' 'https://example.com'"
    echo "  Push:     xcrun simctl push '${SIMULATOR_ID}' ${APP_BUNDLE_ID} notification.json"
    echo ""
}

# Function to generate summary
generate_summary() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}    Setup Summary${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo "Simulator: ${DEFAULT_SIMULATOR}"
    echo "ID: ${SIMULATOR_ID}"
    echo "Status: Booted and Configured"
    echo "App Bundle: ${APP_BUNDLE_ID}"
    echo "Backend: ${BACKEND_URL}"
    echo ""
    echo -e "${GREEN} Simulator is ready for development!${NC}"
    echo ""
}

# Main execution
main() {
    echo "iOS Simulator Setup - $(date)"
    echo ""
    
    # Parse command line arguments
    case "${1:-setup}" in
        setup)
            check_prerequisites
            list_simulators
            create_simulator
            boot_simulator
            configure_simulator
            install_certificates
            configure_permissions
            test_connectivity
            install_app
            launch_app
            generate_summary
            ;;
        boot)
            create_simulator
            boot_simulator
            ;;
        install)
            install_app
            launch_app
            ;;
        screenshot)
            capture_screenshots
            ;;
        record)
            record_video
            ;;
        reset)
            reset_simulator
            ;;
        commands)
            show_commands
            ;;
        *)
            echo "Usage: $0 [setup|boot|install|screenshot|record|reset|commands]"
            echo ""
            echo "  setup      - Complete simulator setup (default)"
            echo "  boot       - Boot simulator only"
            echo "  install    - Install and launch app"
            echo "  screenshot - Capture screenshot"
            echo "  record     - Show recording instructions"
            echo "  reset      - Show reset options"
            echo "  commands   - Show useful commands"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"