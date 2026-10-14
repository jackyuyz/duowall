// DisplaySpecKit - Display geometry and specification for iPhone Duo
//
// This package provides all display dimension calculations needed for
// wallpaper composition targeting iPhone Duo's inner and outer displays.
//
// IMPORTANT: Many dimensions are ASSUMPTIONS pending real device verification.
// See DisplaySpec.json notes and docs/M0-findings.md for verification status.

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

public let displaySpecKitVersion = "1.0.0"
