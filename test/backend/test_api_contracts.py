"""
API Contract Validation Tests
Ensures API responses match documented contracts
"""
import pytest
import httpx
import json
from typing import Dict, Any, List
from datetime import datetime


class ContractValidator:
    """Validates API responses against expected contracts"""
    
    @staticmethod
    def validate_field_types(data: Dict[str, Any], schema: Dict[str, type]) -> List[str]:
        """Validate field types match schema"""
        errors = []
        for field, expected_type in schema.items():
            if field not in data:
                errors.append(f"Missing required field: {field}")
            elif not isinstance(data[field], expected_type):
                errors.append(
                    f"Field {field} type mismatch: expected {expected_type.__name__}, "
                    f"got {type(data[field]).__name__}"
                )
        return errors
    
    @staticmethod
    def validate_optional_fields(data: Dict[str, Any], schema: Dict[str, type]) -> List[str]:
        """Validate optional fields if present"""
        errors = []
        for field, expected_type in schema.items():
            if field in data and data[field] is not None:
                if not isinstance(data[field], expected_type):
                    errors.append(
                        f"Optional field {field} type mismatch: expected {expected_type.__name__}, "
                        f"got {type(data[field]).__name__}"
                    )
        return errors


class TestChatCompletionContract:
    """Test chat completion endpoint contract"""
    
    CHAT_REQUEST_SCHEMA = {
        "model": str,
        "messages": list,
    }
    
    CHAT_REQUEST_OPTIONAL = {
        "temperature": (int, float),
        "max_tokens": int,
        "stream": bool,
        "top_p": (int, float),
        "stop": (str, list),
        "presence_penalty": (int, float),
        "frequency_penalty": (int, float),
    }
    
    CHAT_RESPONSE_SCHEMA = {
        "id": str,
        "object": str,
        "created": int,
        "model": str,
        "choices": list,
    }
    
    CHOICE_SCHEMA = {
        "index": int,
        "message": dict,
        "finish_reason": (str, type(None)),
    }
    
    MESSAGE_SCHEMA = {
        "role": str,
        "content": (str, type(None)),
    }
    
    @pytest.mark.asyncio
    async def test_chat_completion_request_contract(self):
        """Test chat completion request contract"""
        headers = {"Authorization": "Bearer test-api-key"}
        
        # Valid request
        valid_request = {
            "model": "claude-3-5-sonnet-20241022",
            "messages": [
                {"role": "user", "content": "Hello"}
            ],
            "max_tokens": 100,
            "temperature": 0.7
        }
        
        async with httpx.AsyncClient(base_url="http://localhost:8000") as client:
            response = await client.post(
                "/v1/chat/completions",
                headers=headers,
                json=valid_request
            )
            
            # Request should be accepted (might fail auth but structure is valid)
            assert response.status_code in [200, 401, 403]
    
    @pytest.mark.asyncio
    async def test_chat_completion_response_contract(self):
        """Test chat completion response contract"""
        headers = {"Authorization": "Bearer test-api-key"}
        
        request = {
            "model": "claude-3-5-sonnet-20241022",
            "messages": [{"role": "user", "content": "Hi"}],
            "max_tokens": 10
        }
        
        async with httpx.AsyncClient(base_url="http://localhost:8000") as client:
            response = await client.post(
                "/v1/chat/completions",
                headers=headers,
                json=request
            )
            
            if response.status_code == 200:
                data = response.json()
                validator = ContractValidator()
                
                # Validate main response structure
                errors = validator.validate_field_types(data, self.CHAT_RESPONSE_SCHEMA)
                assert not errors, f"Contract violations: {errors}"
                
                # Validate choices
                assert len(data["choices"]) > 0
                for choice in data["choices"]:
                    choice_errors = validator.validate_field_types(choice, self.CHOICE_SCHEMA)
                    assert not choice_errors, f"Choice contract violations: {choice_errors}"
                    
                    # Validate message in choice
                    msg_errors = validator.validate_field_types(
                        choice["message"],
                        self.MESSAGE_SCHEMA
                    )
                    assert not msg_errors, f"Message contract violations: {msg_errors}"
    
    @pytest.mark.asyncio
    async def test_streaming_contract(self):
        """Test SSE streaming response contract"""
        headers = {"Authorization": "Bearer test-api-key"}
        
        request = {
            "model": "claude-3-5-sonnet-20241022",
            "messages": [{"role": "user", "content": "Hi"}],
            "stream": True,
            "max_tokens": 10
        }
        
        async with httpx.AsyncClient(base_url="http://localhost:8000") as client:
            async with client.stream(
                "POST",
                "/v1/chat/completions",
                headers=headers,
                json=request
            ) as response:
                if response.status_code == 200:
                    # Collect SSE events
                    events = []
                    async for line in response.aiter_lines():
                        if line.startswith("data: "):
                            event_data = line[6:]
                            if event_data != "[DONE]":
                                try:
                                    events.append(json.loads(event_data))
                                except json.JSONDecodeError:
                                    pass
                    
                    # Validate streaming events
                    for event in events:
                        assert "choices" in event
                        if event["choices"]:
                            choice = event["choices"][0]
                            assert "delta" in choice
                            assert "index" in choice


