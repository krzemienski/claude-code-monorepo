"""
Chat completions endpoint - OpenAI-compatible chat API
"""

import json
import asyncio
import time
import uuid
from typing import List, Optional, Dict, Any, AsyncGenerator
from datetime import datetime

from fastapi import APIRouter, HTTPException, Depends, Request
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

import anthropic
from anthropic import AsyncAnthropic

from app.core.config import settings
from app.api.deps import get_optional_user
from app.db.session import get_db

router = APIRouter()

# Initialize Anthropic client (lazy initialization to avoid startup issues)
anthropic_client = None

def get_anthropic_client():
    """Get or create Anthropic client"""
    global anthropic_client
    if anthropic_client is None:
        anthropic_client = AsyncAnthropic(api_key=settings.ANTHROPIC_API_KEY or "mock-key")
    return anthropic_client


class ChatMessage(BaseModel):
    """Chat message model"""
    role: str = Field(..., description="Role of the message sender")
    content: str = Field(..., description="Content of the message")
    name: Optional[str] = Field(None, description="Optional name of the sender")


class ChatCompletionRequest(BaseModel):
    """OpenAI-compatible chat completion request"""
    model: str = Field(default=settings.ANTHROPIC_MODEL)
    messages: List[ChatMessage]
    max_tokens: Optional[int] = Field(default=4096)
    temperature: Optional[float] = Field(default=1.0, ge=0.0, le=2.0)
    top_p: Optional[float] = Field(default=1.0)
    n: Optional[int] = Field(default=1)
    stream: Optional[bool] = Field(default=False)
    stop: Optional[List[str]] = Field(default=None)
    presence_penalty: Optional[float] = Field(default=0.0)
    frequency_penalty: Optional[float] = Field(default=0.0)
    user: Optional[str] = Field(default=None)


class ChatCompletionChoice(BaseModel):
    """Chat completion choice"""
    index: int
    message: ChatMessage
    finish_reason: str


class ChatCompletionUsage(BaseModel):
    """Token usage information"""
    prompt_tokens: int
    completion_tokens: int
    total_tokens: int


class ChatCompletionResponse(BaseModel):
    """OpenAI-compatible chat completion response"""
    id: str
    object: str = "chat.completion"
    created: int
    model: str
    choices: List[ChatCompletionChoice]
    usage: ChatCompletionUsage


def convert_to_anthropic_messages(messages: List[ChatMessage]) -> tuple[Optional[str], List[Dict]]:
    """
    Convert OpenAI-style messages to Anthropic format
    Returns (system_prompt, messages)
    """
    system_prompt = None
    anthropic_messages = []
    
    for msg in messages:
        if msg.role == "system":
            system_prompt = msg.content
        elif msg.role == "user":
            anthropic_messages.append({
                "role": "user",
                "content": msg.content
            })
        elif msg.role == "assistant":
            anthropic_messages.append({
                "role": "assistant",
                "content": msg.content
            })
    
    # Ensure conversation starts with user message
    if anthropic_messages and anthropic_messages[0]["role"] != "user":
        anthropic_messages.insert(0, {
            "role": "user",
            "content": "Continue the conversation."
        })
    
    return system_prompt, anthropic_messages


async def stream_chat_completion(
    request: ChatCompletionRequest,
    request_id: str
) -> AsyncGenerator[str, None]:
    """Stream chat completion responses"""
    
    system_prompt, messages = convert_to_anthropic_messages(request.messages)
    
    try:
        # Create streaming response from Anthropic
        client = get_anthropic_client()
        stream = await client.messages.create(
            model=request.model,
            messages=messages,
            system=system_prompt,
            max_tokens=request.max_tokens,
            temperature=request.temperature,
            stream=True
        )
        
        # Stream the response in SSE format
        async for chunk in stream:
            if chunk.type == "content_block_delta":
                delta = {
                    "id": request_id,
                    "object": "chat.completion.chunk",
                    "created": int(time.time()),
                    "model": request.model,
                    "choices": [{
                        "index": 0,
                        "delta": {
                            "content": chunk.delta.text
                        },
                        "finish_reason": None
                    }]
                }
                yield f"data: {json.dumps(delta)}\n\n"
        
        # Send final chunk
        final_chunk = {
            "id": request_id,
            "object": "chat.completion.chunk",
            "created": int(time.time()),
            "model": request.model,
            "choices": [{
                "index": 0,
                "delta": {},
                "finish_reason": "stop"
            }]
        }
        yield f"data: {json.dumps(final_chunk)}\n\n"
        yield "data: [DONE]\n\n"
        
    except Exception as e:
        error_chunk = {
            "error": {
                "message": str(e),
                "type": "api_error",
                "code": "internal_error"
            }
        }
        yield f"data: {json.dumps(error_chunk)}\n\n"


@router.post("/completions", response_model=ChatCompletionResponse)
async def create_chat_completion(
    request: ChatCompletionRequest,
    db: AsyncSession = Depends(get_db),
    user: Optional[Dict] = Depends(get_optional_user)
):
    """
    Create a chat completion (OpenAI-compatible endpoint).
    
    This endpoint is fully compatible with OpenAI's chat completion API,
    allowing drop-in replacement for existing OpenAI integrations.
    """
    
    request_id = f"chatcmpl-{uuid.uuid4().hex[:8]}"
    
    # Handle streaming response
    if request.stream:
        return StreamingResponse(
            stream_chat_completion(request, request_id),
            media_type="text/event-stream"
        )
    
    # Convert messages to Anthropic format
    system_prompt, messages = convert_to_anthropic_messages(request.messages)
    
    try:
        # Create non-streaming response from Anthropic
        client = get_anthropic_client()
        response = await client.messages.create(
            model=request.model,
            messages=messages,
            system=system_prompt,
            max_tokens=request.max_tokens,
            temperature=request.temperature
        )
        
        # Format response in OpenAI style
        return ChatCompletionResponse(
            id=request_id,
            created=int(time.time()),
            model=request.model,
            choices=[
                ChatCompletionChoice(
                    index=0,
                    message=ChatMessage(
                        role="assistant",
                        content=response.content[0].text if response.content else ""
                    ),
                    finish_reason="stop"
                )
            ],
            usage=ChatCompletionUsage(
                prompt_tokens=response.usage.input_tokens if hasattr(response, 'usage') else 0,
                completion_tokens=response.usage.output_tokens if hasattr(response, 'usage') else 0,
                total_tokens=(response.usage.input_tokens + response.usage.output_tokens) if hasattr(response, 'usage') else 0
            )
        )
        
    except anthropic.APIError as e:
        raise HTTPException(status_code=502, detail=f"Anthropic API error: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")