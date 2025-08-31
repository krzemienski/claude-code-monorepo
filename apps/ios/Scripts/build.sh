#!/bin/bash
#
# Tuist Build Script for CI/CD
# This script handles project generation and building with Tuist
#

set -e  # Exit on error

echo "🎯 Tuist Build Script"
echo "===================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME="ClaudeCode"
CONFIGURATION="${1:-Debug}"
DESTINATION="${2:-platform=iOS Simulator,name=iPhone 15 Pro}"

echo "📁 Project Directory: $PROJECT_DIR"
echo "🎯 Scheme: $SCHEME"
echo "⚙️ Configuration: $CONFIGURATION"
echo "📱 Destination: $DESTINATION"
echo ""

# Function to check if Tuist is installed
check_tuist() {
    if ! command -v tuist &> /dev/null; then
        echo -e "${RED}❌ Tuist is not installed${NC}"
        echo "Install it with: curl -Ls https://install.tuist.io | bash"
        exit 1
    fi
    echo -e "${GREEN}✅ Tuist is installed: $(tuist version)${NC}"
}

# Function to generate project with Tuist
generate_project() {
    echo -e "${YELLOW}🔨 Generating Xcode project with Tuist...${NC}"
    cd "$PROJECT_DIR"
    tuist generate
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Project generated successfully${NC}"
    else
        echo -e "${RED}❌ Failed to generate project${NC}"
        exit 1
    fi
}

# Function to build the project
build_project() {
    echo -e "${YELLOW}🏗️ Building project...${NC}"
    xcodebuild build \
        -workspace "$PROJECT_DIR/ClaudeCode.xcworkspace" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -destination "$DESTINATION" \
        -derivedDataPath "$PROJECT_DIR/build" \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Build completed successfully${NC}"
    else
        echo -e "${RED}❌ Build failed${NC}"
        exit 1
    fi
}

# Function to run tests
run_tests() {
    echo -e "${YELLOW}🧪 Running tests...${NC}"
    xcodebuild test \
        -workspace "$PROJECT_DIR/ClaudeCode.xcworkspace" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -destination "$DESTINATION" \
        -enableCodeCoverage YES \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Tests passed successfully${NC}"
    else
        echo -e "${RED}❌ Tests failed${NC}"
        exit 1
    fi
}

# Main execution
echo "🚀 Starting build process..."
echo ""

check_tuist
generate_project
build_project

# Run tests if requested
if [ "$3" == "--test" ]; then
    run_tests
fi

echo ""
echo -e "${GREEN}✅ Build process completed successfully!${NC}"
echo "📦 Build artifacts available at: $PROJECT_DIR/build"