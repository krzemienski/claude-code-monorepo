# Test Strategy and Implementation Guide

## Overview

This document outlines the comprehensive testing strategy for the Claude Code monorepo, covering iOS app, backend API, and integration testing.

## Test Architecture

### Test Pyramid

```
         /\
        /E2E\        <- End-to-End Tests (5%)
       /______\
      /Integration\   <- Integration Tests (15%)
     /____________\
    /   Unit Tests  \ <- Unit Tests (80%)
   /________________\
```

## Test Coverage Matrix

### iOS Application Testing

| Component | Unit Tests | UI Tests | Coverage Target |
|-----------|------------|----------|-----------------|
| Core/AppSettings | ✅ | - | 90% |
| Core/APIClient | ✅ | - | 85% |
| Core/SSEClient | ✅ | - | 80% |
| Core/KeychainService | ✅ | - | 95% |
| Features/Home | ✅ | ✅ | 80% |
| Features/Projects | ✅ | ✅ | 85% |
| Features/Sessions | ✅ | ✅ | 85% |
| Features/MCP | ✅ | ✅ | 80% |
| Features/Settings | ✅ | ✅ | 90% |
| Features/Onboarding | ✅ | ✅ | 95% |

### Backend API Testing

| Endpoint Category | Health Tests | Contract Tests | Integration Tests |
|------------------|--------------|----------------|-------------------|
| /health | ✅ | ✅ | ✅ |
| /v1/models | ✅ | ✅ | ✅ |
| /v1/chat/completions | ✅ | ✅ | ✅ |
| /v1/projects | ✅ | ✅ | ✅ |
| /v1/sessions | ✅ | ✅ | ✅ |
| /v1/mcp/* | ✅ | ✅ | ✅ |

## Test Execution

### Local Development

```bash
# Run all tests
./scripts/run-tests.sh all

# Run specific test suites
./scripts/run-tests.sh ios        # iOS tests only
./scripts/run-tests.sh backend    # Backend tests only
./scripts/run-tests.sh integration # Integration tests only
```

### iOS Testing

```bash
# Unit tests
cd apps/ios
xcodegen generate
xcodebuild test -scheme ClaudeCode -destination 'platform=iOS Simulator,name=iPhone 15'

# UI tests
xcodebuild test -scheme ClaudeCodeUITests -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Backend Testing

```bash
# Start backend
make up

# Run API tests
pytest test/backend/test_api_health.py -v

# Run contract tests
pytest test/backend/test_api_contracts.py -v

# Run with coverage
pytest test/backend/ --cov=test/backend --cov-report=html
```

### Integration Testing

```bash
# Ensure backend is running
make up

# Run E2E tests
pytest test/integration/test_end_to_end.py -v
```

## CI/CD Pipeline

### GitHub Actions Workflow

The test pipeline (`.github/workflows/test-pipeline.yml`) runs on:
- Push to main/develop branches
- Pull requests to main
- Manual workflow dispatch

### Pipeline Stages

1. **iOS Unit Tests** (macos-14)
   - Setup Xcode 15.2
   - Generate project with XcodeGen
   - Run unit tests
   - Generate coverage report

2. **iOS UI Tests** (macos-14)
   - Setup iOS Simulator
   - Run UI tests
   - Capture screenshots on failure

3. **Backend API Tests** (ubuntu-latest)
   - Start Docker services
   - Run health checks
   - Execute API tests
   - Generate coverage

4. **Contract Tests** (ubuntu-latest)
   - Validate API contracts
   - Check response schemas
   - Verify error handling

5. **Integration Tests** (ubuntu-latest)
   - Run E2E workflows
   - Test complete user journeys
   - Validate system integration

6. **Performance Tests** (ubuntu-latest, main branch only)
   - Load testing with k6
   - Response time validation
   - Throughput testing

## Test Data Management

### Test Fixtures

```python
# Backend test fixtures
class TestDataFactory:
    @staticmethod
    def create_test_project():
        return {
            "name": f"Test Project {uuid.uuid4().hex[:8]}",
            "description": "Automated test project"
        }
    
    @staticmethod
    def create_test_session():
        return {
            "model": "claude-3-5-sonnet-20241022",
            "project_id": "test-project"
        }
```

### iOS Test Helpers

```swift
// Test utilities
extension XCTestCase {
    func awaitPublisher<T: Publisher>(_ publisher: T) throws -> T.Output
    func assertEventually<T: Equatable>(_ expression: @autoclosure () throws -> T, equals expected: T)
}

// Mock services
class MockAPIClient: APIClientProtocol {
    var mockResponses: [String: Any] = [:]
    var mockErrors: [String: Error] = [:]
}
```

## Coverage Requirements

### Minimum Coverage Thresholds

- **Unit Tests**: 80% line coverage
- **Integration Tests**: 70% scenario coverage
- **UI Tests**: All critical user paths
- **Overall**: 75% combined coverage

### Coverage Reporting

```bash
# iOS coverage
xcrun xccov view --report TestResults.xcresult

# Backend coverage
pytest --cov=test/backend --cov-report=html:coverage/html

# Upload to Codecov
codecov --file coverage.xml --flags backend
```

## Test Categories

### 1. Unit Tests

**Purpose**: Test individual components in isolation

**Characteristics**:
- Fast execution (<100ms per test)
- No external dependencies
- Use mocks and stubs
- High coverage target (80%+)

**Examples**:
- `AppSettingsTests.swift`
- `APIClientTests.swift`
- `test_api_health.py`

### 2. Integration Tests

**Purpose**: Test component interactions

**Characteristics**:
- Test service boundaries
- Use test databases/services
- Moderate execution time
- Focus on critical paths

**Examples**:
- API endpoint integration
- Database operations
- Service communication

### 3. UI Tests

**Purpose**: Test user interface and workflows

**Characteristics**:
- Simulate user interactions
- Test navigation flows
- Validate UI state
- Screenshot on failure

**Examples**:
- `testOnboardingFlow()`
- `testTabNavigation()`
- `testCreateNewSession()`

### 4. E2E Tests

**Purpose**: Test complete user journeys

**Characteristics**:
- Full system testing
- Real service interactions
- Production-like environment
- Critical business flows

**Examples**:
- Complete chat session
- Project lifecycle
- MCP tool usage

### 5. Contract Tests

**Purpose**: Validate API contracts

**Characteristics**:
- Schema validation
- Response structure verification
- Error format checking
- Version compatibility

**Examples**:
- Response field validation
- Type checking
- Required field verification

### 6. Performance Tests

**Purpose**: Validate performance requirements

**Characteristics**:
- Load testing
- Response time validation
- Throughput measurement
- Resource usage monitoring

**Metrics**:
- Response time <200ms (p95)
- Throughput >100 req/s
- Error rate <1%

## Flaky Test Management

### Detection

```python
# Mark flaky tests
@pytest.mark.flaky(reruns=3, reruns_delay=2)
def test_potentially_flaky():
    pass
```

### Mitigation Strategies

1. **Retry Logic**: Automatic retry for known flaky tests
2. **Wait Strategies**: Proper waits instead of sleep
3. **Test Isolation**: Clean state between tests
4. **Mocking**: Mock external dependencies

## Test Automation Tools

### iOS
- **XCTest**: Unit and UI testing framework
- **XcodeGen**: Project generation
- **xcpretty**: Test output formatting
- **xccov**: Coverage reporting

### Backend
- **pytest**: Python testing framework
- **httpx**: Async HTTP client
- **respx**: HTTP mocking
- **pytest-cov**: Coverage plugin

### CI/CD
- **GitHub Actions**: CI/CD platform
- **Codecov**: Coverage tracking
- **k6**: Performance testing

## Debugging Failed Tests

### Local Debugging

```bash
# Run specific test with verbose output
pytest test/backend/test_api_health.py::TestHealthEndpoints::test_health_endpoint -vvs

# iOS test with detailed output
xcodebuild test -scheme ClaudeCode -only-testing:ClaudeCodeTests/AppSettingsTests/testDefaultBaseURL
```

### CI Debugging

1. Check GitHub Actions logs
2. Download test artifacts
3. Review screenshots (UI tests)
4. Analyze coverage reports

## Best Practices

### Test Writing

1. **Descriptive Names**: Use clear, descriptive test names
2. **Single Responsibility**: One assertion per test
3. **Isolation**: Tests should not depend on each other
4. **Cleanup**: Always clean up test data
5. **Documentation**: Comment complex test logic

### Test Organization

```
test/
├── backend/
│   ├── test_api_health.py
│   ├── test_api_contracts.py
│   └── conftest.py
├── integration/
│   └── test_end_to_end.py
└── performance/
    └── load_test.js

apps/ios/
├── Tests/
│   ├── Core/
│   ├── Features/
│   └── TestHelpers/
└── UITests/
    └── ClaudeCodeUITests.swift
```

## Continuous Improvement

### Metrics to Track

- Test execution time
- Coverage trends
- Flaky test rate
- Test failure rate
- Time to fix failures

### Regular Reviews

- Weekly: Review test failures
- Monthly: Coverage analysis
- Quarterly: Test strategy review

## Troubleshooting

### Common Issues

**iOS Simulator Not Found**
```bash
xcrun simctl list devices
xcrun simctl boot "iPhone 15"
```

**Backend Not Responding**
```bash
docker compose -f deploy/compose/docker-compose.yml logs
make rebuild
```

**Test Timeouts**
- Increase timeout values
- Check network connectivity
- Verify service health

## Contact

For test-related questions or issues:
- Create GitHub issue with `test` label
- Include test output and environment details
- Tag `@test-automation` team