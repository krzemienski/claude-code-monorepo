"""
Files endpoint - File management API
"""

import os
import shutil
from pathlib import Path
from typing import List, Optional
from datetime import datetime

from fastapi import APIRouter, HTTPException, Depends, UploadFile, File, Query
from fastapi.responses import FileResponse
from pydantic import BaseModel, Field

from app.core.config import settings
from app.api.deps import get_optional_user

router = APIRouter()


class FileInfo(BaseModel):
    """File information model"""
    name: str
    path: str
    size: int
    is_directory: bool
    created_at: datetime
    modified_at: datetime
    permissions: str


class DirectoryListing(BaseModel):
    """Directory listing response"""
    path: str
    files: List[FileInfo]
    total: int


class FileContent(BaseModel):
    """File content model"""
    path: str
    content: str
    encoding: str = "utf-8"


def get_file_info(file_path: Path) -> FileInfo:
    """Get file information"""
    stat = file_path.stat()
    
    return FileInfo(
        name=file_path.name,
        path=str(file_path),
        size=stat.st_size if file_path.is_file() else 0,
        is_directory=file_path.is_dir(),
        created_at=datetime.fromtimestamp(stat.st_ctime),
        modified_at=datetime.fromtimestamp(stat.st_mtime),
        permissions=oct(stat.st_mode)[-3:]
    )


def validate_path(path: str) -> Path:
    """Validate and resolve file path within workspace"""
    workspace = Path(settings.WORKSPACE_DIR)
    
    # Resolve the requested path
    requested_path = workspace / path.lstrip("/")
    resolved_path = requested_path.resolve()
    
    # Ensure the path is within the workspace
    if not str(resolved_path).startswith(str(workspace)):
        raise HTTPException(status_code=403, detail="Access denied: Path outside workspace")
    
    return resolved_path


@router.get("/list", response_model=DirectoryListing)
async def list_files(
    path: str = Query("/", description="Directory path to list"),
    user: Optional[dict] = Depends(get_optional_user)
):
    """
    List files in a directory.
    """
    
    dir_path = validate_path(path)
    
    if not dir_path.exists():
        raise HTTPException(status_code=404, detail="Directory not found")
    
    if not dir_path.is_dir():
        raise HTTPException(status_code=400, detail="Path is not a directory")
    
    files = []
    for item in dir_path.iterdir():
        try:
            files.append(get_file_info(item))
        except (PermissionError, OSError):
            continue
    
    # Sort files: directories first, then by name
    files.sort(key=lambda x: (not x.is_directory, x.name.lower()))
    
    return DirectoryListing(
        path=str(dir_path),
        files=files,
        total=len(files)
    )


