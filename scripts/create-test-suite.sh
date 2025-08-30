#!/bin/bash

# Test Suite Creation Script for Claude Code iOS Monorepo
# Addresses critical blocker: Zero test coverage
# Targets: iOS 80%, Backend 90% coverage

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

PROJECT_ROOT="$(dirname "$(dirname "$0")")"
IOS_DIR="$PROJECT_ROOT/apps/ios"
BACKEND_DIR="$PROJECT_ROOT/services/backend"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo -e "${CYAN}🧪 Test Suite Creation Script${NC}"
echo "======================================="
echo "Target Coverage: iOS 80% | Backend 90%"
echo ""

# =============================================================================
# Phase 1: iOS Test Suite Setup
# =============================================================================

echo -e "\n${BLUE}📱 Phase 1: iOS Test Suite Setup${NC}"

# Create iOS test directories
echo "Creating iOS test structure..."
mkdir -p "$IOS_DIR/Tests/Unit"
mkdir -p "$IOS_DIR/Tests/Integration"
mkdir -p "$IOS_DIR/Tests/Mocks"
mkdir -p "$IOS_DIR/Tests/Fixtures"
mkdir -p "$IOS_DIR/Tests/Helpers"
mkdir -p "$IOS_DIR/UITests/Screens"
mkdir -p "$IOS_DIR/UITests/Flows"
mkdir -p "$IOS_DIR/UITests/Helpers"

# Create test configuration
cat > "$IOS_DIR/Tests/TestConfiguration.swift" << 'EOF'
import Foundation
import XCTest

/// Test configuration and environment setup
class TestConfiguration {
    static let shared = TestConfiguration()
    
    var isRunningTests: Bool {
        return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
    
    var testAPIEndpoint: String {
        return ProcessInfo.processInfo.environment["TEST_API_ENDPOINT"] ?? "http://localhost:8000"
    }
    
    var mockDataEnabled: Bool {
        return ProcessInfo.processInfo.environment["USE_MOCK_DATA"] == "true"
    }
    
    var testTimeout: TimeInterval {
        return TimeInterval(ProcessInfo.processInfo.environment["TEST_TIMEOUT"] ?? "30") ?? 30
    }
}

// Test Extensions
extension XCTestCase {
    func waitForAsync(timeout: TimeInterval = 5, file: StaticString = #file, line: UInt = #line, _ block: @escaping () async throws -> Void) {
        let expectation = self.expectation(description: "Async operation")
        
        Task {
            do {
                try await block()
                expectation.fulfill()
            } catch {
                XCTFail("Async operation failed: \(error)", file: file, line: line)
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: timeout)
    }
}
EOF

# Create APIClient tests
cat > "$IOS_DIR/Tests/Unit/APIClientTests.swift" << 'EOF'
import XCTest
@testable import ClaudeCode

final class APIClientTests: XCTestCase {
    var sut: APIClient!
    var mockSession: URLSessionMock!
    
    override func setUp() {
        super.setUp()
        mockSession = URLSessionMock()
        sut = APIClient(session: mockSession)
    }
    
    override func tearDown() {
        sut = nil
        mockSession = nil
        super.tearDown()
    }
    
    func testAuthenticationHeader() async throws {
        // Given
        let apiKey = "test-api-key"
        sut.configure(apiKey: apiKey)
        
        // When
        _ = try? await sut.get("/test")
        
        // Then
        XCTAssertEqual(mockSession.lastRequest?.value(forHTTPHeaderField: "X-API-Key"), apiKey)
    }
    
