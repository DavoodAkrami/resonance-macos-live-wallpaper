import Accelerate
import simd
import Foundation
import QuartzCore

/// Confined to the analysis queue. Overlapping Hann windows preserve attacks across callback boundaries.
final class Analyzer {
    static let size = 2048
    static let hop = 512
    private let setup = vDSP_create_fftsetup(11, FFTRadix(kFFTRadix2))!
    private var window = vDSP.window(ofType: Float.self, usingSequence: .hanningDenormalized, count: size, isHalfWindow: false)
    private var real = [Float](repeating: 0, count: size), imag = [Float](repeating: 0, count: size)
    private var samples = [Float](repeating: 0, count: size), used = 0
    private var previous = [Float](repeating: 0, count: size/2)
    private var peaks = SIMD4<Float>(0.035, 0.035, 0.02, 0.09), smooth = SIMD4<Float>.zero
    private var impulse: Float = 0, refractory: Float = 0
    private let lanes: [Int]
    private var lanePeaks = SIMD8<Float>(repeating: 0.02), spectrum = SIMD8<Float>.zero
    private var fluxFloor = SIMD3<Float>(repeating: 0.001)
    let rate: Float
    init(rate: Double) {
        self.rate = Float(rate)
        // Octave-like regions spread the measured spectrum along each sculpture.
        let edges: [Double] = [80,180,380,800,1600,3400,7200]
        lanes = (0..<Self.size/2).map { bin in
            let hz = Double(bin)*rate/Double(Self.size)
            return edges.firstIndex { hz < $0 } ?? 7
        }
    }
    deinit { vDSP_destroy_fftsetup(setup) }
    func consume(_ input: UnsafeBufferPointer<Float>, output: (Signal) -> Void) {
        var offset = 0
        while offset < input.count {
            let n = min(Self.size - used, input.count - offset)
            samples.withUnsafeMutableBufferPointer { p in
                (p.baseAddress! + used).update(from: input.baseAddress! + offset, count: n)
            }
            used += n; offset += n
            if used == Self.size {
                output(analyze())
                used = Self.size - Self.hop
                _ = samples.withUnsafeMutableBytes { p in memmove(p.baseAddress!, p.baseAddress! + Self.hop * 4, used * 4) }
            }
        }
    }
    private func analyze() -> Signal {
        let n = Self.size, dt = Float(Self.hop) / rate
        let rms = vDSP.rootMeanSquare(samples)
        vDSP.multiply(samples, window, result: &real)
        vDSP.clear(&imag)
        real.withUnsafeMutableBufferPointer { r in imag.withUnsafeMutableBufferPointer { i in
            var split = DSPSplitComplex(realp: r.baseAddress!, imagp: i.baseAddress!)
            vDSP_fft_zip(setup, &split, 1, 11, FFTDirection(FFT_FORWARD))
        }}
        var levels = SIMD4<Float>.zero, lanePower = SIMD8<Float>.zero, flux = SIMD3<Float>.zero
        for k in 1..<(n/2) {
            let hz = Float(k) * rate / Float(n)
            let magnitude = hypot(real[k], imag[k]) * (2 / Float(n))
            if hz >= 25 && hz < 19500 {
                let band = hz < 250 ? 0 : hz < 3000 ? 1 : 2
                levels[band] += magnitude * magnitude
                lanePower[lanes[k]] += magnitude * magnitude
                flux[band] += max(0, magnitude - previous[k])
            }
            previous[k] = magnitude
        }
        levels = levels.squareRoot(); levels.w = rms
        let floors = SIMD4<Float>(0.012, 0.009, 0.006, 0.025)
        peaks = simd_max(floors, simd_max(levels, peaks * exp(-dt/3)))
        let target = rms > 0.00025 ? simd_min(levels / peaks, SIMD4(repeating: 1)) : .zero
        lanePower = lanePower.squareRoot()
        let decay = exp(-dt/3)
        for i in 0..<8 { lanePeaks[i] = max(0.006, max(lanePower[i], lanePeaks[i]*decay)) }
        let local = rms > 0.00025 ? lanePower / lanePeaks : .zero
        for i in 0..<8 {
            spectrum[i] += (local[i] - spectrum[i]) * (1 - exp(-dt / (local[i] > spectrum[i] ? 0.012 : 0.095)))
        }
        for i in 0..<4 {
            smooth[i] += (target[i] - smooth[i]) * (1 - exp(-dt / (target[i] > smooth[i] ? 0.014 : 0.115)))
        }
        refractory = max(0, refractory - dt)
        impulse *= exp(-dt/0.12)
        let relativeFlux = flux / simd_max(fluxFloor, SIMD3<Float>(0.0008,0.0015,0.0015))
        let attack = max(relativeFlux.x, max(relativeFlux.y * 0.85, relativeFlux.z * 0.72))
        if attack > 2.3, rms > 0.00065, refractory == 0 {
            impulse = min(1, (attack - 1) / 4); refractory = 0.10
        }
        fluxFloor += (flux - fluxFloor) * (1 - exp(-dt/0.45))
        return Signal(bands: smooth, spectrum: spectrum, onset: impulse, rms: rms, timestamp: CACurrentMediaTime())
    }
}
