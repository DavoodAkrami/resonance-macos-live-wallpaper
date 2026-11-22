import XCTest
import AVFAudio
import Accelerate
import CoreServices
import Metal
@testable import Resonance

final class ResonanceTests: XCTestCase {
    private func feed(_ samples: [Float], _ analyzer: Analyzer) -> [Signal] {
        var frames = [Signal]()
        samples.withUnsafeBufferPointer { analyzer.consume($0) { frames.append($0) } }
        return frames
    }
    private func tone(_ hz: Double, level: Float = 0.4) -> [Float] {
        (0..<24000).map { level*Float(sin(Double($0)*2*Double.pi*hz/48000)) }
    }
    func testFrequencyBandsAndNormalization() {
        for (index,hz) in [94.0,980,8400].enumerated() {
            let s = feed(tone(hz),Analyzer(rate: 48000)).last!
            XCTAssertGreaterThan(s.bands[index],0.93)
            for other in 0..<3 where other != index { XCTAssertLessThan(s.bands[other],0.05) }
            XCTAssertLessThanOrEqual(s.bands.max(),1); XCTAssertEqual(s.rms,0.283,accuracy: 0.01)
        }
    }
    func testReleaseSilenceAndOnset() {
        let a = Analyzer(rate: 48000)
        let first = feed(tone(125),a)
        XCTAssertGreaterThan(first.map(\.onset).max()!,0.9)
        let quiet = feed([Float](repeating: 0,count: 96000),a)
        XCTAssertGreaterThan(quiet[2].bands.x,0.2)
        XCTAssertLessThan(quiet.last!.bands.max(),0.005); XCTAssertEqual(quiet.last!.rms,0)
        XCTAssertEqual(feed([Float](repeating: 0,count: 4096),Analyzer(rate: 44100)).last!.onset,0)
    }
    func testFragmentedInput() {
        let pcm = tone(330), a = Analyzer(rate: 48000)
        let reference = feed(pcm,Analyzer(rate: 48000))
        var split = [Signal]()
        for k in stride(from: 0,to: pcm.count,by: 137) { split += feed(Array(pcm[k..<min(k+137,pcm.count)]),a) }
        XCTAssertEqual(split.map(\.bands),reference.map(\.bands))
    }
    func testPreferencesRoundTripAndClamping() {
        let domain = "ResonanceTests."+UUID().uuidString, store = UserDefaults(suiteName: domain)!
        defer { store.removePersistentDomain(forName: domain) }
        var p = Preferences(); p.scene = .chrome; p.tuning.speed = 30; p.tuning.intensity = -1
        p.excludedDisplays = ["display"]; p.source = .system; p.save(store)
        XCTAssertEqual(Preferences.load(store),p); XCTAssertEqual(p.tuning.speed,2); XCTAssertEqual(p.tuning.intensity,0)
        p.scene = .particles; XCTAssertEqual(p.tuning,Tuning())
        store.set(Data("invalid".utf8),forKey: Preferences.key); XCTAssertEqual(Preferences.load(store),Preferences())
    }
    func testMusicPropertyParsing() {
        let properties = NSAppleEventDescriptor.record()
        properties.setDescriptor(.init(string: "夜 · Tide"),forKeyword: 0x706e616d)
        properties.setDescriptor(.init(string: "Artist"),forKeyword: 0x70417274)
        properties.setDescriptor(.init(double: 184.3),forKeyword: 0x70447572)
        let track = Track.parse(properties: properties)
        XCTAssertEqual(track.title,"夜 · Tide"); XCTAssertEqual(track.artist,"Artist"); XCTAssertEqual(track.duration,184.3); XCTAssertEqual(track.album,"")
    }
    func testRendererIdleAndTransitions() {
        var m = Motion(); let t = Tuning(), s = Signal(bands: .one,onset: 1)
        m.advance(dt: 0.02,signal:s,fresh:true,tuning:t,color:[1,0.7,0.6])
        XCTAssertGreaterThan(m.energy.x,0); XCTAssertLessThan(m.energy.x,0.78); XCTAssertGreaterThan(m.tint.y,0.7)
        let initial = m.time
        let peak = m.energy.x
        m.advance(dt: 1/60,signal:s,fresh:false,tuning:t,color:.one)
        XCTAssertGreaterThan(m.energy.x,peak*0.97)
        for _ in 0..<300 { m.advance(dt: 1/60,signal:s,fresh:false,tuning:t,color:.one) }
        XCTAssertLessThan(m.energy.x,0.001); XCTAssertGreaterThan(m.time,initial)
        let frozen = m.time; m.advance(dt:0,signal:s,fresh:true,tuning:t,color:.one); XCTAssertEqual(m.time,frozen)
    }
    func testMetalScenesProduceDistinctAnimatedAudioReactiveFrames() throws {
        let studio = try MetalStudio()
        var reactive = Motion(); reactive.energy = .one; reactive.beat = 1
        var later = Motion(); later.time = 5
        var identities = Set<Data>()
        for scene in SceneID.allCases {
            func pixels(_ motion: Motion) throws -> Data {
                let image = try XCTUnwrap(studio.snapshot(scene:scene,width:384,height:216,motion:motion))
                return try XCTUnwrap(image.dataProvider?.data) as Data
            }
            let initial = try pixels(Motion()); identities.insert(initial)
            if scene.isMusical { XCTAssertNotEqual(initial,try pixels(reactive),scene.title) }
            else {
                reactive.tint = [0.3,0.6,0.2]; reactive.spectrum = .one
                XCTAssertEqual(initial,try pixels(reactive),scene.title)
            }
            if scene.isStill { XCTAssertEqual(initial,try pixels(later),scene.title) }
            else { XCTAssertNotEqual(initial,try pixels(later),scene.title) }
            let values = stride(from:0,to:initial.count,by:4).map { initial[$0] }
            XCTAssertGreaterThan(Int(values.max()!) - Int(values.min()!),20,scene.title)
        }
        XCTAssertEqual(identities.count,SceneID.allCases.count)
    }
}

