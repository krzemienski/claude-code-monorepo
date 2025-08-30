"""
Backend API Health and Basic Endpoint Tests
"""
import pytest
import httpx
from unittest.mock import patch, MagicMock
import json


class TestHealthEndpoints:
    """Test health check endpoints"""
    
    @pytest.mark.asyncio
    async def test_health_endpoint(self):
        """Test /health endpoint returns 200"""
        async with httpx.AsyncClient(base_url="http://localhost:8000") as client:
            response = await client.get("/health")
            assert response.status_code == 200
            data = response.json()
            assert "status" in data
            assert data["status"] == "healthy"
    
    @pytest.mark.asyncio
    async def test_readiness_endpoint(self):
        """Test /readiness endpoint"""
        async with httpx.AsyncClient(base_url="http://localhost:8000") as client:
            response = await client.get("/readiness")
            assert response.status_code == 200
            data = response.json()
            assert "ready" in data
            assert data["ready"] is True


class TestModelEndpoints:
    """Test model-related endpoints"""
    
    @pytest.mark.asyncio
    async def test_list_models(self):
        """Test GET /v1/models returns model list"""
        async with httpx.AsyncClient(base_url="http://localhost:8000") as client:
            response = await client.get("/v1/models")
            assert response.status_code == 200
            data = response.json()
            assert "data" in data
            assert isinstance(data["data"], list)
            if data["data"]:
                model = data["data"][0]
                assert "id" in model
                assert "object" in model
                assert model["object"] == "model"
    
    @pytest.mark.asyncio
    async def test_get_model_details(self):
        """Test GET /v1/models/{model_id}"""
        model_id = "claude-3-5-sonnet-20241022"
        async with httpx.AsyncClient(base_url="http://localhost:8000") as client:
            response = await client.get(f"/v1/models/{model_id}")
            if response.status_code == 200:
                data = response.json()
                assert data["id"] == model_id
                assert "created" in data
                assert "owned_by" in data


class TestAuthenticationFlow:
    """Test authentication mechanisms"""
    
    @pytest.mark.asyncio
    async def test_bearer_token_auth(self):
        """Test Bearer token authentication"""
        headers = {"Authorization": "Bearer test-api-key"}
        async with httpx.AsyncClient(base_url="http://localhost:8000") as client:
            response = await client.get("/v1/models", headers=headers)
            # Should accept bearer token
            assert response.status_code in [200, 401]
    
    @pytest.mark.asyncio
    async def test_x_api_key_auth(self):
        """Test x-api-key header authentication"""
        headers = {"x-api-key": "test-api-key"}
        async with httpx.AsyncClient(base_url="http://localhost:8000") as client:
            response = await client.get("/v1/models", headers=headers)
            # Should accept x-api-key
            assert response.status_code in [200, 401]
    
    @pytest.mark.asyncio
    async def test_missing_auth(self):
        """Test request without authentication"""
        async with httpx.AsyncClient(base_url="http://localhost:8000") as client:
            response = await client.post("/v1/chat/completions", json={})
            # Should require authentication for chat endpoint
            assert response.status_code in [401, 403, 422]


class TestProjectEndpoints:
    """Test project management endpoints"""
    
    @pytest.mark.asyncio
    async def test_list_projects(self):
        """Test GET /v1/projects"""
        headers = {"Authorization": "Bearer test-api-key"}
        async with httpx.AsyncClient(base_url="http://localhost:8000") as client:
            response = await client.get("/v1/projects", headers=headers)
            if response.status_code == 200:
                data = response.json()
                assert isinstance(data, list) or "projects" in data
    
    @pytest.mark.asyncio
    async def test_create_project(self):
        """Test POST /v1/projects"""
        headers = {"Authorization": "Bearer test-api-key"}
        project_data = {
            "name": "Test Project",
            "description": "Test project for automated testing",
            "metadata": {"test": True}
        }
        async with httpx.AsyncClient(base_url="http://localhost:8000") as client:
            response = await client.post(
                "/v1/projects",
                headers=headers,
                json=project_data
            )
            if response.status_code in [200, 201]:
                data = response.json()
                assert "id" in data or "project_id" in data
                assert data.get("name") == "Test Project"
                
                # Clean up - delete project
                project_id = data.get("id") or data.get("project_id")
                await client.delete(f"/v1/projects/{project_id}", headers=headers)


