#!/bin/bash

echo "Testing SSE streaming endpoint..."
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer test-key" \
  -d '{
    "model": "claude-3-5-sonnet-20241022",
    "messages": [
      {"role": "user", "content": "Hello, can you help me?"}
    ],
    "stream": true,
    "temperature": 0.7,
    "max_tokens": 100
  }' \
  --no-buffer