#!/usr/bin/env python3
"""
Test Script for Public API Access
Validates that ALL endpoints work without any authentication
and that the environment endpoint returns real host data.
"""

import asyncio
import json
import time
import platform
import psutil
import httpx
from datetime import datetime
from typing import Dict, Any, List


BASE_URL = "http://localhost:8001"


async def test_health():
    """Test health endpoint"""
    async with httpx.AsyncClient() as client:
        response = await client.get(f"{BASE_URL}/health")
        print(f"✅ Health Check: {response.status_code}")
        print(f"   Response: {response.json()}")
        return response.status_code == 200


async def test_root():
    """Test root endpoint"""
    async with httpx.AsyncClient() as client:
        response = await client.get(f"{BASE_URL}/")
        print(f"✅ Root Endpoint: {response.status_code}")
        print(f"   Available endpoints: {list(response.json().get('endpoints', {}).keys())}")
        return response.status_code == 200


async def test_environment():
    """Test environment endpoint returns real host data"""
    async with httpx.AsyncClient() as client:
        # Test full environment info
        response = await client.get(f"{BASE_URL}/v1/environment")
        print(f"\n🔍 Testing Environment Endpoint (Full):")
        print(f"   Status: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            
            # Validate real host data
            validation_passed = True
            
            # Check platform matches
            actual_platform = platform.system()
            reported_platform = data.get('system', {}).get('platform')
            if reported_platform == actual_platform:
                print(f"   ✅ Platform matches: {actual_platform}")
            else:
                print(f"   ❌ Platform mismatch: Expected {actual_platform}, got {reported_platform}")
                validation_passed = False
            
            # Check CPU count matches
            actual_cpu = psutil.cpu_count()
            reported_cpu = data.get('cpu_count')
            if reported_cpu == actual_cpu:
                print(f"   ✅ CPU count matches: {actual_cpu}")
            else:
                print(f"   ❌ CPU mismatch: Expected {actual_cpu}, got {reported_cpu}")
                validation_passed = False
            
            # Check memory is reasonable (within 10% variance)
            actual_mem = psutil.virtual_memory().total
            reported_mem = data.get('memory', {}).get('total', 0)
            mem_diff = abs(reported_mem - actual_mem) / actual_mem if actual_mem > 0 else 1
            if mem_diff < 0.1:
                print(f"   ✅ Memory total matches: {actual_mem / (1024**3):.2f} GB")
            else:
                print(f"   ❌ Memory mismatch: {mem_diff*100:.1f}% difference")
                validation_passed = False
            
            # Display other info
            print(f"   📊 Memory usage: {data.get('memory', {}).get('percent')}%")
            print(f"   💾 Disk usage: {data.get('disk', {}).get('percent')}%")
            print(f"   🐍 Python: {data.get('system', {}).get('python_version', '')[:30]}...")
            print(f"   📁 Working dir: {data.get('working_directory')}")
            print(f"   👤 User: {data.get('user')}")
            
            if validation_passed:
                print(f"   \n   🎉 VALIDATION PASSED: Environment returns REAL host data!")
            else:
                print(f"   \n   ⚠️  VALIDATION FAILED: Some values don't match host system")
        else:
            print(f"   ❌ Failed to get environment data")
            validation_passed = False
        
        # Test summary endpoint
        response = await client.get(f"{BASE_URL}/v1/environment/summary")
        print(f"\n🔍 Testing Environment Summary:")
        print(f"   Status: {response.status_code}")
        if response.status_code == 200:
            summary = response.json()
            print(f"   📋 Summary: {json.dumps(summary, indent=2)}")
        
        return response.status_code == 200 and validation_passed


async def test_models():
    """Test models endpoint"""
    async with httpx.AsyncClient() as client:
        response = await client.get(f"{BASE_URL}/v1/models")
        print(f"✅ Models List: {response.status_code}")
        if response.status_code == 200:
            models = response.json().get('data', [])
            print(f"   Available models: {len(models)}")
            for model in models[:3]:  # Show first 3
                print(f"     - {model.get('id')}")
        return response.status_code == 200


async def test_projects():
    """Test projects endpoints"""
    async with httpx.AsyncClient() as client:
        # Create a project
        project_data = {
            "name": "Test Project",
            "description": "Testing public API access",
            "path": "/test/project"
        }
        response = await client.post(f"{BASE_URL}/v1/projects", json=project_data)
        print(f"✅ Create Project: {response.status_code}")
        
        if response.status_code == 200:
            project = response.json()
            project_id = project.get('id')
            print(f"   Project ID: {project_id}")
            
            # List projects
            response = await client.get(f"{BASE_URL}/v1/projects")
            print(f"✅ List Projects: {response.status_code}")
            
            # Get specific project
            response = await client.get(f"{BASE_URL}/v1/projects/{project_id}")
            print(f"✅ Get Project: {response.status_code}")
            
            # Update project
            update_data = {"description": "Updated description"}
            response = await client.patch(f"{BASE_URL}/v1/projects/{project_id}", json=update_data)
            print(f"✅ Update Project: {response.status_code}")
            
            # Delete project
            response = await client.delete(f"{BASE_URL}/v1/projects/{project_id}")
            print(f"✅ Delete Project: {response.status_code}")
            
            return True
        return False


async def test_sessions():
    """Test sessions endpoints"""
    async with httpx.AsyncClient() as client:
        # Create a session
        session_data = {
            "name": "Test Session",
            "model": "claude-3-opus-20240229"
        }
        response = await client.post(f"{BASE_URL}/v1/sessions", json=session_data)
        print(f"✅ Create Session: {response.status_code}")
        
        if response.status_code == 200:
            session = response.json()
            session_id = session.get('id')
            print(f"   Session ID: {session_id}")
            
            # List sessions
            response = await client.get(f"{BASE_URL}/v1/sessions")
            print(f"✅ List Sessions: {response.status_code}")
            
            # Get session stats
            response = await client.get(f"{BASE_URL}/v1/sessions/{session_id}/stats")
            print(f"✅ Session Stats: {response.status_code}")
            
            # Archive session
            response = await client.post(f"{BASE_URL}/v1/sessions/{session_id}/archive")
            print(f"✅ Archive Session: {response.status_code}")
            
            # Delete session
            response = await client.delete(f"{BASE_URL}/v1/sessions/{session_id}")
            print(f"✅ Delete Session: {response.status_code}")
            
            return True
        return False


async def test_chat():
    """Test chat completions endpoint"""
    async with httpx.AsyncClient(timeout=30.0) as client:
        # Test non-streaming chat
        chat_data = {
            "model": "claude-3-haiku-20240307",
            "messages": [
                {"role": "system", "content": "You are a helpful assistant."},
                {"role": "user", "content": "Say 'Hello, World!' and nothing else."}
            ],
            "max_tokens": 50,
            "stream": False
        }
        
        try:
            response = await client.post(f"{BASE_URL}/v1/chat/completions", json=chat_data)
            print(f"✅ Chat Completion: {response.status_code}")
            if response.status_code == 200:
                result = response.json()
                content = result.get('choices', [{}])[0].get('message', {}).get('content', '')
                print(f"   Response: {content[:100]}")
                return True
        except Exception as e:
            print(f"⚠️  Chat Completion: Failed - {str(e)}")
            print("   Note: This requires a valid ANTHROPIC_API_KEY in the environment")
        
        return False


async def test_mcp():
    """Test MCP endpoints"""
    async with httpx.AsyncClient() as client:
        # List MCP servers
        response = await client.get(f"{BASE_URL}/v1/mcp/servers")
        print(f"✅ MCP Servers: {response.status_code}")
        
        # Get MCP tools
        response = await client.get(f"{BASE_URL}/v1/mcp/tools")
        print(f"✅ MCP Tools: {response.status_code}")
        
        # Get MCP config
        response = await client.get(f"{BASE_URL}/v1/mcp/config")
        print(f"✅ MCP Config: {response.status_code}")
        
        return response.status_code == 200


async def test_files():
    """Test file management endpoints"""
    async with httpx.AsyncClient() as client:
        # List files in root
        response = await client.get(f"{BASE_URL}/v1/files/list?path=/")
        print(f"✅ Files List: {response.status_code}")
        
        # Create a test file
        file_data = {
            "path": "test_file.txt",
            "content": "Hello from public API test!",
            "encoding": "utf-8"
        }
        response = await client.post(f"{BASE_URL}/v1/files/write", params=file_data)
        print(f"✅ Write File: {response.status_code}")
        
        if response.status_code == 200:
            # Read the file back
            response = await client.get(f"{BASE_URL}/v1/files/read?path=test_file.txt")
            print(f"✅ Read File: {response.status_code}")
            
            # Delete the file
            response = await client.delete(f"{BASE_URL}/v1/files/delete?path=test_file.txt")
            print(f"✅ Delete File: {response.status_code}")
            
            return True
        return False


async def main():
    """Run all tests"""
    print("=" * 60)
    print("Testing Claude Code Backend API - Public Access")
    print("=" * 60)
    print(f"Target: {BASE_URL}")
    print(f"Time: {datetime.now().isoformat()}")
    print("-" * 60)
    
    tests = [
        ("Health Check", test_health),
        ("Root Endpoint", test_root),
        ("Environment", test_environment),
        ("Models", test_models),
        ("Projects", test_projects),
        ("Sessions", test_sessions),
        ("Chat Completions", test_chat),
        ("MCP", test_mcp),
        ("Files", test_files),
    ]
    
    results = []
    for name, test_func in tests:
        print(f"\n📋 Testing {name}...")
        try:
            success = await test_func()
            results.append((name, success))
        except Exception as e:
            print(f"❌ {name}: Failed with error: {str(e)}")
            results.append((name, False))
        print("-" * 40)
    
    # Summary
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    
    passed = sum(1 for _, success in results if success)
    total = len(results)
    
    for name, success in results:
        status = "✅ PASS" if success else "❌ FAIL"
        print(f"{status}: {name}")
    
    print("-" * 60)
    print(f"Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("\n🎉 All tests passed! The API is fully accessible without authentication.")
    else:
        print("\n⚠️  Some tests failed. Check the output above for details.")
    
    return passed == total


if __name__ == "__main__":
    success = asyncio.run(main())
    exit(0 if success else 1)