extension ResonanceTests {
    @MainActor
    func testWindowServerOrderingAndRestoration() throws {
        let domain = "ResonanceDesktopTests."+UUID().uuidString
        let store = UserDefaults(suiteName: domain)!
        defer { store.removePersistentDomain(forName: domain) }
        let state = AppState(store: store)
        state.start(); defer { state.shutdown() }
        XCTAssertNil(state.graphicsError)
        let screens = NSScreen.screens
        XCTAssertFalse(screens.isEmpty)
        func windows() -> [NSWindow] { NSApp.windows.filter { $0.isVisible && $0.contentView is CanvasView } }
        func layerList() -> [[String:Any]] {
            CGWindowListCopyWindowInfo(.optionOnScreenOnly,kCGNullWindowID) as? [[String:Any]] ?? []
        }
        XCTAssertEqual(windows().count,screens.count)
        for w in windows() {
            XCTAssertTrue(w.ignoresMouseEvents); XCTAssertFalse(w.canBecomeKey); XCTAssertFalse(w.canBecomeMain)
            XCTAssertTrue(w.collectionBehavior.contains(.canJoinAllSpaces))
            let deadline = Date().addingTimeInterval(2)
            while !layerList().contains(where: { ($0[kCGWindowNumber as String] as? Int) == w.windowNumber }), Date() < deadline {
                RunLoop.main.run(until: Date().addingTimeInterval(0.04))
            }
            let ordered = layerList()
            print("Exposed windows: \(ordered.count); own window \(w.windowNumber), visible \(w.occlusionState.contains(.visible)), level \(w.level.rawValue)")
            let index = try XCTUnwrap(ordered.firstIndex { ($0[kCGWindowNumber as String] as? Int) == w.windowNumber })
            let layer = try XCTUnwrap(ordered[index][kCGWindowLayer as String] as? Int)
            XCTAssertEqual(layer,DesktopManager.level.rawValue)
            XCTAssertLessThan(layer,Int(CGWindowLevelForKey(.desktopIconWindow)))
            XCTAssertGreaterThan(layer,Int(CGWindowLevelForKey(.desktopWindow)))
            let neighbors = ordered.filter { abs(($0[kCGWindowLayer as String] as? Int ?? 0) - layer) <= 30 }.map { "\($0[kCGWindowOwnerName as String] ?? "?") \($0[kCGWindowLayer as String] ?? "?")" }
            print("Desktop stacking, front to back: \(neighbors.joined(separator: ", "))")
            if let icons = ordered.firstIndex(where: { ($0[kCGWindowOwnerName as String] as? String) == "Finder" && ($0[kCGWindowLayer as String] as? Int) == Int(CGWindowLevelForKey(.desktopIconWindow)) }) { XCTAssertLessThan(icons,index) }
        }
        state.prefs.excludedDisplays.insert(screens[0].stableID)
        XCTAssertEqual(windows().count,screens.count-1)
        state.prefs.excludedDisplays.removeAll()
        XCTAssertEqual(windows().count,screens.count)
        let ids = Set(windows().map(\.windowNumber))
        state.prefs.enabled = false
        XCTAssertTrue(windows().isEmpty)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertFalse(layerList().contains { ids.contains($0[kCGWindowNumber as String] as? Int ?? -1) })
    }
    func testGPUFrameTimingAndVisualPlates() throws {
        let s = try MetalStudio(), width = 1920, height = 1080
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.bgra8Unorm,width:width,height:height,mipmapped:false)
        descriptor.storageMode = .private; descriptor.usage = .renderTarget
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = try XCTUnwrap(s.device.makeTexture(descriptor:descriptor))
        pass.colorAttachments[0].loadAction = .clear; pass.colorAttachments[0].storeAction = .store
        descriptor.pixelFormat = .depth32Float
        pass.depthAttachment.texture = try XCTUnwrap(s.device.makeTexture(descriptor:descriptor))
        pass.depthAttachment.loadAction = .clear; pass.depthAttachment.storeAction = .dontCare
        for scene in SceneID.allCases {
            var times = [Double]()
            for n in 0..<26 {
                let buffer = try XCTUnwrap(s.queue.makeCommandBuffer())
                let encoder = try XCTUnwrap(buffer.makeRenderCommandEncoder(descriptor:pass))
                var m = Motion(); m.time = Float(n)/60; m.energy = [0.3,0.2,0.1,0.4]
                s.encode(encoder,frame:.init(size:.init(width:width,height:height),scene:scene,tuning:Tuning(),motion:m),scene:scene)
                buffer.commit(); buffer.waitUntilCompleted()
                XCTAssertEqual(buffer.status,.completed)
                if n > 5 { times.append((buffer.gpuEndTime-buffer.gpuStartTime)*1000) }
            }
            print(String(format:"1080p offscreen GPU %@ median %.2f ms, p95 %.2f ms",scene.title,times.sorted()[10],times.sorted()[18]))
            let cg = try XCTUnwrap(s.snapshot(scene:scene,width:960,height:540))
            let attachment = XCTAttachment(image:NSImage(cgImage:cg,size:.init(width:960,height:540)))
            attachment.name = scene.title; attachment.lifetime = .keepAlways; add(attachment)
        }
    }
}

