import AppKit
import CoreImage

private typealias AED = NSAppleEventDescriptor
private func code(_ s: String) -> UInt32 { s.utf8.reduce(0) { ($0 << 8) | UInt32($1) } }

struct Track {
    var id = "", title = "", artist = "", album = ""
    var playing = false, duration = 0.0, position = 0.0
    var artwork: Data?
    var color = SIMD3<Float>(repeating: 1)
    static func parse(properties: NSAppleEventDescriptor) -> Track {
        func text(_ k: String) -> String { properties.forKeyword(code(k))?.stringValue ?? "" }
        var track = Track()
        track.id = text("pPIS"); track.title = text("pnam"); track.artist = text("pArt"); track.album = text("pAlb")
        track.duration = max(0, properties.forKeyword(code("pDur"))?.doubleValue ?? 0)
        return track
    }
}

/// Apple events address a running PID. The OS cannot launch Music for this target.
private struct MusicEvents {
    let pid: pid_t
    func object(_ kind: String, _ form: String, _ selection: AED, inside parent: AED = .null()) -> AED {
        let r = AED.record()
        r.setDescriptor(AED(typeCode: code(kind)), forKeyword: code("want"))
        r.setDescriptor(AED(enumCode: code(form)), forKeyword: code("form"))
        r.setDescriptor(selection, forKeyword: code("seld"))
        r.setDescriptor(parent, forKeyword: code("from"))
        return r.coerce(toDescriptorType: code("obj "))!
    }
    func property(_ name: String, inside parent: AED = .null()) -> AED {
        object("prop", "prop", AED(typeCode: code(name)), inside: parent)
    }
    func get(_ item: AED) throws -> AED {
        let event = AED(eventClass: code("core"), eventID: code("getd"), targetDescriptor: AED(processIdentifier: pid), returnID: -1, transactionID: 0)
        event.setParam(item, forKeyword: code("----"))
        let reply = try event.sendEvent(options: [.waitForReply, .canInteract], timeout: 2)
        if let err = reply.paramDescriptor(forKeyword: code("errn")), err.int32Value != 0 {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(err.int32Value))
        }
        return reply.paramDescriptor(forKeyword: code("----")) ?? .null()
    }
}

final class MusicService {
    private let queue = DispatchQueue(label: "Resonance.music")
    private var busy = false, denied = false, generation = 0
    private var cached = Track()
    var onChange: ((Track, String) -> Void)?
    static var runningPID: pid_t? { NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").first?.processIdentifier }
    func reset() { generation += 1; denied = false; cached = Track() }
    func refresh() {
        guard !busy, !denied else { return }
        guard let pid = Self.runningPID else { cached = Track(); onChange?(cached, "Music is closed"); return }
        let token = generation, old = cached
        busy = true
        queue.async {
            let events = MusicEvents(pid: pid)
            var track = Track(), status = "Music is stopped", denied = false
            do {
                let state = try events.get(events.property("pPlS")).enumCodeValue
                if state != code("kPSS") {
                    let current = events.property("pTrk")
                    let identity = try? events.get(events.property("pPIS", inside: current)).stringValue
                    if let identity, !identity.isEmpty, identity == old.id { track = old }
                    else {
                        track = Track.parse(properties: try events.get(events.property("pALL", inside: current)))
                        let art = events.object("cArt", "indx", AED(int32: 1), inside: current)
                        if let data = try? events.get(events.property("pRaw", inside: art)).data, !data.isEmpty {
                            track.artwork = data; track.color = Self.tint(data)
                        }
                    }
                    track.playing = state == code("kPSP")
                    track.position = (try? events.get(events.property("pPos")).doubleValue) ?? 0
                    status = track.playing ? "Playing" : "Paused"
                }
            } catch {
                denied = (error as NSError).code == -1743
                status = denied ? "Allow Resonance to control Music in Privacy & Security → Automation, then reconnect." : "Music metadata unavailable"
            }
            DispatchQueue.main.async {
                self.busy = false
                guard token == self.generation else { return }
                self.cached = track; self.denied = denied; self.onChange?(track, status)
            }
        }
    }
    private static func tint(_ data: Data) -> SIMD3<Float> {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 32] as CFDictionary) else { return .one }
        var rgba = [UInt8](repeating: 0, count: 4)
        let space = CGColorSpaceCreateDeviceRGB()
        rgba.withUnsafeMutableBytes { p in
            let ctx = CGContext(data: p.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            ctx?.interpolationQuality = .high; ctx?.draw(image, in: CGRect(x: 0,y: 0,width: 1,height: 1))
        }
        let rgb = SIMD3<Float>(Float(rgba[0]), Float(rgba[1]), Float(rgba[2]))
        return SIMD3(repeating: 0.35) + rgb / max(1, rgb.max()) * 0.85
    }
}
