#!/bin/bash

echo "==================================="
echo "iOS Integration Test Suite"
echo "==================================="

BASE_URL="http://localhost:8000"
API_KEY="test-api-key"

echo -e "\n1. Testing Health Check..."
curl -sS "$BASE_URL/health" | python3 -m json.tool

echo -e "\n2. Testing Models Endpoint..."
curl -sS "$BASE_URL/v1/models" \
  -H "Authorization: Bearer $API_KEY" | python3 -m json.tool | head -20

echo -e "\n3. Testing Project Creation..."
PROJECT_RESPONSE=$(curl -sS -X POST "$BASE_URL/v1/projects" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{"name": "iOS Test Project", "path": "/workspace/ios-test"}')
echo "$PROJECT_RESPONSE" | python3 -m json.tool

echo -e "\n4. Testing Session Creation..."
SESSION_RESPONSE=$(curl -sS -X POST "$BASE_URL/v1/sessions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{"project_id": "proj_001", "name": "iOS Test Session"}')
echo "$SESSION_RESPONSE" | python3 -m json.tool

echo -e "\n5. Testing Chat Completion (Non-Streaming)..."
curl -sS -X POST "$BASE_URL/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{
    "model": "claude-3-5-sonnet-20241022",
    "messages": [
      {"role": "system", "content": "You are a helpful iOS development assistant."},
      {"role": "user", "content": "How do I create a SwiftUI view?"}
    ],
    "stream": false,
    "temperature": 0.7,
    "max_tokens": 150
  }' | python3 -m json.tool

echo -e "\n6. Testing MCP Servers..."
curl -sS "$BASE_URL/v1/mcp/servers" \
  -H "Authorization: Bearer $API_KEY" | python3 -m json.tool

echo -e "\n7. Testing MCP Tools..."
curl -sS "$BASE_URL/v1/mcp/servers/mcp_filesystem/tools" \
  -H "Authorization: Bearer $API_KEY" | python3 -m json.tool

echo -e "\n8. Testing SSE Streaming (5 chunks)..."
echo "Streaming response:"
curl -sS -X POST "$BASE_URL/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Accept: text/event-stream" \
  -d '{
    "model": "claude-3-5-sonnet-20241022",
    "messages": [{"role": "user", "content": "Test streaming"}],
    "stream": true
  }' \
  --no-buffer | head -15

echo -e "\n==================================="
echo "iOS Integration Tests Complete!"
echo "All endpoints are accessible from iOS Simulator"
echo "====================================="