extension ResonanceTests {
    @MainActor
    func testLoginLaunchKeepsStudioClosedUntilRequested() throws {
        let event = NSAppleEventDescriptor(eventClass: kCoreEventClass, eventID: kAEOpenApplication,
                                          targetDescriptor: nil, returnID: -1, transactionID: 0)
        XCTAssertFalse(AppDelegate.isLoginLaunch(nil))
        XCTAssertFalse(AppDelegate.isLoginLaunch(event))
        event.setParam(NSAppleEventDescriptor(enumCode: keyAELaunchedAsServiceItem), forKeyword: keyAEPropData)
        XCTAssertFalse(AppDelegate.isLoginLaunch(event))
        event.setParam(NSAppleEventDescriptor(enumCode: keyAELaunchedAsLogInItem), forKeyword: keyAEPropData)
        XCTAssertTrue(AppDelegate.isLoginLaunch(event))

        let domain = "ResonanceLoginTests." + UUID().uuidString
        let store = try XCTUnwrap(UserDefaults(suiteName: domain))
        defer { store.removePersistentDomain(forName: domain) }
        let state = AppState(store: store)
        state.prefs.enabled = false
        let controller = AppDelegate(state: state)
        controller.startStudio(launchedAtLogin: AppDelegate.isLoginLaunch(event))
        defer { controller.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification)) }
        XCTAssertFalse(state.prefs.introduced)
        XCTAssertFalse(state.panelVisible)

        let menu = NSMenu()
        controller.menuNeedsUpdate(menu)
        let openItem = try XCTUnwrap(menu.item(withTitle: "Open Resonance"))
        XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(openItem.action), to: openItem.target, from: openItem))
        XCTAssertTrue(state.panelVisible)
        let panel = try XCTUnwrap(NSApp.windows.first { $0.title == "Resonance" && $0.isVisible })
        panel.close()
    }

    @MainActor
    func testMenuActionsAndClosedStudioLifecycle() throws {
        let domain = "ResonanceMenuTests."+UUID().uuidString
        let store = UserDefaults(suiteName: domain)!
        defer { store.removePersistentDomain(forName: domain) }
        var p = Preferences(); p.introduced = true; p.save(store)
        let state = AppState(store:store), controller = AppDelegate(state:state)
        controller.startStudio()
        defer { controller.applicationWillTerminate(Notification(name:NSApplication.willTerminateNotification)) }
        let menu = NSMenu(); controller.menuNeedsUpdate(menu)
        func click(_ name:String) throws {
            let item = try XCTUnwrap(menu.item(withTitle:name))
            XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(item.action),to:item.target,from:item))
            controller.menuNeedsUpdate(menu)
        }
        try click("Next scene"); XCTAssertEqual(state.prefs.scene,.particles)
        try click("Previous scene"); XCTAssertEqual(state.prefs.scene,.aurora)
        try click("Pause animations"); XCTAssertTrue(state.prefs.paused)
        try click("Resume animations"); XCTAssertFalse(state.prefs.paused)
        try click("Open Resonance")
        let panel = try XCTUnwrap(NSApp.windows.first { $0.title == "Resonance" && $0.isVisible })
        panel.close()
        XCTAssertTrue(NSApp.windows.contains { $0.contentView is CanvasView && $0.isVisible })
        try click("Restore normal desktop")
        XCTAssertFalse(NSApp.windows.contains { $0.contentView is CanvasView && $0.isVisible })
        try click("Settings…"); XCTAssertTrue(panel.isVisible); XCTAssertTrue(state.settingsOpen)
        panel.close()
    }
}

