// FoldKit - Fold state management for iPhone Duo and other foldable devices
//
// This package provides platform-independent fold state logic that can be
// unit tested on Linux. The SwiftUI/UIKit integration (HingeBridge) lives
// in the iOS app layer, not here.

@_exported import Foundation

// Re-export public types
public typealias FoldKitVersion = String
public let foldKitVersion: FoldKitVersion = "1.0.0"
