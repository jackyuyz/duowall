import SwiftUI
import FoldKit
import EditorCore
import DisplaySpecKit
import RenderKit

/// Main editor view for composing wallpapers
struct EditorView: View {
    let pair: PairManifest?
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.foldStateProvider) private var foldStateProvider
    @State private var foldState: FoldState = .noHinge
    
    @State private var layerDoc: LayerDoc
    @State private var undoManager = EditorUndoManager()
    @State private var selectedLayerId: UUID?
    @State private var showingSafeAreas = true
    @State private var showsCrease = true
    @State private var showsOuterFrame = true
    @State private var showingExportSheet = false
    @State private var showingUnsavedAlert = false
    
    init(pair: PairManifest?) {
        self.pair = pair
        _layerDoc = State(initialValue: LayerDoc.new(template: pair?.template ?? .reveal))
    }
    
    private var isWideLayout: Bool {
        foldState.posture == .fullyOpen || foldState.posture == .partiallyOpen
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isWideLayout {
                    HStack(spacing: 0) {
                        canvasView
                            .frame(maxWidth: .infinity)
                        
                        Divider()
                        
                        toolPanel
                            .frame(width: 300)
                    }
                } else {
                    VStack(spacing: 0) {
                        canvasView
                            .frame(maxHeight: .infinity)
                        
                        Divider()
                        
                        toolPanel
                            .frame(height: 280)
                    }
                }
            }
            .navigationTitle("Editor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        if undoManager.hasUnsavedChanges {
                            showingUnsavedAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        if let newDoc = undoManager.undo(on: layerDoc) {
                            layerDoc = newDoc
                        }
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(!undoManager.canUndo)
                    
                    Button {
                        if let newDoc = undoManager.redo(on: layerDoc) {
                            layerDoc = newDoc
                        }
                    } label: {
                        Image(systemName: "arrow.uturn.forward")
                    }
                    .disabled(!undoManager.canRedo)
                    
                    Button("Export") {
                        showingExportSheet = true
                    }
                }
            }
            .task {
                for await state in foldStateProvider.states() {
                    foldState = state
                }
            }
            .alert("Unsaved Changes", isPresented: $showingUnsavedAlert) {
                Button("Discard", role: .destructive) {
                    dismiss()
                }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("You have unsaved changes. Are you sure you want to discard them?")
            }
            .sheet(isPresented: $showingExportSheet) {
                ExportSheet(layerDoc: layerDoc)
            }
        }
    }
    
    @ViewBuilder
    private var canvasView: some View {
        let spec = DisplaySpecLoader.shared.spec
        
        GeometryReader { geo in
            let canvasAspect = spec.inner.width / spec.inner.height
            let availableAspect = geo.size.width / geo.size.height
            
            let canvasSize: CGSize
            if availableAspect > canvasAspect {
                let height = geo.size.height * 0.9
                canvasSize = CGSize(width: height * canvasAspect, height: height)
            } else {
                let width = geo.size.width * 0.9
                canvasSize = CGSize(width: width, height: width / canvasAspect)
            }
            
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black)
                    .frame(width: canvasSize.width, height: canvasSize.height)
                
                ForEach(layerDoc.layers) { layer in
                    LayerView(
                        layer: layer,
                        canvasSize: canvasSize,
                        isSelected: layer.id == selectedLayerId
                    )
                    .onTapGesture {
                        selectedLayerId = layer.id
                    }
                }
                
                if showsOuterFrame {
                    OuterFrameOverlay(spec: spec, canvasSize: canvasSize)
                }
                
                if showsCrease {
                    CreaseLineOverlay(spec: spec, canvasSize: canvasSize)
                }
                
                if showingSafeAreas {
                    CanvasSafeAreaOverlay(spec: spec, canvasSize: canvasSize)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(white: 0.15))
    }
    
    @ViewBuilder
    private var toolPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                overlayToggles
                
                Divider()
                
                templatePicker
                
                Divider()
                
                layerList
            }
            .padding()
        }
        .background(Color(UIColor.systemBackground))
    }
    
    @ViewBuilder
    private var overlayToggles: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Overlays")
                .font(.headline)
            
            Toggle("Outer Frame", isOn: $showsOuterFrame)
            Toggle("Crease Line", isOn: $showsCrease)
            Toggle("Safe Areas", isOn: $showingSafeAreas)
        }
    }
    
    @ViewBuilder
    private var templatePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Template")
                .font(.headline)
            
            Picker("Template", selection: Binding(
                get: { layerDoc.template },
                set: { newTemplate in
                    layerDoc = undoManager.execute(
                        ChangeTemplateCommand(newTemplate: newTemplate),
                        on: layerDoc
                    )
                }
            )) {
                ForEach(TemplateKind.allCases, id: \.self) { template in
                    Text(LocalizedStringKey(template.displayName)).tag(template)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    @ViewBuilder
    private var layerList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Layers")
                    .font(.headline)
                
                Spacer()
                
                Menu {
                    Button {
                        let fill = FillLayer(kind: .blurExtend)
                        layerDoc = undoManager.execute(
                            AddLayerCommand(layer: .fill(fill)),
                            on: layerDoc
                        )
                    } label: {
                        Label("Add Fill", systemImage: "rectangle.fill")
                    }
                    
                    Button {
                        let text = TextLayer(text: "Text")
                        layerDoc = undoManager.execute(
                            AddLayerCommand(layer: .text(text)),
                            on: layerDoc
                        )
                    } label: {
                        Label("Add Text", systemImage: "textformat")
                    }
                } label: {
                    Image(systemName: "plus.circle")
                }
            }
            
            ForEach(layerDoc.layers.reversed()) { layer in
                LayerRow(
                    layer: layer,
                    isSelected: layer.id == selectedLayerId,
                    onSelect: { selectedLayerId = layer.id },
                    onDelete: {
                        layerDoc = undoManager.execute(
                            RemoveLayerCommand(layerId: layer.id),
                            on: layerDoc
                        )
                        if selectedLayerId == layer.id {
                            selectedLayerId = nil
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Canvas Overlays

struct OuterFrameOverlay: View {
    let spec: DisplaySpec
    let canvasSize: CGSize
    
    var body: some View {
        let crop = spec.singleImage.outerCrop
        let frame = crop.rect(in: canvasSize)
        
        Rectangle()
            .stroke(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
            .foregroundColor(.orange)
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
        
        Text("Outer Screen")
            .font(.caption2)
            .foregroundColor(.orange)
            .position(x: frame.midX, y: frame.minY - 10)
    }
}

struct CreaseLineOverlay: View {
    let spec: DisplaySpec
    let canvasSize: CGSize
    
    var body: some View {
        let crease = spec.creaseBand
        let x = crease.center * canvasSize.width
        
        Rectangle()
            .fill(Color.white.opacity(0.3))
            .frame(width: 2)
            .position(x: x, y: canvasSize.height / 2)
    }
}

struct CanvasSafeAreaOverlay: View {
    let spec: DisplaySpec
    let canvasSize: CGSize
    
    var body: some View {
        ForEach(spec.safeAreas.filter { $0.display == .inner || $0.display == .both }) { area in
            let frame = area.normalizedFrame.rect(in: canvasSize)
            
            RoundedRectangle(cornerRadius: area.cornerRadius * (canvasSize.width / spec.inner.width))
                .stroke(Color.cyan.opacity(0.5), lineWidth: 1)
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
        }
    }
}

// MARK: - Layer Views

struct LayerView: View {
    let layer: Layer
    let canvasSize: CGSize
    let isSelected: Bool
    
    var body: some View {
        Group {
            switch layer {
            case .photo(let photo):
                PhotoLayerView(layer: photo, canvasSize: canvasSize)
            case .fill(let fill):
                FillLayerView(layer: fill, canvasSize: canvasSize)
            case .text(let text):
                TextLayerView(layer: text, canvasSize: canvasSize)
            case .gradient(let gradient):
                GradientLayerView(layer: gradient, canvasSize: canvasSize)
            }
        }
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.accentColor, lineWidth: 2)
            }
        }
    }
}

struct PhotoLayerView: View {
    let layer: PhotoLayer
    let canvasSize: CGSize
    
    var body: some View {
        Image(systemName: "photo")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundColor(.gray)
            .frame(width: 100, height: 100)
            .opacity(layer.opacity)
    }
}

struct FillLayerView: View {
    let layer: FillLayer
    let canvasSize: CGSize
    
    var body: some View {
        Rectangle()
            .fill(fillColor)
            .frame(width: canvasSize.width, height: canvasSize.height)
            .opacity(layer.opacity)
    }
    
    private var fillColor: Color {
        switch layer.kind {
        case .solid(let options):
            return Color(hex: options.colorHex)
        case .blurExtend, .mirrorExtend, .auto:
            return Color.gray.opacity(0.3)
        }
    }
}

struct TextLayerView: View {
    let layer: TextLayer
    let canvasSize: CGSize
    
    var body: some View {
        Text(layer.text)
            .font(.system(size: layer.fontSize))
            .foregroundColor(Color(hex: layer.colorHex))
            .position(
                x: layer.transform.center.x * canvasSize.width,
                y: layer.transform.center.y * canvasSize.height
            )
            .rotationEffect(.degrees(layer.transform.rotation))
            .scaleEffect(layer.transform.scale)
            .opacity(layer.opacity)
    }
}

struct GradientLayerView: View {
    let layer: GradientLayer
    let canvasSize: CGSize
    
    var body: some View {
        LinearGradient(
            stops: layer.stops.map { stop in
                Gradient.Stop(color: Color(hex: stop.colorHex), location: stop.location)
            },
            startPoint: UnitPoint(x: layer.startPoint.x, y: layer.startPoint.y),
            endPoint: UnitPoint(x: layer.endPoint.x, y: layer.endPoint.y)
        )
        .frame(width: canvasSize.width, height: canvasSize.height)
        .opacity(layer.opacity)
    }
}

// MARK: - Layer Row

struct LayerRow: View {
    let layer: Layer
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: layerIcon)
                .foregroundColor(.secondary)
            
            Text(LocalizedStringKey(layer.typeName))
                .lineLimit(1)
            
            Spacer()
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
    
    private var layerIcon: String {
        switch layer {
        case .photo: return "photo"
        case .fill: return "rectangle.fill"
        case .text: return "textformat"
        case .gradient: return "rectangle.fill.on.rectangle.fill"
        }
    }
}

// MARK: - Export Sheet

struct ExportSheet: View {
    let layerDoc: LayerDoc
    @Environment(\.dismiss) private var dismiss
    @Environment(ProStore.self) private var store
    
    @State private var format: ExportFormat = .heic
    @State private var colorSpace: ExportColorSpace = .srgb
    @State private var isExporting = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Format") {
                    Picker("Format", selection: $format) {
                        ForEach(ExportFormat.allCases, id: \.self) { fmt in
                            Text(fmt.rawValue.uppercased()).tag(fmt)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Color Space") {
                    Picker("Color Space", selection: $colorSpace) {
                        ForEach(ExportColorSpace.allCases, id: \.self) { cs in
                            Text(cs.rawValue).tag(cs)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                if store.showsWatermark {
                    Section {
                        Text("Free exports include a small watermark.")
                    }
                }

                Section {
                    Button {
                        isExporting = true
                        let config = ExportConfig(
                            format: format,
                            colorSpace: colorSpace,
                            includeWatermark: store.showsWatermark
                        )
                        _ = config
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            isExporting = false
                            dismiss()
                        }
                    } label: {
                        if isExporting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Export Wallpaper")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isExporting)
                }
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    EditorView(pair: DefaultPacks.freePairs().first)
        .environment(ProStore())
}
