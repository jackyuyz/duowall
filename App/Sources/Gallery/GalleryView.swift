import SwiftUI
import FoldKit
import RenderKit

/// Main gallery view showing wallpaper pairs
struct GalleryView: View {
    @Environment(\.foldStateProvider) private var foldStateProvider
    @State private var foldState: FoldState = .noHinge
    @State private var selectedPair: PairManifest?
    
    private let pack = DefaultPacks.mainPack()
    
    private var columns: [GridItem] {
        switch foldState.posture {
        case .fullyOpen:
            return Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)
        case .partiallyOpen:
            return Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)
        case .closed:
            return Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
        case .noHinge, .unknown:
            return Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
        }
    }
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                Section {
                    ForEach(pack.freePairs) { pair in
                        PairCard(pair: pair, foldState: foldState)
                            .onTapGesture {
                                selectedPair = pair
                            }
                    }
                } header: {
                    sectionHeader("Free Collection")
                }
                
                Section {
                    ForEach(pack.premiumPairs) { pair in
                        PairCard(pair: pair, foldState: foldState, isLocked: true)
                            .onTapGesture {
                                selectedPair = pair
                            }
                    }
                } header: {
                    sectionHeader("Pro Collection")
                }
            }
            .padding()
        }
        .task {
            for await state in foldStateProvider.states() {
                foldState = state
            }
        }
        .sheet(item: $selectedPair) { pair in
            PairDetailView(pair: pair)
        }
        .accessibilityIdentifier(foldState.posture == .fullyOpen || foldState.posture == .partiallyOpen ? "layout.split" : "layout.compact")
    }
    
    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
        }
        .padding(.top, 8)
    }
}

/// Card showing a wallpaper pair with reveal animation
struct PairCard: View {
    let pair: PairManifest
    let foldState: FoldState
    var isLocked: Bool = false
    
    @State private var revealProgress: Double = 0
    @State private var angleTracker = RelativeAngleTracker()
    @State private var isHingeTracking = false
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: pair.palette.first ?? "#333333"))
                .aspectRatio(0.7, contentMode: .fit)
            
            VStack(spacing: 4) {
                Image(systemName: "photo.on.rectangle")
                    .font(.largeTitle)
                    .foregroundColor(.white.opacity(0.8))
                
                Text(pair.localizedTitle())
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            
            GeometryReader { geo in
                let width = geo.size.width
                let revealWidth = width * (1 - revealProgress)
                
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(.black.opacity(0.4))
                        .frame(width: revealWidth / 2)
                    
                    Spacer()
                    
                    Rectangle()
                        .fill(.black.opacity(0.4))
                        .frame(width: revealWidth / 2)
                }
            }
            .allowsHitTesting(false)
            
            if isLocked {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                        Text("PRO")
                            .font(.caption2)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.6))
                    .cornerRadius(4)
                    .padding(8)
                }
            }
        }
        .cornerRadius(12)
        .shadow(radius: 4)
        .onChange(of: foldState) { _, newState in
            updateRevealProgress(for: newState)
        }
        .accessibilityLabel("\(pair.title) pair\(isLocked ? ", Pro required" : ", free")")
        .accessibilityHint(pair.accessibilityDescription)
    }
    
    private func updateRevealProgress(for state: FoldState) {
        switch state.posture {
        case .closed:
            withAnimation(.easeOut(duration: 0.3)) {
                revealProgress = 0
            }
            isHingeTracking = false
            angleTracker.reset()
            
        case .partiallyOpen:
            if let angle = state.angleDegrees {
                if !isHingeTracking {
                    angleTracker.begin(at: angle)
                    isHingeTracking = true
                }
                let progress = angleTracker.update(angle)
                withAnimation(.easeOut(duration: 0.1)) {
                    revealProgress = progress
                }
            }
            
        case .fullyOpen:
            withAnimation(.easeOut(duration: 0.3)) {
                revealProgress = 1
            }
            isHingeTracking = false
            
        case .noHinge, .unknown:
            revealProgress = 1
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    NavigationStack {
        GalleryView()
    }
}
