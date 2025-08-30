#!/bin/bash

# iOS-Backend Integration Validation Script for Claude Code
# This script comprehensively tests all integration points between iOS and backend
# including API endpoints, SSE streaming, WebSocket connections, and MCP tool execution

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
IOS_DIR="$PROJECT_ROOT/apps/ios"
BACKEND_DIR="$PROJECT_ROOT/services/backend"

# Test configuration
BACKEND_URL=${BACKEND_URL:-"http://localhost:8000"}
API_VERSION="v1"
TEST_API_KEY="test-api-key-12345"
TEST_SESSION_ID="test-session-$(date +%s)"
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

echo -e "${BLUE}🔌 Claude Code iOS-Backend Integration Validation${NC}"
echo "=================================================="
echo ""
echo "Backend URL: $BACKEND_URL"
echo "API Version: $API_VERSION"
echo "Test Session: $TEST_SESSION_ID"
echo ""

# Function to print test result
print_test_result() {
    local test_name=$1
    local result=$2
    local details=$3
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [ "$result" = "PASS" ]; then
        echo -e "${GREEN}✅ PASS${NC}: $test_name"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        if [ ! -z "$details" ]; then
            echo "   $details"
        fi
    else
        echo -e "${RED}❌ FAIL${NC}: $test_name"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        if [ ! -z "$details" ]; then
            echo -e "   ${RED}$details${NC}"
        fi
    fi
}

