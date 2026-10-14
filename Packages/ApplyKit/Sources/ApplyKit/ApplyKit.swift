import Foundation

/// Shortcut used to hand a saved wallpaper to the system Set Wallpaper action.
public enum ApplyShortcut {
    public static let name = "DuoWall Apply"

    /// x-callback URL. Success and failure return to the `duowall` URL scheme.
    public static var launchURL: URL {
        URL(string: "shortcuts://x-callback-url/run-shortcut?name=DuoWall%20Apply&x-success=duowall://applied&x-error=duowall://failed")!
    }
}

public enum ShortcutCallback: Equatable, Sendable {
    case success
    case error
}

public enum ManualGuideReason: String, Equatable, Sendable {
    /// User never confirmed the shortcut is installed.
    case shortcutNotInstalled
    /// `open` returned false.
    case openFailed
    /// Shortcuts called the x-error URL.
    case shortcutError
    /// The app became active again without a success callback.
    case returnedWithoutSuccess
}

public enum ApplyPhase: Equatable, Sendable {
    case idle
    case launchingShortcut
    case shortcutSucceeded
    case manualGuide(ManualGuideReason)
}

/// AC7 timing. The manual guide must be visible within one second of returning to the app.
public enum ApplyTiming {
    public static let manualGuideDeadline: Duration = .seconds(1)
    /// Production delay after a return with no success callback. Strictly inside the deadline.
    public static let returnFallbackDelay: Duration = .milliseconds(200)
}

public protocol ShortcutLaunching: Sendable {
    /// Returns false when the shortcut URL cannot be opened.
    func openShortcut(url: URL) async -> Bool
}

/// Apply flow after a wallpaper has been saved.
///
/// A missing shortcut, a failed open, an x-error callback, or a return to the app
/// without success moves to `manualGuide` within `ApplyTiming.manualGuideDeadline`.
public actor ApplyFlow {
    public private(set) var phase: ApplyPhase = .idle
    private let launcher: any ShortcutLaunching
    private let shortcutInstalled: Bool
    private let fallbackDelay: Duration

    public init(
        launcher: any ShortcutLaunching,
        shortcutInstalled: Bool,
        fallbackDelay: Duration = ApplyTiming.returnFallbackDelay
    ) {
        self.launcher = launcher
        self.shortcutInstalled = shortcutInstalled
        precondition(
            fallbackDelay < ApplyTiming.manualGuideDeadline,
            "Manual-guide fallback must be under 1 second (AC7)"
        )
        self.fallbackDelay = fallbackDelay
    }

    /// Try the shortcut. Failure paths show the manual guide immediately.
    @discardableResult
    public func startApply() async -> ApplyPhase {
        guard shortcutInstalled else {
            phase = .manualGuide(.shortcutNotInstalled)
            return phase
        }

        phase = .launchingShortcut
        let opened = await launcher.openShortcut(url: ApplyShortcut.launchURL)
        if !opened {
            phase = .manualGuide(.openFailed)
        }
        return phase
    }

    @discardableResult
    public func handleCallback(_ callback: ShortcutCallback) -> ApplyPhase {
        switch callback {
        case .success:
            phase = .shortcutSucceeded
        case .error:
            phase = .manualGuide(.shortcutError)
        }
        return phase
    }

    /// The user came back to DuoWall without a success callback.
    /// The guide is shown after `fallbackDelay`, which is under one second.
    @discardableResult
    public func handleReturnWithoutSuccess() async -> ApplyPhase {
        guard phase == .launchingShortcut else { return phase }
        if fallbackDelay > .zero {
            try? await Task.sleep(for: fallbackDelay)
        }
        if phase == .launchingShortcut {
            phase = .manualGuide(.returnedWithoutSuccess)
        }
        return phase
    }
}
