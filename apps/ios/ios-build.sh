#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# ClaudeCode iOS Build Script - Tuist Edition
# ═══════════════════════════════════════════════════════════════════════════
# A comprehensive build and deployment script using Tuist for iOS development
# 
# Usage: ./ios-build.sh [action] [config] [device]
#
# Actions:
#   clean     - Clean all build artifacts and derived data
#   generate  - Generate Xcode project from Tuist configuration
#   build     - Build the application
#   run       - Build and run on simulator
#   test      - Run unit and UI tests
#   coverage  - Generate test coverage report
#   logs      - Stream simulator logs
#   all       - Clean, generate, build, and run
#
# Configurations:
#   debug     - Debug configuration (default)
#   release   - Release configuration
#
# Devices:
#   iPhone-16          - iPhone 16 simulator
#   iPhone-16-Plus     - iPhone 16 Plus simulator
#   iPhone-16-Pro      - iPhone 16 Pro simulator (default)
#   iPhone-16-Pro-Max  - iPhone 16 Pro Max simulator
#   iPad               - iPad (A16) simulator
#
# Examples:
#   ./ios-build.sh build debug iPhone-16
#   ./ios-build.sh test
#   ./ios-build.sh run release iPhone-16-Pro
#   ./ios-build.sh all
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail  # Exit on error, undefined variables, pipe failures

# ───────────────────────────────────────────────────────────────────────────
# Configuration
# ───────────────────────────────────────────────────────────────────────────

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Project settings
PROJECT_NAME="ClaudeCode"
WORKSPACE_NAME="ClaudeCode"
SCHEME_NAME="ClaudeCode"
BUNDLE_ID="com.claudecode.ios"

# Default values
DEFAULT_ACTION="build"
DEFAULT_CONFIG="debug"
DEFAULT_DEVICE="iPhone-16-Pro"  # Updated to available device

# Parse command line arguments
ACTION="${1:-$DEFAULT_ACTION}"
CONFIG="${2:-$DEFAULT_CONFIG}"
DEVICE="${3:-$DEFAULT_DEVICE}"

# Convert config to proper case
CONFIG_PROPER=$(echo "$CONFIG" | tr '[:upper:]' '[:lower:]')
if [[ "$CONFIG_PROPER" == "debug" ]]; then
    CONFIGURATION="Debug"
elif [[ "$CONFIG_PROPER" == "release" ]]; then
    CONFIGURATION="Release"
else
    echo -e "${RED}❌ Invalid configuration: $CONFIG${NC}"
    echo "Valid options: debug, release"
    exit 1
fi

# Device mapping - Updated for Xcode 16.4 / iOS 18.5
case "$DEVICE" in
    "iPhone-16")
        SIMULATOR_NAME="iPhone 16"
        SIMULATOR_OS=""
        ;;
    "iPhone-16-Plus")
        SIMULATOR_NAME="iPhone 16 Plus"
        SIMULATOR_OS=""
        ;;
    "iPhone-16-Pro")
        SIMULATOR_NAME="iPhone 16 Pro"
        SIMULATOR_OS=""  # Let simctl find the right OS version
        ;;
    "iPhone-16-Pro-Max")
        SIMULATOR_NAME="iPhone 16 Pro Max"
        SIMULATOR_OS=""
        ;;
    "iPad")
        SIMULATOR_NAME="iPad (A16)"
        SIMULATOR_OS=""
        ;;
    *)
        echo -e "${RED}❌ Invalid device: $DEVICE${NC}"
        echo "Valid options: iPhone-16, iPhone-16-Plus, iPhone-16-Pro, iPhone-16-Pro-Max, iPad"
        exit 1
        ;;
esac

# Paths
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
DERIVED_DATA_PATH="$BUILD_DIR/DerivedData"
LOGS_DIR="$BUILD_DIR/logs"
COVERAGE_DIR="$BUILD_DIR/coverage"

# ───────────────────────────────────────────────────────────────────────────
# Helper Functions
# ───────────────────────────────────────────────────────────────────────────

print_header() {
    echo ""
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN} $1${NC}"
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_progress() {
    echo -e "${MAGENTA}⏳ $1${NC}"
}

