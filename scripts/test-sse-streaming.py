#!/usr/bin/env python3
"""
Test SSE streaming endpoint for Claude Code API
Tests the /v1/chat/completions endpoint with streaming enabled
"""

import json
import requests
import sys
from datetime import datetime

# Configuration
API_BASE_URL = "http://localhost:8000"
ENDPOINT = f"{API_BASE_URL}/v1/chat/completions"

# Test payload
payload = {
    "model": "claude-3-5-haiku-20241022",
    "messages": [
        {
            "role": "user",
            "content": "Write a haiku about coding"
        }
    ],
    "stream": True,
    "max_tokens": 100
}

def test_sse_streaming():
    """Test SSE streaming with the chat completions endpoint"""
    print(f"[{datetime.now().isoformat()}] Testing SSE streaming endpoint...")
    print(f"URL: {ENDPOINT}")
    print(f"Payload: {json.dumps(payload, indent=2)}")
    print("-" * 50)
    
    try:
        # Make streaming request
        response = requests.post(
            ENDPOINT,
            json=payload,
            headers={
                "Content-Type": "application/json",
                "Accept": "text/event-stream"
            },
            stream=True
        )
        
        # Check response status
        if response.status_code != 200:
            print(f"❌ Error: HTTP {response.status_code}")
            print(f"Response: {response.text}")
            return False
        
        print("✅ Connection established, receiving stream...")
        print("-" * 50)
        
        # Process SSE stream
        full_content = ""
        chunk_count = 0
        
        for line in response.iter_lines():
            if line:
                line_str = line.decode('utf-8')
                
                # SSE format: "data: {json}"
                if line_str.startswith("data: "):
                    data_str = line_str[6:]  # Remove "data: " prefix
                    
                    # Check for end of stream
                    if data_str == "[DONE]":
                        print("\n" + "-" * 50)
                        print("✅ Stream completed successfully")
                        break
                    
                    try:
                        # Parse JSON chunk
                        chunk = json.loads(data_str)
                        chunk_count += 1
                        
                        # Extract content from chunk
                        if "choices" in chunk and len(chunk["choices"]) > 0:
                            delta = chunk["choices"][0].get("delta", {})
                            content = delta.get("content", "")
                            if content:
                                full_content += content
                                print(content, end="", flush=True)
                    
                    except json.JSONDecodeError as e:
                        print(f"\n⚠️  Warning: Failed to parse chunk {chunk_count}: {e}")
                        print(f"Raw data: {data_str}")
        
        print(f"\n\n📊 Statistics:")
        print(f"  - Chunks received: {chunk_count}")
        print(f"  - Total characters: {len(full_content)}")
        print(f"  - Full response: {full_content}")
        
        return True
        
    except requests.exceptions.ConnectionError as e:
        print(f"❌ Connection error: {e}")
        print("Make sure the backend is running on port 8000")
        return False
    
    except requests.exceptions.Timeout as e:
        print(f"❌ Request timeout: {e}")
        return False
    
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_non_streaming():
    """Test non-streaming mode for comparison"""
    print(f"\n[{datetime.now().isoformat()}] Testing non-streaming mode...")
    
    non_stream_payload = payload.copy()
    non_stream_payload["stream"] = False
    
    try:
        response = requests.post(
            ENDPOINT,
            json=non_stream_payload,
            headers={"Content-Type": "application/json"}
        )
        
        if response.status_code == 200:
            data = response.json()
            content = data["choices"][0]["message"]["content"]
            print(f"✅ Non-streaming response: {content}")
            return True
        else:
            print(f"❌ Error: HTTP {response.status_code}")
            print(f"Response: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

if __name__ == "__main__":
    print("=" * 50)
    print("SSE Streaming Test for Claude Code API")
    print("=" * 50)
    
    # Test both streaming and non-streaming
    streaming_ok = test_sse_streaming()
    non_streaming_ok = test_non_streaming()
    
    print("\n" + "=" * 50)
    print("Test Results:")
    print(f"  - SSE Streaming: {'✅ PASSED' if streaming_ok else '❌ FAILED'}")
    print(f"  - Non-streaming: {'✅ PASSED' if non_streaming_ok else '❌ FAILED'}")
    print("=" * 50)
    
    sys.exit(0 if (streaming_ok and non_streaming_ok) else 1)
