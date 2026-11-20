import AppKit

extension NSScreen {
    var displayID: CGDirectDisplayID { (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0 }
    var stableID: String {
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() else { return String(displayID) }
        return CFUUIDCreateString(nil,uuid) as String
    }
}
private final class DesktopWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
final class DesktopManager {
    private var windows = [String: NSWindow]()
    var hasVisibleCanvas: Bool { windows.values.contains { $0.occlusionState.contains(.visible) } }
    static var level: NSWindow.Level {
        let wallpaper = CGWindowLevelForKey(.desktopWindow), icons = CGWindowLevelForKey(.desktopIconWindow)
        return .init(rawValue: Int(min(wallpaper+1, icons-1)))
    }
    func sync(_ state: AppState, reorder: Bool = false) {
        let screens = NSScreen.screens.filter { state.prefs.enabled && !state.prefs.excludedDisplays.contains($0.stableID) }
        let ids = Set(screens.map(\.stableID))
        for id in Array(windows.keys) where !ids.contains(id) { remove(id) }
        guard let studio = state.studio else { return }
        for screen in screens {
            let id = screen.stableID
            if let window = windows[id] {
                if window.frame != screen.frame { window.setFrame(screen.frame,display: true) }
                if reorder { window.orderFrontRegardless() }
            } else {
                let window = DesktopWindow(contentRect: screen.frame,styleMask: .borderless,backing: .buffered,defer: false)
                window.title = "Resonance • \(screen.localizedName)"
                window.level = Self.level; window.isOpaque = true; window.backgroundColor = .black
                window.hasShadow = false; window.ignoresMouseEvents = true; window.isReleasedWhenClosed = false
                window.isExcludedFromWindowsMenu = true; window.animationBehavior = .none
                window.collectionBehavior = [.canJoinAllSpaces,.stationary,.ignoresCycle,.fullScreenAuxiliary]
                let canvas = CanvasView(studio: studio,state: state,desktop: true)
                window.contentView = canvas; window.setFrame(screen.frame, display: false)
                windows[id] = window; window.orderFrontRegardless(); canvas.refresh(); canvas.draw()
            }
        }
    }
    func refresh(redraw: Bool = false) {
        for w in windows.values {
            if let v = w.contentView as? CanvasView { v.refresh(); if redraw && v.isPaused && w.isVisible { v.draw() } }
        }
    }
    private func remove(_ id: String) {
        guard let w = windows.removeValue(forKey: id) else { return }
        (w.contentView as? CanvasView)?.isPaused = true
        w.orderOut(nil); w.contentView = nil; w.close()
    }
    func stop() { for id in Array(windows.keys) { remove(id) } }
}
