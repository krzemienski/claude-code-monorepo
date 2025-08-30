"""
Models endpoint - Lists available AI models
"""

from typing import List, Optional, Dict
from datetime import datetime

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from app.core.config import settings
from app.api.deps import get_optional_user

router = APIRouter()


class ModelPermission(BaseModel):
    """Model permission information"""
    id: str = Field(default="modelperm-default")
    object: str = Field(default="model_permission")
    created: int = Field(default_factory=lambda: int(datetime.now().timestamp()))
    allow_create_engine: bool = Field(default=False)
    allow_sampling: bool = Field(default=True)
    allow_logprobs: bool = Field(default=True)
    allow_search_indices: bool = Field(default=False)
    allow_view: bool = Field(default=True)
    allow_fine_tuning: bool = Field(default=False)
    organization: str = Field(default="*")
    group: Optional[str] = Field(default=None)
    is_blocking: bool = Field(default=False)


class Model(BaseModel):
    """Model information"""
    id: str
    object: str = Field(default="model")
    created: int = Field(default_factory=lambda: int(datetime.now().timestamp()))
    owned_by: str = Field(default="anthropic")
    permission: List[ModelPermission] = Field(default_factory=lambda: [ModelPermission()])
    root: str
    parent: Optional[str] = Field(default=None)


class ModelsResponse(BaseModel):
    """Models list response"""
    object: str = Field(default="list")
    data: List[Model]


# Available Claude models
AVAILABLE_MODELS = [
    {
        "id": "claude-3-opus-20240229",
        "root": "claude-3-opus-20240229",
        "owned_by": "anthropic"
    },
    {
        "id": "claude-3-sonnet-20240229",
        "root": "claude-3-sonnet-20240229",
        "owned_by": "anthropic"
    },
    {
        "id": "claude-3-haiku-20240307",
        "root": "claude-3-haiku-20240307",
        "owned_by": "anthropic"
    },
    {
        "id": "claude-3-5-sonnet-20241022",
        "root": "claude-3-5-sonnet-20241022",
        "owned_by": "anthropic"
    },
    {
        "id": "claude-2.1",
        "root": "claude-2.1",
        "owned_by": "anthropic"
    },
    {
        "id": "claude-2.0",
        "root": "claude-2.0",
        "owned_by": "anthropic"
    },
    {
        "id": "claude-instant-1.2",
        "root": "claude-instant-1.2",
        "owned_by": "anthropic"
    }
]


@router.get("", response_model=ModelsResponse)
async def list_models(
    user: Optional[Dict] = Depends(get_optional_user)
):
    """
    List available models (OpenAI-compatible endpoint).
    
    Returns a list of available Claude models in OpenAI's format.
    """
    
    models = [
        Model(
            id=model["id"],
            root=model["root"],
            owned_by=model["owned_by"]
        )
        for model in AVAILABLE_MODELS
    ]
    
    return ModelsResponse(data=models)


@router.get("/{model_id}", response_model=Model)
async def get_model(
    model_id: str,
    user: Optional[Dict] = Depends(get_optional_user)
):
    """
    Get information about a specific model.
    """
    
    for model_info in AVAILABLE_MODELS:
        if model_info["id"] == model_id:
            return Model(
                id=model_info["id"],
                root=model_info["root"],
                owned_by=model_info["owned_by"]
            )
    
    # Return a default model if not found
    return Model(
        id=model_id,
        root=model_id,
        owned_by="anthropic"
    )