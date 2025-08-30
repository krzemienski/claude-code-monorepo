#!/bin/bash

# iOS Build Script for ClaudeCode
# This script builds the iOS app and runs it in the simulator

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="$(cd "$(dirname "$0")/../apps/ios" && pwd)"
PROJECT_NAME="ClaudeCode"
SCHEME="ClaudeCode"
CONFIGURATION="Debug"
SIMULATOR_NAME="iPhone 15 Pro"
BUNDLE_ID="com.claudecode.ios"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check for Xcode
    if ! command -v xcodebuild &> /dev/null; then
        log_error "Xcode is not installed"
        exit 1
    fi
    
    # Check Xcode version
    XCODE_VERSION=$(xcodebuild -version | head -n1 | cut -d' ' -f2)
    log_info "Xcode version: $XCODE_VERSION"
    
    # Check for xcodegen (for Project.yml)
    if ! command -v xcodegen &> /dev/null; then
        log_warning "xcodegen not found. Installing..."
        brew install xcodegen
    fi
    
    log_success "Prerequisites check passed"
}

# Generate Xcode project from Project.yml
generate_project() {
    log_info "Generating Xcode project from Project.yml..."
    cd "$PROJECT_DIR"
    
    if [ -f "Project.yml" ]; then
        xcodegen generate
        log_success "Project generated successfully"
    else
        log_warning "Project.yml not found, using existing .xcodeproj"
    fi
}

# Clean build folder
clean_build() {
    log_info "Cleaning build folder..."
    cd "$PROJECT_DIR"
    
    xcodebuild clean \
        -project "${PROJECT_NAME}.xcodeproj" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        2>&1 | grep -E '^(/.+:[0-9]+:[0-9]+:|Build|Clean)' || true
    
    # Also clean derived data
    rm -rf ~/Library/Developer/Xcode/DerivedData/${PROJECT_NAME}-*
    
    log_success "Build folder cleaned"
}

# Resolve Swift Package Dependencies
resolve_dependencies() {
    log_info "Resolving Swift Package dependencies..."
    cd "$PROJECT_DIR"
    
    xcodebuild -resolvePackageDependencies \
        -project "${PROJECT_NAME}.xcodeproj" \
        -scheme "$SCHEME" \
        2>&1 | grep -E '^(Resolved|Fetching|Cloning)' || true
    
    log_success "Dependencies resolved"
}

# Build the project
build_project() {
    log_info "Building project for iOS Simulator..."
    cd "$PROJECT_DIR"
    
    # Get the simulator destination
    SIMULATOR_ID=$(xcrun simctl list devices | grep "$SIMULATOR_NAME" | grep -v "unavailable" | head -n1 | cut -d'(' -f2 | cut -d')' -f1)
    
    if [ -z "$SIMULATOR_ID" ]; then
        log_error "Simulator '$SIMULATOR_NAME' not found"
        log_info "Available simulators:"
        xcrun simctl list devices | grep -v "unavailable" | grep "iPhone"
        exit 1
    fi
    
    log_info "Using simulator: $SIMULATOR_NAME ($SIMULATOR_ID)"
    
    # Build the app
    xcodebuild build \
        -project "${PROJECT_NAME}.xcodeproj" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
        -derivedDataPath build \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        2>&1 | grep -E '^(/.+:[0-9]+:[0-9]+:|Build|Compile|Link|Copy|Process|Touch|Sign)' || true
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        log_success "Build completed successfully"
    else
        log_error "Build failed"
        exit 1
    fi
}

# Install and run on simulator
run_on_simulator() {
    log_info "Installing and running on simulator..."
    
    # Boot the simulator if not already booted
    SIMULATOR_STATE=$(xcrun simctl list devices | grep "$SIMULATOR_ID" | cut -d'(' -f2 | cut -d')' -f1 | cut -d',' -f2 | xargs)
    
    if [ "$SIMULATOR_STATE" != "Booted" ]; then
        log_info "Booting simulator..."
        xcrun simctl boot "$SIMULATOR_ID"
        sleep 5
    fi
    
    # Open the Simulator app
    open -a Simulator
    
    # Find the app bundle
    APP_BUNDLE=$(find "$PROJECT_DIR/build/Build/Products/$CONFIGURATION-iphonesimulator" -name "*.app" | head -n1)
    
    if [ -z "$APP_BUNDLE" ]; then
        log_error "App bundle not found"
        exit 1
    fi
    
    log_info "Installing app: $(basename "$APP_BUNDLE")"
    
    # Install the app
    xcrun simctl install "$SIMULATOR_ID" "$APP_BUNDLE"
    
    # Launch the app
    log_info "Launching app..."
    xcrun simctl launch "$SIMULATOR_ID" "$BUNDLE_ID"
    
    log_success "App launched successfully"
}

# Start backend server check
check_backend() {
    log_info "Checking backend server..."
    
    if curl -s -f -o /dev/null "http://localhost:8000/health"; then
        log_success "Backend server is running at http://localhost:8000"
    else
        log_warning "Backend server is not running at http://localhost:8000"
        log_info "Start the backend with: cd services/backend && python -m app.main"
    fi
}

# Show logs
show_logs() {
    log_info "Streaming device logs (press Ctrl+C to stop)..."
    log_info "Filter: $BUNDLE_ID"
    
    # Stream logs from the simulator
    xcrun simctl spawn "$SIMULATOR_ID" log stream --predicate "subsystem == 'com.claudecode.ios'" --level debug
}

# Main execution
main() {
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}     ClaudeCode iOS Build & Run Script${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo
    
    # Parse arguments
    CLEAN=false
    LOGS=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --clean)
                CLEAN=true
                shift
                ;;
            --logs)
                LOGS=true
                shift
                ;;
            --simulator)
                SIMULATOR_NAME="$2"
                shift 2
                ;;
            --help)
                echo "Usage: $0 [options]"
                echo "Options:"
                echo "  --clean           Clean build before building"
                echo "  --logs            Show device logs after launching"
                echo "  --simulator NAME  Use specific simulator (default: iPhone 15 Pro)"
                echo "  --help            Show this help message"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Execute build steps
    check_prerequisites
    check_backend
    generate_project
    
    if [ "$CLEAN" = true ]; then
        clean_build
    fi
    
    resolve_dependencies
    build_project
    run_on_simulator
    
    echo
    log_success "iOS app is running!"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}Backend URL:${NC} http://localhost:8000"
    echo -e "${BLUE}Simulator:${NC} $SIMULATOR_NAME"
    echo -e "${BLUE}Bundle ID:${NC} $BUNDLE_ID"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    
    if [ "$LOGS" = true ]; then
        echo
        show_logs
    else
        echo
        log_info "Run with --logs flag to see device logs"
        log_info "Or use: xcrun simctl spawn booted log stream --predicate 'subsystem == \"com.claudecode.ios\"'"
    fi
}

# Run main function
main "$@"