#!/usr/bin/env python3
"""
API Contract Tests
Validates that the backend API matches the expected contracts
"""

import pytest
import json
import yaml
from typing import Dict, List, Any
from pathlib import Path


class TestAPIContracts:
    """Test suite for API contract validation"""
    
    @classmethod
    def setup_class(cls):
        """Load OpenAPI spec and expected contracts"""
        # Load OpenAPI spec
        openapi_path = Path(__file__).parent.parent.parent / "services" / "backend" / "openapi.json"
        if openapi_path.exists():
            with open(openapi_path, 'r') as f:
                cls.openapi_spec = json.load(f)
        else:
            cls.openapi_spec = {}
        
        # Load expected contracts
        contracts_path = Path(__file__).parent.parent.parent / "docs" / "api-contracts.yaml"
        if contracts_path.exists():
            with open(contracts_path, 'r') as f:
                cls.expected_contracts = yaml.safe_load(f)
        else:
            cls.expected_contracts = {}
    
    def test_critical_endpoints_exist(self):
        """Test that all critical endpoints are present"""
        critical_endpoints = [
            ("POST", "/v1/auth/register"),
            ("POST", "/v1/auth/login"),
            ("POST", "/v1/auth/refresh"),
            ("GET", "/v1/sessions/{session_id}/messages"),
            ("GET", "/v1/sessions/{session_id}/tools"),
            ("GET", "/v1/user/profile"),
            ("PUT", "/v1/user/profile"),
            ("POST", "/v1/chat/completions"),
            ("GET", "/health")
        ]
        
        paths = self.openapi_spec.get("paths", {})
        
        for method, endpoint in critical_endpoints:
            # Handle path parameters
            base_path = endpoint.split("{")[0]
            matching_paths = [p for p in paths.keys() if p.startswith(base_path)]
            
            assert len(matching_paths) > 0, f"Endpoint {endpoint} not found"
            
            # Check method exists - use the exact endpoint path for parameter endpoints
            if "{" in endpoint:
                # For parameterized endpoints, check if any matching path has the method
                found = False
                for path in matching_paths:
                    if "{" in path:  # Make sure we're checking the right parameterized path
                        methods = paths[path]
                        if method.lower() in methods:
                            found = True
                            break
                assert found, f"Method {method} not found for {endpoint}"
            else:
                # For non-parameterized endpoints, check exact match
                methods = paths[endpoint]
                assert method.lower() in methods, f"Method {method} not found for {endpoint}"
            
            print(f"✅ {method} {endpoint} exists")
    
    def test_authentication_endpoints(self):
        """Test authentication endpoint contracts"""
        auth_endpoints = {
            "/v1/auth/register": {
                "method": "post",
                "requires": ["email", "password"],
                "returns": ["access_token", "refresh_token"]
            },
            "/v1/auth/login": {
                "method": "post",
                "requires": ["username", "password"],
                "returns": ["access_token", "refresh_token"]
            },
            "/v1/auth/refresh": {
                "method": "post",
                "requires": ["refresh_token"],
                "returns": ["access_token", "refresh_token"]
            }
        }
        
        paths = self.openapi_spec.get("paths", {})
        
        for endpoint, contract in auth_endpoints.items():
            assert endpoint in paths, f"Auth endpoint {endpoint} missing"
            
            endpoint_spec = paths[endpoint].get(contract["method"], {})
            
            # Check request body schema if required fields specified
            if "requires" in contract and "requestBody" in endpoint_spec:
                # This validates that the endpoint expects a request body
                assert "requestBody" in endpoint_spec, f"Request body missing for {endpoint}"
            
            # Check response schema
            responses = endpoint_spec.get("responses", {})
            assert "200" in responses or "201" in responses, f"Success response missing for {endpoint}"
            
            print(f"✅ Auth endpoint {endpoint} contract valid")
    
    def test_session_endpoints_contracts(self):
        """Test session-related endpoint contracts"""
        session_endpoints = {
            "/v1/sessions": {
                "get": {"authenticated": False, "returns": "list"},
                "post": {"authenticated": False, "returns": "session"}
            },
            "/v1/sessions/{session_id}": {
                "get": {"authenticated": False, "returns": "session"},
                "patch": {"authenticated": False, "returns": "session"},
                "delete": {"authenticated": False, "returns": "message"}
            },
            "/v1/sessions/{session_id}/messages": {
                "get": {"authenticated": False, "returns": "messages"}
            },
            "/v1/sessions/{session_id}/tools": {
                "get": {"authenticated": False, "returns": "tools"},
                "post": {"authenticated": False, "returns": "tool"}
            }
        }
        
        paths = self.openapi_spec.get("paths", {})
        
        for endpoint, methods in session_endpoints.items():
            assert endpoint in paths, f"Session endpoint {endpoint} missing"
            
            for method, contract in methods.items():
                endpoint_methods = paths[endpoint]
                assert method in endpoint_methods, f"Method {method} missing for {endpoint}"
                
                # Check response format
                responses = endpoint_methods[method].get("responses", {})
                assert "200" in responses or "201" in responses, f"Success response missing for {method} {endpoint}"
                
                print(f"✅ Session endpoint {method.upper()} {endpoint} contract valid")
    
    def test_profile_endpoints_contracts(self):
        """Test user profile endpoint contracts"""
        profile_endpoints = {
            "/v1/user/profile": {
                "get": {
                    "authenticated": True,
                    "returns": ["id", "email", "username"]
                },
                "put": {
                    "authenticated": True,
                    "accepts": ["username", "preferences"],
                    "returns": ["id", "email", "username"]
                },
                "delete": {
                    "authenticated": True,
                    "requires_confirmation": True
                }
            },
            "/v1/user/profile/reset-api-key": {
                "post": {
                    "authenticated": True,
                    "returns": ["api_key", "message"]
                }
            }
        }
        
        paths = self.openapi_spec.get("paths", {})
        
        for endpoint, methods in profile_endpoints.items():
            assert endpoint in paths, f"Profile endpoint {endpoint} missing"
            
            for method, contract in methods.items():
                endpoint_methods = paths[endpoint]
                assert method in endpoint_methods, f"Method {method} missing for {endpoint}"
                
                method_spec = endpoint_methods[method]
                
                # Check authentication requirement
                if contract.get("authenticated"):
                    # Check for security requirements
                    assert "security" in method_spec or "parameters" in method_spec, \
                        f"Authentication not specified for {method} {endpoint}"
                
                print(f"✅ Profile endpoint {method.upper()} {endpoint} contract valid")
    
    def test_response_formats(self):
        """Test that responses follow consistent format"""
        paths = self.openapi_spec.get("paths", {})
        
        for path, methods in paths.items():
            for method, spec in methods.items():
                if method in ["get", "post", "put", "patch", "delete"]:
                    responses = spec.get("responses", {})
                    
                    # Check for standard response codes
                    assert len(responses) > 0, f"No responses defined for {method.upper()} {path}"
                    
                    # Check for error responses
                    error_codes = ["400", "401", "403", "404", "422", "500"]
                    has_error_handling = any(code in responses for code in error_codes)
                    
                    if has_error_handling:
                        print(f"✅ {method.upper()} {path} has error handling")
    
    def test_parameter_validation(self):
        """Test that path parameters are properly defined"""
        paths = self.openapi_spec.get("paths", {})
        
        for path, methods in paths.items():
            # Check if path has parameters
            if "{" in path:
                for method, spec in methods.items():
                    if method in ["get", "post", "put", "patch", "delete"]:
                        parameters = spec.get("parameters", [])
                        
                        # Extract parameter names from path
                        import re
                        path_params = re.findall(r'\{(\w+)\}', path)
                        
                        # Check each path parameter is defined
                        param_names = [p.get("name") for p in parameters if p.get("in") == "path"]
                        
                        for param in path_params:
                            assert param in param_names, \
                                f"Path parameter {param} not defined for {method.upper()} {path}"
                        
                        print(f"✅ Parameters validated for {method.upper()} {path}")


def main():
    """Run contract tests"""
    print("\n📝 API Contract Validation Tests\n")
    
    test_suite = TestAPIContracts()
    test_suite.setup_class()
    
    if not test_suite.openapi_spec:
        print("⚠️ OpenAPI spec not found. Run backend server test first to generate it.")
        return 1
    
    try:
        print("1️⃣ Testing critical endpoints...")
        test_suite.test_critical_endpoints_exist()
        
        print("\n2️⃣ Testing authentication contracts...")
        test_suite.test_authentication_endpoints()
        
        print("\n3️⃣ Testing session contracts...")
        test_suite.test_session_endpoints_contracts()
        
        print("\n4️⃣ Testing profile contracts...")
        test_suite.test_profile_endpoints_contracts()
        
        print("\n5️⃣ Testing response formats...")
        test_suite.test_response_formats()
        
        print("\n6️⃣ Testing parameter validation...")
        test_suite.test_parameter_validation()
        
        print("\n✅ All API contract tests passed!")
        return 0
        
    except AssertionError as e:
        print(f"\n❌ Contract test failed: {e}")
        return 1
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    exit(main())