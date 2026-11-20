import Foundation
import simd

enum SceneID: Int, CaseIterable, Codable, Identifiable {
    // Persisted identifiers are stable. The gaps belong to retired figurative works.
    case aurora = 0, particles, chrome, cosmic, minimal
    case velvet = 10, golden, ocean, bloom, harmonics
    case obsidian = 17, sunset, glass = 21, ember, horizon = 24
    case nacre = 25, saffron, petrol, caustics, lamina, loom, mercury, prism, carbon, echo
    case citron, alabaster, pistachio, mulberry, cornflower, tea, poppy, eucalyptus, flax, sorbet
    case yuzu, porcelain, morello, lichen, mica, pollen, counterpoint, guava, bistre, spearmint
    var id: Self { self }
    var isMusical: Bool {
        switch self {
        case .aurora,.particles,.chrome,.cosmic,.minimal,.velvet,.golden,.ocean,.bloom,.harmonics: return true
        case .yuzu,.porcelain,.morello,.lichen,.mica,.pollen,.counterpoint,.guava,.bistre,.spearmint: return true
        default: return false
        }
    }
    private var catalog: (title: String, material: String, detail: String, symbol: String) {
        switch self {
        case .aurora: return ("Liquid Aurora","Spectral silk","Fold density","water.waves")
        case .particles: return ("Ethereal Particles","Point field","Field spread","sparkles")
        case .chrome: return ("Liquid Chrome","Polished metal","Surface twist","circle.hexagongrid")
        case .cosmic: return ("Cosmic Atmosphere","Interstellar dust","Dust structure","moon.stars")
        case .minimal: return ("Minimal Frequency","Light study","Curve spacing","waveform.path")
        case .velvet: return ("Velvet Aurora","Atmospheric ribbons","Curtain depth","moon.haze")
        case .golden: return ("Golden Resonance","Liquid gold","Gold relief","wave.3.right")
        case .ocean: return ("Oceanic Silk","Submerged textile","Weave depth","water.waves")
        case .bloom: return ("Celestial Bloom","Luminous porcelain","Petal spread","camera.macro")
        case .harmonics: return ("Midnight Harmonics","Suspended wire","Wire spacing","point.3.connected.trianglepath.dotted")
        case .citron: return ("Citron Crease","Citron paper","Crease depth","wave.3.right")
        case .alabaster: return ("Alabaster Offset","Chalk & putty","Offset","square.on.square")
        case .pistachio: return ("Pistachio Seal","Pistachio enamel","Recess depth","circle.inset.filled")
        case .mulberry: return ("Mulberry Slip","Mulberry lacquer","Curl width","wind")
        case .cornflower: return ("Cornflower Braid","Cornflower satin","Crossing width","point.3.connected.trianglepath.dotted")
        case .tea: return ("Tea Wash","Ink & tannin","Diffusion","drop")
        case .poppy: return ("Poppy Interval","Poppy & salt","Interval","circle.lefthalf.filled")
        case .eucalyptus: return ("Eucalyptus Hollow","Eucalyptus resin","Wall thickness","square.dashed")
        case .flax: return ("Flax Weft","Flax & oat","Weave depth","triangle")
        case .sorbet: return ("Sorbet Divide","Melon & custard","Light spread","rectangle.split.2x1")
        case .yuzu: return ("Yuzu Notch","Yuzu & sumi","Notch angle","chevron.right")
        case .porcelain: return ("Porcelain Mode","Bone china","Relief depth","waveform.path")
        case .morello: return ("Morello Phase","Sour cherry & claret","Overlap","circle.circle")
        case .lichen: return ("Lichen Resonator","Lichen ink","Nodal spacing","scribble")
        case .mica: return ("Mica Tremor","Smoked mica","Facet angle","diamond")
        case .pollen: return ("Pollen Dial","Pollen & umber","Arc width","circle.dashed")
        case .counterpoint: return ("Ink Counterpoint","Ink & hydrangea","Ribbon tension","wind")
        case .guava: return ("Guava Envelope","Guava & hibiscus","Envelope width","capsule")
        case .bistre: return ("Bistre String","Bistre & ecru","Harmonic spread","waveform")
        case .spearmint: return ("Spearmint Rest","Spearmint ceramic","Bevel","square.inset.filled")
        case .nacre: return ("Nacre Drift","Iridescent relief","Lustre","water.waves")
        case .saffron: return ("Saffron Fold","Saffron lacquer","Ribbon width","wind")
        case .petrol: return ("Petrol Interference","Thin-film color","Film thickness","circle.hexagongrid")
        case .caustics: return ("Cobalt Caustics","Refracted light","Refraction","drop")
        case .lamina: return ("Rose Lamina","Translucent layers","Layer spacing","square.3.layers.3d")
        case .loom: return ("Phase Loom","Crossed filaments","Thread pitch","waveform.path")
        case .mercury: return ("Mercury Confluence","Liquid alloy","Surface tension","drop.halffull")
        case .prism: return ("Prism Slip","Dispersed spectrum","Dispersion","squareshape.split.3x3")
        case .carbon: return ("Carbon Pleat","Anodized graphite","Pleat count","lines.measurement.horizontal")
        case .echo: return ("Violet Echo","Nested apertures","Aperture spacing","circle.circle")
        case .obsidian: return ("Obsidian Flow","Volcanic glass","Channel depth","drop.halffull")
        case .sunset: return ("Sunset Silk","Sunlit organza","Pleat depth","wind")
        case .glass: return ("Floating Glass","Optical sculpture","Frost","square.3.layers.3d")
        case .ember: return ("Ember Atmosphere","Amber dust","Ember density","sparkles")
        case .horizon: return ("Chromatic Horizon","Atmospheric color field","Horizon depth","sun.horizon")
        }
    }
    var title: String { catalog.title }
    var material: String { catalog.material }
    var detail: String { catalog.detail }
    var symbol: String { catalog.symbol }
    var supportsCursor: Bool { [.obsidian,.glass,.nacre,.caustics,.mercury,.prism,.echo].contains(self) }
    var story: String {
        switch self {
        case .aurora: return "A pleated sheet of spectral silk twists through blue and violet light."
        case .particles: return "Thousands of small lights gather along a gently curving helix."
        case .chrome: return "A continuous platinum sculpture turns through a reflected studio."
        case .cosmic: return "A backlit planet interrupts a distant band of interstellar dust."
        case .minimal: return "Seven fine traces weave a quiet ribbon across charcoal."
        case .velvet: return "Soft curtains of violet and glacial teal gather over a midnight sky."
        case .golden: return "Champagne light skims the crests of a dark liquid-metal relief."
        case .ocean: return "Translucent emerald sails drift through a column of blue water."
        case .bloom: return "A layered porcelain corolla opens slowly in a field of plum light."
        case .harmonics: return "Fine silver wires trace a suspended architectural vault."
        case .citron: return "A single citron fold catches a pale edge of light on an olive ground."
        case .alabaster: return "Two chalk-white planes drift slightly out of register across a putty field."
        case .pistachio: return "A shallow oval depression travels beneath a wash of pistachio enamel."
        case .mulberry: return "A single face of blackcurrant lacquer turns back to reveal its damson underside."
        case .cornflower: return "Two matte blue bands cross, exchanging a small shadow where they overlap."
        case .tea: return "A spreading edge of tea-colored ink settles into pale unbleached paper."
        case .poppy: return "Two halves of a poppy-red disk slide past one another on a warm salt ground."
        case .eucalyptus: return "A softly squared opening twists through a thick slab of eucalyptus resin."
        case .flax: return "A triangular fold turns the grain of two flax surfaces toward the light."
        case .sorbet: return "A narrow seam of custard light divides two planes of cantaloupe."
        case .yuzu: return "Bass opens a wedge of yuzu light in a dark field. Treble sharpens its lip."
        case .porcelain: return "Low notes flex a porcelain membrane. The upper bands move the light across its relief."
        case .morello: return "Two cherry-colored disks drift into alignment. Bass deepens their overlap."
        case .lichen: return "A standing wave traced in lichen ink changes shape with the frequency balance."
        case .mica: return "Three smoked-mica facets share a hinge that tilts with the bass."
        case .pollen: return "A pollen-yellow arc opens with low notes while higher notes brighten the tip."
        case .counterpoint: return "Two calligraphic bands exchange weight as the bass and midrange rise."
        case .guava: return "A guava-colored field gathers around a soft opening that expands with a phrase."
        case .bistre: return "A dark string casts a fine shadow on ecru. Spectral bands bend its harmonics."
        case .spearmint: return "Two mint planes part on a beat, catching treble along a narrow ceramic lip."
        case .nacre: return "Pearl, lilac and sea-green move through the folds of a continuous surface."
        case .saffron: return "A vermilion ribbon turns slowly through apricot light, revealing its darker reverse."
        case .petrol: return "Turquoise, indigo and amber bands follow a slowly changing interference field."
        case .caustics: return "Narrow paths of blue light converge and separate inside a field of shifting glass."
        case .lamina: return "Overlapping rose and burgundy membranes catch narrow slivers of champagne light."
        case .loom: return "Two fine fields of jade and bronze filaments slide across each other in counterpoint."
        case .mercury: return "Pools of dark silver meet and part beneath long reflected strips of light."
        case .prism: return "Oblique sheets of tinted glass slide past one another, splitting light along their edges."
        case .carbon: return "A fan of graphite folds slowly unfurls around an off-center crease."
        case .echo: return "Eccentric violet apertures recede through a softly illuminated hollow."
        case .obsidian: return "Long softbox reflections describe the folds of black volcanic glass."
        case .sunset: return "Translucent peach and terracotta pleats overlap in late-afternoon light."
        case .glass: return "Clear and frosted optical lenses float above a softly lit mineral backdrop."
        case .ember: return "Suspended motes drift along a narrow shaft of amber light in darkness."
        case .horizon: return "Curved layers of lilac, apricot and violet meet at a luminous horizon."
        }
    }
    var fragment: String? {
        switch self {
        case .aurora,.particles,.chrome,.cosmic,.minimal: return nil
        default: return "art_" + String(describing: self)
        }
    }
    func step(_ offset: Int) -> SceneID {
        let scenes = Self.allCases
        let index = scenes.firstIndex(of:self)!
        return scenes[(index + scenes.count + offset % scenes.count) % scenes.count]
    }
}

