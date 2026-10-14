# DuoWall: Unfold Wallpapers

A native iOS app for iPhone Duo that creates matched wallpapers for the inner (unfolded) and outer (cover) displays.

**App Store Name:** DuoWall: Unfold Wallpapers  
**Bundle ID:** `com.jackyu.duowall`  
**Minimum iOS:** 17.0 (with iOS 27.1+ for Duo hinge APIs)

## Overview

DuoWall is a wallpaper workshop specifically designed for iPhone Duo. It solves the problem of creating wallpapers that look perfect on both the narrow outer display (1398×2034) and the wide unfolded inner display (2670×1878).

### Key Features

- **Reveal Composer**: See the outer crop frame live on the inner canvas
- **Hinge-Driven Preview**: On Duo, the reveal animation follows your hinge angle
- **Safe Area Overlays**: Clock, Dock, Dynamic Island, and crease guides
- **Smart Fill**: Blur extend, mirror extend, or solid color for portrait photos
- **One-Tap Apply**: Export to Photos and apply via Shortcuts

## Pricing

DuoWall Pro (`com.jackyu.duowall.pro`) is a one-time non-consumable with Family Sharing turned on.

| | Price |
|---|---|
| Regular | $6.99 |
| Launch week | $4.99 |

The launch-week price is an introductory offer. Both prices are set in App Store Connect, not hardcoded in the app. `Configuration.storekit` uses the regular **$6.99** price for local StoreKit testing and marks the product `familyShareable`. A family member's purchase unlocks Pro for the rest of the Family Sharing group.

## Project Structure

```
duowall-ios/
├── project.yml           # XcodeGen project definition
├── App/
│   ├── Sources/          # SwiftUI app layer
│   │   ├── Gallery/      # Main gallery view
│   │   ├── Detail/       # Pair detail view
│   │   ├── Editor/       # Wallpaper editor
│   │   ├── Onboarding/   # First-run flow
│   │   └── Settings/     # Settings & FAQ
│   └── Resources/        # Assets, localization, Info.plist
├── Packages/
│   ├── FoldKit/          # Fold state management (testable on Linux)
│   ├── DisplaySpecKit/   # Display geometry helpers
│   ├── EditorCore/       # Layer document model, commands, undo
│   ├── RenderKit/        # Rendering logic, presets
│   └── ApplyKit/         # Shortcut apply flow and manual-guide fallback
├── Configuration.storekit  # StoreKit local config (family-shareable Pro, $6.99)
├── Tests/
│   ├── DuoWallTests/     # Unit tests
│   └── DuoWallUITests/   # UI tests
├── docs/
│   ├── duowall-spec.md   # Full implementation specification
│   └── ui/png/           # UI mockups
└── scripts/              # Build and utility scripts
```

## Building on Mac

### Prerequisites

- macOS 14.0+
- Xcode 15.0+ (Xcode 27.1+ for full Duo simulator support)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) installed:
  ```bash
  brew install xcodegen
  ```

### Steps

1. Clone the repository:
   ```bash
   git clone <repo-url>
   cd duowall-ios
   ```

2. Generate the Xcode project:
   ```bash
   xcodegen generate
   ```

3. Open in Xcode:
   ```bash
   open DuoWall.xcodeproj
   ```

4. Select the `DuoWall` scheme and your target device/simulator.

5. Build and run (⌘R).

### Running Tests

**Swift Package Tests (Linux-compatible):**
```bash
cd Packages/FoldKit && swift test
cd Packages/DisplaySpecKit && swift test
cd Packages/EditorCore && swift test
cd Packages/RenderKit && swift test
cd Packages/ApplyKit && swift test
```

**Xcode Tests:**
- Run the `DuoWall` scheme tests (⌘U) for full integration tests.
- `Tests/DuoWallTests/StoreKitSessionTests.swift` uses StoreKitTest `SKTestSession` for AC9 (purchase, restore, refund, Ask to Buy). The scheme selects `Configuration.storekit`. These tests compile in Xcode and are not part of `swift test` on Linux.

