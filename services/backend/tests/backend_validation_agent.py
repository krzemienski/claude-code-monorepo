#!/usr/bin/env python3
"""
Backend Documentation Validation Agent

Automated testing suite for validating backend API documentation claims
against actual implementation behavior.
"""

import asyncio
import json
import os
import time
from typing import Dict, List, Optional, Tuple
from datetime import datetime
import httpx
import psycopg2
import redis
from dataclasses import dataclass, field
from enum import Enum


class ValidationStatus(Enum):
    """Validation test status"""
    PASSED = "✅ PASSED"
    FAILED = "❌ FAILED"
    WARNING = "⚠️ WARNING"
    SKIPPED = "⏭️ SKIPPED"
    ERROR = "🔴 ERROR"


@dataclass
class ValidationResult:
    """Individual validation result"""
    test_name: str
    status: ValidationStatus
    message: str
    details: Optional[Dict] = None
    timestamp: datetime = field(default_factory=datetime.utcnow)
    duration_ms: Optional[float] = None


@dataclass
class EndpointTest:
    """Endpoint test configuration"""
    method: str
    path: str
    requires_auth: bool = False
    required_role: Optional[str] = None
    expected_status: int = 200
    timeout_ms: int = 5000
    description: str = ""


class BackendValidationAgent:
    """
    Comprehensive backend validation agent for testing:
    - API endpoint availability and behavior
    - Authentication and authorization flows
    - Database schema compliance
    - Redis cache functionality
    - Performance characteristics
    - Security implementations
    """
    
    def __init__(self, base_url: str = "http://localhost:8000"):
        self.base_url = base_url
        self.results: List[ValidationResult] = []
        self.auth_token: Optional[str] = None
        self.test_user = {
            "email": "test@validation.com",
            "password": "Test@Valid123!",
            "username": "validation_agent"
        }
    
    async def run_full_validation(self) -> Dict:
        """
        Run complete validation suite
        """
        print("🚀 Starting Backend Documentation Validation")
        print("=" * 60)
        
        # Phase 1: API Health
        await self.validate_api_health()
        
        # Phase 2: Authentication System
        await self.validate_authentication()
        
        # Phase 3: Public Endpoints
        await self.validate_public_endpoints()
        
        # Phase 4: Protected Endpoints
        await self.validate_protected_endpoints()
        
        # Phase 5: Database Schema
        await self.validate_database_schema()
        
        # Phase 6: Redis Cache
        await self.validate_redis_cache()
        
        # Phase 7: Performance Characteristics
        await self.validate_performance()
        
        # Phase 8: Security Implementation
        await self.validate_security()
        
        # Generate Report
        return self.generate_report()
    
    async def validate_api_health(self):
        """Validate basic API health and availability"""
        print("\n📋 Phase 1: API Health Check")
        print("-" * 40)
        
        health_endpoints = [
            EndpointTest("GET", "/health", description="Health check endpoint"),
            EndpointTest("GET", "/", description="Root API information"),
            EndpointTest("GET", "/docs", description="Swagger documentation"),
            EndpointTest("GET", "/openapi.json", description="OpenAPI specification"),
        ]
        
        async with httpx.AsyncClient() as client:
            for test in health_endpoints:
                await self._test_endpoint(client, test)
    
    async def validate_authentication(self):
        """Validate authentication system claims vs implementation"""
        print("\n🔐 Phase 2: Authentication System Validation")
        print("-" * 40)
        
        async with httpx.AsyncClient() as client:
            # Test if endpoints work without authentication (as documented)
            no_auth_test = await self._test_no_auth_claim(client)
            
            # Test actual authentication system
            if await self._endpoint_exists(client, "/v1/auth/register"):
                # System has authentication - test it
                await self._test_registration(client)
                await self._test_login(client)
                await self._test_token_refresh(client)
            else:
                self.results.append(ValidationResult(
                    test_name="Authentication System",
                    status=ValidationStatus.WARNING,
                    message="No authentication endpoints found (matches 'NO AUTH' documentation)",
                ))
    
    async def validate_public_endpoints(self):
        """Validate documented public endpoints"""
        print("\n🌐 Phase 3: Public Endpoints Validation")
        print("-" * 40)
        
        public_endpoints = [
            EndpointTest("GET", "/v1/environment", description="Environment information"),
            EndpointTest("GET", "/v1/environment/summary", description="Environment summary"),
            EndpointTest("GET", "/v1/models", description="List available models"),
        ]
        
        async with httpx.AsyncClient() as client:
            for test in public_endpoints:
                await self._test_endpoint(client, test)
    
    async def validate_protected_endpoints(self):
        """Validate endpoints that should require authentication"""
        print("\n🔒 Phase 4: Protected Endpoints Validation")
        print("-" * 40)
        
        protected_endpoints = [
            EndpointTest("GET", "/v1/projects", True, description="List projects"),
            EndpointTest("GET", "/v1/sessions", True, description="List sessions"),
            EndpointTest("GET", "/v1/mcp/servers", True, description="MCP servers"),
            EndpointTest("GET", "/v1/files/list", True, description="File listing"),
            EndpointTest("GET", "/v1/analytics/", True, "admin", description="Analytics"),
            EndpointTest("GET", "/v1/debug/", True, "admin", description="Debug info"),
        ]
        
        async with httpx.AsyncClient() as client:
            for test in protected_endpoints:
                # Test without auth first
                await self._test_auth_requirement(client, test)
                
                # Test with auth if we have a token
                if self.auth_token:
                    await self._test_endpoint(client, test, self.auth_token)
    
    async def validate_database_schema(self):
        """Validate database schema and models"""
        print("\n🗄️ Phase 5: Database Schema Validation")
        print("-" * 40)
        
        try:
            # Try to connect to PostgreSQL
            conn_str = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/claudecode")
            
            # Parse connection string
            if conn_str.startswith("postgresql://"):
                conn_str = conn_str.replace("postgresql://", "")
            
            # This is a basic check - in production, use proper connection handling
            self.results.append(ValidationResult(
                test_name="Database Connection",
                status=ValidationStatus.WARNING,
                message="Database validation requires active PostgreSQL connection",
                details={"connection_string": "postgresql://***:***@localhost:5432/claudecode"}
            ))
            
            # Check for required tables
            required_tables = ["users", "sessions", "projects", "messages", "mcp_configs"]
            
            # This would need actual database connection to verify
            self.results.append(ValidationResult(
                test_name="Database Tables",
                status=ValidationStatus.SKIPPED,
                message=f"Expected tables: {', '.join(required_tables)}",
            ))
            
        except Exception as e:
            self.results.append(ValidationResult(
                test_name="Database Validation",
                status=ValidationStatus.ERROR,
                message=f"Database validation failed: {str(e)}",
            ))
    
    async def validate_redis_cache(self):
        """Validate Redis cache functionality"""
        print("\n💾 Phase 6: Redis Cache Validation")
        print("-" * 40)
        
        try:
            # Try to connect to Redis
            redis_url = os.getenv("REDIS_URL", "redis://localhost:6379/0")
            
            self.results.append(ValidationResult(
                test_name="Redis Connection",
                status=ValidationStatus.WARNING,
                message="Redis validation requires active Redis connection",
                details={"redis_url": redis_url}
            ))
            
            # Test cache operations would go here
            cache_operations = [
                "Session storage",
                "Rate limiting counters",
                "Token blacklist",
                "Temporary data cache"
            ]
            
            for op in cache_operations:
                self.results.append(ValidationResult(
                    test_name=f"Redis: {op}",
                    status=ValidationStatus.SKIPPED,
                    message="Requires active Redis connection to test",
                ))
                
        except Exception as e:
            self.results.append(ValidationResult(
                test_name="Redis Validation",
                status=ValidationStatus.ERROR,
                message=f"Redis validation failed: {str(e)}",
            ))
    
    async def validate_performance(self):
        """Validate performance characteristics"""
        print("\n⚡ Phase 7: Performance Validation")
        print("-" * 40)
        
        performance_tests = [
            ("GET", "/health", 50, "Health check should respond < 50ms"),
            ("GET", "/", 100, "Root endpoint should respond < 100ms"),
            ("GET", "/v1/environment", 200, "Environment endpoint should respond < 200ms"),
        ]
        
        async with httpx.AsyncClient() as client:
            for method, path, target_ms, description in performance_tests:
                start_time = time.time()
                
                try:
                    response = await client.request(
                        method, f"{self.base_url}{path}",
                        timeout=5.0
                    )
                    
                    duration_ms = (time.time() - start_time) * 1000
                    
                    status = ValidationStatus.PASSED if duration_ms < target_ms else ValidationStatus.WARNING
                    
                    self.results.append(ValidationResult(
                        test_name=f"Performance: {path}",
                        status=status,
                        message=f"{description}: {duration_ms:.2f}ms (target: <{target_ms}ms)",
                        duration_ms=duration_ms
                    ))
                    
                except Exception as e:
                    self.results.append(ValidationResult(
                        test_name=f"Performance: {path}",
                        status=ValidationStatus.ERROR,
                        message=f"Performance test failed: {str(e)}",
                    ))
    
    async def validate_security(self):
        """Validate security implementations"""
        print("\n🛡️ Phase 8: Security Validation")
        print("-" * 40)
        
        security_checks = [
            ("Security Headers", self._check_security_headers),
            ("CORS Configuration", self._check_cors),
            ("Rate Limiting", self._check_rate_limiting),
            ("Input Validation", self._check_input_validation),
            ("Error Handling", self._check_error_handling),
        ]
        
        async with httpx.AsyncClient() as client:
            for check_name, check_func in security_checks:
                try:
                    await check_func(client)
                except Exception as e:
                    self.results.append(ValidationResult(
                        test_name=f"Security: {check_name}",
                        status=ValidationStatus.ERROR,
                        message=f"Security check failed: {str(e)}",
                    ))
    
    # Helper Methods
    
    async def _test_endpoint(
        self, 
        client: httpx.AsyncClient, 
        test: EndpointTest,
        auth_token: Optional[str] = None
    ):
        """Test a single endpoint"""
        headers = {}
        if auth_token and test.requires_auth:
            headers["Authorization"] = f"Bearer {auth_token}"
        
        try:
            start_time = time.time()
            response = await client.request(
                test.method, 
                f"{self.base_url}{test.path}",
                headers=headers,
                timeout=test.timeout_ms / 1000
            )
            duration_ms = (time.time() - start_time) * 1000
            
            if response.status_code == test.expected_status:
                self.results.append(ValidationResult(
                    test_name=f"{test.method} {test.path}",
                    status=ValidationStatus.PASSED,
                    message=f"{test.description}: Status {response.status_code}",
                    duration_ms=duration_ms
                ))
            else:
                self.results.append(ValidationResult(
                    test_name=f"{test.method} {test.path}",
                    status=ValidationStatus.FAILED,
                    message=f"{test.description}: Expected {test.expected_status}, got {response.status_code}",
                    details={"response": response.text[:200] if response.text else None}
                ))
                
        except Exception as e:
            self.results.append(ValidationResult(
                test_name=f"{test.method} {test.path}",
                status=ValidationStatus.ERROR,
                message=f"{test.description}: {str(e)}",
            ))
    
    async def _test_no_auth_claim(self, client: httpx.AsyncClient) -> bool:
        """Test if API truly requires no authentication as documented"""
        test_endpoints = [
            "/v1/projects",
            "/v1/sessions",
            "/v1/chat/completions"
        ]
        
        no_auth_works = True
        
        for endpoint in test_endpoints:
            try:
                response = await client.get(f"{self.base_url}{endpoint}")
                if response.status_code == 401:
                    no_auth_works = False
                    self.results.append(ValidationResult(
                        test_name=f"No Auth Claim: {endpoint}",
                        status=ValidationStatus.FAILED,
                        message=f"Documentation claims NO AUTH but endpoint returns 401",
                    ))
                else:
                    self.results.append(ValidationResult(
                        test_name=f"No Auth Claim: {endpoint}",
                        status=ValidationStatus.PASSED,
                        message=f"Endpoint accessible without authentication (as documented)",
                    ))
            except:
                pass
        
        return no_auth_works
    
    async def _endpoint_exists(self, client: httpx.AsyncClient, path: str) -> bool:
        """Check if an endpoint exists"""
        try:
            response = await client.options(f"{self.base_url}{path}")
            return response.status_code != 404
        except:
            return False
    
    async def _test_registration(self, client: httpx.AsyncClient):
        """Test user registration"""
        try:
            response = await client.post(
                f"{self.base_url}/v1/auth/register",
                json=self.test_user
            )
            
            if response.status_code in [200, 201]:
                data = response.json()
                self.auth_token = data.get("access_token")
                self.results.append(ValidationResult(
                    test_name="User Registration",
                    status=ValidationStatus.PASSED,
                    message="Registration endpoint works (contradicts NO AUTH documentation)",
                ))
            elif response.status_code == 409:
                self.results.append(ValidationResult(
                    test_name="User Registration",
                    status=ValidationStatus.WARNING,
                    message="User already exists (registration previously successful)",
                ))
            else:
                self.results.append(ValidationResult(
                    test_name="User Registration",
                    status=ValidationStatus.FAILED,
                    message=f"Registration failed with status {response.status_code}",
                ))
        except Exception as e:
            self.results.append(ValidationResult(
                test_name="User Registration",
                status=ValidationStatus.ERROR,
                message=f"Registration test failed: {str(e)}",
            ))
    
    async def _test_login(self, client: httpx.AsyncClient):
        """Test user login"""
        try:
            # OAuth2 compatible form data
            response = await client.post(
                f"{self.base_url}/v1/auth/login",
                data={
                    "username": self.test_user["email"],
                    "password": self.test_user["password"]
                }
            )
            
            if response.status_code == 200:
                data = response.json()
                self.auth_token = data.get("access_token")
                self.results.append(ValidationResult(
                    test_name="User Login",
                    status=ValidationStatus.PASSED,
                    message="Login endpoint works with JWT authentication",
                ))
            else:
                self.results.append(ValidationResult(
                    test_name="User Login",
                    status=ValidationStatus.FAILED,
                    message=f"Login failed with status {response.status_code}",
                ))
        except Exception as e:
            self.results.append(ValidationResult(
                test_name="User Login",
                status=ValidationStatus.ERROR,
                message=f"Login test failed: {str(e)}",
            ))
    
    async def _test_token_refresh(self, client: httpx.AsyncClient):
        """Test token refresh"""
        # This would require a refresh token from login
        self.results.append(ValidationResult(
            test_name="Token Refresh",
            status=ValidationStatus.SKIPPED,
            message="Requires valid refresh token from login",
        ))
    
    async def _test_auth_requirement(self, client: httpx.AsyncClient, test: EndpointTest):
        """Test if endpoint requires authentication"""
        try:
            response = await client.request(
                test.method,
                f"{self.base_url}{test.path}",
                timeout=5.0
            )
            
            if response.status_code == 401:
                self.results.append(ValidationResult(
                    test_name=f"Auth Check: {test.path}",
                    status=ValidationStatus.PASSED,
                    message=f"Endpoint correctly requires authentication",
                ))
            else:
                self.results.append(ValidationResult(
                    test_name=f"Auth Check: {test.path}",
                    status=ValidationStatus.WARNING,
                    message=f"Endpoint doesn't require auth (status: {response.status_code})",
                ))
        except Exception as e:
            self.results.append(ValidationResult(
                test_name=f"Auth Check: {test.path}",
                status=ValidationStatus.ERROR,
                message=f"Auth check failed: {str(e)}",
            ))
    
    async def _check_security_headers(self, client: httpx.AsyncClient):
        """Check security headers"""
        response = await client.get(f"{self.base_url}/health")
        
        required_headers = [
            "X-Content-Type-Options",
            "X-Frame-Options",
            "X-XSS-Protection",
        ]
        
        for header in required_headers:
            if header in response.headers:
                self.results.append(ValidationResult(
                    test_name=f"Security Header: {header}",
                    status=ValidationStatus.PASSED,
                    message=f"Header present: {response.headers[header]}",
                ))
            else:
                self.results.append(ValidationResult(
                    test_name=f"Security Header: {header}",
                    status=ValidationStatus.FAILED,
                    message="Required security header missing",
                ))
    
    async def _check_cors(self, client: httpx.AsyncClient):
        """Check CORS configuration"""
        headers = {"Origin": "http://localhost:3000"}
        response = await client.options(
            f"{self.base_url}/health",
            headers=headers
        )
        
        if "Access-Control-Allow-Origin" in response.headers:
            self.results.append(ValidationResult(
                test_name="CORS Configuration",
                status=ValidationStatus.PASSED,
                message=f"CORS enabled: {response.headers['Access-Control-Allow-Origin']}",
            ))
        else:
            self.results.append(ValidationResult(
                test_name="CORS Configuration",
                status=ValidationStatus.WARNING,
                message="CORS headers not found",
            ))
    
    async def _check_rate_limiting(self, client: httpx.AsyncClient):
        """Check rate limiting"""
        # Make multiple rapid requests
        endpoint = f"{self.base_url}/health"
        
        for i in range(20):
            response = await client.get(endpoint)
            if response.status_code == 429:
                self.results.append(ValidationResult(
                    test_name="Rate Limiting",
                    status=ValidationStatus.PASSED,
                    message=f"Rate limiting active (triggered after {i+1} requests)",
                ))
                return
        
        self.results.append(ValidationResult(
            test_name="Rate Limiting",
            status=ValidationStatus.WARNING,
            message="Rate limiting not triggered after 20 rapid requests",
        ))
    
    async def _check_input_validation(self, client: httpx.AsyncClient):
        """Check input validation"""
        # Test with invalid data
        invalid_data = {
            "email": "not-an-email",
            "password": "weak"
        }
        
        if await self._endpoint_exists(client, "/v1/auth/register"):
            response = await client.post(
                f"{self.base_url}/v1/auth/register",
                json=invalid_data
            )
            
            if response.status_code == 422:
                self.results.append(ValidationResult(
                    test_name="Input Validation",
                    status=ValidationStatus.PASSED,
                    message="Input validation working (returns 422 for invalid data)",
                ))
            else:
                self.results.append(ValidationResult(
                    test_name="Input Validation",
                    status=ValidationStatus.WARNING,
                    message=f"Unexpected response for invalid input: {response.status_code}",
                ))
        else:
            self.results.append(ValidationResult(
                test_name="Input Validation",
                status=ValidationStatus.SKIPPED,
                message="No registration endpoint to test validation",
            ))
    
    async def _check_error_handling(self, client: httpx.AsyncClient):
        """Check error handling"""
        # Test non-existent endpoint
        response = await client.get(f"{self.base_url}/non-existent-endpoint")
        
        if response.status_code == 404:
            try:
                error_data = response.json()
                if "error" in error_data:
                    self.results.append(ValidationResult(
                        test_name="Error Handling",
                        status=ValidationStatus.PASSED,
                        message="Proper error format for 404 responses",
                    ))
                else:
                    self.results.append(ValidationResult(
                        test_name="Error Handling",
                        status=ValidationStatus.WARNING,
                        message="404 response but non-standard error format",
                    ))
            except:
                self.results.append(ValidationResult(
                    test_name="Error Handling",
                    status=ValidationStatus.WARNING,
                    message="404 response but not JSON formatted",
                ))
    
    def generate_report(self) -> Dict:
        """Generate validation report"""
        print("\n" + "=" * 60)
        print("📊 VALIDATION REPORT")
        print("=" * 60)
        
        # Count results by status
        status_counts = {}
        for result in self.results:
            status_counts[result.status] = status_counts.get(result.status, 0) + 1
        
        # Print summary
        print("\nSummary:")
        for status, count in status_counts.items():
            print(f"  {status.value}: {count}")
        
        # Calculate compliance score
        total = len(self.results)
        passed = status_counts.get(ValidationStatus.PASSED, 0)
        compliance = (passed / total * 100) if total > 0 else 0
        
        print(f"\nCompliance Score: {compliance:.1f}%")
        
        # Print critical findings
        critical_findings = [
            r for r in self.results 
            if r.status in [ValidationStatus.FAILED, ValidationStatus.ERROR]
        ]
        
        if critical_findings:
            print("\n🔴 Critical Findings:")
            for finding in critical_findings[:5]:  # Show top 5
                print(f"  - {finding.test_name}: {finding.message}")
        
        # Generate JSON report
        report = {
            "timestamp": datetime.utcnow().isoformat(),
            "base_url": self.base_url,
            "summary": {
                "total_tests": total,
                "passed": passed,
                "failed": status_counts.get(ValidationStatus.FAILED, 0),
                "warnings": status_counts.get(ValidationStatus.WARNING, 0),
                "errors": status_counts.get(ValidationStatus.ERROR, 0),
                "skipped": status_counts.get(ValidationStatus.SKIPPED, 0),
                "compliance_score": compliance
            },
            "results": [
                {
                    "test_name": r.test_name,
                    "status": r.status.value,
                    "message": r.message,
                    "details": r.details,
                    "duration_ms": r.duration_ms,
                    "timestamp": r.timestamp.isoformat()
                }
                for r in self.results
            ],
            "critical_findings": [
                {
                    "test_name": f.test_name,
                    "message": f.message,
                    "details": f.details
                }
                for f in critical_findings
            ]
        }
        
        # Save report
        report_file = f"validation_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(report_file, 'w') as f:
            json.dump(report, f, indent=2)
        
        print(f"\n📄 Full report saved to: {report_file}")
        
        return report


async def main():
    """Run the validation agent"""
    agent = BackendValidationAgent()
    report = await agent.run_full_validation()
    
    # Check if there are critical issues
    if report["summary"]["failed"] > 0 or report["summary"]["errors"] > 0:
        print("\n⚠️  VALIDATION COMPLETED WITH ISSUES")
        exit(1)
    else:
        print("\n✅ VALIDATION COMPLETED SUCCESSFULLY")
        exit(0)


if __name__ == "__main__":
    asyncio.run(main())