enum Source: String, Codable, CaseIterable { case ambient = "Ambient only", music = "Apple Music", system = "System audio" }
enum Palette: String, Codable, CaseIterable {
    case original = "Artist palette", pearl = "Moonstone", ember = "Copper", track = "Track colors"
    case jade = "Deep Jade", indigo = "Ultraviolet", champagne = "Champagne", rose = "Rose Quartz",
         petrol = "Petrol Blue", clay = "Terracotta", glacier = "Glacier", garnet = "Garnet"
}
enum Quality: String, Codable, CaseIterable { case adaptive = "Adaptive", fluid = "60 FPS", quiet = "30 FPS" }

enum Reactivity: String, CaseIterable, Codable {
    case subtle = "Subtle", balanced = "Balanced", expressive = "Expressive"
    var gain: Float { switch self { case .subtle: return 0.21; case .balanced: return 0.43; case .expressive: return 0.74 } }
    var attack: Float { switch self { case .subtle: return 0.62; case .balanced: return 0.34; case .expressive: return 0.18 } }
}
struct Tuning: Codable, Equatable {
    var intensity = 0.78, speed = 0.85, brightness = 0.83, detail = 0.5
    var palette = Palette.original
    // Optional additions decode existing v1 presets with their original slider values.
    private var movement: Double?, pointerGain: Double?, pointerEnabled: Bool?
    var amount: Double { get { movement ?? 0.7 } set { movement = min(1,max(0,newValue)) } }
    var cursorGain: Double { get { pointerGain ?? 0.55 } set { pointerGain = min(1,max(0,newValue)) } }
    var cursorEnabled: Bool { get { pointerEnabled ?? true } set { pointerEnabled = newValue } }
    mutating func sanitize() {
        intensity = min(1, max(0, intensity)); speed = min(2, max(0.15, speed))
        brightness = min(1.25, max(0.18, brightness)); detail = min(1, max(0, detail))
    }
}
struct Preferences: Codable, Equatable {
    var scene = SceneID.aurora, source = Source.ambient, quality = Quality.adaptive
    var enabled = true, paused = false, batterySaver = true, pauseOnBattery = false, reduceCovered = true
    var metadata = false, introduced = false
    var readMusic: Bool { metadata && scene.isMusical }
    private var savedFavorites: Set<SceneID>?, responseStyle: Reactivity?
    var favorites: Set<SceneID> { get { savedFavorites ?? [] } set { savedFavorites = newValue } }
    var response: Reactivity { get { responseStyle ?? .balanced } set { responseStyle = newValue } }
    subscript(scene id: SceneID) -> Tuning {
        get { looks[String(id.rawValue)] ?? Tuning() }
        set { var value = newValue; value.sanitize(); looks[String(id.rawValue)] = value }
    }
    var excludedDisplays = Set<String>()
    var looks = [String: Tuning]()
    var tuning: Tuning {
        get { looks[String(scene.rawValue)] ?? Tuning() }
        set { var v = newValue; v.sanitize(); looks[String(scene.rawValue)] = v }
    }
    static let key = "studio.preferences.v1"
    static func load(_ store: UserDefaults = .standard) -> Self {
        guard let data = store.data(forKey:key) else { return Self() }
        let decoder = JSONDecoder()
        var loaded = try? decoder.decode(Self.self,from:data)
        // A retired selection or favorite must not invalidate the rest of a saved library.
        if loaded == nil, var legacy = try? JSONSerialization.jsonObject(with:data) as? [String:Any] {
            let retired: Set<Int> = [5,6,7,8,9,15,16,19,20,23]
            if let id = legacy["scene"] as? Int, retired.contains(id) { legacy["scene"] = SceneID.obsidian.rawValue }
            if let ids = legacy["savedFavorites"] as? [Int] { legacy["savedFavorites"] = ids.filter { !retired.contains($0) } }
            if let normalized = try? JSONSerialization.data(withJSONObject:legacy) {
                loaded = try? decoder.decode(Self.self,from:normalized)
            }
        }
        guard var p = loaded else { return Self() }
        for key in p.looks.keys { p.looks[key]?.sanitize() }
        return p
    }
    func save(_ store: UserDefaults = .standard) { if let data = try? JSONEncoder().encode(self) { store.set(data, forKey: Self.key) } }
}

