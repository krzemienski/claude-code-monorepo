# Test Environment Specifications - Claude Code Monorepo

## 🎯 Overview

Comprehensive test environment specifications for full-stack Claude Code application including iOS, Backend API, and Infrastructure components.

---

## 📱 iOS Test Environment

### Development Environment

```yaml
Platform: iOS 17.0+
Xcode: 15.0+
Swift: 5.9+
Architecture: arm64 (Apple Silicon)
Simulators:
  - iPhone 15 Pro (iOS 17.0)
  - iPhone 14 (iOS 16.0)
  - iPad Pro 12.9" (iOS 17.0)
```

### Test Frameworks

```swift
// Package.swift dependencies
.package(url: "https://github.com/apple/swift-testing.git", from: "0.10.0"),
.package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.15.0"),
.package(url: "https://github.com/Quick/Quick.git", from: "7.0.0"),
.package(url: "https://github.com/Quick/Nimble.git", from: "13.0.0")
```

### Test Execution Commands

```bash
# Unit Tests
swift test --parallel

# Integration Tests
xcodebuild test \
  -scheme ClaudeCode \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -testPlan IntegrationTests

# UI Tests
xcodebuild test \
  -scheme ClaudeCodeUITests \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -resultBundlePath TestResults.xcresult

# Performance Tests
instruments -t "Time Profiler" \
  -D performance.trace \
  ClaudeCode.app
```

### Test Data Setup

```swift
// TestData/MockData.swift
struct TestEnvironment {
    static let baseURL = "http://localhost:8000"
    static let testAPIKey = "test_api_key_123"
    static let mockUserEmail = "test@claudecode.com"
    static let mockPassword = "Test123!@#"
    
    static let mockJWT = """
        eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.
        eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IlRlc3QgVXNlciIsImlhdCI6MTUxNjIzOTAyMn0.
        SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c
        """
}
```

---

## 🖥️ Backend API Test Environment

### Development Stack

```yaml
Runtime: Python 3.11+
Framework: FastAPI 0.109.0
Database: PostgreSQL 15
Cache: Redis 7.0
Message Queue: Redis Streams
Container: Docker 24.0+
```

### Docker Compose Test Configuration

```yaml
# docker-compose.test.yml
version: '3.8'

services:
  test-api:
    build: 
      context: .
      target: test
    environment:
      - DATABASE_URL=postgresql://test:test@test-db:5432/testdb
      - REDIS_URL=redis://test-redis:6379/0
      - ENVIRONMENT=test
      - DEBUG=true
      - ANTHROPIC_API_KEY=${TEST_ANTHROPIC_KEY}
    ports:
      - "8001:8000"
    depends_on:
      - test-db
      - test-redis
    volumes:
      - ./tests:/app/tests
      - ./coverage:/app/coverage

  test-db:
    image: postgres:15-alpine
    environment:
      - POSTGRES_USER=test
      - POSTGRES_PASSWORD=test
      - POSTGRES_DB=testdb
    ports:
      - "5433:5432"
    volumes:
      - test-db-data:/var/lib/postgresql/data

  test-redis:
    image: redis:7-alpine
    ports:
      - "6380:6379"
    command: redis-server --maxmemory 128mb --maxmemory-policy allkeys-lru

volumes:
  test-db-data:
```

### Test Execution

```bash
# Start test environment
docker-compose -f docker-compose.test.yml up -d

# Run backend tests
docker-compose -f docker-compose.test.yml exec test-api pytest \
  --cov=app \
  --cov-report=html:coverage \
  --cov-report=term \
  -v

# Run specific test suite
docker-compose -f docker-compose.test.yml exec test-api pytest \
  tests/test_auth.py \
  -v

# Load testing
locust -f tests/load/locustfile.py \
  --host=http://localhost:8001 \
  --users=100 \
  --spawn-rate=10

# Security testing
docker run --rm \
  -v $(pwd):/zap/wrk/:rw \
  -t owasp/zap2docker-stable zap-api-scan.py \
  -t http://host.docker.internal:8001/openapi.json \
  -f openapi
```

### Test Database Seeding

