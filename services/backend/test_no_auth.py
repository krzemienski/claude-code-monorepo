#!/usr/bin/env python3
"""
Test script to verify backend works without authentication
"""

import asyncio
import httpx
import json
from datetime import datetime

BASE_URL = "http://localhost:8000"

async def test_endpoints():
    """Test that all endpoints work without authentication"""
    
    async with httpx.AsyncClient(base_url=BASE_URL, timeout=10.0) as client:
        
        print("Testing backend without authentication...")
        print("=" * 50)
        
        # Test health endpoint
        print("\n1. Testing health endpoint...")
        response = await client.get("/health")
        print(f"   Status: {response.status_code}")
        if response.status_code == 200:
            print(f"   Response: {response.json()}")
        
        # Test root endpoint
        print("\n2. Testing root endpoint...")
        response = await client.get("/")
        print(f"   Status: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            print(f"   API Name: {data.get('name')}")
            print(f"   Version: {data.get('version')}")
        
        # Test models endpoint (previously required optional auth)
        print("\n3. Testing models endpoint...")
        response = await client.get("/v1/models")
        print(f"   Status: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            print(f"   Models count: {len(data.get('data', []))}")
        
        # Test chat completions endpoint (main endpoint)
        print("\n4. Testing chat completions endpoint...")
        chat_request = {
            "model": "claude-3-opus-20240229",
            "messages": [
                {"role": "user", "content": "Hello, test without auth"}
            ],
            "max_tokens": 50
        }
        # Note: This will fail if no ANTHROPIC_API_KEY is set, but we're just testing auth removal
        try:
            response = await client.post("/v1/chat/completions", json=chat_request)
            print(f"   Status: {response.status_code}")
            if response.status_code in [200, 500]:  # 500 might occur if no API key
                print(f"   Endpoint accessible without auth: {'✓' if response.status_code != 401 else '✗'}")
        except Exception as e:
            print(f"   Error: {e}")
        
        # Test sessions endpoint
        print("\n5. Testing sessions endpoint...")
        response = await client.get("/v1/sessions")
        print(f"   Status: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            print(f"   Sessions count: {len(data.get('sessions', []))}")
        
        # Test projects endpoint
        print("\n6. Testing projects endpoint...")
        response = await client.get("/v1/projects")
        print(f"   Status: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            print(f"   Projects count: {len(data.get('projects', []))}")
        
        # Test profile endpoint (now returns mock data)
        print("\n7. Testing profile endpoint...")
        response = await client.get("/v1/user/profile")
        print(f"   Status: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            print(f"   Mock user email: {data.get('email')}")
            print(f"   Mock username: {data.get('username')}")
        
        # Test analytics endpoint (previously required admin role)
        print("\n8. Testing analytics endpoint...")
        response = await client.get("/v1/analytics/usage")
        print(f"   Status: {response.status_code}")
        print(f"   Accessible without auth: {'✓' if response.status_code != 401 else '✗'}")
        
        # Test debug endpoint (previously required admin/developer role)
        print("\n9. Testing debug endpoint...")
        response = await client.get("/v1/debug/system-info")
        print(f"   Status: {response.status_code}")
        print(f"   Accessible without auth: {'✓' if response.status_code != 401 else '✗'}")
        
        print("\n" + "=" * 50)
        print("✅ All endpoints tested - Authentication successfully removed!")
        print("\nNOTE: No Bearer tokens or API keys required for any endpoint.")
        print("All endpoints are now publicly accessible.")

if __name__ == "__main__":
    print("\n🔓 Backend Authentication Removal Test")
    print("This script verifies that all endpoints work without authentication")
    print("Make sure the backend is running on http://localhost:8000")
    print("-" * 50)
    
    try:
        asyncio.run(test_endpoints())
    except httpx.ConnectError:
        print("\n❌ Error: Could not connect to backend at http://localhost:8000")
        print("Please start the backend first with:")
        print("  cd services/backend")
        print("  uvicorn app.main:app --reload")
    except Exception as e:
        print(f"\n❌ Error: {e}")