extension ResonanceTests {
    /// Compare at a fixed animation phase so the measured change can only come from PCM.
    private func rhythmicPair() -> (Motion, Motion) {
        let analyzer = Analyzer(rate: 48000)
        var motion = Motion(), before = Motion(), after = Motion()
        for hop in 0..<192 {
            let pcm = (0..<512).map { sample -> Float in
                let seconds = Double(hop*512+sample)/48000
                let phase = seconds.truncatingRemainder(dividingBy: 0.5)
                let pad = 0.024*sin(2*Double.pi*380*seconds) + 0.008*sin(2*Double.pi*1570*seconds)
                let kick = 0.24*exp(-phase*24)*sin(2*Double.pi*85*seconds)
                let hat = 0.045*exp(-phase*55)*sin(2*Double.pi*7620*seconds)
                return Float(pad+kick+hat)
            }
            var latest: Signal?
            pcm.withUnsafeBufferPointer { analyzer.consume($0) { latest = $0 } }
            if let latest {
                motion.advance(dt:Float(Analyzer.hop)/analyzer.rate,signal:latest,fresh:true,tuning:Tuning(),color:.one)
            }
            if hop == 139 { before = motion }
            if hop == 146 { after = motion }
        }
        before.time = 1; after.time = 1
        return (before,after)
    }

