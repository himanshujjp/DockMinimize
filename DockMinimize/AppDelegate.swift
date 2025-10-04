import Cocoa
import ApplicationServices
import CoreGraphics

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var eventTap: CFMachPort?
    private var dockItems: [DockItem] = []
    private var isMonitoring = false
    private var previousActiveApp: NSRunningApplication?
    private var permissionTimer: Timer?
    private var eventTapEnabled = false
    private var lastPermissionCheck = false
    private var needsReopen = false
    private var hasShownInitialAlert = false
    
    // Define a struct to hold the dock item information
    struct DockItem {
        let rect: NSRect
        let appID: String
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 DockMinimize started")
        
        // Hide dock icon and main window
        NSApp.setActivationPolicy(.accessory)
        
        // Setup menubar
        setupMenuBar()
        
        // Check accessibility permission initially
        checkAccessibilityPermission()
        
        // Start permission monitoring
        startPermissionMonitoring()
        
        // Setup workspace notifications to update dock items
        setupWorkspaceNotifications()
        
        // Get initial dock items
        updateDockItems()
        
        print("✅ App initialization complete")
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            // Use custom MenuBar icon from Assets
            if let menuBarIcon = NSImage(named: "MenuBarIcon") {
                button.image = menuBarIcon
                button.image?.isTemplate = true
            } else {
                // Fallback to SF Symbol
                button.image = NSImage(systemSymbolName: "rectangle.stack", accessibilityDescription: "DockMinimize")
                button.image?.isTemplate = true
            }
        }
        
        // Create menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "DockMinimize", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Toggle Active Window", action: #selector(toggleActiveWindow), keyEquivalent: "t"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
        print("✅ MenuBar setup complete")
    }
    
    private func startPermissionMonitoring() {
        // Initial check
        checkAndSetupEventTap()
        
        // Setup timer to continuously monitor permission
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.checkAndSetupEventTap()
        }
    }
    
    private func checkAndSetupEventTap() {
        let trusted = AXIsProcessTrusted()
        
        // Only act if permission state changed
        if trusted != lastPermissionCheck {
            lastPermissionCheck = trusted
            
            if trusted {
                print("✅ Accessibility permission granted - Setting up event tap")
                setupEventTap()
                
                // If we were waiting for permission and user granted it, restart app
                if needsReopen {
                    print("🔄 Permission granted - Restarting app to activate features")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.restartApp()
                    }
                    return
                }
            } else {
                print("❌ Accessibility permission lost - Cleaning up event tap")
                cleanupEventTap()
            }
        } else if trusted && !eventTapEnabled {
            // Permission exists but event tap is not working, try to recreate
            print("🔄 Recreating event tap")
            setupEventTap()
        }
    }
    
    private func checkAccessibilityPermission() {
        let trusted = AXIsProcessTrusted()
        if !trusted {
            print("❌ Accessibility permission not granted")
            showAccessibilityAlert()
        } else {
            print("✅ Accessibility permission granted")
        }
    }
    
    private func showAccessibilityAlert() {
        guard !hasShownInitialAlert else { return }
        hasShownInitialAlert = true
        
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "DockMinimize needs Accessibility permission to minimize/restore windows.\n\nAfter granting permission, the app will automatically restart to activate the feature.\n\nPlease enable in:\nSystem Settings > Privacy & Security > Accessibility"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            needsReopen = true
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }
    
    private func setupEventTap() {
        print("🎯 Setting up event tap for dock click detection...")
        
        // Clean up existing event tap first
        cleanupEventTap()
        
        guard AXIsProcessTrusted() else {
            print("❌ No accessibility permission for event tap")
            eventTapEnabled = false
            return
        }
        
        let eventMask: CGEventMask = (1 << CGEventType.leftMouseDown.rawValue)
        
        // Create the event tap
        guard let eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .tailAppendEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                let appDelegate = Unmanaged<AppDelegate>.fromOpaque(refcon!).takeUnretainedValue()
                return appDelegate.eventTapCallback(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("❌ Failed to create event tap")
            eventTapEnabled = false
            return
        }
        
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        
        // Enable the event tap
        CGEvent.tapEnable(tap: eventTap, enable: true)
        
        self.eventTap = eventTap
        eventTapEnabled = true
        print("✅ Event tap created and enabled successfully")
    }
    
    private func cleanupEventTap() {
        if let eventTap = eventTap {
            print("🧹 Cleaning up existing event tap")
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
        eventTapEnabled = false
    }
    
    private func eventTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let mouseLocation = event.location
        print("🖱️ Mouse click at: \(mouseLocation)")
        
        // Check if the mouse is over any dock item
        for dockItem in dockItems {
            if dockItem.rect.contains(mouseLocation) {
                print("🎯 Dock click detected on: \(dockItem.appID)")
                let shouldSuppress = handleDockClick(appName: dockItem.appID)
                if shouldSuppress {
                    return nil // Suppress the event
                } else {
                    return Unmanaged.passUnretained(event) // Let the system handle it
                }
            }
        }
        
        return Unmanaged.passUnretained(event)
    }
    
    private func handleDockClick(appName: String) -> Bool {
        print("🔄 Handling dock click for: \(appName)")
        
        let runningApps = NSWorkspace.shared.runningApplications
        
        // Find the app by name (exact or partial match)
        var app: NSRunningApplication?
        app = runningApps.first(where: { ($0.localizedName ?? "").lowercased() == appName.lowercased() })
        if app == nil {
            app = runningApps.first(where: { 
                let localized = ($0.localizedName ?? "").lowercased()
                let dockName = appName.lowercased()
                return localized.contains(dockName) || dockName.contains(localized)
            })
        }
        
        if let app = app, app.isActive && !app.isHidden {
            // App is active and visible, hide it with effect
            print("📥 Hiding active app: \(appName)")
            self.hideAppWithEffect(app)
            return true // Suppress the event
        } else {
            // For other cases (not active, hidden, or not running), let the system handle normally
            print("⏭️ Letting system handle: \(appName)")
            return false // Don't suppress
        }
    }
    
    private func findAppURL(for name: String) -> URL? {
        let fm = FileManager.default
        let appDirs = ["/Applications", "/System/Applications", NSHomeDirectory() + "/Applications"]
        
        for dir in appDirs {
            if let contents = try? fm.contentsOfDirectory(atPath: dir) {
                for item in contents {
                    if item.hasSuffix(".app") {
                        let appName = item.replacingOccurrences(of: ".app", with: "")
                        if appName.lowercased() == name.lowercased() || 
                           appName.lowercased().contains(name.lowercased()) || 
                           name.lowercased().contains(appName.lowercased()) {
                            return URL(fileURLWithPath: dir + "/" + item)
                        }
                    }
                }
            }
        }
        return nil
    }
    
    private func setupWorkspaceNotifications() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(dockChanged), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        center.addObserver(self, selector: #selector(dockChanged), name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        center.addObserver(self, selector: #selector(dockChanged), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        print("✅ Workspace notifications setup complete")
    }
    
    @objc private func dockChanged(notification: Notification) {
        // Update dock items whenever a relevant event occurs
        print("🔄 Dock changed notification received")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.updateDockItems()
        }
    }
    
    private func updateDockItems() {
        print("🔄 Updating dock items...")
        getDockItems { [weak self] dockItems in
            self?.dockItems = dockItems
            print("📊 Updated dock items: \(dockItems.count) items")
        }
    }
    
    private func getDockItems(completion: @escaping ([DockItem]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var dockItems: [DockItem] = []
            
            let script = """
            tell application "System Events"
                set dockItemList to {}
                tell process "Dock"
                    set dockItems to every UI element of list 1
                    repeat with dockItem in dockItems
                        set dockPosition to position of dockItem
                        set dockSize to size of dockItem
                        set appID to name of dockItem
                        set end of dockItemList to {dockPosition, dockSize, appID}
                    end repeat
                    return dockItemList
                end tell
            end tell
            """
            
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                let result = appleScript.executeAndReturnError(&error)
                
                if error != nil {
                    print("❌ Error executing AppleScript: \(String(describing: error))")
                    DispatchQueue.main.async {
                        completion([])
                    }
                    return
                }
                
                if result.descriptorType == typeAEList {
                    for index in 1...result.numberOfItems {
                        if let item = result.atIndex(index) {
                            if let positionDescriptor = item.atIndex(1),
                               let sizeDescriptor = item.atIndex(2),
                               let appIDDescriptor = item.atIndex(3) {
                                
                                let positionX = positionDescriptor.atIndex(1)?.doubleValue ?? 0
                                let positionY = positionDescriptor.atIndex(2)?.doubleValue ?? 0
                                
                                let sizeWidth = sizeDescriptor.atIndex(1)?.doubleValue ?? 0
                                let sizeHeight = sizeDescriptor.atIndex(2)?.doubleValue ?? 0
                                
                                let appID = appIDDescriptor.stringValue ?? "Unknown"
                                
                                let rect = NSRect(x: positionX, y: positionY, width: sizeWidth, height: sizeHeight)
                                let dockItem = DockItem(rect: rect, appID: appID)
                                dockItems.append(dockItem)
                                
                                print("📍 Dock item: \(appID) at \(rect)")
                            }
                        }
                    }
                }
            }
            
            DispatchQueue.main.async {
                completion(dockItems)
            }
        }
    }
    
    @objc private func applicationDidActivate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            print("❌ Could not get app from notification")
            return
        }
        
        // Skip our own app
        if app.bundleIdentifier == Bundle.main.bundleIdentifier {
            print("⏭️ Skipping our own app")
            return
        }
        
        print("📱 App activated: \(app.localizedName ?? "Unknown") (\(app.bundleIdentifier ?? "unknown"))")
        print("📊 Previous app: \(previousActiveApp?.localizedName ?? "None")")
        
        // Check if this is a repeated activation (dock click on already active app)
        if let previousApp = previousActiveApp,
           previousApp.bundleIdentifier == app.bundleIdentifier {
            print("🎯 DOCK CLICK DETECTED on active app: \(app.localizedName ?? "Unknown")")
            
            // Add a small delay to ensure the app is fully activated
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.minimizeAppWindows(app)
            }
        } else {
            print("🔄 App switch detected: from \(previousActiveApp?.localizedName ?? "None") to \(app.localizedName ?? "Unknown")")
        }
        
        // Update previous app reference
        previousActiveApp = app
    }
    
    private func hideAppWithEffect(_ app: NSRunningApplication) {
        print("🎬 Hiding app with effect: \(app.localizedName ?? "Unknown")")
        
        // First try to minimize windows with animation
        self.minimizeAppWindows(app)
        
        // Small delay then hide the app
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let success = app.hide()
            print("📥 Hide result: \(success)")
        }
    }
    
    private func minimizeAppWindows(_ app: NSRunningApplication) {
        print("🔽 Attempting to minimize windows for: \(app.localizedName ?? "Unknown")")
        
        guard AXIsProcessTrusted() else {
            print("❌ No accessibility permission")
            return
        }
        
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var windowsRef: CFTypeRef?
        
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)
        
        if result == .success, let windows = windowsRef as? [AXUIElement] {
            print("📊 Found \(windows.count) windows")
            
            var hasVisibleWindows = false
            
            // First pass: check window states
            for window in windows {
                var isMinimized: CFTypeRef?
                var isVisible: CFTypeRef?
                
                AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &isMinimized)
                AXUIElementCopyAttributeValue(window, kAXHiddenAttribute as CFString, &isVisible)
                
                if let minimizedValue = isMinimized as? Bool {
                    if !minimizedValue {
                        hasVisibleWindows = true
                        break
                    }
                }
            }
            
            // Second pass: take action based on state
            for window in windows {
                var isMinimized: CFTypeRef?
                AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &isMinimized)
                
                if let minimizedValue = isMinimized as? Bool {
                    if hasVisibleWindows && !minimizedValue {
                        // If there are visible windows, minimize them
                        print("📥 Minimizing visible window")
                        AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
                    } else if !hasVisibleWindows && minimizedValue {
                        // If all windows are minimized, restore them
                        print("� Restoring minimized window")
                        AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
                    }
                }
            }
        } else {
            print("❌ Failed to get windows for app: \(result.rawValue)")
        }
    }
    
    @objc private func toggleActiveWindow() {
        print("🔄 Manual toggle requested")
        
        if let activeApp = NSWorkspace.shared.frontmostApplication {
            print("🎯 Toggling windows for: \(activeApp.localizedName ?? "Unknown")")
            _ = handleDockClick(appName: activeApp.localizedName ?? "Unknown")
        }
    }
    
    private func restartApp() {
        print("🔄 Restarting app to activate new permissions...")
        
        // Get the app's bundle path
        let appPath = Bundle.main.bundlePath
        
        // Create the restart script
        let script = """
        #!/bin/bash
        sleep 1
        open "\(appPath)"
        """
        
        // Write script to temporary file
        let tempDir = NSTemporaryDirectory()
        let scriptPath = tempDir + "restart_dockminimize.sh"
        
        do {
            try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            
            // Make script executable
            let task = Process()
            task.launchPath = "/bin/chmod"
            task.arguments = ["+x", scriptPath]
            task.launch()
            task.waitUntilExit()
            
            // Execute restart script
            let restartTask = Process()
            restartTask.launchPath = "/bin/bash"
            restartTask.arguments = [scriptPath]
            restartTask.launch()
            
            // Quit current app
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApplication.shared.terminate(self)
            }
            
        } catch {
            print("❌ Failed to create restart script: \(error)")
            // Fallback: just show a message
            showManualRestartMessage()
        }
    }
    
    private func showManualRestartMessage() {
        let alert = NSAlert()
        alert.messageText = "Permission Granted!"
        alert.informativeText = "Accessibility permission has been granted. Please quit and reopen DockMinimize to activate the dock functionality."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Quit App")
        alert.addButton(withTitle: "Continue")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSApplication.shared.terminate(self)
        }
    }
    
    @objc private func quitApp() {
        print("👋 Quitting DockMinimize")
        NSApplication.shared.terminate(self)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("🛑 App terminating")
        
        // Stop permission monitoring
        permissionTimer?.invalidate()
        permissionTimer = nil
        
        // Clean up event tap
        cleanupEventTap()
        
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}
