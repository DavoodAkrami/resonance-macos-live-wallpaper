import AppKit
import MetalKit
import QuartzCore
import SwiftUI

struct FrameUniforms {
    var canvas: SIMD4<Float>, energy: SIMD4<Float>, look: SIMD4<Float>, tint: SIMD4<Float>
    var lowSpectrum: SIMD4<Float>, highSpectrum: SIMD4<Float>
    var gesture: SIMD4<Float>
    init(size: CGSize, scene: SceneID, tuning: Tuning, motion: Motion) {
        canvas = [Float(size.width), Float(size.height), scene.isStill ? 0 : motion.time, Float(tuning.detail)]
        gesture = SIMD4(scene.supportsCursor && tuning.cursorEnabled ? motion.cursor : .zero, Float(tuning.amount))
        energy = scene.isMusical ? motion.energy : .zero
        let spectrum = scene.isMusical ? motion.spectrum : .zero
        lowSpectrum = spectrum.lowHalf; highSpectrum = spectrum.highHalf
        look = [Float(tuning.brightness), scene.isMusical ? motion.beat : 0, Float(scene.rawValue), Float(Palette.allCases.firstIndex(of: tuning.palette) ?? 0)]
        tint = SIMD4(scene.isMusical ? motion.tint : .one, 1)
    }
}
enum StudioError: LocalizedError {
    case unavailable(String)
    var errorDescription: String? { switch self { case let .unavailable(message): return message } }
}
final class MetalStudio {
    let device: MTLDevice, queue: MTLCommandQueue
    private let field: MTLRenderPipelineState, silk: MTLRenderPipelineState, metal: MTLRenderPipelineState, dust: MTLRenderPipelineState
    private let ambient: [SceneID: MTLRenderPipelineState]
    private let depth: MTLDepthStencilState
    private var plates = [SceneID: NSImage]()
    init(bundle: Bundle = .main) throws {
        guard let dev = MTLCreateSystemDefaultDevice(), let queue = dev.makeCommandQueue() else { throw StudioError.unavailable("Metal is unavailable on this display.") }
        device = dev; self.queue = queue
        let sources = try ["Scenes","Ambient","Collection","Editions"].map { name -> String in
            guard let url = bundle.url(forResource: name, withExtension: "metal") else { throw StudioError.unavailable("Missing scene library: " + name) }
            return try String(contentsOf: url,encoding:.utf8)
        }
        let lib = try dev.makeLibrary(source: sources.joined(separator:"\n"), options: nil)
        func pipeline(_ v: String, _ f: String, blend: Bool = false) throws -> MTLRenderPipelineState {
            let p = MTLRenderPipelineDescriptor()
            p.label = f; p.vertexFunction = lib.makeFunction(name: v); p.fragmentFunction = lib.makeFunction(name: f)
            p.depthAttachmentPixelFormat = .depth32Float
            let target = p.colorAttachments[0]!
            target.pixelFormat = .bgra8Unorm
            if blend { target.isBlendingEnabled = true; target.sourceRGBBlendFactor = .one; target.destinationRGBBlendFactor = .one }
            return try dev.makeRenderPipelineState(descriptor: p)
        }
        field = try pipeline("plane","atmosphere"); silk = try pipeline("sculpture","aurora")
        metal = try pipeline("sculpture","chrome"); dust = try pipeline("motes","moteLight", blend: true)
        var programs = [SceneID: MTLRenderPipelineState]()
        for scene in SceneID.allCases {
            if let fragment = scene.fragment { programs[scene] = try pipeline("plane",fragment) }
        }
        ambient = programs
        let d = MTLDepthStencilDescriptor(); d.depthCompareFunction = .lessEqual; d.isDepthWriteEnabled = true
        guard let depth = dev.makeDepthStencilState(descriptor: d) else { throw StudioError.unavailable("Metal depth testing is unavailable.") }
        self.depth = depth
    }
    func encode(_ encoder: MTLRenderCommandEncoder, frame: FrameUniforms, scene: SceneID) {
        var u = frame
        encoder.setVertexBytes(&u, length: MemoryLayout<FrameUniforms>.stride, index: 0)
        encoder.setFragmentBytes(&u, length: MemoryLayout<FrameUniforms>.stride, index: 0)
        encoder.setRenderPipelineState(ambient[scene] ?? field)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        switch scene {
        case .aurora, .chrome:
            encoder.setDepthStencilState(depth)
            encoder.setRenderPipelineState(scene == .aurora ? silk : metal)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 168*52*6)
        case .particles:
            encoder.setRenderPipelineState(dust)
            encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: 14600)
        default: break
        }
        encoder.endEncoding()
    }
    func thumbnail(_ scene: SceneID) -> NSImage? {
        if let image = plates[scene] { return image }
        guard let url = Bundle.main.url(forResource: String(scene.rawValue), withExtension: "jpg", subdirectory: "Previews"),
              let image = NSImage(contentsOf: url) else { return nil }
        plates[scene] = image; return image
    }
    func snapshot(scene: SceneID, width: Int, height: Int, motion: Motion = Motion(), tuning: Tuning = Tuning()) -> CGImage? {
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width,height: height,mipmapped: false)
        desc.usage = .renderTarget; desc.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: desc) else { return nil }
        desc.pixelFormat = .depth32Float; desc.storageMode = .private
        guard let z = device.makeTexture(descriptor: desc), let command = queue.makeCommandBuffer() else { return nil }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture; pass.colorAttachments[0].loadAction = .clear; pass.colorAttachments[0].storeAction = .store
        pass.depthAttachment.texture = z; pass.depthAttachment.loadAction = .clear; pass.depthAttachment.storeAction = .dontCare
        guard let e = command.makeRenderCommandEncoder(descriptor: pass) else { return nil }
        encode(e, frame: .init(size: .init(width: width,height: height),scene: scene,tuning: tuning,motion: motion),scene: scene)
        command.commit(); command.waitUntilCompleted()
        guard command.status == .completed else { return nil }
        var data = Data(count: width*height*4)
        data.withUnsafeMutableBytes { texture.getBytes($0.baseAddress!, bytesPerRow: width*4, from: MTLRegionMake2D(0,0,width,height), mipmapLevel: 0) }
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width*4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: [.byteOrder32Little, CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue)], provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
}