    func testMeasuredPCMChangesEachMusicScene() throws {
        let studio = try MetalStudio(), (before, after) = rhythmicPair()
        for scene in SceneID.allCases.filter(\.isMusical) {
            func frame(_ m: Motion) throws -> Data {
                let image = try XCTUnwrap(studio.snapshot(scene:scene,width:640,height:360,motion:m))
                return try XCTUnwrap(image.dataProvider?.data) as Data
            }
            let a = try frame(before), b = try frame(after)
            var changed = 0
            for i in stride(from:0,to:a.count,by:4) {
                let diff = (0..<3).map { abs(Int(a[i+$0])-Int(b[i+$0])) }.max()!
                if diff >= 10 { changed += 1 }
            }
            let fraction = Double(changed)/Double(a.count/4)
            let previousRelease: [SceneID:Double] = [.aurora:0.442,.particles:0.176,.chrome:0.292,.cosmic:0.465,.minimal:0.057]
            XCTAssertNotEqual(a,b,scene.title)
            if previousRelease[scene] != nil || scene.rawValue >= SceneID.yuzu.rawValue {
                XCTAssertGreaterThan(fraction,0.0001,scene.title)
            }
            if let baseline = previousRelease[scene] { XCTAssertLessThan(fraction,baseline*0.75,scene.title) }
            print(String(format:"PCM beat change %@ %.3f%%",scene.title,100*fraction))
        }
    }
}

extension ResonanceTests {
    @MainActor
    func testAmbientArtReleasesAudioAndKeepsPreferredSource() {
        let domain = "ResonanceAmbientTests."+UUID().uuidString
        let store = UserDefaults(suiteName:domain)!
        defer { store.removePersistentDomain(forName:domain) }
        let state = AppState(store:store)
        var prefs = Preferences(); prefs.scene = .obsidian; prefs.source = .music; prefs.metadata = true
        state.prefs = prefs
        state.setPanelVisible(true)
        for scene in SceneID.allCases.filter({ !$0.isMusical }) {
            state.prefs.scene = scene
            XCTAssertNil(state.capture.key)
            XCTAssertFalse(state.prefs.readMusic)
            XCTAssertEqual(state.audioStatus,"Ambient artwork")
            XCTAssertEqual(state.prefs.source,.music)
        }
        state.setPanelVisible(false); state.prefs.enabled = false
        state.prefs.metadata = false; state.prefs.scene = .chrome
        XCTAssertEqual(state.prefs.source,.music)
    }
    func testSpectrumSeparatesQuietBassFromTreble() {
        let low = feed(tone(94,level:0.012),Analyzer(rate:48000)).last!
        let high = feed(tone(8400,level:0.012),Analyzer(rate:48000)).last!
        XCTAssertGreaterThan(low.spectrum[1],0.35); XCTAssertLessThan(low.spectrum[7],0.01)
        XCTAssertGreaterThan(high.spectrum[7],0.35); XCTAssertLessThan(high.spectrum[1],0.01)
    }
}

