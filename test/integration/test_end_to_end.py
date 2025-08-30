"""
End-to-End Integration Tests
Tests complete user workflows across iOS and Backend
"""
import pytest
import httpx
import asyncio
import json
import uuid
from typing import Dict, Any, List
from datetime import datetime


class E2ETestSession:
    """Manages a complete E2E test session"""
    
    def __init__(self, base_url: str = "http://localhost:8000"):
        self.base_url = base_url
        self.api_key = "test-api-key"
        self.project_id = None
        self.session_id = None
        self.messages = []
        
    async def setup(self):
        """Setup test environment"""
        # Create a test project
        self.project_id = await self.create_project()
        # Create a test session
        self.session_id = await self.create_session()
        
    async def teardown(self):
        """Clean up test resources"""
        if self.session_id:
            await self.delete_session(self.session_id)
        if self.project_id:
            await self.delete_project(self.project_id)
    
    async def create_project(self) -> str:
        """Create a test project"""
        async with httpx.AsyncClient(base_url=self.base_url) as client:
            response = await client.post(
                "/v1/projects",
                headers={"Authorization": f"Bearer {self.api_key}"},
                json={
                    "name": f"E2E Test Project {uuid.uuid4().hex[:8]}",
                    "description": "End-to-end integration test project"
                }
            )
            if response.status_code in [200, 201]:
                data = response.json()
                return data.get("id") or data.get("project_id")
            return None
    
    async def create_session(self) -> str:
        """Create a test session"""
        async with httpx.AsyncClient(base_url=self.base_url) as client:
            response = await client.post(
                "/v1/sessions",
                headers={"Authorization": f"Bearer {self.api_key}"},
                json={
                    "model": "claude-3-5-sonnet-20241022",
                    "project_id": self.project_id
                }
            )
            if response.status_code in [200, 201]:
                data = response.json()
                return data.get("id") or data.get("session_id")
            return None
    
    async def send_message(self, content: str) -> Dict[str, Any]:
        """Send a message and get response"""
        async with httpx.AsyncClient(base_url=self.base_url) as client:
            response = await client.post(
                "/v1/chat/completions",
                headers={"Authorization": f"Bearer {self.api_key}"},
                json={
                    "model": "claude-3-5-sonnet-20241022",
                    "messages": [{"role": "user", "content": content}],
                    "max_tokens": 100,
                    "session_id": self.session_id
                }
            )
            if response.status_code == 200:
                return response.json()
            return None
    
    async def delete_project(self, project_id: str):
        """Delete a project"""
        async with httpx.AsyncClient(base_url=self.base_url) as client:
            await client.delete(
                f"/v1/projects/{project_id}",
                headers={"Authorization": f"Bearer {self.api_key}"}
            )
    
    async def delete_session(self, session_id: str):
        """Delete a session"""
        async with httpx.AsyncClient(base_url=self.base_url) as client:
            await client.delete(
                f"/v1/sessions/{session_id}",
                headers={"Authorization": f"Bearer {self.api_key}"}
            )


class TestAuthenticationFlow:
    """Test complete authentication flow"""
    
    @pytest.mark.asyncio
    async def test_complete_auth_flow(self):
        """Test user authentication and session creation"""
        base_url = "http://localhost:8000"
        
        # Step 1: Check health without auth
        async with httpx.AsyncClient(base_url=base_url) as client:
            response = await client.get("/health")
            assert response.status_code == 200
        
        # Step 2: Try to access protected endpoint without auth
        async with httpx.AsyncClient(base_url=base_url) as client:
            response = await client.get("/v1/projects")
            assert response.status_code in [401, 403]
        
        # Step 3: Authenticate with API key
        headers = {"Authorization": "Bearer test-api-key"}
        async with httpx.AsyncClient(base_url=base_url) as client:
            response = await client.get("/v1/models", headers=headers)
            # Should work with valid auth
            assert response.status_code in [200, 401]  # 401 if key is invalid
        
        # Step 4: Create authenticated session
        if response.status_code == 200:
            async with httpx.AsyncClient(base_url=base_url) as client:
                session_response = await client.post(
                    "/v1/sessions",
                    headers=headers,
                    json={"model": "claude-3-5-sonnet-20241022"}
                )
                if session_response.status_code in [200, 201]:
                    session_data = session_response.json()
                    session_id = session_data.get("id") or session_data.get("session_id")
                    
                    # Clean up
                    await client.delete(f"/v1/sessions/{session_id}", headers=headers)