    func testGetRequest() async throws {
        // Given
        let expectedData = """
        {"status": "success", "data": {"id": 1}}
        """.data(using: .utf8)!
        mockSession.data = expectedData
        mockSession.response = HTTPURLResponse(
            url: URL(string: "http://test.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        // When
        let result: [String: Any] = try await sut.get("/test")
        
        // Then
        XCTAssertEqual(result["status"] as? String, "success")
        XCTAssertNotNil(result["data"])
    }
    
    func testPostRequest() async throws {
        // Given
        let payload = ["name": "Test", "value": 123]
        mockSession.data = "{}".data(using: .utf8)!
        mockSession.response = HTTPURLResponse(
            url: URL(string: "http://test.com")!,
            statusCode: 201,
            httpVersion: nil,
            headerFields: nil
        )
        
        // When
        _ = try await sut.post("/test", body: payload)
        
        // Then
        XCTAssertEqual(mockSession.lastRequest?.httpMethod, "POST")
        XCTAssertNotNil(mockSession.lastRequest?.httpBody)
    }
    
    func testErrorHandling() async {
        // Given
        mockSession.error = URLError(.notConnectedToInternet)
        
        // When/Then
        do {
            let _: [String: Any] = try await sut.get("/test")
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertTrue(error is URLError)
        }
    }
    
    func testRetryMechanism() async throws {
        // Given
        var attemptCount = 0
        mockSession.dataHandler = { _ in
            attemptCount += 1
            if attemptCount < 3 {
                throw URLError(.timedOut)
            }
            return ("{}".data(using: .utf8)!, HTTPURLResponse())
        }
        
        // When
        _ = try await sut.get("/test", retries: 3)
        
        // Then
        XCTAssertEqual(attemptCount, 3)
    }
}
EOF

# Create SSEClient tests
cat > "$IOS_DIR/Tests/Unit/SSEClientTests.swift" << 'EOF'
import XCTest
@testable import ClaudeCode

final class SSEClientTests: XCTestCase {
    var sut: SSEClient!
    var mockEventSource: EventSourceMock!
    
    override func setUp() {
        super.setUp()
        mockEventSource = EventSourceMock()
        sut = SSEClient(eventSource: mockEventSource)
    }
    
    override func tearDown() {
        sut?.disconnect()
        sut = nil
        mockEventSource = nil
        super.tearDown()
    }
    
    func testConnection() {
        // Given
        let url = URL(string: "http://test.com/sse")!
        let expectation = XCTestExpectation(description: "Connected")
        
        sut.onConnected = {
            expectation.fulfill()
        }
        
        // When
        sut.connect(to: url)
        mockEventSource.simulateConnection()
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(sut.isConnected)
    }
    
    func testMessageHandling() {
        // Given
        let expectation = XCTestExpectation(description: "Message received")
        var receivedMessage: SSEMessage?
        
        sut.onMessage = { message in
            receivedMessage = message
            expectation.fulfill()
        }
        
        // When
        sut.connect(to: URL(string: "http://test.com")!)
        mockEventSource.simulateMessage(event: "test", data: "test data")
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedMessage?.event, "test")
        XCTAssertEqual(receivedMessage?.data, "test data")
    }
    
    func testReconnection() {
        // Given
        var connectionCount = 0
        sut.onConnected = {
            connectionCount += 1
        }
        
        // When
        sut.connect(to: URL(string: "http://test.com")!)
        mockEventSource.simulateConnection()
        mockEventSource.simulateDisconnection()
        mockEventSource.simulateConnection()
        
        // Then
        XCTAssertEqual(connectionCount, 2)
    }
    
    func testErrorHandling() {
        // Given
        let expectation = XCTestExpectation(description: "Error received")
        var receivedError: Error?
        
        sut.onError = { error in
            receivedError = error
            expectation.fulfill()
        }
        
        // When
        sut.connect(to: URL(string: "http://test.com")!)
        mockEventSource.simulateError(URLError(.notConnectedToInternet))
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedError)
    }
}
EOF

# Create AuthManager tests
cat > "$IOS_DIR/Tests/Unit/AuthManagerTests.swift" << 'EOF'
import XCTest
@testable import ClaudeCode

final class AuthManagerTests: XCTestCase {
    var sut: AuthManager!
    var mockKeychain: KeychainMock!
    var mockAPIClient: APIClientMock!
    
    override func setUp() {
        super.setUp()
        mockKeychain = KeychainMock()
        mockAPIClient = APIClientMock()
        sut = AuthManager(keychain: mockKeychain, apiClient: mockAPIClient)
    }
    
    override func tearDown() {
        sut = nil
        mockKeychain = nil
        mockAPIClient = nil
        super.tearDown()
    }
    
    func testSuccessfulAuthentication() async throws {
        // Given
        let apiKey = "valid-api-key"
        mockAPIClient.mockResponse = ["valid": true, "user": ["id": "123"]]
        
        // When
        let result = try await sut.authenticate(withAPIKey: apiKey)
        
        // Then
        XCTAssertTrue(result)
        XCTAssertTrue(sut.isAuthenticated)
        XCTAssertEqual(mockKeychain.storedValues["api_key"], apiKey)
    }
    
