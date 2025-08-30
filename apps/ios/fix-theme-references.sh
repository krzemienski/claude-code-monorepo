#!/bin/bash

# Fix Theme spacing references in all Swift files
echo "Fixing Theme spacing references..."

# List of files to fix
FILES=(
    "Sources/Features/Home/HomeView.swift"
    "Sources/Features/Projects/ProjectsListView.swift"
    "Sources/Features/Sessions/SessionsView.swift"
    "Sources/Features/Sessions/ChatConsoleView.swift"
    "Sources/Features/Sessions/AdaptiveChatView.swift"
    "Sources/Features/Monitoring/MonitoringView.swift"
)

for file in "${FILES[@]}"; do
    echo "Processing $file..."
    # Fix Theme.Spacing.adaptive(.xs) -> Theme.Spacing.adaptive(Theme.Spacing.xs)
    sed -i '' 's/Theme\.Spacing\.adaptive(\.xs)/Theme.Spacing.adaptive(Theme.Spacing.xs)/g' "$file"
    sed -i '' 's/Theme\.Spacing\.adaptive(\.sm)/Theme.Spacing.adaptive(Theme.Spacing.sm)/g' "$file"
    sed -i '' 's/Theme\.Spacing\.adaptive(\.md)/Theme.Spacing.adaptive(Theme.Spacing.md)/g' "$file"
    sed -i '' 's/Theme\.Spacing\.adaptive(\.lg)/Theme.Spacing.adaptive(Theme.Spacing.lg)/g' "$file"
    sed -i '' 's/Theme\.Spacing\.adaptive(\.xl)/Theme.Spacing.adaptive(Theme.Spacing.xl)/g' "$file"
    sed -i '' 's/Theme\.Spacing\.adaptive(\.xxl)/Theme.Spacing.adaptive(Theme.Spacing.xxl)/g' "$file"
done

echo "Theme spacing references fixed!"