extension ResonanceTests {
    func testRecordedQuietSynthBassChoirAndBeat() throws {
        let base = URL(fileURLWithPath:"/Library/Audio/Apple Loops/Apple")
        let clips = ["02 Electro House/Delicate Synth Layers", "02 Electro House/Rolling Bass",
                     "01 Hip Hop/City of Angeles Choir", "02 Electro House/Four Four Beat"]
        for (index, name) in clips.enumerated() {
            let url = base.appendingPathComponent(name).appendingPathExtension("caf")
            try XCTSkipUnless(FileManager.default.fileExists(atPath:url.path), "Local Apple Loops library is optional")
            let file = try AVAudioFile(forReading:url)
            let rate = file.processingFormat.sampleRate
            let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat:file.processingFormat,frameCapacity:AVAudioFrameCount(rate*4)))
            try file.read(into:buffer)
            let channels = try XCTUnwrap(buffer.floatChannelData)
            let count = Int(buffer.format.channelCount)
            let mono = (0..<Int(buffer.frameLength)).map { i in
                (0..<count).reduce(Float.zero) { $0 + channels[$1][i] } * (index == 0 ? 0.04 : 1) / Float(count)
            }
            let frames = feed(mono,Analyzer(rate:rate))
            let dt = Float(Analyzer.hop)/Float(rate)
            var m = Motion(), peak: Float = 0
            for signal in frames {
                let before = m.energy
                m.advance(dt:dt,signal:signal,fresh:true,tuning:Tuning(),color:.one)
                peak = max(peak,m.energy.max())
                XCTAssertLessThan((m.energy-before).max(),dt*1.3)
            }
            XCTAssertGreaterThan(peak,0.025,name)
            XCTAssertLessThanOrEqual(peak,Reactivity.balanced.gain)
            let last = m.energy
            for _ in 0..<360 { m.advance(dt:1/60,signal:Signal(),fresh:false,tuning:Tuning(),color:.one) }
            XCTAssertLessThan(m.energy.max(),last.max()*0.011)
            for signal in frames { m.advance(dt:dt,signal:signal,fresh:true,tuning:Tuning(),color:.one) }
            XCTAssertGreaterThan(m.energy.max(),0.02,name)
            print("Recorded PCM \(name): peak envelope \(peak)")
        }
    }
    func testReactivitySettingsOrderAndIndependentAmbientClock() {
        var peaks = [Float]()
        for response in Reactivity.allCases {
            var m = Motion()
            for _ in 0..<60 { m.advance(dt:1/60,signal:Signal(bands:.one,onset:1),fresh:true,tuning:Tuning(),color:.one,response:response) }
            peaks.append(m.energy.x)
            XCTAssertLessThan(m.beat,response.gain*0.28)
        }
        XCTAssertLessThan(peaks[0],peaks[1]); XCTAssertLessThan(peaks[1],peaks[2])
        var silent = Motion(); silent.advance(dt:1,signal:Signal(),fresh:false,tuning:Tuning(),color:.one)
        XCTAssertGreaterThan(silent.time,0); XCTAssertEqual(silent.energy,.zero)
    }
    func testCursorSpringAndRenderedInteraction() throws {
        let studio = try MetalStudio(), size = CGSize(width:240,height:135)
        var spring = CursorMotion()
        XCTAssertEqual(spring.step(point:.zero,dt:1/60,sensitivity:0.8),.zero)
        let first = spring.step(point:[0.5,0.3],dt:1/60,sensitivity:0.8)
        XCTAssertLessThan(first.z,0.003)
        var m = Motion()
        for _ in 0..<60 { m.cursor = spring.step(point:[0.5,0.3],dt:1/60,sensitivity:0.8) }
        XCTAssertGreaterThan(m.cursor.z,0.6); XCTAssertLessThanOrEqual(m.cursor.z,0.8)
        var off = Tuning(); off.cursorEnabled = false
        for scene in SceneID.allCases {
            let disabled = FrameUniforms(size:size,scene:scene,tuning:off,motion:m)
            XCTAssertEqual(disabled.gesture.z,0)
            let on = FrameUniforms(size:size,scene:scene,tuning:Tuning(),motion:m)
            if !scene.supportsCursor { XCTAssertEqual(on.gesture.z,0); continue }
            func data(_ tuning:Tuning) throws -> Data {
                let image = try XCTUnwrap(studio.snapshot(scene:scene,width:240,height:135,motion:m,tuning:tuning))
                return try XCTUnwrap(image.dataProvider?.data) as Data
            }
            XCTAssertNotEqual(try data(Tuning()),try data(off),scene.title)
        }
        for _ in 0..<480 { m.cursor = spring.step(point:[0.5,0.3],dt:1/60,sensitivity:0.8) }
        XCTAssertLessThan(m.cursor.z,0.001)
    }
    @MainActor func testLegacyLibraryMigrationAndPreviewApply() throws {
        let domain = "LibraryMigration."+UUID().uuidString, store = UserDefaults(suiteName:domain)!
        defer { store.removePersistentDomain(forName:domain) }
        var p = Preferences(); p.introduced = true; p.enabled = false; p.scene = .glass; p.tuning.speed = 0.38
        p.save(store)
        let legacy = try XCTUnwrap(store.data(forKey:Preferences.key))
        XCTAssertFalse(String(decoding:legacy,as:UTF8.self).contains("responseStyle"))
        let s = AppState(store:store)
        XCTAssertEqual(s.prefs.response,.balanced); XCTAssertEqual(s.prefs.tuning.speed,0.38)
        s.detail = .nacre; s.favorite(.nacre)
        XCTAssertEqual(s.prefs.scene,.glass); XCTAssertFalse(s.prefs.enabled)
        s.prefs[scene:.nacre].cursorEnabled = false; s.prefs.response = .subtle
        s.apply(.nacre); defer {s.shutdown()}
        let reload = Preferences.load(store)
        XCTAssertTrue(reload.enabled); XCTAssertEqual(reload.scene,.nacre); XCTAssertEqual(reload.favorites,[.nacre])
        XCTAssertFalse(reload.tuning.cursorEnabled); XCTAssertEqual(reload.response,.subtle); XCTAssertEqual(reload[scene:.glass].speed,0.38)
    }
}