@router.get("/read", response_model=FileContent)
async def read_file(
    path: str = Query(..., description="File path to read"),
    user: Optional[dict] = Depends(get_optional_user)
):
    """
    Read the contents of a file.
    """
    
    file_path = validate_path(path)
    
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="File not found")
    
    if not file_path.is_file():
        raise HTTPException(status_code=400, detail="Path is not a file")
    
    # Check file size
    if file_path.stat().st_size > settings.MAX_FILE_SIZE:
        raise HTTPException(status_code=413, detail="File too large")
    
    # Check file extension
    if settings.ALLOWED_FILE_EXTENSIONS:
        if file_path.suffix not in settings.ALLOWED_FILE_EXTENSIONS:
            raise HTTPException(status_code=403, detail="File type not allowed")
    
    try:
        content = file_path.read_text(encoding="utf-8")
        return FileContent(
            path=str(file_path),
            content=content,
            encoding="utf-8"
        )
    except UnicodeDecodeError:
        # Try binary read for non-text files
        content = file_path.read_bytes()
        return FileContent(
            path=str(file_path),
            content=content.hex(),
            encoding="binary"
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error reading file: {str(e)}")


@router.post("/write")
async def write_file(
    path: str,
    content: str,
    encoding: str = "utf-8",
    user: Optional[dict] = Depends(get_optional_user)
):
    """
    Write content to a file.
    """
    
    file_path = validate_path(path)
    
    # Check file extension
    if settings.ALLOWED_FILE_EXTENSIONS:
        if file_path.suffix not in settings.ALLOWED_FILE_EXTENSIONS:
            raise HTTPException(status_code=403, detail="File type not allowed")
    
    # Create parent directories if they don't exist
    file_path.parent.mkdir(parents=True, exist_ok=True)
    
    try:
        if encoding == "binary":
            # Write binary content (hex string)
            file_path.write_bytes(bytes.fromhex(content))
        else:
            file_path.write_text(content, encoding=encoding)
        
        return {
            "message": "File written successfully",
            "path": str(file_path),
            "size": len(content)
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error writing file: {str(e)}")


@router.post("/upload")
async def upload_file(
    file: UploadFile = File(...),
    path: str = Query("/", description="Directory to upload to"),
    user: Optional[dict] = Depends(get_optional_user)
):
    """
    Upload a file.
    """
    
    dir_path = validate_path(path)
    
    if not dir_path.is_dir():
        raise HTTPException(status_code=400, detail="Path is not a directory")
    
    file_path = dir_path / file.filename
    
    # Check file extension
    if settings.ALLOWED_FILE_EXTENSIONS:
        if file_path.suffix not in settings.ALLOWED_FILE_EXTENSIONS:
            raise HTTPException(status_code=403, detail="File type not allowed")
    
    # Check file size
    if file.size and file.size > settings.MAX_FILE_SIZE:
        raise HTTPException(status_code=413, detail="File too large")
    
    try:
        # Save uploaded file
        with file_path.open("wb") as f:
            content = await file.read()
            f.write(content)
        
        return {
            "message": "File uploaded successfully",
            "path": str(file_path),
            "size": len(content),
            "filename": file.filename
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error uploading file: {str(e)}")


@router.get("/download")
async def download_file(
    path: str = Query(..., description="File path to download"),
    user: Optional[dict] = Depends(get_optional_user)
):
    """
    Download a file.
    """
    
    file_path = validate_path(path)
    
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="File not found")
    
    if not file_path.is_file():
        raise HTTPException(status_code=400, detail="Path is not a file")
    
    return FileResponse(
        path=str(file_path),
        filename=file_path.name,
        media_type="application/octet-stream"
    )


@router.delete("/delete")
async def delete_file(
    path: str = Query(..., description="File or directory path to delete"),
    user: Optional[dict] = Depends(get_optional_user)
):
    """
    Delete a file or directory.
    """
    
    file_path = validate_path(path)
    
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="Path not found")
    
    try:
        if file_path.is_file():
            file_path.unlink()
        else:
            shutil.rmtree(file_path)
        
        return {
            "message": "Path deleted successfully",
            "path": str(file_path)
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error deleting path: {str(e)}")


@router.post("/mkdir")
async def create_directory(
    path: str,
    user: Optional[dict] = Depends(get_optional_user)
):
    """
    Create a new directory.
    """
    
    dir_path = validate_path(path)
    
    if dir_path.exists():
        raise HTTPException(status_code=409, detail="Directory already exists")
    
    try:
        dir_path.mkdir(parents=True, exist_ok=True)
        
        return {
            "message": "Directory created successfully",
            "path": str(dir_path)
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error creating directory: {str(e)}")


@router.post("/move")
async def move_file(
    source: str,
    destination: str,
    user: Optional[dict] = Depends(get_optional_user)
):
    """
    Move or rename a file or directory.
    """
    
    source_path = validate_path(source)
    dest_path = validate_path(destination)
    
    if not source_path.exists():
        raise HTTPException(status_code=404, detail="Source path not found")
    
    if dest_path.exists():
        raise HTTPException(status_code=409, detail="Destination already exists")
    
    try:
        shutil.move(str(source_path), str(dest_path))
        
        return {
            "message": "Path moved successfully",
            "source": str(source_path),
            "destination": str(dest_path)
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error moving path: {str(e)}")