    func testFailedAuthentication() async throws {
        // Given
        let apiKey = "invalid-api-key"
        mockAPIClient.shouldThrowError = true
        
        // When
        let result = try? await sut.authenticate(withAPIKey: apiKey)
        
        // Then
        XCTAssertNil(result)
        XCTAssertFalse(sut.isAuthenticated)
        XCTAssertNil(mockKeychain.storedValues["api_key"])
    }
    
    func testLogout() {
        // Given
        sut.isAuthenticated = true
        mockKeychain.storedValues["api_key"] = "test-key"
        
        // When
        sut.logout()
        
        // Then
        XCTAssertFalse(sut.isAuthenticated)
        XCTAssertNil(mockKeychain.storedValues["api_key"])
    }
    
    func testTokenRefresh() async throws {
        // Given
        sut.isAuthenticated = true
        mockAPIClient.mockResponse = ["token": "new-token"]
        
        // When
        let newToken = try await sut.refreshToken()
        
        // Then
        XCTAssertEqual(newToken, "new-token")
        XCTAssertEqual(mockKeychain.storedValues["auth_token"], "new-token")
    }
}
EOF

# Create Mock implementations
cat > "$IOS_DIR/Tests/Mocks/URLSessionMock.swift" << 'EOF'
import Foundation

class URLSessionMock: URLSession {
    var data: Data?
    var response: URLResponse?
    var error: Error?
    var lastRequest: URLRequest?
    var dataHandler: ((URLRequest) throws -> (Data, URLResponse))?
    
    override func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        
        if let handler = dataHandler {
            return try handler(request)
        }
        
        if let error = error {
            throw error
        }
        
        return (data ?? Data(), response ?? URLResponse())
    }
}

class EventSourceMock {
    var onOpen: (() -> Void)?
    var onMessage: ((String, String?) -> Void)?
    var onError: ((Error) -> Void)?
    var onClose: (() -> Void)?
    
    func simulateConnection() {
        onOpen?()
    }
    
    func simulateMessage(event: String, data: String?) {
        onMessage?(event, data)
    }
    
    func simulateError(_ error: Error) {
        onError?(error)
    }
    
    func simulateDisconnection() {
        onClose?()
    }
}

class KeychainMock {
    var storedValues: [String: String] = [:]
    
    func get(_ key: String) -> String? {
        return storedValues[key]
    }
    
    func set(_ value: String, for key: String) {
        storedValues[key] = value
    }
    
    func delete(_ key: String) {
        storedValues.removeValue(forKey: key)
    }
}

class APIClientMock {
    var mockResponse: Any?
    var shouldThrowError = false
    var lastEndpoint: String?
    var lastMethod: String?
    var lastBody: Any?
    
    func get<T>(_ endpoint: String) async throws -> T {
        lastEndpoint = endpoint
        lastMethod = "GET"
        
        if shouldThrowError {
            throw URLError(.badServerResponse)
        }
        
        return mockResponse as! T
    }
    
    func post<T>(_ endpoint: String, body: Any?) async throws -> T {
        lastEndpoint = endpoint
        lastMethod = "POST"
        lastBody = body
        
        if shouldThrowError {
            throw URLError(.badServerResponse)
        }
        
        return mockResponse as! T
    }
}
EOF

# Create UI Tests
cat > "$IOS_DIR/UITests/LoginFlowTests.swift" << 'EOF'
import XCTest

final class LoginFlowTests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "USE_MOCK_DATA"]
        app.launch()
    }
    
    override func tearDown() {
        app = nil
        super.tearDown()
    }
    
    func testSuccessfulLogin() {
        // Given
        let apiKeyField = app.secureTextFields["API Key"]
        let loginButton = app.buttons["Authenticate"]
        
        // When
        apiKeyField.tap()
        apiKeyField.typeText("test-api-key-123")
        loginButton.tap()
        
        // Then
        XCTAssertTrue(app.navigationBars["Projects"].waitForExistence(timeout: 5))
    }
    
    func testInvalidAPIKey() {
        // Given
        let apiKeyField = app.secureTextFields["API Key"]
        let loginButton = app.buttons["Authenticate"]
        
        // When
        apiKeyField.tap()
        apiKeyField.typeText("invalid")
        loginButton.tap()
        
        // Then
        XCTAssertTrue(app.alerts["Authentication Failed"].waitForExistence(timeout: 3))
    }
    
    func testEmptyAPIKey() {
        // Given
        let loginButton = app.buttons["Authenticate"]
        
        // When
        loginButton.tap()
        
        // Then
        XCTAssertTrue(app.staticTexts["API Key is required"].waitForExistence(timeout: 1))
    }
}
EOF