# Check for required tools
check_requirements() {
    local missing_tools=()
    
    # Check for Tuist
    if ! command -v tuist &> /dev/null; then
        missing_tools+=("tuist")
    fi
    
    # Check for xcodebuild
    if ! command -v xcodebuild &> /dev/null; then
        missing_tools+=("xcodebuild (Xcode)")
    fi
    
    # Check for xcrun
    if ! command -v xcrun &> /dev/null; then
        missing_tools+=("xcrun (Xcode Command Line Tools)")
    fi
    
    # Report missing tools
    if [ ${#missing_tools[@]} -gt 0 ]; then
        print_error "Missing required tools:"
        for tool in "${missing_tools[@]}"; do
            echo "  - $tool"
        done
        echo ""
        echo "Installation instructions:"
        echo "  Tuist: curl -Ls https://install.tuist.io | bash"
        echo "  Xcode: Download from Mac App Store"
        echo "  Command Line Tools: xcode-select --install"
        exit 1
    fi
}

# Get simulator UDID
get_simulator_udid() {
    local name="$1"
    local os="${2:-}"
    
    if [ -n "$os" ]; then
        xcrun simctl list devices | grep "$name" | grep "$os" | head -1 | grep -oE '[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}' || true
    else
        xcrun simctl list devices | grep "$name" | head -1 | grep -oE '[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}' || true
    fi
}

# Boot simulator if needed
boot_simulator() {
    local udid="$1"
    local state=$(xcrun simctl list devices | grep "$udid" | grep -oE '\([^)]+\)' | tr -d '()')
    
    if [[ "$state" != "Booted" ]]; then
        print_progress "Booting simulator..."
        xcrun simctl boot "$udid" 2>/dev/null || true
        sleep 3  # Give simulator time to boot
    else
        print_info "Simulator already booted"
    fi
}

# ───────────────────────────────────────────────────────────────────────────
# Action Functions
# ───────────────────────────────────────────────────────────────────────────

action_clean() {
    print_header "Cleaning Build Artifacts"
    
    print_progress "Running tuist clean..."
    tuist clean
    
    print_progress "Removing build directory..."
    rm -rf "$BUILD_DIR"
    
    print_progress "Removing Derived directory..."
    rm -rf "$SCRIPT_DIR/Derived"
    
    print_progress "Removing .build directory..."
    rm -rf "$SCRIPT_DIR/.build"
    
    print_progress "Cleaning simulator caches..."
    xcrun simctl shutdown all 2>/dev/null || true
    
    print_status "Clean completed"
}

action_generate() {
    print_header "Generating Xcode Project with Tuist"
    
    print_progress "Fetching dependencies..."
    tuist install 2>/dev/null || tuist fetch
    
    print_progress "Generating project..."
    tuist generate --no-open
    
    print_status "Project generation completed"
}

action_build() {
    print_header "Building $PROJECT_NAME ($CONFIGURATION)"
    
    # Ensure project is generated
    if [ ! -d "$SCRIPT_DIR/$PROJECT_NAME.xcworkspace" ]; then
        action_generate
    fi
    
    # Create build directory
    mkdir -p "$BUILD_DIR"
    
    # Build with xcodebuild
    print_progress "Building for $SIMULATOR_NAME..."
    
    local destination="platform=iOS Simulator,name=$SIMULATOR_NAME"
    
    # Try with xcbeautify first, fallback to plain output
    if command -v xcbeautify &> /dev/null; then
        xcodebuild \
            -workspace "$PROJECT_NAME.xcworkspace" \
            -scheme "$SCHEME_NAME" \
            -configuration "$CONFIGURATION" \
            -destination "$destination" \
            -derivedDataPath "$DERIVED_DATA_PATH" \
            -allowProvisioningUpdates \
            clean build \
            CODE_SIGN_IDENTITY="" \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGNING_ALLOWED=NO \
            ONLY_ACTIVE_ARCH=YES \
            | xcbeautify --renderer terminal
    else
        xcodebuild \
            -workspace "$PROJECT_NAME.xcworkspace" \
            -scheme "$SCHEME_NAME" \
            -configuration "$CONFIGURATION" \
            -destination "$destination" \
            -derivedDataPath "$DERIVED_DATA_PATH" \
            -allowProvisioningUpdates \
            clean build \
            CODE_SIGN_IDENTITY="" \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGNING_ALLOWED=NO \
            ONLY_ACTIVE_ARCH=YES
    fi
    
    print_status "Build completed successfully"
}

action_run() {
    print_header "Running $PROJECT_NAME on $SIMULATOR_NAME"
    
    # Build first
    action_build
    
    # Find the app bundle
    local app_path=$(find "$DERIVED_DATA_PATH" -name "*.app" -type d | grep -v "Tests" | head -n 1)
    
    if [ -z "$app_path" ]; then
        print_error "Could not find app bundle"
        exit 1
    fi
    
    print_info "App bundle: $app_path"
    
    # Get simulator UDID
    local udid=$(get_simulator_udid "$SIMULATOR_NAME" "$SIMULATOR_OS")
    
    if [ -z "$udid" ]; then
        print_error "Could not find simulator: $SIMULATOR_NAME"
        print_info "Available simulators:"
        xcrun simctl list devices
        exit 1
    fi
    
    print_info "Simulator UDID: $udid"
    
    # Boot simulator
    boot_simulator "$udid"
    
    # Open Simulator app
    open -a Simulator
    
    # Install app
    print_progress "Installing app to simulator..."
    xcrun simctl install "$udid" "$app_path"
    
    # Launch app
    print_progress "Launching app..."
    xcrun simctl launch --console-pty "$udid" "$BUNDLE_ID"
    
    print_status "App launched successfully"
}

action_test() {
    print_header "Running Tests"
    
    # Ensure project is generated
    if [ ! -d "$SCRIPT_DIR/$PROJECT_NAME.xcworkspace" ]; then
        action_generate
    fi
    
    # Create logs directory
    mkdir -p "$LOGS_DIR"
    
    local destination="platform=iOS Simulator,name=$SIMULATOR_NAME"
    local test_log="$LOGS_DIR/test-$(date +%Y%m%d-%H%M%S).log"
    
    print_progress "Running unit tests..."
    
    if command -v xcbeautify &> /dev/null; then
        xcodebuild test \
            -workspace "$PROJECT_NAME.xcworkspace" \
            -scheme "$SCHEME_NAME" \
            -configuration "$CONFIGURATION" \
            -destination "$destination" \
            -derivedDataPath "$DERIVED_DATA_PATH" \
            -enableCodeCoverage YES \
            CODE_SIGN_IDENTITY="" \
            CODE_SIGNING_REQUIRED=NO \
            | tee "$test_log" | xcbeautify --renderer terminal --report junit --junit-report-path "$LOGS_DIR/junit.xml"
    else
        xcodebuild test \
            -workspace "$PROJECT_NAME.xcworkspace" \
            -scheme "$SCHEME_NAME" \
            -configuration "$CONFIGURATION" \
            -destination "$destination" \
            -derivedDataPath "$DERIVED_DATA_PATH" \
            -enableCodeCoverage YES \
            CODE_SIGN_IDENTITY="" \
            CODE_SIGNING_REQUIRED=NO \
            | tee "$test_log"
    fi
    
    print_status "Tests completed. Log saved to: $test_log"
}

action_coverage() {
    print_header "Generating Code Coverage Report"
    
    # Run tests with coverage
    action_test
    
    # Create coverage directory
    mkdir -p "$COVERAGE_DIR"
    
    # Find coverage data
    local prof_data=$(find "$DERIVED_DATA_PATH" -name "*.profdata" | head -n 1)
    local binary=$(find "$DERIVED_DATA_PATH" -name "$PROJECT_NAME" -type f | grep -v "Tests" | head -n 1)
    
    if [ -z "$prof_data" ] || [ -z "$binary" ]; then
        print_error "Could not find coverage data"
        exit 1
    fi
    
    print_progress "Generating coverage report..."
    
    # Generate coverage report
    xcrun llvm-cov report \
        "$binary" \
        -instr-profile="$prof_data" \
        -ignore-filename-regex=".*Tests.*" \
        > "$COVERAGE_DIR/coverage.txt"
    
    # Generate HTML report
    xcrun llvm-cov show \
        "$binary" \
        -instr-profile="$prof_data" \
        -format=html \
        -output-dir="$COVERAGE_DIR/html" \
        -ignore-filename-regex=".*Tests.*"
    
    print_status "Coverage report generated:"
    echo "  Text report: $COVERAGE_DIR/coverage.txt"
    echo "  HTML report: $COVERAGE_DIR/html/index.html"
    
    # Display summary
    echo ""
    echo "Coverage Summary:"
    tail -n 5 "$COVERAGE_DIR/coverage.txt"
}

action_logs() {
    print_header "Streaming Simulator Logs"
    
    # Get simulator UDID
    local udid=$(get_simulator_udid "$SIMULATOR_NAME" "$SIMULATOR_OS")
    
    if [ -z "$udid" ]; then
        print_error "Could not find simulator: $SIMULATOR_NAME"
        exit 1
    fi
    
    # Boot simulator if needed
    boot_simulator "$udid"
    
    print_info "Streaming logs for $PROJECT_NAME on $SIMULATOR_NAME"
    print_info "Press Ctrl+C to stop"
    echo ""
    
    # Stream logs with filtering
    xcrun simctl spawn "$udid" log stream \
        --predicate "processImagePath CONTAINS '$PROJECT_NAME' OR subsystem CONTAINS '$BUNDLE_ID'" \
        --level debug \
        --style compact
}

action_all() {
    print_header "Complete Build and Run Pipeline"
    
    action_clean
    action_generate
    action_build
    action_run
    
    print_status "All actions completed successfully"
}

# ───────────────────────────────────────────────────────────────────────────
# Tuist-specific Actions
# ───────────────────────────────────────────────────────────────────────────

action_tuist_edit() {
    print_header "Opening Tuist Manifests in Xcode"
    
    tuist edit
    
    print_status "Tuist manifests opened in Xcode"
}

action_tuist_graph() {
    print_header "Generating Dependency Graph"
    
    mkdir -p "$BUILD_DIR"
    # Updated for newer Tuist version
    tuist graph --output-path "$BUILD_DIR/dependency-graph.png" --format png
    
    print_status "Dependency graph saved to: $BUILD_DIR/dependency-graph.png"
    open "$BUILD_DIR/dependency-graph.png" 2>/dev/null || true
}

action_tuist_cache() {
    print_header "Building and Caching Dependencies"
    
    tuist cache warm
    
    print_status "Dependencies cached successfully"
}

# ───────────────────────────────────────────────────────────────────────────
# Main Script
# ───────────────────────────────────────────────────────────────────────────

main() {
    # Change to script directory
    cd "$SCRIPT_DIR"
    
    # Display banner
    echo -e "${BOLD}${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════════════════╗"
    echo "║              ClaudeCode iOS Build System - Tuist Edition                 ║"
    echo "╚═══════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Display configuration
    print_info "Configuration:"
    echo "  Action: $ACTION"
    echo "  Config: $CONFIGURATION"
    echo "  Device: $SIMULATOR_NAME"
    echo "  Path:   $SCRIPT_DIR"
    
    # Check requirements
    check_requirements
    
    # Execute action
    case "$ACTION" in
        clean)
            action_clean
            ;;
        generate)
            action_generate
            ;;
        build)
            action_build
            ;;
        run)
            action_run
            ;;
        test)
            action_test
            ;;
        coverage)
            action_coverage
            ;;
        logs)
            action_logs
            ;;
        all)
            action_all
            ;;
        edit)
            action_tuist_edit
            ;;
        graph)
            action_tuist_graph
            ;;
        cache)
            action_tuist_cache
            ;;
        help|--help|-h)
            echo "Usage: $0 [action] [config] [device]"
            echo ""
            echo "Actions:"
            echo "  clean     - Clean all build artifacts"
            echo "  generate  - Generate Xcode project from Tuist"
            echo "  build     - Build the application"
            echo "  run       - Build and run on simulator"
            echo "  test      - Run unit and UI tests"
            echo "  coverage  - Generate test coverage report"
            echo "  logs      - Stream simulator logs"
            echo "  all       - Clean, generate, build, and run"
            echo "  edit      - Open Tuist manifests in Xcode"
            echo "  graph     - Generate dependency graph"
            echo "  cache     - Build and cache dependencies"
            echo ""
            echo "Configurations:"
            echo "  debug     - Debug configuration (default)"
            echo "  release   - Release configuration"
            echo ""
            echo "Devices:"
            echo "  iPhone-16          - iPhone 16 simulator"
            echo "  iPhone-16-Plus     - iPhone 16 Plus simulator"
            echo "  iPhone-16-Pro      - iPhone 16 Pro simulator (default)"
            echo "  iPhone-16-Pro-Max  - iPhone 16 Pro Max simulator"
            echo "  iPad               - iPad (A16) simulator"
            exit 0
            ;;
        *)
            print_error "Invalid action: $ACTION"
            echo "Run '$0 help' for usage information"
            exit 1
            ;;
    esac
    
    echo ""
    print_status "Operation completed successfully!"
}

# Run main function
main "$@"