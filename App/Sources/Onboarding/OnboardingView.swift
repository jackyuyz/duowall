import SwiftUI
import FoldKit

/// Onboarding flow for new users
struct OnboardingView: View {
    @Binding var isPresented: Bool
    @Environment(\.foldStateProvider) private var foldStateProvider
    @State private var foldState: FoldState = .noHinge
    @State private var currentPage = 0
    
    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                RevealDemoPage(foldState: foldState)
                    .tag(0)
                
                HowItWorksPage()
                    .tag(1)
                
                ShortcutPage(onComplete: completeOnboarding)
                    .tag(2)
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            
            HStack {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation {
                            currentPage -= 1
                        }
                    }
                }
                
                Spacer()
                
                if currentPage < 2 {
                    Button("Next") {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .task {
            for await state in foldStateProvider.states() {
                foldState = state
            }
        }
    }
    
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        isPresented = false
    }
}

// MARK: - Onboarding Pages

struct RevealDemoPage: View {
    let foldState: FoldState
    @State private var revealProgress: Double = 0
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 32) {
            Text("Perfect on Both Screens")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 280, height: 200)
                
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(.black.opacity(0.5))
                        .frame(width: 140 * (1 - revealProgress))
                    
                    Spacer()
                    
                    Rectangle()
                        .fill(.black.opacity(0.5))
                        .frame(width: 140 * (1 - revealProgress))
                }
                .frame(width: 280, height: 200)
                .cornerRadius(24)
                .allowsHitTesting(false)
                
                VStack {
                    Text(revealProgress < 0.5 ? "Outer" : "Inner")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Image(systemName: "mountain.2.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }
            }
            
            if foldState.hasHinge {
                Text("Flex your phone to see the reveal")
                    .foregroundColor(.secondary)
            } else {
                Slider(value: $revealProgress, in: 0...1)
                    .padding(.horizontal, 40)
                
                Text("Slide to preview the reveal effect")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .onAppear {
            if !foldState.hasHinge && !isAnimating {
                startAnimation()
            }
        }
    }
    
    private func startAnimation() {
        isAnimating = true
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            revealProgress = 1
        }
    }
}

struct HowItWorksPage: View {
    var body: some View {
        VStack(spacing: 32) {
            Text("How DuoWall Works")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 24) {
                infoRow(
                    icon: "photo.fill",
                    title: "Design Your Wallpaper",
                    description: "Create or customize wallpapers with our editor"
                )
                
                infoRow(
                    icon: "square.and.arrow.down",
                    title: "Export to Photos",
                    description: "Save your creation to your photo library"
                )
                
                infoRow(
                    icon: "shortcuts",
                    title: "Apply with Shortcuts",
                    description: "Use our free shortcut to set your wallpaper"
                )
            }
            .padding(.horizontal)
            
            Text("Note: iOS doesn't allow apps to set wallpapers directly. DuoWall creates the perfect image, and you apply it with a simple tap.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
        }
        .padding()
    }
    
    @ViewBuilder
    private func infoRow(icon: String, title: LocalizedStringKey, description: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct ShortcutPage: View {
    let onComplete: () -> Void
    @State private var shortcutAdded = false
    
    private let shortcutURL = URL(string: "https://www.icloud.com/shortcuts/duowall-apply")!
    
    var body: some View {
        VStack(spacing: 32) {
            Text("Add the Apply Shortcut")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Image(systemName: "shortcuts")
                .font(.system(size: 60))
                .foregroundColor(.pink)
            
            Text("The DuoWall Apply shortcut lets you set your wallpaper with one tap after exporting.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                Link(destination: shortcutURL) {
                    Label("Get the Shortcut", systemImage: "arrow.down.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                
                Button("I Added It") {
                    UserDefaults.standard.set(true, forKey: "shortcutInstalledConfirmed")
                    shortcutAdded = true
                    onComplete()
                }
                .buttonStyle(.bordered)
                
                Button("Skip for Now") {
                    onComplete()
                }
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 40)
        }
        .padding()
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}