### UI Test Schemes

The project includes multiple schemes for UI testing with different fold states:

- `DuoWall` - Default scheme
- `DuoWall-UITest-NoHinge` - Tests non-foldable device behavior
- `DuoWall-UITest-Closed` - Tests closed (outer display) state
- `DuoWall-UITest-Open` - Tests fully open state

## Architecture

### Platform-Independent Packages

All core logic is in Swift packages that build and test on Linux:

- **FoldKit**: `FoldState`, `FoldStateProvider` protocol, `MockFoldStateProvider`, `RelativeAngleTracker`
- **DisplaySpecKit**: `DisplaySpec` model, geometry calculations, safe area definitions
- **EditorCore**: `LayerDoc`, layer types, `EditorCommand` protocol, `EditorUndoManager`
- **RenderKit**: `ExportRenderer` geometry, `PresetPacks`, export configuration

### iOS App Layer

The SwiftUI app layer (`App/Sources/`) handles:
- UI views and navigation
- System integration (Photos, Shortcuts)
- Hinge API integration via `HingeBridge`
- StoreKit 2 purchases

## Display Specifications

### Assumed Dimensions (VERIFY ON DEVICE)

| Display | Width | Height | Orientation |
|---------|-------|--------|-------------|
| Inner | 2670 px | 1878 px | Landscape |
| Outer | 1398 px | 2034 px | Portrait |

### Outer Crop Mapping

The outer display shows a centered crop of the inner canvas:
- Crop width: ~48.5% of inner width (1295 px)
- Crop position: Horizontally centered (x: 0.2573)
- Crop height: Full inner height

**⚠️ These are assumptions based on the outer display's aspect ratio. Must be verified with the M0 calibration test on the Duo simulator or real device.**

## Open Questions / Unverified APIs

### For Product Manager Review

1. **Per-display wallpaper**: Currently assumed not available. If Apple adds this in iOS 27.x, Mode D becomes relevant.

2. **Outer crop mapping**: The exact crop that iOS applies to a single wallpaper for the outer display needs measurement. The current assumption (~48.5% centered) is derived from aspect ratio math.

3. **Shortcut behavior**: Does the "Set Wallpaper" Shortcuts action work correctly on Duo with a 2670×1878 image?

4. **Add-only Photos permission**: Can an app with only add-only permission name or create an album?

5. **Safe area positions**: The clock position (reportedly off-center per Reddit reports), dock, and Dynamic Island positions need verification on the real device.

### Unverified APIs (wrapped with protocols/mocks)

| API | Status | Fallback |
|-----|--------|----------|
| `onHingeChange` / `DeviceHinge` | Confirmed iOS 27.1 | `MockFoldStateProvider` |
| `ArrangementView` | Confirmed iOS 27.1 | Standard layout |
| `reservedRegions(kind:)` | Confirmed iOS 27.1 | Manual safe areas |
| Scene accessories for outer display | UNCONFIRMED | Not implemented |
| Background hinge events | Not found | Foreground only |

## UI Mockups

See `docs/ui/png/` for mockups of key screens:

- `duowall-inner-unfolded.png` - Editor on fully open inner display
- `duowall-half-folded.png` - Editor in laptop/tent mode
- `duowall-outer-cover.png` - Wallpaper on outer display
- `duowall-gallery.png` - Gallery view with pair cards

## Localization

The app supports:
- English (en)
- Simplified Chinese (zh-Hans)

String Catalog: `App/Resources/Localizable.xcstrings`

## Privacy

- **No tracking, no analytics, no data collection off-device**
- App Store Privacy Label: **Data Not Collected**
- Only permissions: `NSPhotoLibraryAddUsageDescription` (add-only Photos access)

## License

Copyright © 2026 Jack Yu. All rights reserved.

---

*See `docs/duowall-spec.md` for the full implementation specification including fold-state behavior matrix, edge cases, testing plan, and milestones.*
