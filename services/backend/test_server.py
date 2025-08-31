#!/usr/bin/env python3
"""
Test script to validate backend server and generate OpenAPI spec
"""

import json
import sys
import os

# Add the backend directory to path
sys.path.insert(0, os.path.dirname(__file__))

# Set minimal environment variables for testing
os.environ["ANTHROPIC_API_KEY"] = "test-key-for-validation"
os.environ["SECRET_KEY"] = "test-secret-key-for-validation"
os.environ["DATABASE_URL"] = "sqlite+aiosqlite:///./test_validation.db"

try:
    from app.main import app
    print("✅ FastAPI app imported successfully")
    
    # Get OpenAPI schema
    openapi_schema = app.openapi()
    print(f"✅ OpenAPI schema generated with {len(openapi_schema.get('paths', {}))} endpoints")
    
    # Save OpenAPI spec
    with open("openapi.json", "w") as f:
        json.dump(openapi_schema, f, indent=2)
    print("✅ OpenAPI spec saved to openapi.json")
    
    # List all endpoints
    print("\n📍 Available endpoints:")
    for path, methods in openapi_schema.get("paths", {}).items():
        for method in methods:
            if method in ["get", "post", "put", "delete", "patch"]:
                print(f"  {method.upper():6} {path}")
    
    # Check for our missing endpoints
    print("\n🔍 Checking for missing endpoints:")
    required_endpoints = [
        ("/v1/auth/refresh", "post"),
        ("/v1/sessions/{session_id}/messages", "get"),
        ("/v1/sessions/{session_id}/tools", "get"),
        ("/v1/user/profile", "get"),
    ]
    
    for endpoint, method in required_endpoints:
        if endpoint in openapi_schema.get("paths", {}) and method in openapi_schema["paths"][endpoint]:
            print(f"  ✅ {method.upper()} {endpoint} - FOUND")
        else:
            print(f"  ❌ {method.upper()} {endpoint} - MISSING")
    
except Exception as e:
    print(f"❌ Error: {e}")
    import traceback
    traceback.print_exc()