# DockMinimize

A powerful open-source macOS utility that brings intuitive window management to macOS. DockMinimize allows users to **single-click an app's Dock icon to minimize or restore its windows**, similar to behavior found on Windows and Linux.

![DockMinimize Icon](app_icon_preview.png)

## Features

- **Single-Click Dock Interaction**: Click on any active app's dock icon to hide/show windows
- **Smart Window Management**: Automatically detects window states and toggles between minimize/restore
- **Menubar Integration**: Clean menubar interface with quick access controls
- **Background Operation**: Runs silently in the background without cluttering your dock
- **Cross-Platform Behavior**: Familiar window management from Windows/Linux on macOS

## Installation

### Download DMG (Recommended)
1. Download `DockMinimize.dmg` from the releases
2. Open the DMG file
3. Drag DockMinimize to your Applications folder
4. Launch DockMinimize from Applications

### Build from Source
```bash
git clone https://github.com/himanshujjp/DockMinimize.git
cd DockMinimize
./build_and_run.sh
```

## Setup

### Accessibility Permission Required
1. Launch DockMinimize
2. When prompted, click "Open System Settings"
3. Navigate to **Privacy & Security > Accessibility**
4. Enable DockMinimize in the list
5. The app will automatically restart

## Usage

- Launch DockMinimize - it appears in your menubar
- Click on any active app's dock icon to minimize/restore its windows
- Use menubar menu for manual controls

## System Requirements

- **macOS**: 10.15 (Catalina) or later
- **Architecture**: Intel and Apple Silicon compatible
- **Permissions**: Accessibility access required

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

## License

This project is open source. Feel free to use, modify, and distribute.

---

**Note**: DockMinimize uses macOS accessibility APIs solely for window management purposes.