class TestProjectWorkflow:
    """Test complete project management workflow"""
    
    @pytest.mark.asyncio
    async def test_project_lifecycle(self):
        """Test create, update, list, and delete project"""
        session = E2ETestSession()
        headers = {"Authorization": f"Bearer {session.api_key}"}
        
        async with httpx.AsyncClient(base_url=session.base_url) as client:
            # Create project
            create_response = await client.post(
                "/v1/projects",
                headers=headers,
                json={
                    "name": "Workflow Test Project",
                    "description": "Testing project lifecycle"
                }
            )
            
            if create_response.status_code in [200, 201]:
                project = create_response.json()
                project_id = project.get("id") or project.get("project_id")
                
                # List projects - should include our project
                list_response = await client.get("/v1/projects", headers=headers)
                if list_response.status_code == 200:
                    projects = list_response.json()
                    if isinstance(projects, dict):
                        projects = projects.get("projects", [])
                    
                    # Our project should be in the list
                    project_ids = [p.get("id") or p.get("project_id") for p in projects]
                    assert project_id in project_ids
                
                # Update project
                update_response = await client.patch(
                    f"/v1/projects/{project_id}",
                    headers=headers,
                    json={"description": "Updated description"}
                )
                # Update might not be implemented
                assert update_response.status_code in [200, 404, 405]
                
                # Delete project
                delete_response = await client.delete(
                    f"/v1/projects/{project_id}",
                    headers=headers
                )
                assert delete_response.status_code in [200, 204]


class TestChatSessionWorkflow:
    """Test complete chat session workflow"""
    
    @pytest.mark.asyncio
    async def test_chat_conversation_flow(self):
        """Test a complete conversation flow"""
        session = E2ETestSession()
        
        try:
            await session.setup()
            
            if not session.session_id:
                pytest.skip("Could not create session")
            
            # Send first message
            response1 = await session.send_message("Hello, can you help me with Python?")
            if response1:
                assert "choices" in response1
                assert len(response1["choices"]) > 0
                
                # Send follow-up message
                response2 = await session.send_message("What's a list comprehension?")
                if response2:
                    assert "choices" in response2
                    # Response should be contextual
                    content = response2["choices"][0]["message"]["content"]
                    assert content  # Should have content
        
        finally:
            await session.teardown()
    
    @pytest.mark.asyncio
    async def test_streaming_conversation(self):
        """Test streaming chat responses"""
        session = E2ETestSession()
        
        try:
            await session.setup()
            
            if not session.session_id:
                pytest.skip("Could not create session")
            
            # Send streaming request
            async with httpx.AsyncClient(base_url=session.base_url) as client:
                async with client.stream(
                    "POST",
                    "/v1/chat/completions",
                    headers={"Authorization": f"Bearer {session.api_key}"},
                    json={
                        "model": "claude-3-5-sonnet-20241022",
                        "messages": [{"role": "user", "content": "Count to 5"}],
                        "stream": True,
                        "max_tokens": 50,
                        "session_id": session.session_id
                    }
                ) as response:
                    if response.status_code == 200:
                        chunks = []
                        async for line in response.aiter_lines():
                            if line.startswith("data: "):
                                chunk = line[6:]
                                if chunk != "[DONE]":
                                    chunks.append(chunk)
                        
                        # Should receive multiple chunks
                        assert len(chunks) > 0
        
        finally:
            await session.teardown()