/// Each display owns its drawable and clock. All surfaces share immutable pipelines and the audio snapshot.
final class CanvasView: MTKView, MTKViewDelegate {
    private weak var state: AppState?
    private let studio: MetalStudio, desktop: Bool
    private var motion = Motion(), last = CACurrentMediaTime(), frameCount = 0, gpuMS = 0.0
    private var lastScene: SceneID?
    private var pointer = CursorMotion()
    var previewScene: SceneID?
    private var scale = 1.0
    private let inflight = DispatchSemaphore(value: 2)
    init(studio: MetalStudio, state: AppState, desktop: Bool) {
        self.studio = studio; self.state = state; self.desktop = desktop
        super.init(frame: .zero, device: studio.device)
        colorPixelFormat = .bgra8Unorm; depthStencilPixelFormat = .depth32Float
        autoResizeDrawable = false; preferredFramesPerSecond = 30; delegate = self
        clearColor = MTLClearColorMake(0.018,0.02,0.035,1); framebufferOnly = true
        isPaused = true
    }
    required init(coder: NSCoder) { fatalError("Use init(studio:state:desktop:)") }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); refresh() }
    override func layout() { super.layout(); resize() }
    private func resize() {
        let factor = min(window?.backingScaleFactor ?? 1, desktop ? 1.55 : 2) * scale
        let size = CGSize(width: max(1,round(bounds.width*factor)),height: max(1,round(bounds.height*factor)))
        if drawableSize != size { drawableSize = size; if isPaused && window?.isVisible == true { draw() } }
    }
    func refresh() {
        guard let state, let window else { isPaused = true; return }
        let p = state.prefs
        let visible = desktop ? (!p.reduceCovered || window.occlusionState.contains(.visible)) : window.occlusionState.contains(.visible)
        let scene = desktop ? p.scene : (previewScene ?? p.scene)
        let shouldPause = scene.isStill || state.suspended || p.paused || !window.isVisible || !visible || (!desktop && isHiddenOrHasHiddenAncestor)
        if isPaused != shouldPause { last = CACurrentMediaTime(); isPaused = shouldPause }
        let quiet = state.conserve || p.quality == .quiet
        let activeArt = !scene.isMusical && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let target = quiet ? 30 : (p.quality == .fluid || state.hearing || activeArt ? 60 : 30)
        let fps = (gpuMS > 14 && target == 60 && p.quality == .adaptive) ? 30 : target
        if preferredFramesPerSecond != fps { preferredFramesPerSecond = fps }
        let newScale = quiet ? 0.77 : (p.quality == .adaptive && gpuMS > 12 ? 0.83 : 1)
        if scale != newScale { scale = newScale; resize() }
    }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    func draw(in view: MTKView) {
        guard let state, bounds.width >= 1, bounds.height >= 1,
              inflight.wait(timeout: .now()) == .success else { return }
        guard let pass = currentRenderPassDescriptor, let drawable = currentDrawable, let buffer = studio.queue.makeCommandBuffer(),
              let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) else { inflight.signal(); return }
        let now = CACurrentMediaTime(), dt = Float(min(0.09, max(0,now-last))); last = now
        let p = state.prefs
        let scene = desktop ? p.scene : (previewScene ?? p.scene)
        var tuning = p[scene: scene]
        if lastScene != scene { motion = Motion(); pointer = CursorMotion(); lastScene = scene }
        let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if reduced { tuning.amount *= 0.25 }
        let elapsed: Float = p.paused || state.suspended || tuning.amount == 0 ? 0 : dt*(reduced ? 0.28 : 1)
        if scene.isMusical {
            let signal = state.capture.bus.read()
            motion.advance(dt:elapsed,signal:signal,fresh:now-signal.timestamp<0.20,
                           tuning:tuning,color:state.sceneTint(for:scene),response:p.response)
        } else { motion.time += elapsed * Float(tuning.speed) * (0.65 + 1.45 * Float(tuning.amount)) }
        if scene.supportsCursor && tuning.cursorEnabled && !reduced, let window {
            let location = convert(window.convertPoint(fromScreen:NSEvent.mouseLocation),from:nil)
            let local = bounds.contains(location) ? SIMD2<Float>(Float(location.x/bounds.width)*2-1,Float(location.y/bounds.height)*2-1) : nil
            motion.cursor = pointer.step(point:local,dt:elapsed,sensitivity:Float(tuning.cursorGain))
        } else { pointer = CursorMotion(); motion.cursor = .zero }
        studio.encode(encoder,frame:FrameUniforms(size:drawableSize,scene:scene,tuning:tuning,motion:motion),scene:scene)
        frameCount += 1
        let measure = frameCount % 45 == 0, semaphore = inflight
        buffer.addCompletedHandler { [weak self] command in
            semaphore.signal()
            if measure {
                let ms = (command.gpuEndTime-command.gpuStartTime)*1000
                DispatchQueue.main.async { self?.gpuMS = ms }
            }
        }
        buffer.present(drawable); buffer.commit()
    }
}

struct LivePreview: NSViewRepresentable {
    let state: AppState, studio: MetalStudio, scene: SceneID
    func makeNSView(context: Context) -> CanvasView {
        let v = CanvasView(studio: studio,state: state,desktop: false); v.previewScene = scene; state.preview = v; return v
    }
    func updateNSView(_ view: CanvasView, context: Context) { view.previewScene = scene; view.refresh(); if view.isPaused { view.draw() } }
    static func dismantleNSView(_ view: CanvasView, coordinator: Void) { view.isPaused = true }
}
