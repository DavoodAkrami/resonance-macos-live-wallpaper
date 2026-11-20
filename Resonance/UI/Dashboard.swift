import SwiftUI
import ServiceManagement

private enum Shelf: String, CaseIterable, Identifiable {
    case discover = "Discover", music = "Music Reactive", live = "Live Wallpapers", favorites = "Favorites"
    var id: Self { self }
    var icon: String {
        switch self { case .discover: return "square.grid.2x2"; case .music: return "waveform"; case .live: return "sparkle.magnifyingglass"; case .favorites: return "heart" }
    }
}
private let exhibition: [SceneID] = [.citron,.morello,.cornflower,.yuzu,.mulberry,.mica,.pistachio,.lichen,.tea,.pollen,.guava,.eucalyptus,.sorbet,.counterpoint,.flax,.bistre,.poppy,.porcelain,.alabaster,.spearmint,.nacre,.obsidian,.saffron,.glass,.mercury,.prism,.bloom,.lamina,.petrol,.carbon,.echo,.caustics,.loom,.velvet,.golden]
private func displayType(_ s: SceneID) -> String { s.isMusical ? "Music reactive" : "Live wallpaper" }

private struct Plate: View {
    let scene: SceneID, studio: MetalStudio?
    var body: some View {
        GeometryReader { box in
            if let img = studio?.thumbnail(scene) {
                Image(nsImage:img).resizable().scaledToFill().frame(width:box.size.width,height:box.size.height).clipped()
            } else { Color(nsColor:.underPageBackgroundColor).overlay(Image(systemName:scene.symbol)) }
        }.accessibilityHidden(true)
    }
}
private struct WallCard: View {
    @ObservedObject var state: AppState
    let scene: SceneID, select: () -> Void
    @State private var hover = false
    @Environment(\.accessibilityReduceMotion) private var reduced
    var body: some View {
        let active = state.prefs.scene == scene && state.prefs.enabled
        VStack(alignment:.leading,spacing:7) {
            Button(action:select) {
                Plate(scene:scene,studio:state.studio)
                    .aspectRatio(1.82,contentMode:.fit)
                    .overlay(alignment:.topTrailing) {
                        if active { Image(systemName:"checkmark.circle.fill").symbolRenderingMode(.palette).foregroundStyle(.white,.black.opacity(0.64)).padding(7) }
                    }
                    .clipShape(RoundedRectangle(cornerRadius:9))
                    .overlay(RoundedRectangle(cornerRadius:9).strokeBorder(hover ? Color.accentColor : .primary.opacity(0.10),lineWidth:hover ? 2 : 1))
            }.buttonStyle(.plain).accessibilityLabel("Preview " + scene.title + (active ? ", applied" : ""))
            HStack {
                VStack(alignment:.leading,spacing:3) {
                    Text(scene.title).font(.system(size:13,weight:.semibold))
                    Text(displayType(scene)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                FavoriteButton(state:state,scene:scene)
            }
        }.onHover { value in withAnimation(reduced ? nil : .easeOut(duration:0.15)) { hover=value } }
        .contextMenu {
            Button("Preview wallpaper",action:select)
            Button("Apply wallpaper") { state.apply(scene) }
            Button(state.prefs.favorites.contains(scene) ? "Remove from favorites" : "Add to favorites") { state.favorite(scene) }
        }
    }
}
private struct FavoriteButton: View {
    @ObservedObject var state: AppState
    let scene: SceneID
    var body: some View {
        let saved = state.prefs.favorites.contains(scene)
        Button { state.favorite(scene) } label: { Image(systemName:saved ? "heart.fill" : "heart").foregroundStyle(saved ? Color.accentColor : .secondary) }
            .buttonStyle(.borderless).accessibilityLabel((saved ? "Unfavorite " : "Favorite ") + scene.title)
            .help(saved ? "Remove from Favorites" : "Add to Favorites")
    }
}

struct Dashboard: View {
    @ObservedObject var state: AppState
    @AppStorage("library.shelf.v2") private var shelf = Shelf.discover
    @State private var search = ""
    @State private var setup = false
    @FocusState private var searching: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var matches: [SceneID] {
        (exhibition + SceneID.allCases.filter { !exhibition.contains($0) }).filter { scene in
            (shelf == .discover || (shelf == .music && scene.isMusical) || (shelf == .live && !scene.isMusical) || (shelf == .favorites && state.prefs.favorites.contains(scene)))
                && (search.isEmpty || scene.title.localizedCaseInsensitiveContains(search) || scene.material.localizedCaseInsensitiveContains(search))
        }
    }
    private func browse(_ new: Shelf) { state.detail=nil; state.settingsOpen=false; search=""; shelf=new }
    private func select(_ scene: SceneID) { withAnimation(reduceMotion ? nil : .easeOut(duration:0.17)) { state.detail=scene } }
    var body: some View {
        NavigationSplitView {
            List(selection:Binding<String?>(get:{state.settingsOpen ? "Settings" : shelf.rawValue},set:{ value in
                if let value, let s=Shelf(rawValue:value) { browse(s) } else if value=="Settings" {state.detail=nil; state.settingsOpen=true}
            })) {
                Section("Library") {
                    ForEach(Shelf.allCases) { item in Label(item.rawValue,systemImage:item.icon).tag(item.rawValue) }
                }
                Section { Label("Settings",systemImage:"gearshape").tag("Settings") }
            }.listStyle(.sidebar).navigationSplitViewColumnWidth(min:155,ideal:182,max:225)
            .safeAreaInset(edge:.bottom) {
                Button { state.settingsOpen=false; select(state.prefs.scene) } label: {
                    HStack(spacing:9) {
                        Plate(scene:state.prefs.scene,studio:state.studio).frame(width:38,height:32).clipShape(RoundedRectangle(cornerRadius:5))
                        VStack(alignment:.leading,spacing:2) {
                            Text(state.prefs.enabled ? "On your desktop" : "Desktop is off").font(.caption2).foregroundStyle(.secondary)
                            Text(state.prefs.scene.title).font(.caption.bold()).lineLimit(1)
                        }
                        Spacer()
                    }.padding(10)
                }.buttonStyle(.plain).accessibilityLabel("Inspect current wallpaper, " + state.prefs.scene.title)
            }
        } detail: {
            Group {
                if state.settingsOpen { PreferencesView(state:state) }
                else if let detail=state.detail { WallpaperDetail(state:state,scene:detail).id(detail) }
                else { gallery }
            }
            .toolbar {
                ToolbarItem(placement:.navigation) {
                    if state.detail != nil && !state.settingsOpen {
                        Button { state.detail=nil } label:{ Label("Back to library",systemImage:"chevron.left") }.keyboardShortcut("[",modifiers:.command)
                    }
                }
                if !state.settingsOpen && state.detail == nil {
                    ToolbarItem(placement:.primaryAction) {
                        HStack(spacing:7) {
                            Image(systemName:"magnifyingglass").foregroundStyle(.secondary)
                            TextField("Search wallpapers",text:$search)
                                .textFieldStyle(.plain).focused($searching).accessibilityLabel("Search wallpapers")
                            if !search.isEmpty {
                                Button {search=""} label:{Image(systemName:"xmark.circle.fill")}
                                    .buttonStyle(.plain).accessibilityLabel("Clear search")
                            }
                        }.padding(.horizontal,9).frame(width:195,height:28)
                    }
                    if #available(macOS 26, *) { ToolbarSpacer(.fixed,placement:.primaryAction) }
                }
                ToolbarItem(placement:.primaryAction) {
                    Button {state.prefs.paused.toggle()} label:{Label(state.prefs.paused ? "Resume animations" : "Pause animations",systemImage:state.prefs.paused ? "play" : "pause")}
                        .help(state.prefs.paused ? "Resume animations" : "Pause animations")
                }
            }
        }
        .background(Button("Find wallpapers") { state.settingsOpen=false;state.detail=nil;searching=true }.keyboardShortcut("f").hidden())
        .onChange(of:state.settingsOpen) { _,open in if open { state.detail=nil }; state.refreshCapture() }
        .onAppear { setup = !state.prefs.introduced }
        .sheet(isPresented:$setup) { Welcome(state:state,done:{setup=false}) }
    }
    private var gallery: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:18) {
                HStack(alignment:.firstTextBaseline) {
                    Text(shelf.rawValue).font(.system(size:32,weight:.medium,design:.serif))
                    Spacer(); Text("\(matches.count) wallpapers").font(.subheadline).foregroundStyle(.secondary)
                }
                if shelf == .discover && search.isEmpty {
                    Button {select(.citron)} label: {
                        ZStack(alignment:.bottomLeading) {
                            Plate(scene:.citron,studio:state.studio)
                            LinearGradient(colors:[.black.opacity(0.76),.clear],startPoint:.leading,endPoint:.trailing)
                            VStack(alignment:.leading,spacing:9) {
                                Label("Featured wallpaper",systemImage:"sparkles").font(.caption.weight(.medium))
                                Text(SceneID.citron.title).font(.system(size:34,weight:.regular,design:.serif))
                                Text("Citron paper folded against deep olive.").font(.callout)
                                Label("Preview",systemImage:"play.circle").font(.callout.weight(.semibold)).padding(.top,5)
                            }.foregroundStyle(.white).padding(22)
                        }.aspectRatio(3.05,contentMode:.fit).clipShape(RoundedRectangle(cornerRadius:13))
                    }.buttonStyle(.plain).accessibilityLabel("Preview featured wallpaper, Citron Crease")
                }
                if matches.isEmpty {
                    ContentUnavailableView(search.isEmpty ? "No favorites yet" : "No matching wallpapers",
                        systemImage:search.isEmpty ? "heart" : "magnifyingglass",
                        description:Text(search.isEmpty ? "Use the heart beside a wallpaper to save it here." : "Try another title or material."))
                } else {
                    LazyVGrid(columns:[GridItem(.adaptive(minimum:185,maximum:365),spacing:15)],spacing:19) {
                        ForEach(matches) { scene in WallCard(state:state,scene:scene) {select(scene)} }
                    }
                }
            }.padding(24)
        }.id(shelf)
    }
}

