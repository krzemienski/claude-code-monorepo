"""
Projects endpoint - Project management
"""

import uuid
from datetime import datetime
from typing import List, Optional, Dict

from fastapi import APIRouter, HTTPException, Depends, Query
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, delete

from app.db.session import get_db
from app.models.project import Project
from app.api.deps import get_optional_user

router = APIRouter()


class ProjectCreate(BaseModel):
    """Project creation model"""
    name: str = Field(..., description="Project name")
    description: Optional[str] = Field(None, description="Project description")
    path: Optional[str] = Field(None, description="Project file path")
    metadata: Optional[Dict] = Field(default_factory=dict)


class ProjectUpdate(BaseModel):
    """Project update model"""
    name: Optional[str] = None
    description: Optional[str] = None
    path: Optional[str] = None
    metadata: Optional[Dict] = None
    is_active: Optional[bool] = None


class ProjectResponse(BaseModel):
    """Project response model"""
    id: str
    name: str
    description: Optional[str]
    path: Optional[str]
    is_active: bool
    metadata: Dict
    created_at: datetime
    updated_at: datetime
    user_id: str
    
    class Config:
        from_attributes = True


class ProjectsList(BaseModel):
    """Projects list response"""
    projects: List[ProjectResponse]
    total: int
    limit: int
    offset: int


@router.post("", response_model=ProjectResponse)
async def create_project(
    project_data: ProjectCreate,
    db: AsyncSession = Depends(get_db),
    user: Optional[Dict] = Depends(get_optional_user)
):
    """
    Create a new project.
    """
    
    # Create project
    project = Project(
        id=str(uuid.uuid4()),
        name=project_data.name,
        description=project_data.description,
        path=project_data.path,
        metadata=project_data.metadata or {},
        user_id=user.get("id", "default") if user else "default",
        is_active=True,
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow()
    )
    
    db.add(project)
    await db.commit()
    await db.refresh(project)
    
    return ProjectResponse.model_validate(project)


@router.get("", response_model=ProjectsList)
async def list_projects(
    is_active: Optional[bool] = Query(None),
    limit: int = Query(100, le=1000),
    offset: int = Query(0),
    db: AsyncSession = Depends(get_db),
    user: Optional[Dict] = Depends(get_optional_user)
):
    """
    List all projects for the current user.
    """
    
    user_id = user.get("id", "default") if user else "default"
    
    # Build query
    query = select(Project).where(Project.user_id == user_id)
    
    if is_active is not None:
        query = query.where(Project.is_active == is_active)
    
    query = query.offset(offset).limit(limit)
    
    # Execute query
    result = await db.execute(query)
    projects = result.scalars().all()
    
    # Get total count
    from sqlalchemy import func
    count_query = select(func.count()).select_from(Project).where(
        Project.user_id == user_id
    )
    if is_active is not None:
        count_query = count_query.where(Project.is_active == is_active)
    
    total = await db.scalar(count_query)
    
    return ProjectsList(
        projects=[ProjectResponse.model_validate(p) for p in projects],
        total=total or 0,
        limit=limit,
        offset=offset
    )


@router.get("/{project_id}", response_model=ProjectResponse)
async def get_project(
    project_id: str,
    db: AsyncSession = Depends(get_db),
    user: Optional[Dict] = Depends(get_optional_user)
):
    """
    Get a specific project by ID.
    """
    
    user_id = user.get("id", "default") if user else "default"
    
    result = await db.execute(
        select(Project).where(
            Project.id == project_id,
            Project.user_id == user_id
        )
    )
    project = result.scalar_one_or_none()
    
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    
    return ProjectResponse.model_validate(project)


@router.patch("/{project_id}", response_model=ProjectResponse)
async def update_project(
    project_id: str,
    project_update: ProjectUpdate,
    db: AsyncSession = Depends(get_db),
    user: Optional[Dict] = Depends(get_optional_user)
):
    """
    Update a project.
    """
    
    user_id = user.get("id", "default") if user else "default"
    
    # Get project
    result = await db.execute(
        select(Project).where(
            Project.id == project_id,
            Project.user_id == user_id
        )
    )
    project = result.scalar_one_or_none()
    
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    
    # Update fields
    update_data = project_update.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(project, field, value)
    
    project.updated_at = datetime.utcnow()
    
    await db.commit()
    await db.refresh(project)
    
    return ProjectResponse.model_validate(project)


@router.delete("/{project_id}")
async def delete_project(
    project_id: str,
    db: AsyncSession = Depends(get_db),
    user: Optional[Dict] = Depends(get_optional_user)
):
    """
    Delete a project.
    """
    
    user_id = user.get("id", "default") if user else "default"
    
    # Get project
    result = await db.execute(
        select(Project).where(
            Project.id == project_id,
            Project.user_id == user_id
        )
    )
    project = result.scalar_one_or_none()
    
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    
    # Delete project
    await db.delete(project)
    await db.commit()
    
    return {"message": "Project deleted successfully"}