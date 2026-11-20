import AppKit
import SwiftUI
import ServiceManagement
import IOKit.ps
import QuartzCore

final class AppState: ObservableObject {
    private let store: UserDefaults
    init(store: UserDefaults = .standard) { self.store = store; self.prefs = Preferences.load(store) }
    @Published var prefs: Preferences {
        didSet {
            guard prefs != oldValue else { return }
            prefs.save(store)
            if prefs.source != oldValue.source { noSoundSince = CACurrentMediaTime() }
            if prefs.enabled != oldValue.enabled || prefs.excludedDisplays != oldValue.excludedDisplays { desktop.sync(self) }
            refreshPower(); refreshCapture(); desktop.refresh(redraw: true); preview?.refresh()
            if preview?.isPaused == true { preview?.draw() }
        }
    }
    @Published var track = Track()
    @Published var musicStatus = "Track details off"
    @Published var audioStatus = "Ambient only"
    @Published var hearing = false
    @Published var listening = false
    @Published var loginStatus = SMAppService.mainApp.status
    @Published var loginError = ""
    @Published var settingsOpen = false
    @Published var revision = 0
    @Published var suspended = false
    @Published var conserve = false
    private(set) var studio: MetalStudio?, graphicsError: String?
    let capture = Capture(), desktop = DesktopManager(), music = MusicService()
    @Published var detail: SceneID? { didSet { if oldValue != detail { refreshCapture() } } }
    func apply(_ scene: SceneID) {
        var p = prefs; p.scene = scene; p.enabled = true; p.paused = false; prefs = p
    }
    func favorite(_ scene: SceneID) {
        if prefs.favorites.contains(scene) { prefs.favorites.remove(scene) } else { prefs.favorites.insert(scene) }
    }
    private var queryingMusic = false
    weak var preview: CanvasView?
    var panelVisible = false
    private var asleep = false, onBattery = false, ticks = 0
    private var timer: Timer?, tokens = [(NotificationCenter, NSObjectProtocol)]()
    private var noSoundSince = CACurrentMediaTime(), connectionMessage = "Audio off"
    private var currentOutput = OutputRoute()
    func sceneTint(for scene: SceneID) -> SIMD3<Float> {
        guard scene.isMusical else { return .one }
        if prefs[scene:scene].palette == .track, !track.id.isEmpty { return track.color }
        if prefs.metadata, !track.title.isEmpty, prefs[scene:scene].palette == .original {
            // A restrained identity tint also works for titles without artwork.
            let h = track.title.utf8.reduce(UInt32(2166136261)) { ($0 ^ UInt32($1)) &* 16777619 }
            let phase = Float(h % 1000) / 1000 * 6.283
            return SIMD3(1+0.055*cos(phase),1+0.055*cos(phase+2.1),1+0.055*cos(phase+4.2))
        }
        return .one
    }
    func start() {
        do { studio = try MetalStudio() } catch { graphicsError = error.localizedDescription }
        capture.onStatus = { [weak self] message, live in
            guard let self else { return }
            self.connectionMessage = message; self.listening = live; self.noSoundSince = CACurrentMediaTime(); self.updateMeter()
        }
        music.onChange = { [weak self] track,status in self?.track = track; self?.musicStatus = status }
        func observe(_ center: NotificationCenter, _ name: Notification.Name, _ action: @escaping () -> Void) {
            tokens.append((center,center.addObserver(forName: name,object: nil,queue: .main) { _ in action() }))
        }
        let nc = NotificationCenter.default, ws = NSWorkspace.shared.notificationCenter
        observe(nc,NSApplication.didChangeScreenParametersNotification) { [weak self] in self?.syncDisplays() }
        observe(ws,NSWorkspace.activeSpaceDidChangeNotification) { [weak self] in self?.syncDisplays() }
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            observe(ws,name) { [weak self] in self?.sleep(true, reason: name) }
        }
        for name in [NSWorkspace.didWakeNotification,NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            observe(ws,name) { [weak self] in self?.sleep(false, reason: name) }
        }
        refreshPower(); desktop.sync(self); refreshCapture()
        let timer = Timer(timeInterval: 1.0,repeats: true) { [weak self] _ in self?.tick() }
        timer.tolerance = 0.15; RunLoop.main.add(timer,forMode: .common); self.timer = timer
    }
    private var sleepReasons = Set<Int>()
    private func sleep(_ value: Bool, reason: Notification.Name) {
        let groups = [[NSWorkspace.willSleepNotification,NSWorkspace.didWakeNotification],[NSWorkspace.screensDidSleepNotification,NSWorkspace.screensDidWakeNotification],[NSWorkspace.sessionDidResignActiveNotification,NSWorkspace.sessionDidBecomeActiveNotification]]
        let key = groups.firstIndex { $0.contains(reason) } ?? 0
        if value { sleepReasons.insert(key) } else { sleepReasons.remove(key) }
        asleep = !sleepReasons.isEmpty
        refreshPower(); syncDisplays()
    }
    func syncDisplays() { desktop.sync(self,reorder: true); revision += 1; desktop.refresh(); preview?.refresh(); refreshCapture() }
    func setPanelVisible(_ visible: Bool) { panelVisible = visible; preview?.refresh(); refreshCapture() }
    func refreshCapture(force: Bool = false) {
        let wallpaperVisible = prefs.enabled && (prefs.reduceCovered ? desktop.hasVisibleCanvas : NSScreen.screens.contains { !prefs.excludedDisplays.contains($0.stableID) })
        let previewMusic = panelVisible && !settingsOpen && detail?.isMusical == true
        let musicConsumer = (prefs.scene.isMusical && (wallpaperVisible || (panelVisible && settingsOpen))) || previewMusic
        let wantsDetails = musicConsumer && prefs.metadata && !suspended
        if wantsDetails != queryingMusic {
            queryingMusic = wantsDetails; music.reset(); track = Track(); musicStatus = "Track details off"
            if wantsDetails { music.refresh() }
        }
        let needed = musicConsumer && !suspended && !prefs.paused && prefs.source != .ambient
        // The settings pane is also a consumer: it shows the live connection and level.
        if needed && capture.key == nil {currentOutput = outputRoute()}
        let key = needed ? CaptureKey(source: prefs.source,musicPID: prefs.source == .music ? MusicService.runningPID : nil,route: currentOutput) : nil
        capture.reconcile(key, force: force); updateMeter()
    }
    private func tick() {
        ticks += 1
        if ticks % 3 == 0 {
            refreshPower(); if capture.key != nil {currentOutput = outputRoute()}
            let login = SMAppService.mainApp.status; if loginStatus != login { loginStatus = login }
        }
        if ticks % 6 == 0 && queryingMusic { music.refresh() }
        let musicOutputAppeared = ticks % 6 == 0 && connectionMessage.hasPrefix("Music has no audio output")
        refreshCapture(force: musicOutputAppeared); desktop.refresh(); preview?.refresh()
    }
    private func updateMeter() {
        let sig = capture.bus.read(), now = CACurrentMediaTime()
        let hasSound = listening && now-sig.timestamp < 0.65 && sig.rms > 0.00025
        if hearing != hasSound { hearing = hasSound }
        if hasSound { noSoundSince = now }
        let message: String
        if !prefs.scene.isMusical && !(panelVisible && detail?.isMusical == true && !settingsOpen) { message = "Ambient artwork" }
        else if prefs.source == .ambient { message = "Ambient only" }
        else if capture.key == nil { message = "Capture paused" }
        else if hasSound { message = "Receiving audio" }
        else if listening { message = now-noSoundSince > 4 ? "No audible PCM. Playback may be quiet, protected, or missing capture access." : "Waiting for sound" }
        else { message = connectionMessage }
        if audioStatus != message { audioStatus = message }
    }
    private func refreshPower() {
        if let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() {
            onBattery = (IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String?) == kIOPSBatteryPowerValue
        }
        let process = ProcessInfo.processInfo
        let idle = asleep || (onBattery && prefs.pauseOnBattery)
        let saving = process.isLowPowerModeEnabled || process.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue || (prefs.batterySaver && onBattery)
        if suspended != idle { suspended = idle }
        if conserve != saving { conserve = saving }
    }
    func login(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = ""
        } catch { loginError = error.localizedDescription }
        loginStatus = SMAppService.mainApp.status
    }
    func reset() {
        if loginStatus == .enabled || loginStatus == .requiresApproval { login(false) }
        var defaults = Preferences(); defaults.introduced = true; defaults.favorites = prefs.favorites; prefs = defaults
    }
    func reconnect() { refreshCapture(force: true); if queryingMusic { music.reset(); music.refresh() } }
    func shutdown() {
        timer?.invalidate(); timer = nil
        for (center,token) in tokens { center.removeObserver(token) }; tokens.removeAll()
        preview?.isPaused = true; desktop.stop(); capture.shutdown()
    }
}