private struct WallpaperDetail: View {
    @ObservedObject var state: AppState
    let scene: SceneID
    @State private var advanced=false
    private func tune<T>(_ path: WritableKeyPath<Tuning,T>) -> Binding<T> {
        Binding(get:{state.prefs[scene:scene][keyPath:path]},set:{state.prefs[scene:scene][keyPath:path]=$0})
    }
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:15) {
                HStack {
                    VStack(alignment:.leading,spacing:3) {
                        Text(displayType(scene)).font(.caption).foregroundStyle(.secondary)
                        Text(scene.title).font(.system(size:31,weight:.medium,design:.serif))
                    }
                    Spacer(); FavoriteButton(state:state,scene:scene)
                    Button(state.prefs.scene==scene && state.prefs.enabled ? "Applied to desktop" : "Apply wallpaper") { state.apply(scene) }
                        .buttonStyle(.borderedProminent).disabled(state.prefs.scene==scene && state.prefs.enabled && !state.prefs.paused)
                        .keyboardShortcut(.return,modifiers:.command)
                }
                if let studio=state.studio {
                    LivePreview(state:state,studio:studio,scene:scene).aspectRatio(2.28,contentMode:.fit).clipShape(RoundedRectangle(cornerRadius:12)).accessibilityLabel("Live preview of "+scene.title)
                } else { Text(state.graphicsError ?? "Preparing Metal…") }
                Text(scene.story).foregroundStyle(.secondary)
                if scene.isMusical {
                    Picker("Music reactivity",selection:$state.prefs.response) { ForEach(Reactivity.allCases,id:\.self){Text($0.rawValue)} }.pickerStyle(.segmented).frame(maxWidth:450)
                    control("Music sensitivity",\.intensity,0...1)
                }
                HStack(spacing:24) { control("Animation speed",\.speed,0.15...2); control("Motion intensity",\.amount,0...1) }
                if scene.supportsCursor {
                    HStack(spacing:24) { Toggle("Cursor interaction",isOn:tune(\.cursorEnabled)).toggleStyle(.switch)
                        if state.prefs[scene:scene].cursorEnabled { control("Cursor sensitivity",\.cursorGain,0...1) }
                    }
                }
                Button {
                    advanced.toggle()
                } label: {
                    HStack {
                        Text("Appearance and quality").font(.headline)
                        Spacer()
                        Image(systemName:advanced ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal,10).frame(minHeight:34)
                    .background(.quaternary.opacity(0.45),in:RoundedRectangle(cornerRadius:7))
                    .contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityValue(advanced ? "Expanded" : "Collapsed")
                if advanced {
                    VStack(spacing:12) {
                        HStack(spacing:24) { control("Brightness",\.brightness,0.18...1.25); control(scene.detail,\.detail,0...1) }
                        HStack {
                            Picker("Palette",selection:tune(\.palette)) { ForEach(Palette.allCases.filter{scene.isMusical || $0 != .track},id:\.self){Text($0.rawValue)} }
                            Picker("Render quality",selection:$state.prefs.quality) {ForEach(Quality.allCases,id:\.self){Text($0.rawValue)}}
                        }
                    }.padding(.top,9)
                }
                if scene.isMusical { Divider(); TrackCard(state:state) }
            }.padding(24)
        }
    }
    private func control(_ title:String,_ path:WritableKeyPath<Tuning,Double>,_ range:ClosedRange<Double>) -> some View {
        VStack(alignment:.leading,spacing:3) {
            HStack {Text(title);Spacer();Text(tune(path).wrappedValue,format:.percent.precision(.fractionLength(0))).monospacedDigit().foregroundStyle(.secondary)}.font(.caption)
            Slider(value:tune(path),in:range).controlSize(.small).accessibilityLabel(title)
        }
    }
}
private struct Welcome: View {
    @ObservedObject var state:AppState
    let done:()->Void
    @State private var page=0
    private let pages=[
        ("Choose a living desktop","Browse the gallery, open a live preview and choose Apply wallpaper. Standalone artwork works immediately, including when Music is closed.","square.grid.2x2"),
        ("Let sound shape the artwork","Choose Apple Music or System audio in Settings to enable local audio analysis. macOS may ask for system audio access. Track titles and artwork use a separate optional Music Automation permission.","waveform"),
        ("Keep the desktop comfortable","Use Subtle, Balanced or Expressive in a music preview. Settings includes refresh rate and battery controls. The menu bar waveform pauses animations or restores your regular desktop.","slider.horizontal.3")
    ]
    var body:some View {
        VStack(alignment:.leading,spacing:17) {
            Image(systemName:pages[page].2).font(.largeTitle).foregroundStyle(.tint)
            Text(pages[page].0).font(.title2.bold());Text(pages[page].1).fixedSize(horizontal:false,vertical:true)
            HStack { Button("Skip guide",action:finish);Spacer()
                if page>0 {Button("Back"){page-=1}}
                Button(page==2 ? "Open gallery" : "Continue"){if page==2 {finish()} else {page+=1}}.keyboardShortcut(.defaultAction)
            }
        }.padding(30).frame(width:470)
    }
    private func finish(){state.prefs.introduced=true;done()}
}
private struct TrackCard: View {
    @ObservedObject var state: AppState
    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let data = state.track.artwork, let image = NSImage(data: data) { Image(nsImage: image).resizable().scaledToFill() }
                else { Image(systemName: "opticaldisc").font(.system(size: 23,weight: .thin)) }
            }.frame(width: 45,height: 45).background(Color.white.opacity(0.045)).clipShape(RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading,spacing: 3) {
                if state.track.title.isEmpty {
                    Text(state.prefs.source.rawValue).font(.system(size: 13,weight: .semibold))
                    Text(state.audioStatus == "Ambient only" ? "Sound reactivity is off" : state.audioStatus).font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(state.track.title).bold().lineLimit(1)
                    Text(state.audioStatus).font(.caption).foregroundStyle(.secondary)
                    Text([state.track.artist,state.track.album].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Text("\(state.musicStatus) · \(time(state.track.position)) / \(time(state.track.duration))").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button { state.settingsOpen = true } label: { Label("Audio settings",systemImage: "waveform") }.buttonStyle(.bordered)
        }
    }
    private func time(_ v: Double) -> String { let s = Int(max(0,min(v.isFinite ? v : 0, 999999))); return String(format: "%d:%02d",s/60,s%60) }
}