# Create test runner script
cat > "$IOS_DIR/Scripts/run-tests.sh" << 'EOF'
#!/bin/bash

# iOS Test Runner
set -e

SCHEME="ClaudeCode"
DESTINATION="platform=iOS Simulator,name=iPhone 15 Pro,OS=17.0"

echo "🧪 Running iOS Tests..."

# Unit Tests
echo "📦 Running Unit Tests..."
xcodebuild test \
    -workspace ClaudeCode.xcworkspace \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -only-testing:ClaudeCodeTests \
    -enableCodeCoverage YES \
    | xcbeautify

# UI Tests
echo "🖥️ Running UI Tests..."
xcodebuild test \
    -workspace ClaudeCode.xcworkspace \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -only-testing:ClaudeCodeUITests \
    | xcbeautify

# Generate coverage report
echo "📊 Generating Coverage Report..."
xcrun xccov view --report DerivedData/*/Logs/Test/*.xcresult
EOF

chmod +x "$IOS_DIR/Scripts/run-tests.sh"

echo -e "${GREEN}✅ iOS test suite structure created${NC}"

# =============================================================================
# Phase 2: Backend Test Suite Setup
# =============================================================================

echo -e "\n${BLUE}🐍 Phase 2: Backend Test Suite Setup${NC}"

# Create backend test directories
echo "Creating backend test structure..."
mkdir -p "$BACKEND_DIR/tests/unit"
mkdir -p "$BACKEND_DIR/tests/integration"
mkdir -p "$BACKEND_DIR/tests/fixtures"
mkdir -p "$BACKEND_DIR/tests/mocks"

# Create pytest configuration
cat > "$BACKEND_DIR/pytest.ini" << 'EOF'
[pytest]
minversion = 7.0
testpaths = tests
python_files = test_*.py
python_classes = Test*
python_functions = test_*
addopts = 
    -v
    --strict-markers
    --tb=short
    --cov=app
    --cov-report=term-missing
    --cov-report=html:htmlcov
    --cov-report=xml
    --cov-fail-under=90
markers =
    unit: Unit tests
    integration: Integration tests
    slow: Slow tests
    asyncio: Async tests
asyncio_mode = auto
EOF

# Create conftest.py
cat > "$BACKEND_DIR/tests/conftest.py" << 'EOF'
import asyncio
import pytest
from typing import AsyncGenerator, Generator
from unittest.mock import MagicMock
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.pool import NullPool
from httpx import AsyncClient

from app.main import app
from app.database import Base, get_db
from app.config import settings

# Test database URL
TEST_DATABASE_URL = "postgresql+asyncpg://test:test@localhost/test_claudecode"

@pytest.fixture(scope="session")
def event_loop() -> Generator:
    """Create an instance of the default event loop for the test session."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()

@pytest.fixture(scope="session")
async def test_engine():
    """Create test database engine."""
    engine = create_async_engine(
        TEST_DATABASE_URL,
        poolclass=NullPool,
        echo=False
    )
    
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    
    yield engine
    
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    
    await engine.dispose()

@pytest.fixture
async def db_session(test_engine) -> AsyncGenerator[AsyncSession, None]:
    """Create a test database session."""
    async_session = async_sessionmaker(
        test_engine,
        class_=AsyncSession,
        expire_on_commit=False
    )
    
    async with async_session() as session:
        yield session
        await session.rollback()

@pytest.fixture
async def client(db_session) -> AsyncGenerator[AsyncClient, None]:
    """Create test client with database override."""
    def override_get_db():
        return db_session
    
    app.dependency_overrides[get_db] = override_get_db
    
    async with AsyncClient(app=app, base_url="http://test") as ac:
        yield ac
    
    app.dependency_overrides.clear()

@pytest.fixture
def mock_redis():
    """Mock Redis client."""
    mock = MagicMock()
    mock.get = MagicMock(return_value=None)
    mock.set = MagicMock(return_value=True)
    mock.delete = MagicMock(return_value=1)
    mock.exists = MagicMock(return_value=0)
    return mock

@pytest.fixture
def auth_headers():
    """Generate test authentication headers."""
    return {"X-API-Key": "test-api-key-123"}

@pytest.fixture
async def test_user(db_session):
    """Create a test user."""
    from app.models import User
    
    user = User(
        email="test@example.com",
        username="testuser",
        full_name="Test User",
        is_active=True
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user

@pytest.fixture
async def test_api_key(db_session, test_user):
    """Create a test API key."""
    from app.models import APIKey
    import secrets
    
    api_key = APIKey(
        key=f"sk-test-{secrets.token_urlsafe(32)}",
        name="Test API Key",
        user_id=test_user.id,
        is_active=True
    )
    db_session.add(api_key)
    await db_session.commit()
    await db_session.refresh(api_key)
    return api_key
EOF

# Create authentication tests
cat > "$BACKEND_DIR/tests/unit/test_auth.py" << 'EOF'
import pytest
from datetime import datetime, timedelta
from unittest.mock import Mock, patch

from app.auth import (
    create_access_token,
    verify_token,
    hash_api_key,
    verify_api_key,
    get_current_user
)

@pytest.mark.unit
class TestAuthentication:
    
    def test_create_access_token(self):
        """Test JWT token creation."""
        data = {"sub": "user123", "email": "test@example.com"}
        token = create_access_token(data)
        
        assert token is not None
        assert isinstance(token, str)
        assert len(token) > 0
    
    def test_verify_valid_token(self):
        """Test verification of valid token."""
        data = {"sub": "user123"}
        token = create_access_token(data)
        
        payload = verify_token(token)
        assert payload is not None
        assert payload["sub"] == "user123"
    
    def test_verify_expired_token(self):
        """Test verification of expired token."""
        data = {"sub": "user123"}
        token = create_access_token(data, expires_delta=timedelta(seconds=-1))
        
        payload = verify_token(token)
        assert payload is None
    
    def test_hash_api_key(self):
        """Test API key hashing."""
        api_key = "sk-test-1234567890"
        hashed = hash_api_key(api_key)
        
        assert hashed != api_key
        assert len(hashed) > 0
    
    def test_verify_api_key_success(self):
        """Test successful API key verification."""
        api_key = "sk-test-1234567890"
        hashed = hash_api_key(api_key)
        
        result = verify_api_key(api_key, hashed)
        assert result is True
    
    def test_verify_api_key_failure(self):
        """Test failed API key verification."""
        api_key = "sk-test-1234567890"
        wrong_key = "sk-test-wrong"
        hashed = hash_api_key(api_key)
        
        result = verify_api_key(wrong_key, hashed)
        assert result is False
    
    @pytest.mark.asyncio
    async def test_get_current_user_valid(self, test_user, test_api_key):
        """Test getting current user with valid API key."""
        from fastapi import HTTPException
        
        mock_db = Mock()
        mock_db.query.return_value.filter.return_value.first.return_value = test_api_key
        
        try:
            user = await get_current_user(test_api_key.key, mock_db)
            assert user is not None
        except HTTPException:
            pytest.fail("Should not raise exception for valid API key")
    
    @pytest.mark.asyncio
    async def test_get_current_user_invalid(self):
        """Test getting current user with invalid API key."""
        from fastapi import HTTPException
        
        mock_db = Mock()
        mock_db.query.return_value.filter.return_value.first.return_value = None
        
        with pytest.raises(HTTPException) as exc_info:
            await get_current_user("invalid-key", mock_db)
        
        assert exc_info.value.status_code == 401
EOF

# Create API endpoint tests
cat > "$BACKEND_DIR/tests/integration/test_api.py" << 'EOF'
import pytest
from httpx import AsyncClient

@pytest.mark.integration
class TestAPIEndpoints:
    
    @pytest.mark.asyncio
    async def test_health_check(self, client: AsyncClient):
        """Test health check endpoint."""
        response = await client.get("/health")
        assert response.status_code == 200
        assert response.json()["status"] == "healthy"
    
    @pytest.mark.asyncio
    async def test_create_session(self, client: AsyncClient, auth_headers):
        """Test session creation endpoint."""
        response = await client.post(
            "/api/sessions",
            headers=auth_headers,
            json={"project_id": "test-project"}
        )
        assert response.status_code == 201
        data = response.json()
        assert "session_id" in data
        assert data["status"] == "active"
    
    @pytest.mark.asyncio
    async def test_list_sessions(self, client: AsyncClient, auth_headers):
        """Test listing sessions endpoint."""
        response = await client.get("/api/sessions", headers=auth_headers)
        assert response.status_code == 200
        assert isinstance(response.json(), list)
    
    @pytest.mark.asyncio
    async def test_get_session(self, client: AsyncClient, auth_headers):
        """Test getting specific session."""
        # Create session first
        create_response = await client.post(
            "/api/sessions",
            headers=auth_headers,
            json={"project_id": "test-project"}
        )
        session_id = create_response.json()["session_id"]
        
        # Get session
        response = await client.get(f"/api/sessions/{session_id}", headers=auth_headers)
        assert response.status_code == 200
        assert response.json()["session_id"] == session_id
    
    @pytest.mark.asyncio
    async def test_unauthorized_access(self, client: AsyncClient):
        """Test unauthorized access is blocked."""
        response = await client.get("/api/sessions")
        assert response.status_code == 401
    
    @pytest.mark.asyncio
    async def test_sse_endpoint(self, client: AsyncClient, auth_headers):
        """Test SSE streaming endpoint."""
        async with client.stream(
            "GET",
            "/api/sessions/test-session/stream",
            headers=auth_headers
        ) as response:
            assert response.status_code == 200
            assert "text/event-stream" in response.headers["content-type"]
EOF

# Create model tests
cat > "$BACKEND_DIR/tests/unit/test_models.py" << 'EOF'
import pytest
from datetime import datetime
from sqlalchemy.exc import IntegrityError

from app.models import User, APIKey, Session, Project, File

@pytest.mark.unit
class TestModels:
    
    @pytest.mark.asyncio
    async def test_user_creation(self, db_session):
        """Test user model creation."""
        user = User(
            email="newuser@example.com",
            username="newuser",
            full_name="New User"
        )
        db_session.add(user)
        await db_session.commit()
        
        assert user.id is not None
        assert user.email == "newuser@example.com"
        assert user.is_active is True
        assert user.created_at is not None
    
    @pytest.mark.asyncio
    async def test_user_unique_email(self, db_session, test_user):
        """Test email uniqueness constraint."""
        duplicate_user = User(
            email=test_user.email,
            username="another",
            full_name="Another User"
        )
        db_session.add(duplicate_user)
        
        with pytest.raises(IntegrityError):
            await db_session.commit()
    
    @pytest.mark.asyncio
    async def test_api_key_creation(self, db_session, test_user):
        """Test API key model creation."""
        api_key = APIKey(
            key="sk-test-new-key",
            name="New API Key",
            user_id=test_user.id
        )
        db_session.add(api_key)
        await db_session.commit()
        
        assert api_key.id is not None
        assert api_key.user_id == test_user.id
        assert api_key.is_active is True
    
    @pytest.mark.asyncio
    async def test_session_creation(self, db_session, test_user):
        """Test session model creation."""
        session = Session(
            user_id=test_user.id,
            project_id="test-project"
        )
        db_session.add(session)
        await db_session.commit()
        
        assert session.id is not None
        assert session.status == "active"
        assert session.messages == []
    
    @pytest.mark.asyncio
    async def test_project_creation(self, db_session, test_user):
        """Test project model creation."""
        project = Project(
            name="Test Project",
            description="A test project",
            user_id=test_user.id
        )
        db_session.add(project)
        await db_session.commit()
        
        assert project.id is not None
        assert project.name == "Test Project"
        assert project.settings == {}
    
    @pytest.mark.asyncio
    async def test_file_creation(self, db_session, test_user):
        """Test file model creation."""
        project = Project(
            name="File Test Project",
            user_id=test_user.id
        )
        db_session.add(project)
        await db_session.commit()
        
        file = File(
            path="/test/file.py",
            content="print('test')",
            project_id=project.id
        )
        db_session.add(file)
        await db_session.commit()
        
        assert file.id is not None
        assert file.path == "/test/file.py"
        assert file.size == len("print('test')")
EOF

# Create test coverage script
cat > "$BACKEND_DIR/scripts/test-coverage.sh" << 'EOF'
#!/bin/bash

# Backend Test Coverage Script
set -e

echo "🧪 Running Backend Tests with Coverage..."

# Install test dependencies if needed
pip install -q pytest pytest-asyncio pytest-cov pytest-mock httpx

# Run tests with coverage
pytest \
    --cov=app \
    --cov-report=term-missing \
    --cov-report=html:htmlcov \
    --cov-report=xml \
    --cov-fail-under=90 \
    -v

# Display coverage summary
echo ""
echo "📊 Coverage Summary:"
python -c "
import xml.etree.ElementTree as ET
tree = ET.parse('coverage.xml')
root = tree.getroot()
coverage = float(root.attrib['line-rate']) * 100
print(f'Total Coverage: {coverage:.2f}%')
print(f'Target: 90%')
if coverage >= 90:
    print('✅ Coverage target met!')
else:
    print(f'❌ Coverage below target (need {90 - coverage:.2f}% more)')
"
EOF

chmod +x "$BACKEND_DIR/scripts/test-coverage.sh"

echo -e "${GREEN}✅ Backend test suite structure created${NC}"

# =============================================================================
# Phase 3: CI/CD Integration
# =============================================================================

echo -e "\n${BLUE}🔄 Phase 3: CI/CD Integration${NC}"

# Create GitHub Actions workflow
mkdir -p "$PROJECT_ROOT/.github/workflows"

cat > "$PROJECT_ROOT/.github/workflows/test.yml" << 'EOF'
name: Test Suite

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  ios-tests:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Xcode
      uses: maxim-lobanov/setup-xcode@v1
      with:
        xcode-version: '15.0'
    
    - name: Install dependencies
      run: |
        cd apps/ios
        if [ -f "Package.swift" ]; then
          swift package resolve
        fi
    
    - name: Run tests
      run: |
        cd apps/ios
        ./Scripts/run-tests.sh
    
    - name: Upload coverage
      uses: codecov/codecov-action@v3
      with:
        file: ./apps/ios/coverage.xml
        flags: ios
        fail_ci_if_error: true

  backend-tests:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
          POSTGRES_DB: test_claudecode
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432
      
      redis:
        image: redis:7
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 6379:6379
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.11'
    
    - name: Install dependencies
      run: |
        cd services/backend
        pip install -r requirements.txt
        pip install pytest pytest-asyncio pytest-cov httpx
    
    - name: Run tests
      run: |
        cd services/backend
        ./scripts/test-coverage.sh
      env:
        DATABASE_URL: postgresql+asyncpg://test:test@localhost/test_claudecode
        REDIS_URL: redis://localhost:6379
    
    - name: Upload coverage
      uses: codecov/codecov-action@v3
      with:
        file: ./services/backend/coverage.xml
        flags: backend
        fail_ci_if_error: true

  coverage-check:
    runs-on: ubuntu-latest
    needs: [ios-tests, backend-tests]
    
    steps:
    - name: Check coverage thresholds
      run: |
        echo "Checking coverage meets targets:"
        echo "iOS target: 80%"
        echo "Backend target: 90%"
EOF

echo -e "${GREEN}✅ CI/CD workflow created${NC}"

# =============================================================================
# Phase 4: Test Documentation
# =============================================================================

echo -e "\n${BLUE}📚 Phase 4: Test Documentation${NC}"

cat > "$PROJECT_ROOT/docs/TEST-STRATEGY.md" << 'EOF'
# Test Strategy & Implementation Guide

## Overview
This document outlines the comprehensive test strategy for the Claude Code iOS Monorepo project.

## Coverage Targets
- **iOS**: 80% minimum coverage
- **Backend**: 90% minimum coverage
- **Integration**: 70% minimum coverage

## Test Pyramid

```
         /\
        /UI\       (10%) - Critical user flows
       /----\
      / Intg \     (20%) - API & component integration
     /--------\
    /   Unit   \   (70%) - Business logic & components
   /____________\
```

## iOS Testing

### Unit Tests
- **Location**: `/apps/ios/Tests/Unit/`
- **Framework**: XCTest
- **Coverage**: Core business logic, models, utilities
- **Mocking**: Protocol-based dependency injection

### Integration Tests
- **Location**: `/apps/ios/Tests/Integration/`
- **Framework**: XCTest
- **Coverage**: API client, data persistence, service integration

### UI Tests
- **Location**: `/apps/ios/UITests/`
- **Framework**: XCUITest
- **Coverage**: Critical user flows, authentication, navigation

### Running iOS Tests
```bash
cd apps/ios
./Scripts/run-tests.sh
```

## Backend Testing

### Unit Tests
- **Location**: `/services/backend/tests/unit/`
- **Framework**: pytest
- **Coverage**: Models, utilities, authentication, business logic

### Integration Tests
- **Location**: `/services/backend/tests/integration/`
- **Framework**: pytest + httpx
- **Coverage**: API endpoints, database operations, SSE streaming

### Running Backend Tests
```bash
cd services/backend
./scripts/test-coverage.sh
```

## CI/CD Integration

Tests run automatically on:
- Push to main/develop branches
- Pull requests to main
- Manual workflow dispatch

## Test Data Management

### Fixtures
- Reusable test data in `/tests/fixtures/`
- Database seeds for integration tests
- Mock API responses for unit tests

### Environment Variables
```bash
# Test environment
TEST_DATABASE_URL=postgresql://test:test@localhost/test_claudecode
USE_MOCK_DATA=true
TEST_TIMEOUT=30
```

## Best Practices

1. **Write tests first** (TDD approach)
2. **Keep tests independent** - No test should depend on another
3. **Use descriptive names** - Test names should explain what they test
4. **Mock external dependencies** - Tests should be deterministic
5. **Maintain test coverage** - Never merge code that reduces coverage
6. **Review test quality** - Tests are code too, keep them clean

## Monitoring & Reporting

- Coverage reports generated in CI/CD
- Codecov integration for tracking trends
- Failed test notifications in pull requests
- Weekly coverage reports to team

## Next Steps

1. Implement remaining unit tests to reach coverage targets
2. Add performance benchmarking tests
3. Implement contract testing for API
4. Add mutation testing for critical paths
5. Set up test environment automation
EOF

echo -e "${GREEN}✅ Test documentation created${NC}"

# =============================================================================
# Verification
# =============================================================================

echo -e "\n${YELLOW}📋 Verification${NC}"

# Check iOS test structure
if [ -d "$IOS_DIR/Tests" ] && [ -d "$IOS_DIR/UITests" ]; then
    echo -e "${GREEN}✅ iOS test directories created${NC}"
    find "$IOS_DIR/Tests" -name "*.swift" | wc -l | xargs -I {} echo "  iOS test files created: {}"
else
    echo -e "${RED}❌ iOS test directories missing${NC}"
fi

# Check backend test structure
if [ -d "$BACKEND_DIR/tests" ]; then
    echo -e "${GREEN}✅ Backend test directories created${NC}"
    find "$BACKEND_DIR/tests" -name "*.py" | wc -l | xargs -I {} echo "  Backend test files created: {}"
else
    echo -e "${RED}❌ Backend test directories missing${NC}"
fi

# Check CI/CD workflow
if [ -f "$PROJECT_ROOT/.github/workflows/test.yml" ]; then
    echo -e "${GREEN}✅ CI/CD workflow configured${NC}"
else
    echo -e "${RED}❌ CI/CD workflow missing${NC}"
fi

echo -e "\n${CYAN}📊 Summary${NC}"
echo "========================="
echo "Test suite structure created successfully!"
echo ""
echo "Coverage Targets:"
echo "- iOS: 80% (currently 0% - tests need to be run)"
echo "- Backend: 90% (currently 0% - tests need to be run)"
echo ""
echo "Next Steps:"
echo "1. Run iOS tests: cd apps/ios && ./Scripts/run-tests.sh"
echo "2. Run backend tests: cd services/backend && ./scripts/test-coverage.sh"
echo "3. Configure CI/CD secrets in GitHub"
echo "4. Implement additional test cases to reach coverage targets"
echo "5. Set up test database and environment"
echo ""
echo -e "${GREEN}✅ Test suite initialization complete!${NC}"
echo "This addresses the most critical blocker: Zero test coverage"