```python
# tests/fixtures/seed_data.py
import asyncio
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.session import async_session
from app.models import User, Project, Session

async def seed_test_data():
    async with async_session() as db:
        # Create test users
        test_user = User(
            email="test@claudecode.com",
            username="testuser",
            hashed_password="$2b$12$xxx",  # Pre-hashed password
            is_active=True,
            is_verified=True
        )
        db.add(test_user)
        
        # Create test project
        test_project = Project(
            name="Test Project",
            description="Integration test project",
            user_id=test_user.id,
            settings={"theme": "dark", "language": "en"}
        )
        db.add(test_project)
        
        # Create test session
        test_session = Session(
            name="Test Session",
            project_id=test_project.id,
            model="claude-3-opus-20240229",
            messages=[]
        )
        db.add(test_session)
        
        await db.commit()

if __name__ == "__main__":
    asyncio.run(seed_test_data())
```

---

## 🔗 Integration Test Environment

### Full-Stack Test Setup

```bash
#!/bin/bash
# scripts/setup-integration-tests.sh

# Start backend services
cd services/backend
docker-compose -f docker-compose.test.yml up -d
./scripts/wait-for-healthy.sh

# Seed test data
docker-compose exec test-api python tests/fixtures/seed_data.py

# Start iOS simulator
xcrun simctl boot "iPhone 15 Pro"
xcrun simctl openurl booted http://localhost:8001

# Run integration tests
cd ../../apps/ios
xcodebuild test \
  -scheme ClaudeCodeIntegration \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:ClaudeCodeTests/Integration
```

### End-to-End Test Scenarios

```swift
// Tests/Integration/E2ETests.swift
import XCTest
@testable import ClaudeCode

class E2ETests: XCTestCase {
    let testEnvironment = TestEnvironment()
    
    override func setUp() {
        super.setUp()
        // Reset test environment
        testEnvironment.reset()
        // Configure test backend
        AppSettings.shared.baseURL = "http://localhost:8001"
    }
    
    func testCompleteAuthenticationFlow() async throws {
        // 1. Register new user
        let registration = try await AuthManager.shared.register(
            email: "e2e@test.com",
            password: "TestPass123!"
        )
        XCTAssertNotNil(registration.accessToken)
        
        // 2. Logout
        await AuthManager.shared.logout()
        
        // 3. Login with credentials
        let login = try await AuthManager.shared.login(
            email: "e2e@test.com",
            password: "TestPass123!"
        )
        XCTAssertNotNil(login.accessToken)
        
        // 4. Refresh token
        try await AuthManager.shared.refreshToken()
        
        // 5. Make authenticated request
        let projects = try await ProjectManager.shared.fetchProjects()
        XCTAssertNotNil(projects)
    }
    
    func testChatCompletionFlow() async throws {
        // Setup authentication
        try await authenticateTestUser()
        
        // Create session
        let session = try await SessionManager.shared.createSession(
            name: "E2E Test Session",
            model: "claude-3-haiku-20240307"
        )
        
        // Send message
        let response = try await ChatManager.shared.sendMessage(
            content: "Hello, this is an E2E test",
            sessionId: session.id
        )
        
        XCTAssertFalse(response.content.isEmpty)
    }
}
```

---

## 🚀 CI/CD Test Pipeline

### GitHub Actions Configuration

```yaml
# .github/workflows/test.yml
name: Full Stack Tests

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  ios-tests:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Xcode
        uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: '15.0'
      
      - name: Cache Swift packages
        uses: actions/cache@v3
        with:
          path: ~/Library/Developer/Xcode/DerivedData
          key: ${{ runner.os }}-spm-${{ hashFiles('**/Package.resolved') }}
      
      - name: Run iOS Tests
        run: |
          cd apps/ios
          xcodebuild test \
            -scheme ClaudeCode \
            -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
            -resultBundlePath TestResults.xcresult
      
      - name: Upload Test Results
        uses: actions/upload-artifact@v3
        with:
          name: ios-test-results
          path: apps/ios/TestResults.xcresult

  backend-tests:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: test
          POSTGRES_DB: testdb
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
      
      redis:
        image: redis:7
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      
      - name: Install dependencies
        run: |
          cd services/backend
          pip install -r requirements.txt
          pip install -r requirements-test.txt
      
      - name: Run Backend Tests
        env:
          DATABASE_URL: postgresql://postgres:test@localhost/testdb
          REDIS_URL: redis://localhost:6379
        run: |
          cd services/backend
          pytest --cov=app --cov-report=xml -v
      
      - name: Upload Coverage
        uses: codecov/codecov-action@v3
        with:
          file: ./services/backend/coverage.xml

  integration-tests:
    needs: [ios-tests, backend-tests]
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Start Backend Services
        run: |
          cd services/backend
          docker-compose -f docker-compose.test.yml up -d
          ./scripts/wait-for-healthy.sh
      
      - name: Run Integration Tests
        run: |
          cd apps/ios
          xcodebuild test \
            -scheme ClaudeCodeIntegration \
            -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
            -only-testing:ClaudeCodeTests/Integration
```