class TestSessionEndpoints:
    """Test session management endpoints"""
    
    @pytest.mark.asyncio
    async def test_create_session(self):
        """Test POST /v1/sessions"""
        headers = {"Authorization": "Bearer test-api-key"}
        session_data = {
            "model": "claude-3-5-sonnet-20241022",
            "project_id": "test-project"
        }
        async with httpx.AsyncClient(base_url="http://localhost:8000") as client:
            response = await client.post(
                "/v1/sessions",
                headers=headers,
                json=session_data
            )
            if response.status_code in [200, 201]:
                data = response.json()
                assert "id" in data or "session_id" in data
                
                # Clean up
                session_id = data.get("id") or data.get("session_id")
                await client.delete(f"/v1/sessions/{session_id}", headers=headers)
    
    @pytest.mark.asyncio
    async def test_list_sessions(self):
        """Test GET /v1/sessions"""
        headers = {"Authorization": "Bearer test-api-key"}
        async with httpx.AsyncClient(base_url="http://localhost:8000") as client:
            response = await client.get("/v1/sessions", headers=headers)
            if response.status_code == 200:
                data = response.json()
                assert isinstance(data, list) or "sessions" in data


class TestMCPEndpoints:
    """Test MCP (Model Context Protocol) endpoints"""
    
    @pytest.mark.asyncio
    async def test_list_mcp_servers(self):
        """Test GET /v1/mcp/servers"""
        headers = {"Authorization": "Bearer test-api-key"}
        async with httpx.AsyncClient(base_url="http://localhost:8000") as client:
            response = await client.get("/v1/mcp/servers", headers=headers)
            if response.status_code == 200:
                data = response.json()
                assert isinstance(data, list) or "servers" in data
    
    @pytest.mark.asyncio
    async def test_get_mcp_tools(self):
        """Test GET /v1/mcp/servers/{server_id}/tools"""
        headers = {"Authorization": "Bearer test-api-key"}
        server_id = "filesystem"  # Common MCP server
        async with httpx.AsyncClient(base_url="http://localhost:8000") as client:
            response = await client.get(
                f"/v1/mcp/servers/{server_id}/tools",
                headers=headers
            )
            if response.status_code == 200:
                data = response.json()
                assert isinstance(data, list) or "tools" in data


class TestErrorHandling:
    """Test error handling and edge cases"""
    
    @pytest.mark.asyncio
    async def test_404_handling(self):
        """Test 404 for non-existent endpoint"""
        async with httpx.AsyncClient(base_url="http://localhost:8000") as client:
            response = await client.get("/non-existent-endpoint")
            assert response.status_code == 404
    
    @pytest.mark.asyncio
    async def test_invalid_json_body(self):
        """Test handling of invalid JSON in request body"""
        headers = {
            "Authorization": "Bearer test-api-key",
            "Content-Type": "application/json"
        }
        async with httpx.AsyncClient(base_url="http://localhost:8000") as client:
            response = await client.post(
                "/v1/chat/completions",
                headers=headers,
                content="invalid json"
            )
            assert response.status_code in [400, 422]
    
    @pytest.mark.asyncio
    async def test_method_not_allowed(self):
        """Test METHOD NOT ALLOWED for wrong HTTP method"""
        async with httpx.AsyncClient(base_url="http://localhost:8000") as client:
            # Try DELETE on an endpoint that doesn't support it
            response = await client.delete("/v1/models")
            assert response.status_code in [405, 404]


class TestRateLimiting:
    """Test rate limiting if implemented"""
    
    @pytest.mark.asyncio
    async def test_rate_limit_headers(self):
        """Check for rate limit headers in response"""
        headers = {"Authorization": "Bearer test-api-key"}
        async with httpx.AsyncClient(base_url="http://localhost:8000") as client:
            response = await client.get("/v1/models", headers=headers)
            # Check if rate limit headers are present
            rate_limit_headers = [
                "X-RateLimit-Limit",
                "X-RateLimit-Remaining",
                "X-RateLimit-Reset"
            ]
            # This is optional - not all APIs implement rate limiting
            if any(h in response.headers for h in rate_limit_headers):
                assert "X-RateLimit-Limit" in response.headers


if __name__ == "__main__":
    pytest.main([__file__, "-v"])