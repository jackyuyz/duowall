import SwiftUI
import FoldKit

@main
struct DuoWallApp: App {
    @State private var foldStateProvider: any FoldStateProvider = {
        #if DEBUG
        if let mockValue = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("-FoldMock") }) {
            let value = mockValue.replacingOccurrences(of: "-FoldMock", with: "").trimmingCharacters(in: .whitespaces)
            if !value.isEmpty {
                return MockFoldStateProvider.from(launchArgument: value)
            }
        }
        if CommandLine.arguments.contains("-UITestMode") {
            if let mockIndex = CommandLine.arguments.firstIndex(of: "-FoldMock"),
               mockIndex + 1 < CommandLine.arguments.count {
                let value = CommandLine.arguments[mockIndex + 1]
                return MockFoldStateProvider.from(launchArgument: value)
            }
        }
        #endif
        return SystemFoldStateProvider()
    }()
    
    @State private var proStore = ProStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.foldStateProvider, foldStateProvider)
                .environment(proStore)
                .task {
                    await proStore.listenForTransactions()
                }
        }
    }
}

// MARK: - Environment Key for FoldStateProvider

private struct FoldStateProviderKey: EnvironmentKey {
    static let defaultValue: any FoldStateProvider = SystemFoldStateProvider()
}

extension EnvironmentValues {
    var foldStateProvider: any FoldStateProvider {
        get { self[FoldStateProviderKey.self] }
        set { self[FoldStateProviderKey.self] = newValue }
    }
}