private struct PreferencesView: View {
    @ObservedObject var state: AppState
    @State private var reset = false
    var body: some View {
        VStack(alignment: .leading,spacing: 8) {
            Text("Settings").font(.system(size:28,weight:.medium,design:.serif)).padding(.leading,24).padding(.top,42)
            Form {
                Section("Sound & Music") {
                    Picker("Audio source",selection: $state.prefs.source) { ForEach(Source.allCases,id: \.self) { Text($0.rawValue) } }
                    LabeledContent("Connection") { Text(state.audioStatus).font(.caption).multilineTextAlignment(.trailing).textSelection(.enabled) }
                    Toggle("Read track details and artwork from Music",isOn: $state.prefs.metadata)
                    if state.prefs.metadata { LabeledContent("Music") { Text(state.musicStatus).font(.caption) } }
                    if state.prefs.source != .ambient || state.prefs.metadata {
                        HStack { Button("Reconnect") { state.reconnect() }; Button("Privacy settings…") { NSWorkspace.shared.open(URL(string:"x-apple.systempreferences:com.apple.preference.security")!) } }
                    }
                    Text("For quiet or protected playback, choose Ambient only to keep the scene moving independently.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Playback & energy") {
                    Picker("Frame rate",selection: $state.prefs.quality) { ForEach(Quality.allCases,id: \.self) { Text($0.rawValue) } }
                    Toggle("Save energy on battery",isOn: $state.prefs.batterySaver)
                    Toggle("Pause on battery",isOn: $state.prefs.pauseOnBattery)
                    Toggle("Suspend covered desktops and full-screen Spaces",isOn: $state.prefs.reduceCovered)
                }
                Section("Displays") {
                    Toggle("Enable live wallpaper",isOn: $state.prefs.enabled)
                    ForEach(NSScreen.screens,id: \.stableID) { screen in
                        Toggle(screen.localizedName,isOn: Binding(get: { !state.prefs.excludedDisplays.contains(screen.stableID) },set: { included in
                            if included { state.prefs.excludedDisplays.remove(screen.stableID) } else { state.prefs.excludedDisplays.insert(screen.stableID) }
                        }))
                    }
                }
                Section("General") {
                    Toggle("Open at login",isOn: Binding(get: { state.loginStatus == .enabled || state.loginStatus == .requiresApproval },set: state.login))
                    Text("Starts in the menu bar without opening the studio.").font(.caption).foregroundStyle(.secondary)
                    if state.loginStatus == .requiresApproval { Button("Approve in Login Items…") { SMAppService.openSystemSettingsLoginItems() } }
                    if !state.loginError.isEmpty { Text(state.loginError).font(.caption) }
                    Button("Reset to defaults…") { reset = true }
                }
            }.formStyle(.grouped).scrollContentBackground(.hidden)
        }.frame(maxWidth: .infinity,alignment: .leading)
        .alert("Reset Resonance settings?",isPresented: $reset) {
            Button("Reset",role: .destructive) { state.reset() }; Button("Cancel",role: .cancel) {}
        } message: { Text("Restore the original scene controls, displays, audio source, and startup settings.") }
    }
}
