import SwiftUI

struct PaywallView: View {
    @Environment(ProStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("DuoWall Pro")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Unlock all features")
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    feature("No watermark on exports")
                    feature("All 30 bundled wallpaper pairs")
                    feature("Text and gradient layers")
                    feature("Future bundled packs")
                    feature("One-time purchase")
                }

                if store.isPendingAskToBuy {
                    Label("Waiting for approval", systemImage: "hourglass")
                        .foregroundColor(.secondary)
                }

                if let loadError = store.loadError {
                    Text(LocalizedStringKey(loadError))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    isPurchasing = true
                    Task {
                        try? await store.purchase()
                        isPurchasing = false
                        if store.isPro {
                            dismiss()
                        }
                    }
                } label: {
                    if isPurchasing {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("DuoWall Pro")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isPurchasing || store.isPro || store.isPendingAskToBuy)

                Button("Restore Purchases") {
                    Task { try? await store.restore() }
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
            .navigationTitle("Purchase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task {
            await store.loadProducts()
        }
    }

    private func feature(_ title: LocalizedStringKey) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: "checkmark")
        }
    }
}