struct Signal {
    var bands = SIMD4<Float>.zero // bass, mids, treble, RMS
    var spectrum = SIMD8<Float>.zero
    var onset: Float = 0
    var rms: Float = 0
    var timestamp: TimeInterval = 0
}
final class SignalBus {
    private let lock = NSLock()
    private var value = Signal()
    func publish(_ new: Signal) { lock.withLock { value = new } }
    func read() -> Signal { lock.withLock { value } }
}

struct Motion {
    var time: Float = 0, beat: Float = 0
    var energy = SIMD4<Float>.zero
    var spectrum = SIMD8<Float>.zero
    var tint = SIMD3<Float>(repeating: 1)
    var cursor = SIMD3<Float>.zero
    mutating func advance(dt: Float, signal: Signal, fresh: Bool, tuning: Tuning, color: SIMD3<Float>, response: Reactivity = .balanced) {
        let gain = fresh ? response.gain * Float(tuning.intensity) : 0
        // Preserve changes across phrases. Treat percussion as a short input to a much slower envelope.
        for i in 0..<4 {
            let sample = min(1,max(0,signal.bands[i]))
            let target = sample * (0.65 + 0.35*sample) * gain
            let tau = target > energy[i] ? response.attack : 1.25
            energy[i] += (target-energy[i]) * (1-exp(-dt/tau))
        }
        let pulse = min(1,max(0,signal.onset))*gain*0.28
        beat += (pulse-beat)*(1-exp(-dt/(pulse > beat ? 0.24 : 0.94)))
        let local = signal.spectrum*gain
        spectrum += (local-spectrum)*(1-exp(-dt/0.42))
        tint += (color-tint)*(1-exp(-dt/2.2))
        time += dt*Float(tuning.speed)*(0.112 + 0.13*energy.w)
    }
}

/// A bounded damped spring follows normalized local position, then settles at rest.
struct CursorMotion {
    private var last: SIMD2<Float>?
    private var rest: Float = 10
    private var position = SIMD3<Float>.zero, velocity = SIMD3<Float>.zero
    mutating func step(point: SIMD2<Float>?, dt: Float, sensitivity: Float) -> SIMD3<Float> {
        if let point, let last, simd_distance(point,last) > 0.001 { rest = 0 } else { rest += dt }
        last = point
        let influence = point == nil ? 0 : max(0,min(1,(2.4-rest)/1.5))*sensitivity
        let target = SIMD3<Float>(point ?? .zero,1)*influence
        // Subdivide slow frames to keep acceleration and displacement bounded.
        let count = max(1,Int(ceil(min(dt,0.1)*120))), step = min(dt,0.1)/Float(count)
        for _ in 0..<count {
            let a = simd_clamp((target-position)*20-velocity*9, SIMD3(repeating:-4), SIMD3(repeating:4))
            velocity += a*step; position += velocity*step
        }
        return position
    }
}
