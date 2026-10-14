import SwiftUI
import FoldKit
import RenderKit
import DisplaySpecKit

/// Detail view for a wallpaper pair
struct PairDetailView: View {
    let pair: PairManifest
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.foldStateProvider) private var foldStateProvider
    @State private var foldState: FoldState = .noHinge
    @State private var selectedPreview: PreviewMode = .inner
    @State private var showingSafeAreas = true
    @State private var showingEditor = false
    
    enum PreviewMode: String, CaseIterable {
        case outer = "Outer"
        case inner = "Inner"
        case lockScreen = "Lock Screen"
        case homeScreen = "Home Screen"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    previewSection
                    
                    Picker("Preview", selection: $selectedPreview) {
                        ForEach(PreviewMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    infoSection
                    
                    actionButtons
                }
                .padding(.vertical)
            }
            .navigationTitle(pair.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                for await state in foldStateProvider.states() {
                    foldState = state
                }
            }
        }
        .fullScreenCover(isPresented: $showingEditor) {
            EditorView(pair: pair)
        }
    }
    
    @ViewBuilder
    private var previewSection: some View {
        let isWideLayout = foldState.posture == .fullyOpen || foldState.posture == .partiallyOpen
        
        if isWideLayout {
            HStack(spacing: 20) {
                previewCard(mode: .outer)
                previewCard(mode: .inner)
            }
            .padding(.horizontal)
        } else {
            previewCard(mode: selectedPreview)
                .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private func previewCard(mode: PreviewMode) -> some View {
        let spec = DisplaySpecLoader.shared.spec
        let aspectRatio: CGFloat
        
        switch mode {
        case .outer, .lockScreen, .homeScreen:
            aspectRatio = spec.outer.width / spec.outer.height
        case .inner:
            aspectRatio = spec.inner.width / spec.inner.height
        }
        
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: pair.palette.first ?? "#333333"))
                .aspectRatio(aspectRatio, contentMode: .fit)
            
            VStack {
                Text(mode.rawValue)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                Image(systemName: "photo")
                    .font(.title)
                    .foregroundColor(.white)
            }
            
            if showingSafeAreas && (mode == .lockScreen || mode == .homeScreen || mode == .outer) {
                SafeAreaOverlay(display: .outer)
            }
            
            if mode == .inner {
                CreaseOverlay()
            }
        }
        .cornerRadius(16)
        .shadow(radius: 8)
    }
    
    @ViewBuilder
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Template")
                    .foregroundColor(.secondary)
                Spacer()
                Text(pair.template.displayName)
            }
            
            if let artist = pair.artistCredit {
                HStack {
                    Text("Artist")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(artist)
                }
            }
            
            HStack {
                Text("Tags")
                    .foregroundColor(.secondary)
                Spacer()
                Text(pair.tags.joined(separator: ", "))
                    .foregroundColor(.secondary)
            }
            
            Toggle("Show Safe Areas", isOn: $showingSafeAreas)
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                showingEditor = true
            } label: {
                Label("Edit", systemImage: "pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            
            Button {
                // TODO: Apply flow
            } label: {
                Label("Apply Wallpaper", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            
            HStack(spacing: 12) {
                Button {
                    // TODO: Favorite
                } label: {
                    Label("Favorite", systemImage: "heart")
                }
                .buttonStyle(.bordered)
                
                Button {
                    // TODO: Duplicate
                } label: {
                    Label("Duplicate", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal)
    }
}

/// Overlay showing safe areas (clock, dock, dynamic island)
struct SafeAreaOverlay: View {
    let display: DisplayTarget
    
    var body: some View {
        let areas = DisplaySpecLoader.shared.safeAreas(for: display)
        
        GeometryReader { geo in
            ForEach(areas) { area in
                let frame = area.normalizedFrame.rect(in: geo.size)
                
                RoundedRectangle(cornerRadius: area.cornerRadius)
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: area.cornerRadius)
                            .fill(Color.white.opacity(0.1))
                    )
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)
                    .overlay(alignment: .center) {
                        Text(area.label)
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.5))
                            .position(x: frame.midX, y: frame.midY)
                    }
            }
        }
    }
}

/// Overlay showing the crease line
struct CreaseOverlay: View {
    var body: some View {
        let crease = DisplaySpecLoader.shared.spec.creaseBand
        
        GeometryReader { geo in
            let x = crease.center * geo.size.width
            let width = crease.width * geo.size.width
            
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(width: width)
                .position(x: x, y: geo.size.height / 2)
            
            Rectangle()
                .fill(Color.white.opacity(0.5))
                .frame(width: 1)
                .position(x: x, y: geo.size.height / 2)
        }
    }
}

#Preview {
    PairDetailView(pair: DefaultPacks.freePairs().first!)
}