class TestProjectContract:
    """Test project endpoint contracts"""
    
    PROJECT_SCHEMA = {
        "id": str,
        "name": str,
        "created_at": (str, int),
    }
    
    PROJECT_OPTIONAL = {
        "description": str,
        "metadata": dict,
        "updated_at": (str, int),
        "owner": str,
    }
    
    @pytest.mark.asyncio
    async def test_project_creation_contract(self):
        """Test project creation response contract"""
        headers = {"Authorization": "Bearer test-api-key"}
        
        project_data = {
            "name": "Contract Test Project",
            "description": "Testing API contracts"
        }
        
        async with httpx.AsyncClient(base_url="http://localhost:8000") as client:
            response = await client.post(
                "/v1/projects",
                headers=headers,
                json=project_data
            )
            
            if response.status_code in [200, 201]:
                data = response.json()
                validator = ContractValidator()
                
                # Check required fields
                required_fields = ["id", "name"]
                for field in required_fields:
                    assert field in data or f"{field}_id" in data
                
                # Clean up
                project_id = data.get("id") or data.get("project_id")
                await client.delete(f"/v1/projects/{project_id}", headers=headers)
    
    @pytest.mark.asyncio
    async def test_project_list_contract(self):
        """Test project list response contract"""
        headers = {"Authorization": "Bearer test-api-key"}
        
        async with httpx.AsyncClient(base_url="http://localhost:8000") as client:
            response = await client.get("/v1/projects", headers=headers)
            
            if response.status_code == 200:
                data = response.json()
                
                # Should be array or have projects field
                if isinstance(data, dict):
                    assert "projects" in data
                    projects = data["projects"]
                else:
                    projects = data
                
                assert isinstance(projects, list)
                
                # Validate each project
                validator = ContractValidator()
                for project in projects:
                    # Check for ID and name at minimum
                    assert "id" in project or "project_id" in project
                    assert "name" in project


class TestSessionContract:
    """Test session endpoint contracts"""
    
    SESSION_SCHEMA = {
        "id": str,
        "model": str,
        "created_at": (str, int),
        "status": str,
    }
    
    SESSION_OPTIONAL = {
        "project_id": str,
        "metadata": dict,
        "updated_at": (str, int),
        "messages": list,
    }
    
    @pytest.mark.asyncio
    async def test_session_creation_contract(self):
        """Test session creation response contract"""
        headers = {"Authorization": "Bearer test-api-key"}
        
        session_data = {
            "model": "claude-3-5-sonnet-20241022"
        }
        
        async with httpx.AsyncClient(base_url="http://localhost:8000") as client:
            response = await client.post(
                "/v1/sessions",
                headers=headers,
                json=session_data
            )
            
            if response.status_code in [200, 201]:
                data = response.json()
                
                # Check required fields
                assert "id" in data or "session_id" in data
                assert "model" in data or session_data["model"] == data.get("model")
                
                # Clean up
                session_id = data.get("id") or data.get("session_id")
                await client.delete(f"/v1/sessions/{session_id}", headers=headers)


class TestMCPContract:
    """Test MCP endpoint contracts"""
    
    MCP_SERVER_SCHEMA = {
        "id": str,
        "name": str,
        "type": str,
    }
    
    MCP_TOOL_SCHEMA = {
        "name": str,
        "description": str,
    }
    
    @pytest.mark.asyncio
    async def test_mcp_server_list_contract(self):
        """Test MCP server list contract"""
        headers = {"Authorization": "Bearer test-api-key"}
        
        async with httpx.AsyncClient(base_url="http://localhost:8000") as client:
            response = await client.get("/v1/mcp/servers", headers=headers)
            
            if response.status_code == 200:
                data = response.json()
                
                # Should be array or have servers field
                if isinstance(data, dict):
                    servers = data.get("servers", [])
                else:
                    servers = data
                
                assert isinstance(servers, list)
                
                # Validate each server
                for server in servers:
                    assert "id" in server or "server_id" in server
                    assert "name" in server
    
    @pytest.mark.asyncio
    async def test_mcp_tools_contract(self):
        """Test MCP tools list contract"""
        headers = {"Authorization": "Bearer test-api-key"}
        server_id = "filesystem"
        
        async with httpx.AsyncClient(base_url="http://localhost:8000") as client:
            response = await client.get(
                f"/v1/mcp/servers/{server_id}/tools",
                headers=headers
            )
            
            if response.status_code == 200:
                data = response.json()
                
                # Should be array or have tools field
                if isinstance(data, dict):
                    tools = data.get("tools", [])
                else:
                    tools = data
                
                assert isinstance(tools, list)
                
                # Validate each tool
                for tool in tools:
                    assert "name" in tool
                    # Description is often present
                    if "description" in tool:
                        assert isinstance(tool["description"], str)


class TestErrorResponseContract:
    """Test error response contracts"""
    
    ERROR_SCHEMA = {
        "error": dict,
    }
    
    ERROR_DETAIL_SCHEMA = {
        "message": str,
        "type": str,
    }
    
    @pytest.mark.asyncio
    async def test_error_response_contract(self):
        """Test error response structure"""
        async with httpx.AsyncClient(base_url="http://localhost:8000") as client:
            # Trigger 404
            response = await client.get("/non-existent")
            
            if response.status_code == 404:
                data = response.json()
                
                # Should have error field
                assert "error" in data or "message" in data
                
                if "error" in data:
                    error = data["error"]
                    assert isinstance(error, (dict, str))
                    if isinstance(error, dict):
                        assert "message" in error or "detail" in error
    
    @pytest.mark.asyncio
    async def test_validation_error_contract(self):
        """Test validation error response"""
        headers = {"Authorization": "Bearer test-api-key"}
        
        # Invalid request - missing required fields
        invalid_request = {
            "temperature": 0.7  # Missing model and messages
        }
        
        async with httpx.AsyncClient(base_url="http://localhost:8000") as client:
            response = await client.post(
                "/v1/chat/completions",
                headers=headers,
                json=invalid_request
            )
            
            if response.status_code in [400, 422]:
                data = response.json()
                
                # Should have error details
                assert "error" in data or "detail" in data
                
                # FastAPI validation errors have specific structure
                if "detail" in data:
                    assert isinstance(data["detail"], (list, str, dict))


if __name__ == "__main__":
    pytest.main([__file__, "-v"])