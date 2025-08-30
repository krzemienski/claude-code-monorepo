#!/bin/bash

# Bundle ID Standardization Script for Claude Code iOS
# Fixes critical blocker: Inconsistent bundle identifiers
# Target: com.claudecode.ios

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PROJECT_ROOT="$(dirname "$(dirname "$0")")"
IOS_DIR="$PROJECT_ROOT/apps/ios"
CORRECT_BUNDLE_ID="com.claudecode.ios"
BACKUP_DIR="$PROJECT_ROOT/backups/bundle-id-$(date +%Y%m%d-%H%M%S)"

echo -e "${BLUE}🔧 Bundle ID Standardization Script${NC}"
echo "======================================"
echo "Target Bundle ID: $CORRECT_BUNDLE_ID"
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"
echo -e "${BLUE}📦 Creating backup at: $BACKUP_DIR${NC}"

# Function to backup file
backup_file() {
    local file=$1
    local relative_path=${file#$PROJECT_ROOT/}
    local backup_path="$BACKUP_DIR/$relative_path"
    mkdir -p "$(dirname "$backup_path")"
    cp "$file" "$backup_path"
    echo "  Backed up: $relative_path"
}

# Function to fix bundle ID in file
fix_bundle_id() {
    local file=$1
    local old_id=$2
    
    if grep -q "$old_id" "$file"; then
        backup_file "$file"
        sed -i '' "s/$old_id/$CORRECT_BUNDLE_ID/g" "$file"
        echo -e "${GREEN}✅ Fixed: ${file#$PROJECT_ROOT/}${NC}"
        return 0
    fi
    return 1
}

echo -e "\n${YELLOW}🔍 Phase 1: Scanning for bundle ID references...${NC}"

# Common incorrect bundle IDs to search for
INCORRECT_IDS=(
    "com.claude.ios"
    "com.claudeai.ios"
    "com.anthropic.claudecode"
    "com.example.claudecode"
    "com.yourcompany.claudecode"
)

# Files to check
FILES_TO_CHECK=(
    "$IOS_DIR/Info.plist"
    "$IOS_DIR/Project.yml"
    "$IOS_DIR/Project.swift"
    "$IOS_DIR/Config.swift"
    "$IOS_DIR/Tuist.swift"
    "$IOS_DIR/Workspace.swift"
    "$IOS_DIR/ClaudeCode.xcodeproj/project.pbxproj"
)

# Find all Info.plist files
find "$IOS_DIR" -name "Info.plist" -type f | while read -r plist; do
    FILES_TO_CHECK+=("$plist")
done

# Find all xcconfig files
find "$IOS_DIR" -name "*.xcconfig" -type f | while read -r xcconfig; do
    FILES_TO_CHECK+=("$xcconfig")
done

echo -e "\n${YELLOW}🔧 Phase 2: Fixing bundle identifiers...${NC}"

FIXED_COUNT=0
for file in "${FILES_TO_CHECK[@]}"; do
    if [ -f "$file" ]; then
        for incorrect_id in "${INCORRECT_IDS[@]}"; do
            if fix_bundle_id "$file" "$incorrect_id"; then
                ((FIXED_COUNT++))
            fi
        done
        
        # Also check for PRODUCT_BUNDLE_IDENTIFIER
        if grep -q "PRODUCT_BUNDLE_IDENTIFIER" "$file"; then
            backup_file "$file"
            sed -i '' "s/PRODUCT_BUNDLE_IDENTIFIER = .*/PRODUCT_BUNDLE_IDENTIFIER = $CORRECT_BUNDLE_ID;/g" "$file"
            echo -e "${GREEN}✅ Updated PRODUCT_BUNDLE_IDENTIFIER in: ${file#$PROJECT_ROOT/}${NC}"
        fi
    fi
done

echo -e "\n${YELLOW}🔧 Phase 3: Updating Tuist configuration...${NC}"

# Update Tuist Project.swift
if [ -f "$IOS_DIR/Project.swift" ]; then
    backup_file "$IOS_DIR/Project.swift"
    cat > "$IOS_DIR/Project.swift.tmp" << 'EOF'
import ProjectDescription

let project = Project(
    name: "ClaudeCode",
    organizationName: "ClaudeCode",
    options: .options(
        automaticSchemesOptions: .enabled(),
        disableBundleAccessors: false,
        disableShowEnvironmentVarsInScriptPhases: false,
        disableSynthesizedResourceAccessors: false,
        textSettings: .textSettings(
            usesTabs: false,
            indentWidth: 4,
            tabWidth: 4,
            wrapsLines: true
        )
    ),
    packages: [
        .remote(url: "https://github.com/apple/swift-log.git", requirement: .upToNextMajor(from: "1.5.3")),
        .remote(url: "https://github.com/apple/swift-metrics.git", requirement: .upToNextMajor(from: "2.5.0")),
        .remote(url: "https://github.com/LaunchDarkly/swift-eventsource.git", requirement: .upToNextMajor(from: "3.0.0")),
        .remote(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", requirement: .upToNextMajor(from: "4.2.2")),
        .remote(url: "https://github.com/ChartsOrg/Charts.git", requirement: .upToNextMajor(from: "5.1.0"))
    ],
    settings: Settings.settings(
        base: [
            "PRODUCT_BUNDLE_IDENTIFIER": "com.claudecode.ios",
            "DEVELOPMENT_TEAM": "$(DEVELOPMENT_TEAM)",
            "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
            "SWIFT_VERSION": "5.9",
            "ENABLE_BITCODE": "NO"
        ],
        configurations: [
            .debug(name: "Debug", xcconfig: "Configs/Debug.xcconfig"),
            .release(name: "Release", xcconfig: "Configs/Release.xcconfig")
        ]
    ),
    targets: [
        Target(
            name: "ClaudeCode",
            platform: .iOS,
            product: .app,
            bundleId: "com.claudecode.ios",
            deploymentTarget: .iOS(targetVersion: "17.0", devices: [.iphone, .ipad]),
            infoPlist: .extendingDefault(with: [
                "UILaunchStoryboardName": "LaunchScreen",
                "UIApplicationSceneManifest": [
                    "UIApplicationSupportsMultipleScenes": false,
                    "UISceneConfigurations": [
                        "UIWindowSceneSessionRoleApplication": [
                            [
                                "UISceneConfigurationName": "Default Configuration",
                                "UISceneDelegateClassName": "$(PRODUCT_MODULE_NAME).SceneDelegate"
                            ]
                        ]
                    ]
                ],
                "NSAppTransportSecurity": [
                    "NSAllowsArbitraryLoads": true
                ]
            ]),
            sources: ["Sources/**"],
            resources: ["Resources/**"],
            dependencies: [
                .package(product: "Logging"),
                .package(product: "Metrics"),
                .package(product: "LDSwiftEventSource"),
                .package(product: "KeychainAccess"),
                .package(product: "DGCharts")
            ]
        ),
        Target(
            name: "ClaudeCodeTests",
            platform: .iOS,
            product: .unitTests,
            bundleId: "com.claudecode.ios.tests",
            sources: ["Tests/**"],
            dependencies: [
                .target(name: "ClaudeCode")
            ]
        ),
        Target(
            name: "ClaudeCodeUITests",
            platform: .iOS,
            product: .uiTests,
            bundleId: "com.claudecode.ios.uitests",
            sources: ["UITests/**"],
            dependencies: [
                .target(name: "ClaudeCode")
            ]
        )
    ],
    schemes: [
        Scheme(
            name: "ClaudeCode",
            shared: true,
            buildAction: BuildAction(
                targets: ["ClaudeCode"]
            ),
            testAction: TestAction.targets(
                ["ClaudeCodeTests", "ClaudeCodeUITests"],
                configuration: .debug,
                options: .options(coverage: true, codeCoverageTargets: ["ClaudeCode"])
            ),
            runAction: RunAction.runAction(
                configuration: .debug,
                executable: "ClaudeCode"
            ),
            archiveAction: ArchiveAction.archiveAction(
                configuration: .release
            ),
            profileAction: ProfileAction.profileAction(
                configuration: .release,
                executable: "ClaudeCode"
            ),
            analyzeAction: AnalyzeAction.analyzeAction(
                configuration: .debug
            )
        )
    ]
)
EOF
    mv "$IOS_DIR/Project.swift.tmp" "$IOS_DIR/Project.swift"
    echo -e "${GREEN}✅ Updated Tuist Project.swift${NC}"
fi

echo -e "\n${YELLOW}🔧 Phase 4: Regenerating project files...${NC}"

cd "$IOS_DIR"

# Clean existing generated files
if [ -d "ClaudeCode.xcodeproj" ]; then
    rm -rf ClaudeCode.xcodeproj
    echo "  Removed old .xcodeproj"
fi

if [ -d "ClaudeCode.xcworkspace" ]; then
    rm -rf ClaudeCode.xcworkspace
    echo "  Removed old .xcworkspace"
fi

# Regenerate with Tuist
if command -v tuist &> /dev/null; then
    echo "  Generating project with Tuist..."
    tuist generate
    echo -e "${GREEN}✅ Project regenerated with Tuist${NC}"
elif command -v xcodegen &> /dev/null && [ -f "Project.yml" ]; then
    echo "  Generating project with XcodeGen..."
    xcodegen generate
    echo -e "${GREEN}✅ Project regenerated with XcodeGen${NC}"
else
    echo -e "${YELLOW}⚠️  Could not regenerate project (Tuist/XcodeGen not found)${NC}"
fi

echo -e "\n${YELLOW}📋 Phase 5: Verification...${NC}"

# Verify the changes
VERIFICATION_PASSED=true

echo -n "Checking bundle ID consistency... "
for file in "${FILES_TO_CHECK[@]}"; do
    if [ -f "$file" ]; then
        for incorrect_id in "${INCORRECT_IDS[@]}"; do
            if grep -q "$incorrect_id" "$file" 2>/dev/null; then
                echo -e "${RED}❌ Found incorrect ID in ${file#$PROJECT_ROOT/}${NC}"
                VERIFICATION_PASSED=false
            fi
        done
    fi
done

if [ "$VERIFICATION_PASSED" = true ]; then
    echo -e "${GREEN}✅ All bundle IDs standardized${NC}"
else
    echo -e "${RED}❌ Some bundle IDs still need fixing${NC}"
fi

echo -e "\n${BLUE}📊 Summary:${NC}"
echo "- Fixed $FIXED_COUNT bundle ID references"
echo "- Backup created at: $BACKUP_DIR"
echo "- Target bundle ID: $CORRECT_BUNDLE_ID"

if [ "$VERIFICATION_PASSED" = true ]; then
    echo -e "\n${GREEN}✅ Bundle ID standardization complete!${NC}"
    echo "Next steps:"
    echo "1. Open Xcode and verify the project builds"
    echo "2. Clean build folder (Cmd+Shift+K)"
    echo "3. Build and run the project"
    exit 0
else
    echo -e "\n${RED}⚠️  Bundle ID standardization incomplete${NC}"
    echo "Please review the remaining issues and fix manually"
    exit 1
fi