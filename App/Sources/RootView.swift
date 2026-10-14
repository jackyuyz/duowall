import SwiftUI
import FoldKit

/// Root view that adapts layout based on fold state
struct RootView: View {
    @Environment(\.foldStateProvider) private var foldStateProvider
    @State private var foldState: FoldState = .noHinge
    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    @State private var showingOnboarding = false
    
    var body: some View {
        NavigationStack {
            GalleryView()
                .navigationTitle("DuoWall")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            SettingsView()
                        } label: {
                            Image(systemName: "gear")
                        }
                    }
                }
        }
        .task {
            for await state in foldStateProvider.states() {
                foldState = state
            }
        }
        .onAppear {
            if !hasCompletedOnboarding {
                showingOnboarding = true
            }
        }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView(isPresented: $showingOnboarding)
        }
        .overlay(alignment: .bottom) {
            #if DEBUG
            if CommandLine.arguments.contains("-FoldDebugOverlay") {
                FoldDebugOverlay(foldState: foldState)
            }
            #endif
        }
    }
}

// MARK: - Fold Debug Overlay (for UI testing)

#if DEBUG
struct FoldDebugOverlay: View {
    let foldState: FoldState
    @Environment(\.foldStateProvider) private var provider
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Fold: \(foldState.posture.rawValue)")
                .font(.caption)
            
            if let angle = foldState.angleDegrees {
                Text("Angle: \(Int(angle))°")
                    .font(.caption2)
            }
            
            HStack(spacing: 4) {
                Button("C") {
                    if let mock = provider as? MockFoldStateProvider {
                        mock.set(.closed, angle: 0)
                    }
                }
                .accessibilityIdentifier("fold.closed")
                
                Button("H") {
                    if let mock = provider as? MockFoldStateProvider {
                        mock.set(.partiallyOpen, angle: 90)
                    }
                }
                .accessibilityIdentifier("fold.half")
                
                Button("O") {
                    if let mock = provider as? MockFoldStateProvider {
                        mock.set(.fullyOpen, angle: 180)
                    }
                }
                .accessibilityIdentifier("fold.open")
                
                Button("N") {
                    if let mock = provider as? MockFoldStateProvider {
                        mock.set(.noHinge)
                    }
                }
                .accessibilityIdentifier("fold.nohinge")
            }
            .buttonStyle(.bordered)
            .font(.caption2)
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
        .padding()
    }
}
#endif

#Preview {
    RootView()
}
