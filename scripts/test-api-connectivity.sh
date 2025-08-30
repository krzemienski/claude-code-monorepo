#!/bin/bash

# Test API connectivity for Claude Code iOS integration
# This script tests all critical endpoints from localhost

echo "🔍 Testing Claude Code API Connectivity..."
echo "==========================================="
echo ""

API_BASE="http://localhost:8000"

# Test 1: Health Check
echo "1️⃣ Testing Health Endpoint..."
HEALTH_RESPONSE=$(curl -s -w "\n%{http_code}" "$API_BASE/health")
HEALTH_CODE=$(echo "$HEALTH_RESPONSE" | tail -n1)
HEALTH_BODY=$(echo "$HEALTH_RESPONSE" | head -n-1)

if [ "$HEALTH_CODE" = "200" ]; then
    echo "✅ Health check passed: $HEALTH_BODY"
else
    echo "❌ Health check failed with code: $HEALTH_CODE"
fi
echo ""

# Test 2: Models Endpoint  
echo "2️⃣ Testing Models Endpoint..."
MODELS_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer test-api-key" \
    "$API_BASE/v1/models")
MODELS_CODE=$(echo "$MODELS_RESPONSE" | tail -n1)

if [ "$MODELS_CODE" = "200" ]; then
    echo "✅ Models endpoint accessible"
    echo "$MODELS_RESPONSE" | head -n-1 | python3 -m json.tool | head -20
else
    echo "❌ Models endpoint failed with code: $MODELS_CODE"
fi
echo ""

# Test 3: CORS Headers
echo "3️⃣ Testing CORS Configuration..."
CORS_RESPONSE=$(curl -s -I -X OPTIONS \
    -H "Origin: http://localhost" \
    -H "Access-Control-Request-Method: POST" \
    "$API_BASE/v1/chat/completions" | grep -i "access-control")

if echo "$CORS_RESPONSE" | grep -q "Access-Control-Allow-Origin"; then
    echo "✅ CORS headers present:"
    echo "$CORS_RESPONSE"
else
    echo "❌ CORS headers missing"
fi
echo ""

# Test 4: Sessions Endpoint
echo "4️⃣ Testing Sessions Endpoint..."
SESSIONS_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer test-api-key" \
    "$API_BASE/v1/sessions")
SESSIONS_CODE=$(echo "$SESSIONS_RESPONSE" | tail -n1)

if [ "$SESSIONS_CODE" = "200" ] || [ "$SESSIONS_CODE" = "401" ]; then
    echo "✅ Sessions endpoint reachable (code: $SESSIONS_CODE)"
else
    echo "❌ Sessions endpoint failed with code: $SESSIONS_CODE"
fi
echo ""

# Test 5: SSE Streaming Readiness
echo "5️⃣ Testing SSE Streaming Endpoint..."
SSE_TEST=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer test-api-key" \
    -d '{"messages":[{"role":"user","content":"test"}],"stream":false}' \
    "$API_BASE/v1/chat/completions")

if [ "$SSE_TEST" = "200" ] || [ "$SSE_TEST" = "401" ]; then
    echo "✅ SSE endpoint reachable (code: $SSE_TEST)"
else
    echo "❌ SSE endpoint failed with code: $SSE_TEST"
fi
echo ""

# Summary
echo "==========================================="
echo "📊 API Connectivity Test Summary"
echo "- Base URL: $API_BASE"
echo "- Health: $([ "$HEALTH_CODE" = "200" ] && echo "✅" || echo "❌")"
echo "- Models: $([ "$MODELS_CODE" = "200" ] && echo "✅" || echo "❌")"
echo "- CORS: $(echo "$CORS_RESPONSE" | grep -q "Access-Control-Allow-Origin" && echo "✅" || echo "❌")"
echo "- Sessions: $([ "$SESSIONS_CODE" = "200" ] || [ "$SESSIONS_CODE" = "401" ] && echo "✅" || echo "❌")"
echo "- SSE: $([ "$SSE_TEST" = "200" ] || [ "$SSE_TEST" = "401" ] && echo "✅" || echo "❌")"
echo "==========================================="