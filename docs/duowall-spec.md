# DuoWall: Implementation Spec (iOS)

> **Instructions for the coding agent**
> 1. Read this whole spec before writing any code, including §3 (fold-state matrix), §7 (edge cases), §8 (tests and acceptance criteria) and §11 (assumptions).
> 2. Implement strictly in the milestone order in §10. Finish each milestone's tests before starting the next one, and keep `main` buildable at every step.
> 3. Keep everything local and on-device: no backend, no server, no database beyond local files / SwiftData / UserDefaults, no login, no analytics or ad SDKs, no third-party networking.
> 4. Write unit tests alongside each module (not at the end). UI tests drive the app through the mockable `FoldStateProvider` and launch arguments described in §8.
> 5. Any API marked **UNCONFIRMED** in this spec must be wrapped in a runtime capability check with the fallback described next to it. Never call it unguarded, and never "fix" a compile error by inventing a different API name: stop and leave a `// TODO(verify-api):` note instead.
> 6. Use the hinge only for interactions and effects. Use size classes, `ArrangementView`, and reserved regions for layout (Apple's guidance).
> 7. Do not add a backend, login, cloud sync service, or remote config. If something seems to need one, stop and add it to §11 as an open question.

## 0. Header

| Field | Value |
|---|---|
| Project codename | **DuoWall** (Notion: "DuoWall 双屏壁纸工坊", Jack's idea (a); ranked #1 in the ideas doc) |
| Official App Store name | **DuoWall: Unfold Wallpapers** (26 chars) |
| Subtitle | **Outer + inner reveal designer** (29 chars) |
| Name check (US App Store, 2026-10-13) | No app named "DuoWall". Closest competitor found: **"FoldTales: Duo Wallpapers"** ($3.99, released Oct 9 2026, a curated wallpaper pack). Several generic "Duo wallpaper" web sites exist (duothemes.com, foldwallpaper.com, iphoneduowallpapers.com). Fallback name: "UnfoldWall: Reveal Wallpapers". |
| Recommended repo | `duowall-ios` |
| Bundle ID | `com.jackyu.duowall` |
| Platform / min OS | iOS, **iPhone only**, **min iOS 27.0** (Duo APIs guarded by `#available(iOS 27.1, *)`). On iPad it runs in iPhone compatibility mode → `noHinge`. |
| Priority | **Medium** (Notion "All Duo Projects"); the ideas doc ranked it #1 for launch-window speed |
| Target | 2–3 weeks to submission |

**Platform API status (checked 2026-10-13, ET).** Sources: Apple tech talks 111463 / 111464 / 111465 on developer.apple.com/videos (transcript summaries at wwdc.ai), Apple's "Prepare your app for iPhone Duo" page (developer.apple.com/iphone-duo/prepare/), Apple doc content for `UIHingeInteraction` and `onHingeChange` (developer.apple.com pages render with JavaScript, so their text was read through a doc mirror and the tech talks), and the Apple-engineer answers in the Sept 23–24 iPhone Duo Photos & Camera forum Q&A.

| API / fact | Status | Notes |
|---|---|---|
| `View.onHingeChange(isEnabled:_:)` → `(DeviceHingeContext, DeviceHingeContext)`; `context.hinge: DeviceHinge?`; `DeviceHinge.angle: Angle`; `DeviceHinge.status` ∈ `.closed / .partiallyOpen / .fullyOpen` | **Confirmed** | `hinge == nil` means no hinge (any non-Duo device). Exact `@available` version is assumed to be iOS 27.1: guard with `if #available(iOS 27.1, *)`. |
| `UIHingeInteraction(updateHandler:)`, `update.hinge` (`UIHinge`, angle in radians `CGFloat`, status includes extra `.unknown`) | **Confirmed** | `hinge` becomes nil when the interaction leaves a hierarchy that provides hinge updates. |
| Hinge angle range, update rate, precision | **Not documented** ("system policy") | Never map absolute angles to outcomes. Use relative angle from an anchor, plus a calibration step. Smooth between samples. |
| `ArrangementView { } secondary: { }`, `.arrangementViewStyle(.split)`, `.split.axes(.horizontal)`, `.overlay`, `@Environment(\.overlayArrangementZIndex)`; UIKit `UIArrangementViewController` | **Confirmed** (iOS 27.1) | Put it inside a `NavigationStack`, never inside `List` / `ScrollView`. |
| `GeometryProxy.reservedRegions(kind:options:layoutDirectionBehavior:)`, kinds `.division` (fold) and `.occlusion` (cameras), option `.includeInactive`; `UIView.reservedRegions(kind:options:)` | **Confirmed** | The fold region is active only while the device is partially folded and has zero width when flat. Reported to be empty on the first layout pass, so re-query with `onGeometryChange`. |
| `.sceneAccessory { CameraCaptureAccessory(isEnabled:) { … } .onAvailabilityChange { } }`; UIKit `UISceneAccessory.cameraCapture(sceneConfiguration:userInfo:)` + `registerSceneAccessory(_:)` | **SwiftUI confirmed**; UIKit names are from a third-party write-up (**verify**) | Available only while the app is full screen on the inner display, in the foreground, with an active capture session (an `ARSession` also qualifies). Goes away when the device closes. Whether accessory views receive touches is **UNCONFIRMED**: treat them as display-only. |
| Non-camera scene accessories for third parties (outer display UI without a camera session) | **UNCONFIRMED / not available as far as public docs show** | Don't design around it. |
| `.builtInOuterUltraWideCamera`, `.builtInInnerUltraWideCamera`, Virtual Front Camera (position `.front`), `AVCaptureDeviceDirectionCoordinator(view:deviceTypes:changeHandler:)`, `AVCaptureDeviceDescriptor`, `AVCaptureDevice.dynamicAspectRatio`, `AVCaptureDeviceRotationCoordinator`, `AVCapturePhotoOutput.isCameraSensorOrientationCompensationEnabled` | **Confirmed** (tech talk 111465) | Inner camera: 1080p up to 60 fps. Outer front: up to 4K/120. The inner camera is unavailable while closed. Ask the direction coordinator; don't infer from the hinge. |
| `AVCaptureMultiCamSession` on Duo | **Confirmed in principle** (Apple engineer: up to 3 physical cameras) | Specific combinations: **runtime only** via `AVCaptureMultiCamSession.isMultiCamSupported` and `AVCaptureDevice.DiscoverySession.supportedMultiCamDeviceSets`. |
| New windows on the outer display | **Not allowed** | Use `UIWindowSceneActivation` for new-window UI; it hides itself when unavailable. Handle scene-request errors. |
| A public "which display am I on" API | **Not found** | For layout use size/traits. For cameras use the direction coordinator. For behavior, treat `hinge.status == .closed` as "on outer display" (heuristic, **verify on device**). |
| Background hinge events / lifetime fold count | **Not found** | Count only while the app is in the foreground. |
| Simulator posture control from CLI | **No official command** (`simctl` has no posture/hinge subcommand) | Device Hub UI has Closed / Open / Rotate buttons and an Option-key hinge slider. The third-party `hinge` CLI (github.com/artemnovichkov/hinge) uses a private protocol. Use it for local experiments only, never in CI gates. |

**DuoWall-specific facts:**
- **There is no public API to set the wallpaper** (unchanged in iOS 27). DuoWall renders and exports. The user applies the wallpaper via Settings → Wallpaper or via a Shortcuts "Set Wallpaper" action launched with `shortcuts://run-shortcut?name=…`.
- **Per-display wallpaper: not supported, as far as public information shows.** In the Sept 23–24 Duo forum Q&A an Apple engineer said wallpaper "works the same as on other iPhones" and didn't mention per-display settings. Apple's own Duo wallpaper is a **single landscape image (2670×1878)**: closed, the system zooms or crops it onto the outer display, and opening animates the transition (Beebom [B5], iClarified [B4]). Jack's own observation: "both screens share the same wallpaper". → **Mode S (single-image reveal) is the primary product.** Mode D (two images) is a hidden, runtime-switchable path in case Apple adds per-display wallpaper. It is **not** built in MVP beyond the data model.
- How exactly the system derives the outer image from the single image (center crop of ≈1291 px width = 1878 × 1398/2034, i.e. ≈48% of inner width? or a different zoom/offset?) is **UNCONFIRMED**. Measure it in M0 on the simulator (set a calibration grid image as wallpaper and screenshot both displays). Write the result into the bundled `DisplaySpec.json`.

## 1. PRD background

**Positioning:** The wallpaper studio for iPhone Duo. Design one image that looks perfect on the outer screen and *reveals more* when you unfold.

**Target users:** early iPhone Duo owners (premium, personalization-hungry, $1,999 device); designers and wallpaper creators who want templates and safe-area guides; gift and couples use (post-MVP).

**Pain point + evidence:**
- Duo uses one wallpaper for two very different aspect ratios (outer portrait 1398×2034 vs inner landscape 2670×1878), so a normal photo gets cropped badly on one of them. Third-party sites are already publishing "paired" wallpapers and how-to guides (duothemes.com/guides/different-wallpaper-each-screen, foldwallpaper.com/devices/iphone-duo, iphoneduowallpapers.com/how-to-set), and a $3.99 pack app (FoldTales) launched Oct 9. That's demand, but nobody offers an *editor for your own photos*.
- Lock-screen layout on Duo is unusual. "Lock screen clock not centered" thread: https://www.reddit.com/r/iPhoneFold/comments/1wvwfi3/ (311/107). Users need guides for where the clock, side Dock, and vertical Dynamic Island will cover their photo.
- Personalization is the first thing new-device owners do. Wallpaper is a proven paid category, and Apple's own Duo wallpaper with its opening animation is the demo everyone saw ([B5] https://gadgets.beebom.com/guides/apple-iphone-duo-wallpapers).
- Pricing feedback across the Reddit research: one-time purchases are preferred over subscriptions for small utilities (r/galaxyzflip paid launcher thread https://www.reddit.com/r/galaxyzflip/comments/1wa8aku/, 602/88).

**Selling points:** (1) **Reveal composer**: see the outer crop frame live on the inner canvas, so your subject stays perfect closed and the sides appear when opened; (2) **hinge-driven preview**: on a Duo, half-open the phone and the preview animates with your hinge; (3) safe-area overlays for the clock, Dock, vertical Dynamic Island, and crease; (4) smart fill for portrait photos (blur, mirror, color extend); (5) a curated pack of 30 designed pairs; (6) a one-tap apply via the free "DuoWall Apply" shortcut; (7) everything stays on your phone.

**Pricing (StoreKit 2):**
- Free: 10 bundled pairs + editor with photo import, reveal frame, safe areas, and blur/mirror fill. Exports carry a small corner watermark.
- **DuoWall Pro, one-time $6.99** (launch week $4.99): no watermark, all 30 bundled pairs + future bundled packs, gradient/text layers, all templates, HEIC/PNG quality options. Notion proposed a subscription ($2.99/mo, $14.99/yr, or $12.99–19.99 lifetime). We **deliberately choose a single low one-time price** per the Reddit pricing signal and the "no server" principle, which means no content feed to justify a subscription.
- Post-MVP: artist packs as non-consumables ($1.99–2.99), bundled in app updates (no download server).

**Success metrics (first 30 days after Oct 23):** 5,000 downloads; ≥6% Pro conversion; ≥4.5★; ≥30% of new users export at least one wallpaper (tracked locally only. For a product decision, use App Store Connect retention data plus review mining. No analytics SDK).

## 2. MVP scope

| ID | Feature | Detail |
|---|---|---|
| F1 | Onboarding (3 pages) | (1) reveal animation demo (hinge-driven on Duo, auto-plays elsewhere); (2) honest explanation: "iOS doesn't let apps set wallpapers. DuoWall makes the image, and you apply it in one tap with a Shortcut or in Settings"; (3) "Add the DuoWall Apply shortcut" (opens an iCloud shortcut link) + "I added it" / "Skip" (stored locally as `shortcutInstalledConfirmed`). |
| F2 | Gallery | Grid of pair cards (bundled packs, then "My Wallpapers"). Each card shows outer thumbnail + inner thumbnail. On Duo, when the device is `partiallyOpen`, the focused card's reveal progress follows the **relative** hinge angle via `RelativeAngleTracker`, with progress 0→1 mapped from the angle at the moment of half-opening to +60° or fully open. On no-hinge devices a "Preview reveal" scrubber is shown instead. |
| F3 | Pair Detail | Large preview, segmented control: Outer · Inner · Lock Screen · Home Screen (mock overlays for the clock, side Dock, vertical Dynamic Island, crease line). Actions: Apply (F6), Edit (F4), Favorite, Duplicate. |
| F4 | Editor (core) | Canvas = inner 2670×1878 (landscape). Overlay: **outer crop frame** derived from `DisplaySpec.singleImage.outerCrop` (fixed in Mode S; movable only in Mode D, hidden in MVP). Layers: photo (pan/zoom/rotate), fill (blur extend / mirror extend / solid color picked from photo / gradient), text (Pro), gradient (Pro). Templates: **Reveal** (subject centered in outer frame, "secret" on sides), **Panorama** (wide image across the inner screen), **Split Mood** (left/right halves differ; outer shows the center blend). Toggles: safe areas, crease line, outer-frame-only view. Undo/redo (50 steps). |
| F5 | Render & export | `ExportRenderer` renders the layer doc at exactly 2670×1878 (Mode S) using Core Image/Core Graphics, sRGB or Display P3, HEIC (default) or PNG. Free tier: watermark bottom-right of the *outer crop area* corner so it's visible but small. Also exports a 1398×2034 outer-crop preview image for sharing (not for wallpaper). |
| F6 | Apply flow | Save to the "DuoWall" album with `PHPhotoLibrary.requestAuthorization(for: .addOnly)`. Creating a named album needs read-write access, so album creation is **optional**: if only add-only is granted, save to the library and name the asset via the filename `DuoWall-<shortID>`. Album-name handling is UNCONFIRMED under add-only: verify. Then: if `shortcutInstalledConfirmed`, open `shortcuts://run-shortcut?name=DuoWall%20Apply` (the shortcut takes "latest photo from Recents/Album" → Set Wallpaper). If opening fails or the user returns within 3 s without success, show the manual guide: Settings → Wallpaper → Add New → Photos → pick it. On Duo, a step-by-step overlay advances when the user closes or opens the phone to check both displays ("Close your Duo to see the outer crop" → detects `closed` → "Now open it"). |
| F7 | Bundled packs | 30 pairs (10 free, 20 Pro) designed in-house or licensed CC0/commercial, shipped in the app bundle (~40 MB budget, HEIC). Each with `PairManifest` (title, palette, artist credit, template). |
| F8 | My Wallpapers | Local library of user projects (re-editable), favorites, delete, duplicate. |
| F9 | App Intents | `ApplyPairIntent(pair:)` (opens app → renders → saves → returns the image file as intent output, so a user's own Shortcut can chain "Set Wallpaper") and `RandomPairIntent`. `AppEntity` for pairs. Whether a Shortcut action can receive an image from an App Intent and pass it to Set Wallpaper on Duo: **verify in M0.** |
| F10 | Paywall + Settings | StoreKit 2 one-time Pro; Settings: export format, color space, overlay defaults, re-run onboarding, FAQ (honest wallpaper limits), privacy, Restore. |

**Non-goals (MVP):** setting the wallpaper programmatically (impossible); live or video wallpapers; Mode D UI; AI outpainting (Image Playground has no "extend" API. **Do not promise it**); creator uploads or revenue share; couples mode (two Duos side by side); widgets; iCloud sync (local only for MVP; CloudKit private DB would be post-MVP and still serverless); downloading packs from a server; remote config.

**Backlog:** Mode D (if Apple adds per-display wallpaper); rotation collections + Focus automation tutorial; couples template; FoldGlance color-matched widgets bundle; iCloud sync via CloudKit private database; sticker library; Apple Intelligence-based Image Playground styles (only if an API allows it; verify).

## 3. Fold-state behavior matrix

| State | Layout | Hinge-driven behavior |
|---|---|---|
| `closed` (outer, portrait 1398×2034) | Single column. Gallery 2-col grid; Editor = canvas on top (showing the *outer crop region* by default with a "Show full canvas" toggle), tool panel as a bottom sheet (`.presentationDetents`). | None. A banner in the editor says "Open your Duo to see the full canvas". |
| `partiallyOpen` (any angle, laptop/book/tent; system doesn't say which) | Same as `fullyOpen` layout (app is on the inner display). Use `reservedRegions(kind: .division)` to keep controls off the crease band. | Gallery: reveal progress follows the relative angle. Editor: optional "hinge preview" pill toggles a live closed↔open preview while flexing. Apply guide: ignored. |
| `fullyOpen` (inner, landscape 2670×1878) | `ArrangementView` `.split`: primary = canvas, secondary = layers/tools panel. Gallery: 4-col grid; Detail: inner preview with outer preview side by side. | None (reveal progress = 1). |
| Inner portrait (device rotated) | `.split.axes(.horizontal)`: canvas above, tools below; gallery 3-col. | — |
| Outer landscape | Gallery 3-col; editor tools as a trailing sidebar sheet. | — |
| Transitions closed↔open | No state loss: the editor keeps selection, zoom, undo stack, and open sheet (state in the `EditorModel`, not the view). The Apply guide advances steps on transitions. | Reveal animation plays once (Reduce Motion → cross-fade). |
| Split View (DuoWall + another app) | Compact width → closed layout regardless of posture. Hinge events are still received but only used in the gallery. | — |
| Non-Duo iPhone (`noHinge`) | Standard iPhone layout. Editor still edits the Duo canvas (for users preparing wallpapers or with a Duo on order) and can additionally export a "this iPhone" crop at `UIScreen` native size. | Reveal scrubber replaces hinge. |
| iPad (compatibility mode) | iPhone layout, `noHinge`. | Scrubber. |
| `unknown` | Treat as last known layout. | Ignore samples. |

## 4. User flows and screens

Navigation: `NavigationStack` with a root `TabView`-less design (gallery is home). Toolbar: My Wallpapers, Settings. Editor is a full-screen cover.

| Screen | States |
|---|---|
| S1 Onboarding | normal; "Shortcut link failed to open" (no network to fetch the iCloud shortcut → "You can add it later in Settings") |
| S2 Gallery | loading thumbnails (placeholder shimmer, no network); empty My Wallpapers ("Create your first: Import Photo"); Pro-locked cards with a lock badge |
| S3 Pair Detail | normal; rendering preview (progress); Pro-locked → paywall |
| S4 Photo import (PhotosPicker, no library permission needed) | user cancels → back; unsupported/huge image (> 100 MP or RAW only) → error toast with "Try another photo"; HDR photo → tone-mapped with a note |
| S5 Editor | editing; low-memory warning (reduce preview resolution); export in progress; unsaved-changes prompt on close |
| S6 Apply sheet | saving; **Photos permission denied** ("Allow DuoWall to add photos in Settings" + button to `UIApplication.openSettingsURLString` + "Share instead" fallback via `ShareLink`); saved; shortcut launched; manual guide steps; error (disk full) |
| S7 Paywall | products loading; **offline / unavailable** ("Store unavailable. Try again later", free features unaffected); pending (Ask to Buy); success |
| S8 Settings / FAQ | — |

Offline: the whole app works offline except the purchase and the iCloud shortcut link.

## 5. UI / design brief

- **Visual direction:** gallery-first, image-forward, dark-leaning (wallpapers look best on near-black chrome). Hero motif: a card that physically "opens" like a book to reveal a wider image. The UI chrome stays minimal: floating translucent toolbars (Liquid Glass materials of iOS 26+ via standard components; don't hand-roll glass).
- **Layout per state:** see §3. Editor on the inner display: canvas ~70% width, tool panel ~30%, tool panel on the side *away from* the right-edge status bar zone. Keep every interactive control out of `reservedRegions(.division)` and `(.occlusion)` (the camera on inner, the vertical Dynamic Island on outer).
- **Components:** PairCard (dual thumbnail + reveal animation), CropFrameOverlay (dashed rounded rect with "Outer screen" label), SafeAreaOverlay (semi-transparent clock/Dock/Island shapes, togglable), CreaseGuide (thin centered line + translucent band), LayerList rows, FillModePicker, PaywallView (StoreKit `ProductView`/`StoreView` styled).
- **Type:** SF Pro, Dynamic Type everywhere except the canvas. Captions in the overlays use `.caption2`.
- **Color:** neutral grays + one accent (suggest warm amber, "unfold light"). Respect wallpaper colors on detail pages (extract the palette for background tint). Full dark and light modes; overlays legible on both (use outlined + shadowed strokes).
- **Motion:** the reveal opening is the signature animation (spring, 0.6 s). Reduce Motion → instant swap + cross-fade. Hinge-driven progress uses no extra animation (direct mapping, with a light low-pass filter).
- **Accessibility:** VoiceOver labels for pair cards ("Aurora pair, free, outer shows mountain, opens to valley"); editor gestures have button alternatives (nudge, zoom ±, rotate ±); the hinge preview has a slider alternative; contrast ≥ 4.5:1 for chrome text; Dynamic Type up to AX5 in all non-canvas UI (tool panel scrolls).
- **Localization:** en + zh-Hans String Catalog; pair titles localized; FAQ localized.
- **App Store screenshots:** iPhone Duo outer (1398×2034) + inner (2007×2853), plus the standard 6.9" iPhone set. Story: (1) "Perfect closed. Stunning open." reveal; (2) editor with crop frame; (3) safe-area overlays; (4) one-tap apply; (5) gallery. Make them with DuoShots (dogfood). **Icon:** two overlapping panels like an opening book, with a gradient landscape inside; no Apple device silhouette.

## 6. Technical architecture

**Stack:** Swift 6, SwiftUI, Observation, **SwiftData** for local user projects (no CloudKit in MVP), Core Image + Core Graphics for rendering, PhotosUI (`PhotosPicker`), Photos (`PHPhotoLibrary`, add-only), App Intents, StoreKit 2, FoldKit (shared).

All fold logic goes through one small local Swift package, **`FoldKit`**. It's the same package in every iOS project in this portfolio: copy it in as `Packages/FoldKit`. Nothing else in the app may call `onHingeChange` / `UIHingeInteraction` directly.

```swift
// Packages/FoldKit/Sources/FoldKit/FoldState.swift
import SwiftUI
import Observation

public enum FoldPosture: String, Codable, Sendable, CaseIterable {
    case noHinge        // non-Duo iPhone, iPad, Mac ("Designed for iPad"), or hinge context unavailable
    case closed         // folded; app is (assumed) on the outer display
    case partiallyOpen  // flexed / half-folded (laptop, book, tent… system does not tell which)
    case fullyOpen      // flat; app on inner display
    case unknown        // UIKit `.unknown`, or transient states
}

public struct FoldState: Equatable, Sendable {
    public var posture: FoldPosture
    /// Degrees exactly as reported by the system. `nil` when there is no hinge.
    /// The range is NOT documented. Never compare to absolute thresholds without calibration.
    public var angleDegrees: Double?
    public var timestamp: Date
    public init(posture: FoldPosture, angleDegrees: Double?, timestamp: Date = .now) {
        self.posture = posture; self.angleDegrees = angleDegrees; self.timestamp = timestamp
    }
    public static let noHinge = FoldState(posture: .noHinge, angleDegrees: nil, timestamp: .distantPast)
    public var hasHinge: Bool { posture != .noHinge }
}

@MainActor
public protocol FoldStateProvider: AnyObject, Observable {
    var state: FoldState { get }
    /// Yields the current value immediately, then every change.
    func states() -> AsyncStream<FoldState>
}

/// Production provider. Fed by `HingeBridge`, attached once at the root of every scene.
@MainActor @Observable
public final class SystemFoldStateProvider: FoldStateProvider { /* stores state, fans out to continuations */ }

/// Test / preview / UI-test provider. Driven by code or by launch arguments (see §8).
@MainActor @Observable
public final class MockFoldStateProvider: FoldStateProvider {
    public func set(_ posture: FoldPosture, angle: Double? = nil)
    public func play(_ script: [FoldScriptStep]) async   // e.g. sweep 180→0 over 2 s at 30 Hz
}

public struct HingeBridge: ViewModifier {
    let provider: SystemFoldStateProvider
    public func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {                     // availability version assumed. Verify in Xcode 27.1
            content.onHingeChange { _, ctx in provider.ingest(ctx.hinge) }   // maps DeviceHinge → FoldState
        } else {
            content.onAppear { provider.ingestNoHinge() }
        }
    }
}

/// Converts noisy absolute angles into a stable 0…1 control value.
public struct RelativeAngleTracker: Sendable {
    public var anchorDegrees: Double?             // set when the interaction starts
    public var observedMin: Double, observedMax: Double   // learned during calibration
    public var smoothing: Double = 0.25           // EMA factor; animate between samples
    public mutating func begin(at degrees: Double)
    public mutating func update(_ degrees: Double) -> Double     // returns normalized progress 0…1
    public mutating func delta(_ degrees: Double) -> Double       // signed degrees since anchor
    public mutating func reset()
}
```

Rules:
- `DeviceHinge.status` mapping: `.closed → .closed`, `.partiallyOpen → .partiallyOpen`, `.fullyOpen → .fullyOpen`, `@unknown default → .unknown`. A `nil` hinge maps to `.noHinge`.
- Inject the provider through the SwiftUI environment: `@Environment(\.foldState)`. Feature code depends on the `FoldStateProvider` protocol, never on the concrete class.
- Launch argument `-FoldMock <value>` swaps in `MockFoldStateProvider`. Values: `nohinge`, `closed`, `open`, `half:<deg>`, `sweep:<from>-<to>:<seconds>`, `script:<bundled-json-name>`. It is only honored in DEBUG builds or when `-UITestMode 1` is present.
- Every hinge-driven interaction must also have a non-hinge control (slider, buttons, drag, or tilt) with identical results. This covers non-Duo devices, VoiceOver users, and App Review on devices without a hinge.

**Modules:** `FoldKit` (shared), `DisplaySpecKit` (bundled `DisplaySpec.json` loader + geometry helpers: outer crop rect, safe-area rects, crease band), `EditorCore` (layer doc, commands, undo), `RenderKit` (renderer, fill algorithms, watermark), `Library` (SwiftData models, bundled packs), `ApplyKit` (Photos save, Shortcut launch, manual guide state machine), `Store`, `App` (views).

**Data model:**
```swift
enum PairMode: String, Codable { case single, dual }           // MVP: .single only
enum PairSource: Codable, Hashable { case user, bundled(packID: String) }
@Model final class WallpaperPair {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var modeRaw: String                       // PairMode
    var layerDocData: Data                    // JSON-encoded LayerDoc
    var renderedInnerFile: String?            // relative path in Application Support/Renders
    var renderedOuterPreviewFile: String?     // 1398×2034 crop preview (sharing only)
    var isFavorite: Bool
    var sourceData: Data                      // JSON PairSource
    var isPremium: Bool                       // bundled Pro pairs
}
struct LayerDoc: Codable, Equatable {
    var canvas: CGSize = .init(width: 2670, height: 1878)
    var layers: [Layer]
    var template: TemplateKind
    var outerCrop: CGRect?                    // normalized; nil = DisplaySpec default (Mode S)
}
enum Layer: Codable, Equatable, Identifiable {
    case photo(PhotoLayer), fill(FillLayer), text(TextLayer), gradient(GradientLayer)
}
struct PhotoLayer: Codable, Equatable { var id: UUID; var assetFile: String; var transform: LayerTransform }
struct FillLayer: Codable, Equatable { var id: UUID; var kind: FillKind /* blurExtend, mirrorExtend, solid(RGBA), auto */ }
struct LayerTransform: Codable, Equatable { var center: CGPoint; var scale: CGFloat; var rotation: Double }  // canvas-normalized
enum TemplateKind: String, Codable { case reveal, panorama, splitMood }
struct DisplaySpec: Codable { // bundled DisplaySpec.json (updated only via app releases, never remote)
    var inner: CGSize      // 2670×1878 (landscape canvas)
    var outer: CGSize      // 1398×2034
    var singleImage: SingleImageMapping  // outerCrop (normalized rect), measured in M0
    var safeAreas: [SafeAreaShape]       // clock, dock, island, camera — per display, normalized
    var creaseBand: ClosedRange<Double>  // normalized x on inner, e.g. 0.49...0.51
    var version: Int
}
```
Imported photos are copied into `Application Support/Assets/<uuid>.heic` (downscaled to ≤ 3× canvas long edge) so projects never depend on Photos library access.

**Persistence:** SwiftData store in Application Support; renders in `Application Support/Renders`; settings in `UserDefaults`; purchase state recomputed from StoreKit (cached Bool in UserDefaults only for first-frame UI).

**Frameworks:** SwiftUI, SwiftData, PhotosUI, Photos, CoreImage, CoreGraphics, ImageIO, UniformTypeIdentifiers, AppIntents, StoreKit, FoldKit.

**Permissions / Info.plist:**
- `NSPhotoLibraryAddUsageDescription`: "DuoWall saves the wallpapers you create to your photo library so you can set them as your wallpaper." / zh-Hans: "DuoWall 会把你制作的壁纸保存到照片图库，方便你将其设为墙纸。"
- **No** `NSPhotoLibraryUsageDescription` (PhotosPicker needs no permission), no camera, no location.
- `LSApplicationQueriesSchemes`: `shortcuts` (only needed for `canOpenURL`; opening works without it).

Privacy stance: **no tracking, no data collection off-device.** App Store privacy label: **Data Not Collected.** No third-party SDKs. No `NSUserTrackingUsageDescription`, no ATT prompt.

Base `PrivacyInfo.xcprivacy` (add a required-reason entry only for APIs the app actually touches. The reason codes below are Apple's published codes; re-check against the current list when submitting):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>NSPrivacyTracking</key><false/>
  <key>NSPrivacyTrackingDomains</key><array/>
  <key>NSPrivacyCollectedDataTypes</key><array/>
  <key>NSPrivacyAccessedAPITypes</key><array>
    <dict>
      <key>NSPrivacyAccessedAPIType</key><string>NSPrivacyAccessedAPICategoryUserDefaults</string>
      <key>NSPrivacyAccessedAPITypeReasons</key><array><string>CA92.1</string></array>
    </dict>
    <!-- add FileTimestamp (C617.1) if you read file modification dates in the app container -->
    <!-- add DiskSpace (E174.1) if you check free space before writing large files -->
  </array>
</dict></plist>
```
Widget / app extensions get their own copy of the manifest.
DuoWall entries: `NSPrivacyAccessedAPICategoryUserDefaults` (CA92.1), `NSPrivacyAccessedAPICategoryFileTimestamp` (C617.1, sorting renders by date) and `NSPrivacyAccessedAPICategoryDiskSpace` (E174.1, only if checking free space before export).

**StoreKit config:** `com.jackyu.duowall.pro` non-consumable $6.99, Family Sharing enabled.
StoreKit 2 implementation (shared pattern, `Store` module):
- `@MainActor @Observable final class Store`: loads products with `Product.products(for:)`, starts a `Transaction.updates` listener at launch, and recomputes entitlements from `Transaction.currentEntitlements`. Every `VerificationResult` is checked; `.unverified` grants nothing.
- Purchase: `product.purchase()`. Handle `.success(.verified)` (then `transaction.finish()`), `.pending` (Ask to Buy / SCA: show a "Waiting for approval" state), and `.userCancelled` (silently return).
- Restore: a "Restore Purchases" button calls `AppStore.sync()`. Also show it in Settings.
- Refunds / revocation: a transaction with `revocationDate != nil` removes the entitlement immediately (next launch at the latest).
- Family Sharing: enable it in App Store Connect for the non-consumable unlock(s). The code doesn't change.
- Offline: cache the last computed entitlement set in `UserDefaults` only to avoid a paywall flash, and always re-verify when `currentEntitlements` arrives.
- The paywall uses SwiftUI `ProductView` / `StoreView` where it fits (it localizes prices automatically). Never hardcode prices in UI strings.
- Local testing: a `Configuration.storekit` file in the repo, selected in the Run scheme. Unit tests use `StoreKitTest.SKTestSession` (purchase, Ask-to-Buy, refund, expire, failure).

**Shortcut asset:** "DuoWall Apply", published as an iCloud link (created manually by Jack on a device and recorded in `docs/shortcut.md`). Actions: Find Photos (sorted by creation date, limit 1, filename contains "DuoWall") → Set Wallpaper (Lock + Home, perspective off, "show preview" on). Verify each action on Duo in M0.

**Project structure:**
```
duowall-ios/
├─ DuoWall.xcodeproj
├─ App/ (DuoWallApp.swift, RootView, Gallery/, Detail/, Editor/, Apply/, Paywall/, Settings/, Onboarding/)
│  ├─ Resources/ Localizable.xcstrings, Assets.xcassets, DisplaySpec.json, Packs/<packID>/*.heic + manifest.json
│  ├─ PrivacyInfo.xcprivacy, Info.plist
├─ Packages/ FoldKit/ DisplaySpecKit/ EditorCore/ RenderKit/ Library/ ApplyKit/ Store/
├─ Tests/ (unit per package) UITests/
├─ Configuration.storekit
└─ docs/ M0-findings.md, shortcut.md, artwork-licenses.md
```

## 7. Edge cases

- Huge photos (48 MP ProRAW, panoramas 20k px wide) → downsample with `CGImageSourceCreateThumbnailAtIndex` to ≤ 8000 px long edge before editing; memory-pressure handler drops preview caches.
- Portrait-only photo in a landscape canvas → default fill = blur extend; warn if the subject would be cut by the outer frame (use Vision saliency `VNGenerateAttentionBasedSaliencyImageRequest` to auto-center the subject in the outer crop, user-overridable).
- Tiny photos (< 1000 px) → allowed, with a "may look blurry" badge.
- HDR / Display P3 / 10-bit photos → render in P3 if the user picks P3; otherwise convert to sRGB; HDR gain map dropped (note it). Wallpaper HDR behavior on Duo is UNCONFIRMED.
- Live Photos / videos selected → use the still frame only (PhotosPicker filter `.images`).
- Photos add-only denied or restricted (parental controls) → Share sheet fallback ("Save Image" there also needs permission. Offer "Save to Files").
- Disk full on render → error with retry; temp files cleaned.
- Shortcut not installed, renamed, or failed → `UIApplication.open` returns false or the shortcut errors (user returns to app) → manual guide; offer "Reinstall shortcut". Shortcuts can't call back unless `x-success` is used. Use `shortcuts://x-callback-url/run-shortcut?name=…&x-success=duowall://applied&x-error=duowall://failed` (x-callback support is documented for Shortcuts; register the `duowall` URL scheme).
- Set Wallpaper action unavailable on Duo or produces wrong cropping → FAQ + manual path; `DisplaySpec` update in the next release.
- Apple adds per-display wallpaper in iOS 27.x → Mode D enabled in an app update (not remote).
- User folds or unfolds mid-edit → no state loss (AC).
- Rapid hinge flapping → reveal progress low-pass filtered; no heavy re-render during flex (use pre-rendered thumbnails).
- Hinge never reports (nil on Duo due to Split View / context) → scrubber appears.
- Locale: zh-Hans text layers need fonts with CJK glyphs (use system font; custom fonts limited to those with CJK coverage or fall back).
- Accessibility: VoiceOver can complete import → template → export → apply without gestures.
- StoreKit: refund → Pro features lock; previously exported images remain; watermark appears on new exports only. Family Sharing grants Pro.
- Bundled pack license metadata missing → build-time test fails.
- App update changes `DisplaySpec` → existing projects keep their layer docs (normalized coordinates); re-render on next export.

## 8. Testing plan

How to simulate fold states and hinge angles:
1. **Unit tests (fast, CI):** inject `MockFoldStateProvider`. Drive `set(.closed)`, `set(.partiallyOpen, angle: 95)`, `set(.fullyOpen)`, `set(.noHinge)` and scripted sweeps, and assert on view-model state. No simulator posture needed.
2. **UI tests (XCUITest, CI):** launch with `-UITestMode 1 -FoldMock <value>`. A hidden DEBUG-only "Fold debug" overlay (toggled with `-FoldDebugOverlay 1`) exposes buttons with accessibility identifiers `fold.closed`, `fold.half`, `fold.open`, `fold.nohinge`, `fold.sweep`, so a UI test can change the mocked posture mid-flow. Mocking changes hinge signals only. It does **not** resize the window.
3. **Real layout changes (manual or semi-automated):** run on the **iPhone Duo simulator** (Xcode 27.1, Device Hub). Use the Closed / Open / Rotate buttons, and hold Option for the hinge-angle slider. This is the only official way to test true outer↔inner resizing, reserved regions, and split view. `simctl` has no posture command.
4. **Optional local helper:** the third-party `hinge` CLI (`hinge 120`, `hinge sweep 180 0 2`) sets the simulator hinge through a private, undocumented protocol. Use it for local exploration only, and never make a CI gate depend on it.
5. **Non-Duo fallback:** run the same UI tests on an iPhone 17/18 simulator with `-FoldMock nohinge`, and without any mock, to verify `hinge == nil` handling.

**Unit tests:** `DisplaySpecKit` (outer crop rect computation, safe-area mapping, rotation); `EditorCore` (commands, undo/redo, codable round-trip, template application); `RenderKit` (exact output size 2670×1878; no alpha in HEIC/PNG output; watermark present only when free; fill algorithms deterministic for fixture images; snapshot comparison with tolerance); `ApplyKit` state machine (shortcut success / x-error / timeout → manual guide; permission denied → share fallback) using a `PhotoSaver` protocol + `URLOpener` protocol mocks; `RelativeAngleTracker` mapping for the reveal (anchor at first `partiallyOpen` sample; progress clamps 0…1; jitter filter); `Store` with `SKTestSession` (purchase, restore, refund, Ask to Buy, Family Sharing).

**UI tests:** `-UITestMode 1 -FoldMock closed|open|half:100|sweep:20-180:3|nohinge` → assert layouts (split vs single column by accessibility identifiers `layout.split` / `layout.compact`), reveal progress label `reveal.progress` changes during the sweep, the scrubber exists in `nohinge`. Full flow: import fixture photo (UI-test hook injects an image instead of PhotosPicker: `-UITestImportFixture aurora`) → Reveal template → export → apply sheet with mocked saver.

**Real device needed (after Oct 23):** system wallpaper mapping from one image to both displays; Set Wallpaper Shortcut behavior; add-only album naming; hinge feel for the reveal; safe-area positions (clock, Dock, Island) for `DisplaySpec`.

**Acceptance criteria:**
- AC1: Exported Mode S wallpaper is exactly 2670×1878 px, HEIC or PNG, no alpha.
- AC2: On the iPhone Duo simulator in closed, half-open (Option-slider), and open states, no interactive control intersects `reservedRegions(.division)` or `(.occlusion)` (UI test reads frames via a debug overlay that logs intersections; zero intersections).
- AC3: After M0 measurement, the outer-crop overlay matches the system's actual outer wallpaper crop within 2% (compare a grid wallpaper screenshot of the outer display with the app's crop frame).
- AC4: With `-FoldMock nohinge`, the reveal is controlled by a slider and every feature works; no crash.
- AC5: With `-FoldMock sweep:20-180:3`, gallery reveal progress rises monotonically from 0 to 1 (±0.05 jitter).
- AC6: Closing and reopening mid-edit preserves layers, selection, zoom, and the undo stack (UI test with mock transitions + manual check in Device Hub).
- AC7: Shortcut failure or missing shortcut falls back to the manual guide within 1 s of returning to the app.
- AC8: Only `NSPhotoLibraryAddUsageDescription` is requested; no camera, location, or full Photos permission strings exist in Info.plist (build-script check).
- AC9: StoreKit test: purchase removes the watermark immediately; restore works; refund re-adds the watermark on next export; Ask to Buy shows pending.
- AC10: All UI strings exist in en and zh-Hans (String Catalog has 0 untranslated).
- AC11: VoiceOver can complete the full import→export→apply flow (manual checklist).
- AC12: No network requests except StoreKit and the user-initiated shortcut link (verified with a `URLProtocol` audit in DEBUG + Charles/Proxyman manual check).

## 9. App Store review risks

| Risk | Mitigation |
|---|---|
| **4.2 / 4.3 Spam: "just a wallpaper pack"** | The editor and fold-specific reveal composer are the core; bundled content is secondary. Review Notes describe the editor flow and include a demo video. |
| **Wallpaper limitations / misleading claims (2.3.1)** | Never say "sets your wallpaper automatically". Copy: "Create wallpapers and apply them in one tap with Shortcuts". The FAQ explains the limits. |
| Shortcut dependency | The app is fully useful without the shortcut (manual guide). Shortcut link is user-initiated. |
| Content rights (5.2) | Bundled art in-house or licensed; `docs/artwork-licenses.md`; artist credits shown in Detail. User photos never leave the device. |
| Trademark ("Duo") | "Duo" is generic; don't use Apple's product imagery in the icon. Keep "iPhone Duo" in the description only descriptively. |
| Review on non-Duo device | Works on every iPhone (scrubber reveal, Duo canvas editing). Review Notes explain. |
| Photos permission rationale (5.1.1) | Add-only; purpose string precise. |

## 10. Milestones

| # | Milestone | Tasks | Est. |
|---|---|---|---|
| M0 | Verification (simulator now, device Oct 23) | Measure outer crop from a single wallpaper (grid image) in the Duo simulator; record safe areas from screenshots; test Set Wallpaper shortcut + x-callback on simulator; test add-only album behavior; write `DisplaySpec.json` v1 + `docs/M0-findings.md` | 1 d |
| M1 | Skeleton | Project, FoldKit package, DisplaySpecKit + tests, SwiftData models, String Catalog, privacy manifest, CI | 1 d |
| M2 | Gallery + Detail | Bundled pack loader (start with 6 placeholder pairs), PairCard reveal (mock + hinge), Detail overlays | 2 d |
| M3 | Editor core | Layer doc, photo layer, transforms, undo, crop frame, safe-area + crease overlays, templates | 3 d |
| M4 | Fill + render | Blur/mirror/solid/auto fill, saliency centering, ExportRenderer, watermark, tests (AC1) | 2 d |
| M5 | Apply flow | Photos add-only, shortcut launch + x-callback, manual guide with hinge-driven steps (AC7, AC8) | 1.5 d |
| M6 | Fold layouts | ArrangementView split, reservedRegions, rotation, Split View compact, state preservation (AC2, AC6) | 1.5 d |
| M7 | Store + paywall + settings + intents | StoreKit 2, paywall, Pro gating, App Intents (AC9) | 1.5 d |
| M8 | Content + polish | Final 30 pairs, onboarding, zh-Hans, a11y pass, App Store screenshots via DuoShots, Review Notes (AC10–AC12) | 2.5 d |
| M9 | Device verification | On real Duo: AC3, hinge feel, Shortcut; update `DisplaySpec` | 0.5 d |
| | **Total** | | **≈16.5 dev-days** |

## 11. Open questions & assumptions

1. How exactly does iOS map one wallpaper image onto the outer display (crop rect, zoom, parallax)? Assumed: centered crop ≈48% of inner width. **Measure.**
2. Is there any per-display wallpaper setting in iOS 27.1 (Settings or Shortcuts "Set Wallpaper" parameters)? Assumed: no (Apple engineer Q&A).
3. Does the Shortcuts Set Wallpaper action work on Duo with a 2670×1878 image, and does it crop correctly for the outer display?
4. Can an add-only app create or name an album? (Assumed: no; use filename tagging.)
5. Exact safe-area shapes: lock-screen clock (reported off-center: r/iPhoneFold 1wvwfi3), side Dock, vertical Dynamic Island, inner camera.
6. Hinge reveal mapping comfort: anchor + 60° span is a guess; tune on device.
7. Price: $6.99 one-time vs Notion's subscription. Assumption: one-time wins; review after 2 weeks.
8. Bundled content: who designs the 30 pairs (Jack, commissioned artist, CC0)? Budget and licenses needed before M8.
9. `@available` versions of `onHingeChange`/`ArrangementView` (assumed 27.1 → min OS 27.0 with guards; if they are 27.0, simplify).


---
*Spec version 1.0 · 2026-10-13 · Prepared for Jack Yu. API facts were checked against Apple developer sources on that date (see the API status table). Items marked UNCONFIRMED or "verify" must be validated in M0 or on a real device.*
