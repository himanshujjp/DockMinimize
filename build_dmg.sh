#!/bin/bash

# DockMinimize DMG Build Script
# Builds the app and creates a distributable DMG file

echo "🔨 Building DockMinimize for distribution..."

# Change to project directory
cd "$(dirname "$0")"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf build/
mkdir -p build

# Build the project for Release
echo "⚙️ Building Release version..."
xcodebuild -project DockMinimize.xcodeproj \
    -scheme DockMinimize \
    -configuration Release \
    -derivedDataPath ./build/DerivedData \
    ENABLE_APP_SANDBOX=NO \
    ENABLE_HARDENED_RUNTIME=NO \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    DEVELOPMENT_TEAM="" \
    clean build

if [ $? -ne 0 ]; then
    echo "❌ Build failed! Check the output above for errors."
    exit 1
fi

# Copy icon file to app bundle
if [ -f "DockMinimize.icns" ]; then
    echo "📱 Copying app icon..."
    APP_PATH="./build/DerivedData/Build/Products/Release/DockMinimize.app"
    if [ -d "$APP_PATH" ]; then
        cp DockMinimize.icns "$APP_PATH/Contents/Resources/"
        echo "✅ Icon copied to app bundle"
    fi
fi

echo "✅ Build successful!"

# Get the built app path
APP_PATH="./build/DerivedData/Build/Products/Release/DockMinimize.app"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ Could not find built app at: $APP_PATH"
    exit 1
fi

# Create DMG staging directory
DMG_STAGING_DIR="./build/dmg_staging"
rm -rf "$DMG_STAGING_DIR"
mkdir -p "$DMG_STAGING_DIR"

echo "📦 Preparing DMG contents..."

# Copy the app to staging directory
cp -R "$APP_PATH" "$DMG_STAGING_DIR/"

# Create Applications symlink for easy installation
ln -s /Applications "$DMG_STAGING_DIR/Applications"

# Create a background image (optional)
mkdir -p "$DMG_STAGING_DIR/.background"

# Create a simple README for the DMG
cat > "$DMG_STAGING_DIR/README.txt" << EOF
DockMinimize - Dock Click to Minimize/Restore Apps

Installation:
1. Drag DockMinimize.app to the Applications folder
2. Run DockMinimize from Applications
3. Grant Accessibility permission when prompted
4. Look for the menubar icon (rectangle stack)

Usage:
- Click any dock icon to hide/show that app
- Use Cmd+T to toggle the active app
- Right-click menubar icon to quit

Requirements:
- macOS 10.15 or later
- Accessibility permission

For support, visit: https://github.com/himanshujjp/DockMinimize
EOF

# DMG settings
DMG_NAME="DockMinimize"
DMG_FILE="./DockMinimize.dmg"
VOLUME_NAME="DockMinimize Installer"

echo "🎁 Creating DMG file..."

# Remove existing DMG
rm -f "$DMG_FILE"

# Create the DMG
hdiutil create -volname "$VOLUME_NAME" \
    -srcfolder "$DMG_STAGING_DIR" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_FILE"

if [ $? -eq 0 ]; then
    echo "✅ DMG created successfully!"
    echo "📍 DMG location: $(pwd)/$DMG_FILE"
    
    # Get DMG size
    DMG_SIZE=$(du -h "$DMG_FILE" | cut -f1)
    echo "📏 DMG size: $DMG_SIZE"
    
    # Open the DMG to test
    echo "🔍 Opening DMG to verify..."
    open "$DMG_FILE"
    
    echo ""
    echo "🎉 Build and packaging complete!"
    echo "📦 Ready to distribute: $DMG_FILE"
    echo ""
    echo "Next steps:"
    echo "1. Test the DMG by mounting and installing"
    echo "2. Share the DMG file with users"
    echo "3. Users should drag DockMinimize.app to Applications"
    
else
    echo "❌ Failed to create DMG!"
    exit 1
fi

# Cleanup staging directory
echo "🧹 Cleaning up staging files..."
rm -rf "$DMG_STAGING_DIR"

echo "🏁 All done!"