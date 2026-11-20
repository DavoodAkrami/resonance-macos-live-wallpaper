import AppKit
import CoreAudio
import QuartzCore

private func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
    .init(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
}
func outputRoute() -> OutputRoute {
    var id = AudioObjectID(0), size = UInt32(MemoryLayout<AudioObjectID>.size), a = address(kAudioHardwarePropertyDefaultOutputDevice)
    _ = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, &size, &id)
    var rate = 0.0
    if id != 0 {
        size = UInt32(MemoryLayout<Double>.size); a = address(kAudioDevicePropertyNominalSampleRate)
        _ = AudioObjectGetPropertyData(id, &a, 0, nil, &size, &rate)
    }
    return OutputRoute(id: id, rate: rate)
}

struct OutputRoute: Equatable {
    var id: AudioObjectID = 0
    var rate: Double = 0
}

private struct TapFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
private func check(_ status: OSStatus, _ action: String) throws {
    if status != noErr {
        throw TapFailure(message: "\(action) failed (\(status)). Check System Audio Recording access in Privacy & Security, then retry.")
    }
}

/// A bounded handoff. The HAL callback never waits for the FFT queue or allocates per packet.
private final class AudioMailbox {
    private let capacity = 16384, lock = NSLock()
    private var storage = [Float](repeating: 0, count: 16384), used = 0
    private var scratch = [Float](repeating: 0, count: 16384)
    func offer(_ buffer: AudioBuffer) {
        guard let data = buffer.mData, lock.try() else { return }
        defer { lock.unlock() }
        let n = min(Int(buffer.mDataByteSize)/4, capacity - used)
        guard n > 0 else { return }
        storage.withUnsafeMutableBufferPointer { ($0.baseAddress! + used).update(from: data.assumingMemoryBound(to: Float.self), count: n) }
        used += n
    }
    func drain(_ analyzer: Analyzer, _ bus: SignalBus) {
        lock.lock()
        let n = used
        swap(&storage, &scratch); used = 0
        lock.unlock()
        guard n > 0 else { return }
        scratch.withUnsafeBufferPointer { p in analyzer.consume(UnsafeBufferPointer(start: p.baseAddress, count: n), output: bus.publish) }
    }
}

/// Owned exclusively by Capture's serial control queue.
private final class TapSession {
    private var tap: AudioObjectID = 0, device: AudioObjectID = 0
    private var procedure: AudioDeviceIOProcID?
    private var timer: DispatchSourceTimer?
    private let mailbox = AudioMailbox()
    func start(source: Source, pid: pid_t?, bus: SignalBus) throws {
        let desc: CATapDescription
        if source == .music {
            guard var pid else { throw TapFailure(message: "Open Music and play a track to connect.") }
            var object: AudioObjectID = 0, size: UInt32 = 4, a = address(kAudioHardwarePropertyTranslatePIDToProcessObject)
            try check(AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, 4, &pid, &size, &object), "Music audio lookup")
            guard object != 0 else { throw TapFailure(message: "Music has no audio output yet. Play a track, then retry.") }
            desc = CATapDescription(monoMixdownOfProcesses: [object])
        } else { desc = CATapDescription(monoGlobalTapButExcludeProcesses: []) }
        desc.name = "Resonance Audio"; desc.isPrivate = true; desc.muteBehavior = .unmuted
        try check(AudioHardwareCreateProcessTap(desc, &tap), "Audio tap")
        var format = AudioStreamBasicDescription(), a = address(kAudioTapPropertyFormat)
        var size = UInt32(MemoryLayout.size(ofValue: format))
        try check(AudioObjectGetPropertyData(tap, &a, 0, nil, &size, &format), "Audio format lookup")
        guard format.mFormatID == kAudioFormatLinearPCM, format.mFormatFlags & kAudioFormatFlagIsFloat != 0,
              format.mBitsPerChannel == 32, format.mChannelsPerFrame == 1, format.mSampleRate > 0 else {
            throw TapFailure(message: "This output does not provide supported mono floating-point PCM. Choose another output or Ambient only.")
        }
        let aggregate: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Resonance Analysis",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceTapListKey: [[kAudioSubTapUIDKey: desc.uuid.uuidString, kAudioSubTapDriftCompensationKey: true]]
        ]
        try check(AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &device), "Private audio device")
        let mailbox = self.mailbox, analyzer = Analyzer(rate: format.mSampleRate)
        let queue = DispatchQueue(label: "Resonance.audio.input", qos: .userInteractive)
        try check(AudioDeviceCreateIOProcIDWithBlock(&procedure, device, queue) { _, input, _, _, _ in
            if input.pointee.mNumberBuffers > 0 { mailbox.offer(input.pointee.mBuffers) }
        }, "Audio input")
        try check(AudioDeviceStart(device, procedure), "System audio access")
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "Resonance.audio.analysis", qos: .userInitiated))
        timer.schedule(deadline: .now(), repeating: .milliseconds(18), leeway: .milliseconds(3))
        timer.setEventHandler { mailbox.drain(analyzer, bus) }
        timer.resume(); self.timer = timer
    }
    func stop() {
        if let procedure { AudioDeviceStop(device, procedure); AudioDeviceDestroyIOProcID(device, procedure); self.procedure = nil }
        timer?.cancel(); timer = nil
        if device != 0 { AudioHardwareDestroyAggregateDevice(device); device = 0 }
        if tap != 0 { AudioHardwareDestroyProcessTap(tap); tap = 0 }
    }
    deinit { stop() }
}

struct CaptureKey: Equatable {
    var source: Source
    var musicPID: pid_t?
    var route: OutputRoute
}
final class Capture {
    private let queue = DispatchQueue(label: "Resonance.audio.control")
    private var session: TapSession?
    private(set) var key: CaptureKey?
    private(set) var bus = SignalBus()
    var onStatus: ((String, Bool) -> Void)?
    func reconcile(_ new: CaptureKey?, force: Bool = false) {
        guard force || key != new else { return }
        key = new
        let bus = SignalBus()
        self.bus = bus
        onStatus?(new == nil ? "Audio off" : "Connecting…", false)
        queue.async { [weak self] in
            guard let self else { return }
            self.session?.stop(); self.session = nil
            guard let new else { return }
            let session = TapSession()
            do {
                try session.start(source: new.source, pid: new.musicPID, bus: bus)
                self.session = session
                DispatchQueue.main.async { if self.bus === bus { self.onStatus?("Listening", true) } }
            } catch {
                session.stop()
                DispatchQueue.main.async { if self.bus === bus { self.onStatus?(error.localizedDescription, false) } }
            }
        }
    }
    func shutdown() {
        // A first-use system consent dialog can hold the HAL startup call open.
        // Keep quitting responsive in that case. The OS owns process-private taps.
        let stopped = DispatchSemaphore(value: 0)
        queue.async { self.session?.stop(); self.session = nil; stopped.signal() }
        _ = stopped.wait(timeout: .now() + .milliseconds(400))
    }
}
