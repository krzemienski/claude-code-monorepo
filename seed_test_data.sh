#!/bin/bash

echo "Creating test projects..."

# Create iOS Project
curl -X POST http://localhost:8000/v1/projects \
  -H "Content-Type: application/json" \
  -d '{
    "name": "iOS Claude Code App",
    "path": "/workspace/ios-app"
  }' | python3 -m json.tool

# Create Backend Project
curl -X POST http://localhost:8000/v1/projects \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Backend API Service",
    "path": "/workspace/backend-api"
  }' | python3 -m json.tool

# Create Test Project
curl -X POST http://localhost:8000/v1/projects \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test Automation Suite",
    "path": "/workspace/test-suite"
  }' | python3 -m json.tool

echo -e "\nCreating test sessions..."

# Create session for iOS project
curl -X POST http://localhost:8000/v1/sessions \
  -H "Content-Type: application/json" \
  -d '{
    "project_id": "proj_001",
    "name": "iOS Development Session"
  }' | python3 -m json.tool

# Create session for backend project
curl -X POST http://localhost:8000/v1/sessions \
  -H "Content-Type: application/json" \
  -d '{
    "project_id": "proj_new",
    "name": "Backend Implementation Session"
  }' | python3 -m json.tool

echo -e "\nTest data created successfully!"