import AppKit
import CoreServices
import SwiftUI

@main
enum ResonanceApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    private let state: AppState
    init(state: AppState = AppState()) { self.state = state; super.init() }
    private var item: NSStatusItem?, panel: NSWindow?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil || NSClassFromString("XCTestCase") != nil { return }
        startStudio(launchedAtLogin: Self.isLoginLaunch(NSAppleEventManager.shared().currentAppleEvent))
    }

    static func isLoginLaunch(_ event: NSAppleEventDescriptor?) -> Bool {
        guard let event, event.eventClass == kCoreEventClass, event.eventID == kAEOpenApplication else { return false }
        return event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }

    func startStudio(launchedAtLogin: Bool = false) {
        let menu = NSMenu()
        menu.delegate = self
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "waveform.path.ecg", accessibilityDescription: "Resonance")
        item.button?.toolTip = "Resonance"; item.menu = menu; self.item = item
        state.start()
        if !launchedAtLogin && (!state.prefs.introduced || state.graphicsError != nil) { showPanel() }
    }
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        func entry(_ s: String, _ sel: Selector?, _ key: String = "") {
            let i = NSMenuItem(title: s,action: sel,keyEquivalent: key); i.target = self; menu.addItem(i)
        }
        entry("Open Resonance",#selector(openStudio)); entry("Settings…",#selector(settings),",")
        menu.addItem(.separator()); entry(state.prefs.scene.title,nil)
        entry("Previous scene",#selector(previous)); entry("Next scene",#selector(next))
        entry(state.prefs.paused ? "Resume animations" : "Pause animations",#selector(pause))
        entry(state.prefs.enabled ? "Restore normal desktop" : "Enable live wallpaper",#selector(toggleDesktop))
        menu.addItem(.separator()); entry(state.hearing ? "\(state.prefs.source.rawValue) · Receiving audio" : state.audioStatus,nil)
        menu.addItem(.separator()); entry("Quit Resonance",#selector(quit),"q")
    }
    @objc private func openStudio() { state.settingsOpen = false; showPanel() }
    @objc private func settings() { state.settingsOpen = true; showPanel() }
    @objc private func previous() { state.prefs.scene = state.prefs.scene.step(-1) }
    @objc private func next() { state.prefs.scene = state.prefs.scene.step(1) }
    @objc private func pause() { state.prefs.paused.toggle() }
    @objc private func toggleDesktop() { state.prefs.enabled.toggle() }
    @objc private func quit() { NSApp.terminate(nil) }
    func showPanel() {
        if panel == nil {
            let w = NSWindow(contentRect: NSRect(x: 0,y: 0,width: 1130,height: 760),styleMask: [.titled,.closable,.miniaturizable,.resizable,.fullSizeContentView],backing: .buffered,defer: false)
            w.title = "Resonance"; w.titleVisibility = .visible; w.toolbarStyle = .unified
            w.isMovableByWindowBackground = true; w.isReleasedWhenClosed = false; w.minSize = NSSize(width: 850,height: 590)
            w.backgroundColor = .windowBackgroundColor
            w.contentViewController = NSHostingController(rootView: Dashboard(state: state)); w.delegate = self
            w.center(); w.setFrameAutosaveName("Resonance.Studio"); panel = w
        }
        NSApp.activate(ignoringOtherApps: true); panel?.makeKeyAndOrderFront(nil); state.setPanelVisible(true)
    }
    func windowDidChangeOcclusionState(_ notification: Notification) { state.setPanelVisible(panel?.occlusionState.contains(.visible) == true) }
    func windowWillClose(_ notification: Notification) { state.setPanelVisible(false) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showPanel(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { state.shutdown(); if let item { NSStatusBar.system.removeStatusItem(item) } }
}