extension ResonanceTests {
    func testRetiredSceneMigrationAndMenuCycle() throws {
        let domain = "RetiredArt."+UUID().uuidString, store = UserDefaults(suiteName:domain)!
        defer {store.removePersistentDomain(forName:domain)}
        var old = Preferences()
        old.source = .system; old.paused = true; old.enabled = false; old.introduced = true
        old[scene:.glass].brightness = 0.57; old.save(store)
        let data = try XCTUnwrap(store.data(forKey:Preferences.key))
        var dictionary = try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
        for retired in [5,6,7,8,9,15,16,19,20,23] {
            dictionary["scene"] = retired
            dictionary["savedFavorites"] = [SceneID.glass.rawValue, retired]
            store.set(try JSONSerialization.data(withJSONObject:dictionary),forKey:Preferences.key)
            let loaded = Preferences.load(store)
            XCTAssertEqual(loaded.scene,.obsidian); XCTAssertEqual(loaded.favorites,[.glass])
            XCTAssertEqual(loaded.source,.system); XCTAssertTrue(loaded.paused); XCTAssertFalse(loaded.enabled)
            XCTAssertEqual(loaded[scene:.glass].brightness,0.57)
        }
        var visited = Set<SceneID>(), scene = SceneID.aurora
        repeat { XCTAssertTrue(visited.insert(scene).inserted); XCTAssertEqual(scene.step(1).step(-1),scene); scene = scene.step(1) } while scene != .aurora
        XCTAssertEqual(visited,Set(SceneID.allCases)); XCTAssertEqual(visited.count,65)
        XCTAssertEqual(visited.filter(\.isMusical).count,20)
    }

    func testPaletteRenderingAndContinuousMotion() throws {
        let studio = try MetalStudio()
        func pixels(_ scene:SceneID, palette:Palette = .original, time:Float = 0) throws -> Data {
            var motion = Motion(), tuning = Tuning(); motion.time = time; tuning.palette = palette
            let cg = try XCTUnwrap(studio.snapshot(scene:scene,width:192,height:108,motion:motion,tuning:tuning))
            return try XCTUnwrap(cg.dataProvider?.data) as Data
        }
        func difference(_ a:Data,_ b:Data) -> Double {
            var total = 0
            for i in stride(from:0,to:a.count,by:4) {
                for j in 0..<3 {total += abs(Int(a[i+j])-Int(b[i+j]))}
            }
            return Double(total)/Double(a.count/4*3)
        }
        for scene in SceneID.allCases {
            var looks = Set<Data>()
            for palette in Palette.allCases where palette != .track {
                XCTAssertTrue(looks.insert(try pixels(scene,palette:palette)).inserted,"\(scene.title), \(palette.rawValue)")
            }
            if scene.rawValue >= 25 && !scene.isStill {
                let base = try pixels(scene,time:4), next = try pixels(scene,time:4+1/60)
                let step = difference(base,next), passage = difference(base,try pixels(scene,time:8))
                XCTAssertGreaterThan(step,0,scene.title); XCTAssertLessThan(step,2.0,scene.title)
                XCTAssertGreaterThan(passage,1.5,scene.title)
                print(String(format:"Motion %@ mean RGB step %.3f, passage %.2f",scene.title,step,passage))
            }
        }
    }
}
