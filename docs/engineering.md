# Architecture and verification

## Implementation

- **Desktop.** A borderless, non-key, mouse-transparent AppKit window per selected display. Its level is one above the Core Graphics desktop level, bounded below the icon level. Windows join Spaces, track screen geometry and persistent display UUIDs, and respond to sleep, wake, display and session changes. Quitting or disabling the wallpaper closes them. macOS controls Spaces, Stage Manager and full-screen composition.
- **Capture.** A private, unmuted Core Audio process tap feeds a private aggregate device. The HAL callback copies mono float PCM into a bounded mailbox using a nonblocking lock. A separate analysis queue drains it. Source, process and default output route changes rebuild the tap. Capture stops when paused or when no active desktop or studio needs it.
- **Analysis.** A 2,048-sample Hann window with a 512-sample hop (75% overlap) feeds a vDSP FFT. Three broad bands, eight local spectrum regions, RMS, band-relative spectral flux, an adaptive onset threshold, a refractory interval, peak normalization and separate attack/release envelopes drive the renderer. Old readings decay into ambient motion. PCM exists only in volatile memory.
- **Music.** Public Apple Events use the terminology from Music’s scripting dictionary and address its running process ID. Metadata is opt-in. A background queue polls at six-second intervals, caches track properties and artwork, and stops querying after an Automation denial until reconnected. Album color and track changes ease into the active scene.
- **Metal.** Liquid Aurora renders a pleated, twisted sheet. Ethereal Particles uses 14,600 procedural point sprites. Liquid Chrome lights a deformed metallic torus with a reflected studio environment. Cosmic Atmosphere combines warped dust fields, layered stars and a backlit planetary limb. Minimal Frequency draws antialiased parametric curves. One set of compiled pipelines serves every preview and display. The other works use dedicated fragment programs for their materials and lighting. Gallery thumbnails are bundled frames exported from these same pipelines. Opening a preview starts one live Metal surface.
- **Power.** Adaptive mode targets 60 FPS for active standalone artwork or detected sound, and 30 FPS for silent music scenes. It can reduce resolution and frame rate in response to measured GPU cost. Low Power Mode, serious thermal pressure, battery settings, sleep and AppKit occlusion influence the rendering policy. Covered-desktop suspension uses system occlusion reports and therefore depends on the compositor.
- **Persistence.** Visual tuning is stored per scene. Display selection, audio source, playback preferences and onboarding state are stored in local UserDefaults. The original scene IDs, defaults domain and tuning keys are retained. Favorites, pointer controls and reactivity presets load with defaults for older installs. Login registration is read from the OS.


In 2.1, a retired desktop selection migrates to Obsidian Flow. Surviving favorites and scene tuning keep their original identifiers. Open the full-width **Appearance and quality** button to choose a palette. Deep Jade, Ultraviolet, Champagne, Rose Quartz, Petrol Blue, Terracotta, Glacier and Garnet recolor both music and standalone scenes.

## Version 2.0 verification on the M5

On macOS 27.2.1, the 2.0 test suite ran 17 tests with no failures. The hosted tests compiled every Metal pipeline, rendered all 25 scenes at multiple times, checked independent scenes against injected audio, and compared the six pointer-enabled renderers with interaction enabled and disabled. Audio checks covered generated signals, silence and release after a peak, plus recordings from the locally installed Apple Loops library representing quiet synth, bass, choir and percussion. These recordings are optional test fixtures and are not shipped.

A controlled kick passed through the same analyzer and motion path in both releases. At a fixed animation phase, the proportion of a 640 × 360 frame changing by at least 10/255 in any color channel was:

| Scene | 1.1 | 2.0 Balanced |
| --- | ---: | ---: |
| Liquid Aurora | 44.16% | 3.24% |
| Ethereal Particles | 17.64% | 7.78% |
| Liquid Chrome | 29.17% | 2.81% |
| Cosmic Atmosphere | 46.53% | 0.81% |
| Minimal Frequency | 5.68% | 1.16% |

Metal command-buffer timing at 1920 × 1080 gave scene medians of 0.22–2.51 ms on this Mac. Each sample used 20 measured frames after six warm-up frames. These measurements exclude presentation and compositor work. Sustained display FPS, long-session battery life, monitor hot-plug and every Spaces configuration remain unmeasured.

WindowServer reported Finder icons at −2147483603, Resonance at −2147483622 and the system wallpaper at −2147483625. The tests checked click-through window flags, removal and recreation on the connected display, closing the studio, menu actions, settings migration, and changing a preview without applying it.

The native split view, sidebar, controls, and motion behavior follow Apple's guidance for a Mac application. [Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos) · [Motion](https://developer.apple.com/design/human-interface-guidelines/motion) · [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)

The installed 2.0 Release bundle passed strict signature verification and launched as a menu bar application. In the installed studio, Discover listed 25 wallpapers. The Celestial Bloom detail showed its rendered preview, Balanced controls, and Applied to desktop. During actual Apple Music playback it reported Receiving audio and advancing track metadata.

The standalone tests exercised a stopped capture engine. The live session already had Music open and audio access enabled, so the release review did not exercise a freshly denied system permission. No physical second display was attached.

## Version 2.1 verification on the M5

All 19 hosted tests passed on macOS 27.2.1. Each of the 25 renderers produced distinct frames with all eight added palettes. The ten new works changed measurably over a four-second shader-time interval. At a 1/60-second interval the mean RGB channel change stayed below one 8-bit level per scene in the sampled frames. At 1920 × 1080 the new works took 0.26–1.78 ms median GPU time in the final offscreen run. These figures exclude presentation latency and sustained battery load.

The migration test exercised each of the ten retired scene IDs, including favorites, disabled desktop state and paused state. Forward and backward menu navigation visited each current scene exactly once.

## Version 2.2 verification on the M5

All 19 hosted tests passed with 45 scenes. The new library includes ten independent minimal works and ten new music works. Tests rendered each scene at multiple times and with each manual palette. Every new music scene changed the rendered geometry or lighting during a measured PCM kick at a fixed animation phase. The ten standalone editions remained pixel-identical under injected audio at the same time. The final 1080p offscreen run measured median GPU times of 0.12–0.91 ms across the twenty additions. This measures shader execution and excludes presentation.

## Version 2.2.1 release verification

The macOS suite passed all 20 tests on an Apple Silicon Mac. The login test constructed Apple's login-item launch event and checked that first-run onboarding stays closed until the menu bar action opens the studio. A full sign-out and sign-in was outside this test.

The release app includes `arm64` and `x86_64` slices. The disk image passed checksum verification, and the app inside the mounted image passed strict signature verification for both architectures. The Intel slice was built and inspected on Apple Silicon. It has yet to be exercised on Intel hardware.
