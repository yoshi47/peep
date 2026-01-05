import SwiftUI
import AppKit

@main
struct StickShotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        AppCoordinator.shared.start()
    }
    
    // Prevent app from terminating when last window closes
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    // Handle app termination
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        return .terminateNow
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "StickShot")
        }
        
        let menu = NSMenu()
        
        let captureItem = NSMenuItem(title: "Capture Region (⌥⌘P)", action: #selector(captureRegion), keyEquivalent: "")
        captureItem.target = self
        menu.addItem(captureItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let closeAllItem = NSMenuItem(title: "Close All Captures", action: #selector(closeAllCaptures), keyEquivalent: "")
        closeAllItem.target = self
        menu.addItem(closeAllItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit StickShot", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    @objc private func captureRegion() {
        AppCoordinator.shared.startCapture()
    }
    
    @objc private func closeAllCaptures() {
        AppCoordinator.shared.closeAllPanels()
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
