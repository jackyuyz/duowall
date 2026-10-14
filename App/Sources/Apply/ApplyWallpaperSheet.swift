import SwiftUI
import ApplyKit

struct SystemShortcutLauncher: ShortcutLaunching {
    func openShortcut(url: URL) async -> Bool {
        await UIApplication.shared.open(url)
    }
}

@MainActor
@Observable
final class ApplySheetModel {
    private let flow: ApplyFlow
    var phase: ApplyPhase = .idle

    init(shortcutInstalled: Bool, launcher: any ShortcutLaunching) {
        self.flow = ApplyFlow(launcher: launcher, shortcutInstalled: shortcutInstalled)
    }

    func start() async {
        phase = await flow.startApply()
    }

    func handleCallback(_ callback: ShortcutCallback) async {
        phase = await flow.handleCallback(callback)
    }

    func handleReturnWithoutSuccess() async {
        phase = await flow.handleReturnWithoutSuccess()
    }
}

struct ApplyWallpaperSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: ApplySheetModel
    @State private var didLeaveApp = false

    init(shortcutInstalled: Bool, launcher: any ShortcutLaunching = SystemShortcutLauncher()) {
        _model = State(initialValue: ApplySheetModel(
            shortcutInstalled: shortcutInstalled,
            launcher: launcher
        ))
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                switch model.phase {
                case .idle, .launchingShortcut:
                    ProgressView("Opening Shortcuts...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .shortcutSucceeded:
                    ContentUnavailableView(
                        "Saved!",
                        systemImage: "checkmark.circle",
                        description: Text("Apply with Shortcuts")
                    )
                case .manualGuide:
                    manualGuide
                }
            }
            .padding()
            .navigationTitle("Apply Wallpaper")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            await model.start()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .inactive || phase == .background {
                didLeaveApp = true
            }
            if phase == .active, didLeaveApp {
                Task { await model.handleReturnWithoutSuccess() }
            }
        }
        .onOpenURL { url in
            guard url.scheme == "duowall" else { return }
            Task {
                if url.host == "applied" {
                    await model.handleCallback(.success)
                } else if url.host == "failed" {
                    await model.handleCallback(.error)
                }
            }
        }
    }

    @ViewBuilder
    private var manualGuide: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("The shortcut couldn't be opened. Follow the manual steps below.")
                    .foregroundColor(.secondary)

                Text("Manual Guide")
                    .font(.headline)

                guideStep("Step 1: Open Settings")
                guideStep("Step 2: Tap Wallpaper")
                guideStep("Step 3: Add New Wallpaper")
                guideStep("Step 4: Choose from Photos")
                guideStep("Step 5: Select your DuoWall image")

                Text("Close your Duo to see the outer crop")
                    .font(.subheadline)
                Text("Now open it to see the full wallpaper")
                    .font(.subheadline)

                Link(destination: URL(string: "https://www.icloud.com/shortcuts/duowall-apply")!) {
                    Label("Reinstall shortcut", systemImage: "arrow.down.circle")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func guideStep(_ title: LocalizedStringKey) -> some View {
        Text(title)
    }
}
