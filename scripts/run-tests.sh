#!/bin/bash
# Comprehensive Test Execution Script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test results tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

print_header() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}========================================${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Function to run iOS tests
run_ios_tests() {
    print_header "Running iOS Tests"
    
    cd apps/ios
    
    # Generate Xcode project if needed
    if [ ! -d "ClaudeCode.xcodeproj" ]; then
        print_warning "Generating Xcode project..."
        xcodegen generate
    fi
    
    # Run unit tests
    echo "Running iOS unit tests..."
    if xcodebuild test \
        -project ClaudeCode.xcodeproj \
        -scheme ClaudeCode \
        -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
        -quiet; then
        print_success "iOS unit tests passed"
        ((PASSED_TESTS++))
    else
        print_error "iOS unit tests failed"
        ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))
    
    # Run UI tests
    echo "Running iOS UI tests..."
    if xcodebuild test \
        -project ClaudeCode.xcodeproj \
        -scheme ClaudeCodeUITests \
        -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
        -quiet; then
        print_success "iOS UI tests passed"
        ((PASSED_TESTS++))
    else
        print_error "iOS UI tests failed"
        ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))
    
    cd ../..
}

# Function to run backend tests
run_backend_tests() {
    print_header "Running Backend Tests"
    
    # Check if backend is running
    if ! curl -s http://localhost:8000/health > /dev/null; then
        print_warning "Starting backend services..."
        make up
        sleep 10
    fi
    
    # Install test dependencies
    pip install -q pytest pytest-asyncio httpx respx faker pytest-cov
    
    # Run API health tests
    echo "Running API health tests..."
    if pytest test/backend/test_api_health.py -v --tb=short; then
        print_success "API health tests passed"
        ((PASSED_TESTS++))
    else
        print_error "API health tests failed"
        ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))
    
    # Run contract tests
    echo "Running API contract tests..."
    if pytest test/backend/test_api_contracts.py -v --tb=short; then
        print_success "API contract tests passed"
        ((PASSED_TESTS++))
    else
        print_error "API contract tests failed"
        ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))
}

# Function to run integration tests
run_integration_tests() {
    print_header "Running Integration Tests"
    
    echo "Running E2E integration tests..."
    if pytest test/integration/test_end_to_end.py -v --tb=short; then
        print_success "Integration tests passed"
        ((PASSED_TESTS++))
    else
        print_error "Integration tests failed"
        ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))
}

# Function to generate coverage report
generate_coverage_report() {
    print_header "Generating Coverage Report"
    
    # iOS Coverage
    if [ -f "apps/ios/TestResults.xcresult" ]; then
        echo "Generating iOS coverage report..."
        xcrun xccov view --report apps/ios/TestResults.xcresult > coverage/ios-coverage.txt
        print_success "iOS coverage report generated"
    fi
    
    # Backend Coverage
    echo "Generating backend coverage report..."
    pytest test/backend/ --cov=test/backend --cov-report=html:coverage/backend-html --cov-report=term
    print_success "Backend coverage report generated"
}

# Main execution
main() {
    print_header "Claude Code Test Suite"
    echo "Starting comprehensive test execution..."
    echo ""
    
    # Parse arguments
    TEST_TYPE=${1:-all}
    
    case $TEST_TYPE in
        ios)
            run_ios_tests
            ;;
        backend)
            run_backend_tests
            ;;
        integration)
            run_integration_tests
            ;;
        all)
            run_ios_tests
            run_backend_tests
            run_integration_tests
            generate_coverage_report
            ;;
        *)
            echo "Usage: $0 [ios|backend|integration|all]"
            exit 1
            ;;
    esac
    
    # Print summary
    echo ""
    print_header "Test Execution Summary"
    echo "Total Tests Run: $TOTAL_TESTS"
    echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
    echo -e "${RED}Failed: $FAILED_TESTS${NC}"
    
    if [ $FAILED_TESTS -eq 0 ]; then
        print_success "All tests passed! 🎉"
        exit 0
    else
        print_error "Some tests failed. Please review the output above."
        exit 1
    fi
}

# Create coverage directory if it doesn't exist
mkdir -p coverage

# Run main function
main "$@"