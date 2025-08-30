#!/bin/bash

# E2E Integration Test Runner
# Run end-to-end tests for Claude Code iOS monorepo

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🚀 Claude Code E2E Test Runner"
echo "================================"

# Check if we're in the right directory
if [ ! -f "package.json" ] || [ ! -d "services/backend" ] || [ ! -d "apps/ios" ]; then
    echo -e "${RED}Error: Must run from monorepo root directory${NC}"
    exit 1
fi

# Start backend services
echo -e "\n${YELLOW}Starting backend services...${NC}"
docker-compose up -d postgres redis

# Wait for services to be ready
echo "Waiting for PostgreSQL..."
until docker-compose exec -T postgres pg_isready -U postgres > /dev/null 2>&1; do
    sleep 1
done
echo -e "${GREEN}✓ PostgreSQL ready${NC}"

echo "Waiting for Redis..."
until docker-compose exec -T redis redis-cli ping > /dev/null 2>&1; do
    sleep 1
done
echo -e "${GREEN}✓ Redis ready${NC}"

# Run database migrations
echo -e "\n${YELLOW}Running database migrations...${NC}"
cd services/backend
export DATABASE_URL="postgresql://postgres:postgres@localhost:5432/claudecode_test"
alembic upgrade head
cd ../..
echo -e "${GREEN}✓ Migrations complete${NC}"

# Run E2E tests with coverage
echo -e "\n${YELLOW}Running E2E integration tests...${NC}"
cd services/backend
export TESTING=true
export DATABASE_URL="postgresql://postgres:postgres@localhost:5432/claudecode_test"

# Run with coverage
pytest tests/e2e/test_auth_integration.py \
    -v \
    --cov=app \
    --cov-report=term-missing \
    --cov-report=html:coverage_html \
    --cov-report=json:coverage.json \
    --asyncio-mode=auto

TEST_EXIT_CODE=$?

cd ../..

# Clean up
echo -e "\n${YELLOW}Cleaning up...${NC}"
docker-compose down

# Report results
if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo -e "\n${GREEN}✅ All E2E tests passed!${NC}"
    
    # Parse coverage from JSON
    if [ -f "services/backend/coverage.json" ]; then
        COVERAGE=$(python3 -c "import json; data = json.load(open('services/backend/coverage.json')); print(f\"{data['totals']['percent_covered']:.1f}\")")
        echo -e "${GREEN}📊 Test Coverage: ${COVERAGE}%${NC}"
        
        # Check if coverage meets minimum threshold
        if (( $(echo "$COVERAGE >= 40" | bc -l) )); then
            echo -e "${GREEN}✅ Coverage threshold met (>= 40%)${NC}"
        else
            echo -e "${YELLOW}⚠️ Coverage below 40% threshold${NC}"
        fi
    fi
else
    echo -e "\n${RED}❌ E2E tests failed!${NC}"
    exit $TEST_EXIT_CODE
fi

echo -e "\n📋 Coverage report available at: services/backend/coverage_html/index.html"