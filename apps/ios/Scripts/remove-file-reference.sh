#!/bin/bash

# Remove AdaptiveLayout.swift references from Xcode project file

PROJECT_FILE="ClaudeCode.xcodeproj/project.pbxproj"

# Create backup
cp "$PROJECT_FILE" "$PROJECT_FILE.backup"

# Remove the build phase reference
sed -i '' '/8CD90291B82C2868A593DCF9.*AdaptiveLayout.swift in Sources/d' "$PROJECT_FILE"

# Remove the file reference
sed -i '' '/2BC4A7C91E8085C5AAFA98D5.*AdaptiveLayout.swift.*PBXFileReference/d' "$PROJECT_FILE"

# Remove from the Components group
sed -i '' '/2BC4A7C91E8085C5AAFA98D5.*AdaptiveLayout.swift/d' "$PROJECT_FILE"

# Remove from build phases
sed -i '' '/8CD90291B82C2868A593DCF9.*AdaptiveLayout.swift in Sources/d' "$PROJECT_FILE"

echo "✅ Removed AdaptiveLayout.swift references from project file"
echo "Backup created at: $PROJECT_FILE.backup"