---

## 📊 Test Metrics & Monitoring

### Coverage Requirements

```yaml
Minimum Coverage Thresholds:
  iOS:
    - Unit Tests: 80%
    - Integration Tests: 70%
    - UI Tests: 60%
  
  Backend:
    - Unit Tests: 85%
    - Integration Tests: 75%
    - API Tests: 90%
  
  Overall:
    - Full Stack Integration: 70%
    - Critical Paths: 95%
```

### Performance Benchmarks

```yaml
Response Time Targets:
  API Endpoints:
    - Health Check: < 50ms
    - Authentication: < 200ms
    - Chat Completion: < 2000ms (first token)
    - File Operations: < 500ms
  
  iOS App:
    - App Launch: < 1s
    - Screen Transitions: < 300ms
    - API Calls: < 1s (excluding network)
    - Memory Usage: < 150MB
```

### Test Monitoring Dashboard

```python
# monitoring/test_metrics.py
from prometheus_client import Counter, Histogram, Gauge

# Test execution metrics
test_runs = Counter('test_runs_total', 'Total test runs', ['suite', 'status'])
test_duration = Histogram('test_duration_seconds', 'Test execution time', ['suite'])
test_coverage = Gauge('test_coverage_percent', 'Test coverage percentage', ['component'])
test_failures = Counter('test_failures_total', 'Total test failures', ['suite', 'test_name'])

# Performance metrics
api_response_time = Histogram('api_response_seconds', 'API response time', ['endpoint'])
ios_memory_usage = Gauge('ios_memory_mb', 'iOS app memory usage')
db_query_time = Histogram('db_query_seconds', 'Database query time', ['query_type'])
```

---

## 🔒 Security Test Environment

### Security Testing Tools

```bash
# OWASP ZAP for API security testing
docker run -t owasp/zap2docker-stable zap-baseline.py \
  -t http://localhost:8000 \
  -r security-report.html

# iOS security testing with MobSF
docker run -it --rm \
  -p 8000:8000 \
  opensecurity/mobile-security-framework-mobsf:latest

# Dependency vulnerability scanning
# Backend
cd services/backend
safety check --json > security-report.json

# iOS
cd apps/ios
swift package audit --format json > security-audit.json
```

### Penetration Testing Checklist

- [ ] SQL Injection testing
- [ ] XSS vulnerability scanning
- [ ] Authentication bypass attempts
- [ ] JWT token manipulation
- [ ] Rate limiting validation
- [ ] CORS policy testing
- [ ] File upload security
- [ ] API key exposure checks
- [ ] iOS keychain security
- [ ] Certificate pinning validation

---

## 🚦 Test Environment Management

### Environment Variables

```bash
# .env.test
# Backend
DATABASE_URL=postgresql://test:test@localhost:5433/testdb
REDIS_URL=redis://localhost:6380/0
SECRET_KEY=test-secret-key-only-for-testing
ANTHROPIC_API_KEY=test-key-xxx
ENVIRONMENT=test
DEBUG=true

# iOS
TEST_BASE_URL=http://localhost:8001
TEST_API_KEY=test_api_key_123
TEST_USER_EMAIL=test@claudecode.com
TEST_USER_PASSWORD=TestPass123!
ENABLE_TEST_LOGGING=true
```

### Test Data Cleanup

```bash
#!/bin/bash
# scripts/cleanup-test-env.sh

echo "Cleaning up test environment..."

# Stop and remove test containers
docker-compose -f docker-compose.test.yml down -v

# Clean iOS simulator
xcrun simctl shutdown all
xcrun simctl erase all

# Remove test artifacts
rm -rf coverage/
rm -rf TestResults.xcresult
rm -rf .pytest_cache/
rm -rf test-reports/

# Reset test database
psql -U postgres -c "DROP DATABASE IF EXISTS testdb;"
psql -U postgres -c "CREATE DATABASE testdb;"

echo "Test environment cleaned!"
```

---

## 📝 Test Documentation Requirements

Each test suite must include:

1. **Test Plan Document** - Objectives, scope, approach
2. **Test Cases** - Detailed scenarios with expected results
3. **Test Data** - Sample data and fixtures
4. **Environment Setup** - Step-by-step configuration
5. **Execution Guide** - How to run tests
6. **Results Template** - Reporting format
7. **Known Issues** - Documented limitations

---

**Generated**: 2025-08-31  
**Version**: 1.0.0  
**Next Review**: Monthly