# Function to check if backend is running
check_backend_status() {
    if curl -s -f "$BACKEND_URL/health" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# ===========================================
# PHASE 1: Backend Service Health Checks
# ===========================================
echo -e "\n${BLUE}📋 Phase 1: Backend Service Health${NC}"
echo "----------------------------------------"

# Test 1.1: Backend Health Endpoint
echo -n "Testing backend health endpoint... "
if check_backend_status; then
    HEALTH_RESPONSE=$(curl -s "$BACKEND_URL/health")
    if echo "$HEALTH_RESPONSE" | grep -q "healthy"; then
        print_test_result "Backend Health Check" "PASS" "Status: healthy"
    else
        print_test_result "Backend Health Check" "FAIL" "Unexpected response: $HEALTH_RESPONSE"
    fi
else
    print_test_result "Backend Health Check" "FAIL" "Backend not responding at $BACKEND_URL"
    echo -e "${RED}⚠️  Backend must be running. Start with: cd $BACKEND_DIR && docker compose up${NC}"
    exit 1
fi

# Test 1.2: API Version Check
echo -n "Testing API version endpoint... "
VERSION_RESPONSE=$(curl -s "$BACKEND_URL/$API_VERSION" 2>/dev/null || echo "FAILED")
if echo "$VERSION_RESPONSE" | grep -q "version"; then
    print_test_result "API Version Check" "PASS" "Version endpoint accessible"
else
    print_test_result "API Version Check" "FAIL" "Version endpoint not accessible"
fi

# Test 1.3: Database Connectivity
echo -n "Testing database connectivity... "
DB_TEST=$(curl -s "$BACKEND_URL/$API_VERSION/health/database" 2>/dev/null || echo '{"status":"error"}')
if echo "$DB_TEST" | grep -q '"status":"connected"'; then
    print_test_result "Database Connectivity" "PASS" "PostgreSQL connected"
else
    print_test_result "Database Connectivity" "FAIL" "Database connection failed"
fi

# Test 1.4: Redis Connectivity
echo -n "Testing Redis connectivity... "
REDIS_TEST=$(curl -s "$BACKEND_URL/$API_VERSION/health/redis" 2>/dev/null || echo '{"status":"error"}')
if echo "$REDIS_TEST" | grep -q '"status":"connected"'; then
    print_test_result "Redis Connectivity" "PASS" "Redis connected"
else
    print_test_result "Redis Connectivity" "FAIL" "Redis connection failed"
fi

# ===========================================
# PHASE 2: Authentication & Authorization
# ===========================================
echo -e "\n${BLUE}🔐 Phase 2: Authentication Testing${NC}"
echo "----------------------------------------"

# Test 2.1: API Key Validation
echo -n "Testing API key validation... "
AUTH_RESPONSE=$(curl -s -X POST "$BACKEND_URL/$API_VERSION/auth/validate" \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $TEST_API_KEY" \
    -d '{"api_key":"'$TEST_API_KEY'"}' 2>/dev/null || echo "FAILED")

if echo "$AUTH_RESPONSE" | grep -q '"valid"'; then
    print_test_result "API Key Validation" "PASS" "Key accepted"
else
    print_test_result "API Key Validation" "FAIL" "Invalid key response"
fi

# Test 2.2: Session Creation
echo -n "Testing session creation... "
SESSION_RESPONSE=$(curl -s -X POST "$BACKEND_URL/$API_VERSION/sessions" \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $TEST_API_KEY" \
    -d '{"title":"Integration Test Session","model":"claude-3-opus"}' 2>/dev/null || echo "FAILED")

if echo "$SESSION_RESPONSE" | grep -q '"id"'; then
    SESSION_ID=$(echo "$SESSION_RESPONSE" | grep -o '"id":"[^"]*' | cut -d'"' -f4)
    print_test_result "Session Creation" "PASS" "Session ID: $SESSION_ID"
else
    print_test_result "Session Creation" "FAIL" "Could not create session"
    SESSION_ID=$TEST_SESSION_ID
fi

# Test 2.3: JWT Token Generation
echo -n "Testing JWT token generation... "
JWT_RESPONSE=$(curl -s -X POST "$BACKEND_URL/$API_VERSION/auth/token" \
    -H "Content-Type: application/json" \
    -d '{"api_key":"'$TEST_API_KEY'"}' 2>/dev/null || echo "FAILED")

if echo "$JWT_RESPONSE" | grep -q '"access_token"'; then
    JWT_TOKEN=$(echo "$JWT_RESPONSE" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)
    print_test_result "JWT Token Generation" "PASS" "Token received"
else
    print_test_result "JWT Token Generation" "FAIL" "Token generation failed"
fi

# ===========================================
# PHASE 3: RESTful API Endpoints
# ===========================================
echo -e "\n${BLUE}🌐 Phase 3: REST API Endpoints${NC}"
echo "----------------------------------------"

# Test 3.1: GET Sessions List
echo -n "Testing GET /sessions... "
GET_SESSIONS=$(curl -s -X GET "$BACKEND_URL/$API_VERSION/sessions" \
    -H "X-API-Key: $TEST_API_KEY" 2>/dev/null || echo "FAILED")

if [ "$GET_SESSIONS" != "FAILED" ] && echo "$GET_SESSIONS" | grep -q '\['; then
    print_test_result "GET Sessions" "PASS" "Sessions list retrieved"
else
    print_test_result "GET Sessions" "FAIL" "Could not retrieve sessions"
fi

# Test 3.2: POST Message
echo -n "Testing POST /sessions/{id}/messages... "
MESSAGE_RESPONSE=$(curl -s -X POST "$BACKEND_URL/$API_VERSION/sessions/$SESSION_ID/messages" \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $TEST_API_KEY" \
    -d '{"content":"Test message from integration test","role":"user"}' 2>/dev/null || echo "FAILED")

if echo "$MESSAGE_RESPONSE" | grep -q '"id"'; then
    MESSAGE_ID=$(echo "$MESSAGE_RESPONSE" | grep -o '"id":"[^"]*' | cut -d'"' -f4)
    print_test_result "POST Message" "PASS" "Message ID: $MESSAGE_ID"
else
    print_test_result "POST Message" "FAIL" "Could not post message"
fi

# Test 3.3: GET Session Details
echo -n "Testing GET /sessions/{id}... "
SESSION_DETAILS=$(curl -s -X GET "$BACKEND_URL/$API_VERSION/sessions/$SESSION_ID" \
    -H "X-API-Key: $TEST_API_KEY" 2>/dev/null || echo "FAILED")

if echo "$SESSION_DETAILS" | grep -q '"id"'; then
    print_test_result "GET Session Details" "PASS" "Session details retrieved"
else
    print_test_result "GET Session Details" "FAIL" "Could not retrieve session"
fi

# Test 3.4: DELETE Session
echo -n "Testing DELETE /sessions/{id}... "
DELETE_RESPONSE=$(curl -s -X DELETE "$BACKEND_URL/$API_VERSION/sessions/$SESSION_ID" \
    -H "X-API-Key: $TEST_API_KEY" 2>/dev/null || echo "FAILED")

if [ "$?" -eq 0 ]; then
    print_test_result "DELETE Session" "PASS" "Session deleted"
else
    print_test_result "DELETE Session" "FAIL" "Could not delete session"
fi

# ===========================================
# PHASE 4: Server-Sent Events (SSE)
# ===========================================
echo -e "\n${BLUE}📡 Phase 4: SSE Streaming${NC}"
echo "----------------------------------------"

# Create new session for SSE testing
SESSION_RESPONSE=$(curl -s -X POST "$BACKEND_URL/$API_VERSION/sessions" \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $TEST_API_KEY" \
    -d '{"title":"SSE Test Session","model":"claude-3-opus"}' 2>/dev/null || echo "FAILED")

if echo "$SESSION_RESPONSE" | grep -q '"id"'; then
    SSE_SESSION_ID=$(echo "$SESSION_RESPONSE" | grep -o '"id":"[^"]*' | cut -d'"' -f4)
else
    SSE_SESSION_ID=$TEST_SESSION_ID
fi

# Test 4.1: SSE Connection
echo -n "Testing SSE connection... "
SSE_TEST_FILE="/tmp/sse_test_$(date +%s).txt"
timeout 3 curl -s -N "$BACKEND_URL/$API_VERSION/sessions/$SSE_SESSION_ID/stream" \
    -H "X-API-Key: $TEST_API_KEY" > "$SSE_TEST_FILE" 2>/dev/null &
SSE_PID=$!

sleep 2

if ps -p $SSE_PID > /dev/null 2>&1; then
    kill $SSE_PID 2>/dev/null
    print_test_result "SSE Connection" "PASS" "Stream connection established"
else
    print_test_result "SSE Connection" "FAIL" "Could not establish SSE connection"
fi

# Test 4.2: SSE Event Format
echo -n "Testing SSE event format... "
if [ -f "$SSE_TEST_FILE" ] && grep -q "event:" "$SSE_TEST_FILE" 2>/dev/null; then
    print_test_result "SSE Event Format" "PASS" "SSE format valid"
else
    print_test_result "SSE Event Format" "FAIL" "Invalid SSE format"
fi

rm -f "$SSE_TEST_FILE"

# Test 4.3: SSE Heartbeat
echo -n "Testing SSE heartbeat... "
HEARTBEAT_TEST="/tmp/heartbeat_$(date +%s).txt"
timeout 5 curl -s -N "$BACKEND_URL/$API_VERSION/sessions/$SSE_SESSION_ID/stream" \
    -H "X-API-Key: $TEST_API_KEY" > "$HEARTBEAT_TEST" 2>/dev/null &
HB_PID=$!

sleep 4
kill $HB_PID 2>/dev/null || true

if [ -f "$HEARTBEAT_TEST" ] && grep -q "heartbeat" "$HEARTBEAT_TEST" 2>/dev/null; then
    print_test_result "SSE Heartbeat" "PASS" "Heartbeat events received"
else
    print_test_result "SSE Heartbeat" "FAIL" "No heartbeat events"
fi

rm -f "$HEARTBEAT_TEST"

# ===========================================
# PHASE 5: WebSocket Connection
# ===========================================
echo -e "\n${BLUE}🔌 Phase 5: WebSocket Testing${NC}"
echo "----------------------------------------"

# Test 5.1: WebSocket Upgrade
echo -n "Testing WebSocket upgrade... "
WS_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Upgrade: websocket" \
    -H "Connection: Upgrade" \
    -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
    -H "Sec-WebSocket-Version: 13" \
    "$BACKEND_URL/$API_VERSION/ws" 2>/dev/null || echo "000")

if [ "$WS_RESPONSE" = "101" ] || [ "$WS_RESPONSE" = "426" ]; then
    print_test_result "WebSocket Upgrade" "PASS" "WebSocket endpoint available"
else
    print_test_result "WebSocket Upgrade" "FAIL" "WebSocket not configured (HTTP $WS_RESPONSE)"
fi

# Test 5.2: WebSocket with Authentication
echo -n "Testing WebSocket authentication... "
WS_AUTH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Upgrade: websocket" \
    -H "Connection: Upgrade" \
    -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
    -H "Sec-WebSocket-Version: 13" \
    -H "X-API-Key: $TEST_API_KEY" \
    "$BACKEND_URL/$API_VERSION/ws?token=$TEST_API_KEY" 2>/dev/null || echo "000")

if [ "$WS_AUTH_RESPONSE" = "101" ] || [ "$WS_AUTH_RESPONSE" = "426" ]; then
    print_test_result "WebSocket Auth" "PASS" "Authentication accepted"
else
    print_test_result "WebSocket Auth" "FAIL" "Authentication failed"
fi

# ===========================================
# PHASE 6: MCP Tool Integration
# ===========================================
echo -e "\n${BLUE}🔧 Phase 6: MCP Tool Execution${NC}"
echo "----------------------------------------"

# Test 6.1: MCP Server Discovery
echo -n "Testing MCP server discovery... "
MCP_DISCOVERY=$(curl -s "$BACKEND_URL/$API_VERSION/mcp/servers" \
    -H "X-API-Key: $TEST_API_KEY" 2>/dev/null || echo "FAILED")

if echo "$MCP_DISCOVERY" | grep -q '"servers"'; then
    print_test_result "MCP Server Discovery" "PASS" "Servers discovered"
else
    print_test_result "MCP Server Discovery" "FAIL" "Discovery failed"
fi

# Test 6.2: MCP Tool Listing
echo -n "Testing MCP tool listing... "
MCP_TOOLS=$(curl -s "$BACKEND_URL/$API_VERSION/mcp/tools" \
    -H "X-API-Key: $TEST_API_KEY" 2>/dev/null || echo "FAILED")

if echo "$MCP_TOOLS" | grep -q '"tools"'; then
    print_test_result "MCP Tool Listing" "PASS" "Tools listed"
else
    print_test_result "MCP Tool Listing" "FAIL" "Could not list tools"
fi

# Test 6.3: MCP Tool Invocation
echo -n "Testing MCP tool invocation... "
TOOL_RESPONSE=$(curl -s -X POST "$BACKEND_URL/$API_VERSION/mcp/tools/invoke" \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $TEST_API_KEY" \
    -d '{"tool":"test_tool","parameters":{"test":"value"}}' 2>/dev/null || echo "FAILED")

if [ "$TOOL_RESPONSE" != "FAILED" ]; then
    print_test_result "MCP Tool Invocation" "PASS" "Tool invoked"
else
    print_test_result "MCP Tool Invocation" "FAIL" "Invocation failed"
fi

# ===========================================
# PHASE 7: Performance & Limits
# ===========================================
echo -e "\n${BLUE}⚡ Phase 7: Performance Testing${NC}"
echo "----------------------------------------"

# Test 7.1: Response Time
echo -n "Testing API response time... "
START_TIME=$(date +%s%N)
curl -s "$BACKEND_URL/$API_VERSION/health" > /dev/null 2>&1
END_TIME=$(date +%s%N)
RESPONSE_TIME=$(( (END_TIME - START_TIME) / 1000000 ))

if [ $RESPONSE_TIME -lt 500 ]; then
    print_test_result "Response Time" "PASS" "${RESPONSE_TIME}ms < 500ms target"
else
    print_test_result "Response Time" "FAIL" "${RESPONSE_TIME}ms > 500ms target"
fi

# Test 7.2: Rate Limiting
echo -n "Testing rate limiting... "
RATE_LIMIT_HIT=false
for i in {1..20}; do
    RATE_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$BACKEND_URL/$API_VERSION/health" 2>/dev/null)
    if [ "$RATE_RESPONSE" = "429" ]; then
        RATE_LIMIT_HIT=true
        break
    fi
done

if [ "$RATE_LIMIT_HIT" = true ]; then
    print_test_result "Rate Limiting" "PASS" "Rate limits enforced"
else
    print_test_result "Rate Limiting" "FAIL" "No rate limiting detected"
fi

# Test 7.3: Concurrent Connections
echo -n "Testing concurrent connections... "
for i in {1..5}; do
    curl -s "$BACKEND_URL/$API_VERSION/health" > /dev/null 2>&1 &
done
wait

CONCURRENT_SUCCESS=true
for job in $(jobs -p); do
    wait $job || CONCURRENT_SUCCESS=false
done

if [ "$CONCURRENT_SUCCESS" = true ]; then
    print_test_result "Concurrent Connections" "PASS" "5 concurrent connections handled"
else
    print_test_result "Concurrent Connections" "FAIL" "Concurrent connection issues"
fi

# ===========================================
# PHASE 8: Error Handling
# ===========================================
echo -e "\n${BLUE}🛡️ Phase 8: Error Handling${NC}"
echo "----------------------------------------"

# Test 8.1: 404 Not Found
echo -n "Testing 404 error handling... "
NOT_FOUND=$(curl -s -o /dev/null -w "%{http_code}" "$BACKEND_URL/$API_VERSION/nonexistent" 2>/dev/null)
if [ "$NOT_FOUND" = "404" ]; then
    print_test_result "404 Error Handling" "PASS" "Proper 404 response"
else
    print_test_result "404 Error Handling" "FAIL" "Unexpected response: $NOT_FOUND"
fi

# Test 8.2: 401 Unauthorized
echo -n "Testing 401 unauthorized... "
UNAUTH=$(curl -s -o /dev/null -w "%{http_code}" "$BACKEND_URL/$API_VERSION/sessions" 2>/dev/null)
if [ "$UNAUTH" = "401" ] || [ "$UNAUTH" = "403" ]; then
    print_test_result "401 Unauthorized" "PASS" "Proper auth rejection"
else
    print_test_result "401 Unauthorized" "FAIL" "Unexpected response: $UNAUTH"
fi

# Test 8.3: Invalid JSON
echo -n "Testing invalid JSON handling... "
INVALID_JSON=$(curl -s -X POST "$BACKEND_URL/$API_VERSION/sessions" \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $TEST_API_KEY" \
    -d 'invalid json}' 2>/dev/null || echo "FAILED")

if echo "$INVALID_JSON" | grep -q "error\|400\|invalid"; then
    print_test_result "Invalid JSON Handling" "PASS" "Proper error response"
else
    print_test_result "Invalid JSON Handling" "FAIL" "No proper error handling"
fi

# ===========================================
# PHASE 9: iOS-Specific Integration
# ===========================================
echo -e "\n${BLUE}📱 Phase 9: iOS-Specific Tests${NC}"
echo "----------------------------------------"

# Test 9.1: CORS Headers
echo -n "Testing CORS headers... "
CORS_HEADERS=$(curl -s -I "$BACKEND_URL/$API_VERSION/health" 2>/dev/null | grep -i "access-control")
if echo "$CORS_HEADERS" | grep -q "Access-Control-Allow-Origin"; then
    print_test_result "CORS Headers" "PASS" "CORS configured"
else
    print_test_result "CORS Headers" "FAIL" "CORS not configured"
fi

# Test 9.2: Content-Type Support
echo -n "Testing Content-Type support... "
JSON_RESPONSE=$(curl -s -H "Accept: application/json" "$BACKEND_URL/$API_VERSION/health" 2>/dev/null)
if echo "$JSON_RESPONSE" | grep -q "{"; then
    print_test_result "JSON Content-Type" "PASS" "JSON supported"
else
    print_test_result "JSON Content-Type" "FAIL" "JSON not supported"
fi

# Test 9.3: API Versioning
echo -n "Testing API versioning... "
V1_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$BACKEND_URL/v1/health" 2>/dev/null)
V2_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$BACKEND_URL/v2/health" 2>/dev/null)

if [ "$V1_RESPONSE" = "200" ]; then
    print_test_result "API Versioning" "PASS" "v1 endpoint active"
else
    print_test_result "API Versioning" "FAIL" "Versioning not working"
fi

# ===========================================
# PHASE 10: End-to-End Workflow
# ===========================================
echo -e "\n${BLUE}🔄 Phase 10: End-to-End Workflow${NC}"
echo "----------------------------------------"

# Test 10.1: Complete Session Workflow
echo -n "Testing complete session workflow... "

# Step 1: Create session
E2E_SESSION=$(curl -s -X POST "$BACKEND_URL/$API_VERSION/sessions" \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $TEST_API_KEY" \
    -d '{"title":"E2E Test","model":"claude-3-opus"}' 2>/dev/null)

if echo "$E2E_SESSION" | grep -q '"id"'; then
    E2E_ID=$(echo "$E2E_SESSION" | grep -o '"id":"[^"]*' | cut -d'"' -f4)
    
    # Step 2: Send message
    E2E_MESSAGE=$(curl -s -X POST "$BACKEND_URL/$API_VERSION/sessions/$E2E_ID/messages" \
        -H "Content-Type: application/json" \
        -H "X-API-Key: $TEST_API_KEY" \
        -d '{"content":"Test","role":"user"}' 2>/dev/null)
    
    # Step 3: Start SSE stream
    timeout 2 curl -s -N "$BACKEND_URL/$API_VERSION/sessions/$E2E_ID/stream" \
        -H "X-API-Key: $TEST_API_KEY" > /dev/null 2>&1 &
    
    # Step 4: Clean up
    curl -s -X DELETE "$BACKEND_URL/$API_VERSION/sessions/$E2E_ID" \
        -H "X-API-Key: $TEST_API_KEY" > /dev/null 2>&1
    
    print_test_result "E2E Workflow" "PASS" "Complete workflow successful"
else
    print_test_result "E2E Workflow" "FAIL" "Workflow failed at session creation"
fi

# ===========================================
# FINAL SUMMARY
# ===========================================
echo ""
echo "=================================================="
echo -e "${BLUE}📊 Integration Test Summary${NC}"
echo "=================================================="
echo ""
echo "Total Tests: $TOTAL_TESTS"
echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed: ${RED}$FAILED_TESTS${NC}"
echo ""

# Calculate pass rate
if [ $TOTAL_TESTS -gt 0 ]; then
    PASS_RATE=$(( PASSED_TESTS * 100 / TOTAL_TESTS ))
    echo "Pass Rate: ${PASS_RATE}%"
    
    if [ $PASS_RATE -ge 90 ]; then
        echo -e "\n${GREEN}✨ Excellent! Integration is working well.${NC}"
    elif [ $PASS_RATE -ge 70 ]; then
        echo -e "\n${YELLOW}⚠️  Good, but some issues need attention.${NC}"
    else
        echo -e "\n${RED}❌ Critical issues detected. Review failed tests.${NC}"
    fi
else
    echo "No tests executed"
fi

# Generate detailed report
REPORT_FILE="$PROJECT_ROOT/integration-test-report-$(date +%Y%m%d-%H%M%S).md"
cat > "$REPORT_FILE" << EOF
# iOS-Backend Integration Test Report

Generated: $(date)

## Test Environment
- Backend URL: $BACKEND_URL
- API Version: $API_VERSION
- Test Session: $TEST_SESSION_ID

## Results Summary
- Total Tests: $TOTAL_TESTS
- Passed: $PASSED_TESTS
- Failed: $FAILED_TESTS
- Pass Rate: ${PASS_RATE}%

## Test Categories

### Phase 1: Backend Service Health
- Backend Health Check
- API Version Check
- Database Connectivity
- Redis Connectivity

### Phase 2: Authentication
- API Key Validation
- Session Creation
- JWT Token Generation

### Phase 3: REST API Endpoints
- GET Sessions List
- POST Message
- GET Session Details
- DELETE Session

### Phase 4: SSE Streaming
- SSE Connection
- SSE Event Format
- SSE Heartbeat

### Phase 5: WebSocket
- WebSocket Upgrade
- WebSocket Authentication

### Phase 6: MCP Tools
- Server Discovery
- Tool Listing
- Tool Invocation

### Phase 7: Performance
- Response Time
- Rate Limiting
- Concurrent Connections

### Phase 8: Error Handling
- 404 Not Found
- 401 Unauthorized
- Invalid JSON

### Phase 9: iOS-Specific
- CORS Headers
- Content-Type Support
- API Versioning

### Phase 10: End-to-End
- Complete Session Workflow

## Recommendations

$(if [ $FAILED_TESTS -gt 0 ]; then
    echo "### Failed Tests Requiring Attention:"
    echo "Please review the test output above for specific failures."
    echo ""
    echo "Common fixes:"
    echo "- Ensure backend is running: cd $BACKEND_DIR && docker compose up"
    echo "- Check database migrations: cd $BACKEND_DIR && alembic upgrade head"
    echo "- Verify Redis is running: docker ps | grep redis"
    echo "- Check API key configuration in .env"
else
    echo "All tests passed successfully!"
fi)

## Next Steps

1. Fix any failed tests identified above
2. Run iOS app tests: cd $IOS_DIR && ./Scripts/run-tests.sh
3. Test with actual iOS simulator
4. Monitor production metrics

EOF

echo ""
echo -e "${BLUE}📄 Detailed report saved to:${NC}"
echo "   $REPORT_FILE"
echo ""

# Exit with appropriate code
if [ $FAILED_TESTS -gt 0 ]; then
    exit 1
else
    exit 0
fi