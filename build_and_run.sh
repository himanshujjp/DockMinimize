#!/bin/bash

# DockMinimize Build Script
# Builds and runs the Doc            echo "❌ Could not find DockMinimize.app after build"
        echo "🔍 Expected locations:"
        echo "   - $BUILD_PATH/DockMinimize.app"
        echo "   - $FALLBACK_PATH/DockMinimize.app"
        echo "💡 Try running: find ~/Library/Developer/Xcode/DerivedData -name 'DockMinimize.app'"cho "❌ Could not find DockMinimize.app after build"
        echo "🔍 Expected locations:"
        echo "   - $BUILD_PATH/DockMinimize.app"
        echo "   - $FALLBACK_PATH/DockMinimize.app"
        echo "💡 Try running: find ~/Library/Developer/Xcode/DerivedData -name 'DockMinimize.app'"mize app

echo "🔨 Building DockMinimize..."

# Change to project directory
cd "$(dirname "$0")"

# Build the project
xcodebuild -project DockMinimize.xcodeproj \
    -scheme DockMinimize \
    -configuration Debug \
    ENABLE_APP_SANDBOX=NO \
    ENABLE_HARDENED_RUNTIME=NO \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    DEVELOPMENT_TEAM="" \
    build

# Copy icon file to app bundle
if [ -f "DockMinimize.icns" ]; then
    echo "📱 Copying app icon..."
    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "DockMinimize.app" -path "*/Debug/*" 2>/dev/null | head -1)
    if [ -n "$APP_PATH" ]; then
        cp DockMinimize.icns "$APP_PATH/Contents/Resources/"
        echo "✅ Icon copied to app bundle"
    fi
fi

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo "🚀 Launching DockMinimize..."
    
    # Get the correct build path using xcodebuild
    BUILD_PATH=$(xcodebuild -project DockMinimize.xcodeproj -scheme DockMinimize -configuration Debug -showBuildSettings | grep "BUILT_PRODUCTS_DIR" | head -1 | sed 's/.*= //')
    
    # Alternative fallback path
    DERIVED_DATA_PATH=$(xcodebuild -project DockMinimize.xcodeproj -showBuildSettings | grep "BUILD_DIR" | head -1 | sed 's/.*= //' | sed 's|/Build/Products||')
    FALLBACK_PATH="$DERIVED_DATA_PATH/Build/Products/Debug"
    
    # Try to find the app in multiple locations
    APP_PATH=""
    if [ -d "$BUILD_PATH/DockMinimize.app" ]; then
        APP_PATH="$BUILD_PATH/DockMinimize.app"
        echo "📍 Found app at: $APP_PATH"
    elif [ -d "$FALLBACK_PATH/DockMinimize.app" ]; then
        APP_PATH="$FALLBACK_PATH/DockMinimize.app"
        echo "📍 Found app at fallback location: $APP_PATH"
    else
        # Search in common build locations
        echo "🔍 Searching for DockMinimize.app..."
        SEARCH_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "DockMinimize.app" -type d 2>/dev/null | grep Debug | head -1)
        if [ -n "$SEARCH_PATH" ]; then
            APP_PATH="$SEARCH_PATH"
            echo "📍 Found app via search: $APP_PATH"
        fi
    fi
    
    # Launch the app if found
    if [ -n "$APP_PATH" ] && [ -d "$APP_PATH" ]; then
        echo "🚀 Launching: $APP_PATH"
        open "$APP_PATH"
        echo "📱 App launched! Look for the menubar icon."
        echo "📋 To monitor logs: open Console.app and filter for 'DockMinimize'"
    else
        echo "❌ Could not find DockMinimize.app after build"
        echo "🔍 Tried locations:"
        echo "   - $BUILD_PATH/DockMinimize.app"
        echo "   - $FALLBACK_PATH/DockMinimize.app"
        echo "💡 Try running: find ~/Library/Developer/Xcode/DerivedData -name 'DockMinimize.app'"
        exit 1
    fi
else
    echo "❌ Build failed! Check the output above for errors."
    exit 1
fi