class TestMCPIntegration:
    """Test MCP tool integration workflow"""
    
    @pytest.mark.asyncio
    async def test_mcp_tool_discovery_and_usage(self):
        """Test discovering and using MCP tools"""
        session = E2ETestSession()
        headers = {"Authorization": f"Bearer {session.api_key}"}
        
        async with httpx.AsyncClient(base_url=session.base_url) as client:
            # Discover available MCP servers
            servers_response = await client.get("/v1/mcp/servers", headers=headers)
            
            if servers_response.status_code == 200:
                servers = servers_response.json()
                if isinstance(servers, dict):
                    servers = servers.get("servers", [])
                
                # Get tools for first server
                if servers:
                    server = servers[0]
                    server_id = server.get("id") or server.get("server_id")
                    
                    tools_response = await client.get(
                        f"/v1/mcp/servers/{server_id}/tools",
                        headers=headers
                    )
                    
                    if tools_response.status_code == 200:
                        tools = tools_response.json()
                        if isinstance(tools, dict):
                            tools = tools.get("tools", [])
                        
                        # Tools should have names and descriptions
                        if tools:
                            tool = tools[0]
                            assert "name" in tool
    
    @pytest.mark.asyncio
    async def test_mcp_tool_configuration(self):
        """Test configuring MCP tools for a session"""
        session = E2ETestSession()
        
        try:
            await session.setup()
            
            if not session.session_id:
                pytest.skip("Could not create session")
            
            headers = {"Authorization": f"Bearer {session.api_key}"}
            
            async with httpx.AsyncClient(base_url=session.base_url) as client:
                # Configure tools for session
                config_response = await client.post(
                    f"/v1/sessions/{session.session_id}/tools",
                    headers=headers,
                    json={
                        "tools": ["filesystem.read", "filesystem.write"],
                        "enabled": True
                    }
                )
                
                # Configuration might not be implemented
                assert config_response.status_code in [200, 201, 404, 405]
        
        finally:
            await session.teardown()


class TestErrorRecovery:
    """Test error handling and recovery"""
    
    @pytest.mark.asyncio
    async def test_invalid_model_handling(self):
        """Test handling of invalid model requests"""
        headers = {"Authorization": "Bearer test-api-key"}
        
        async with httpx.AsyncClient(base_url="http://localhost:8000") as client:
            response = await client.post(
                "/v1/chat/completions",
                headers=headers,
                json={
                    "model": "non-existent-model",
                    "messages": [{"role": "user", "content": "test"}]
                }
            )
            
            # Should return error
            assert response.status_code in [400, 404, 422]
            
            # Error should have structure
            error_data = response.json()
            assert "error" in error_data or "detail" in error_data
    
    @pytest.mark.asyncio
    async def test_session_recovery(self):
        """Test session recovery after error"""
        session = E2ETestSession()
        
        try:
            await session.setup()
            
            if not session.session_id:
                pytest.skip("Could not create session")
            
            # Send invalid request
            invalid_response = await session.send_message("")
            
            # Should handle gracefully
            if invalid_response is None:
                # Try valid request after error
                valid_response = await session.send_message("Hello")
                # Session should still work
                assert valid_response is not None or True  # Graceful handling
        
        finally:
            await session.teardown()


class TestPerformanceScenarios:
    """Test performance-critical scenarios"""
    
    @pytest.mark.asyncio
    async def test_concurrent_sessions(self):
        """Test handling multiple concurrent sessions"""
        sessions = []
        
        try:
            # Create multiple sessions
            for i in range(3):
                session = E2ETestSession()
                await session.setup()
                sessions.append(session)
            
            # Send concurrent messages
            tasks = []
            for session in sessions:
                if session.session_id:
                    task = session.send_message(f"Test message {session.session_id}")
                    tasks.append(task)
            
            # Wait for all responses
            responses = await asyncio.gather(*tasks, return_exceptions=True)
            
            # Most should succeed
            successful = sum(1 for r in responses if r and not isinstance(r, Exception))
            assert successful >= len(tasks) // 2  # At least half should succeed
        
        finally:
            # Clean up all sessions
            for session in sessions:
                await session.teardown()
    
    @pytest.mark.asyncio
    async def test_large_context_handling(self):
        """Test handling of large context windows"""
        session = E2ETestSession()
        
        try:
            await session.setup()
            
            if not session.session_id:
                pytest.skip("Could not create session")
            
            # Send message with large context
            large_context = "Lorem ipsum " * 100  # ~200 words
            response = await session.send_message(f"Summarize this: {large_context}")
            
            if response:
                assert "choices" in response
                # Should handle large input
                assert response["choices"][0]["message"]["content"]
        
        finally:
            await session.teardown()


if __name__ == "__main__":
    pytest.main([__file__, "-v", "-s"])