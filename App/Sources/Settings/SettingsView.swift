import SwiftUI
import RenderKit

/// Settings screen
struct SettingsView: View {
    @AppStorage("exportFormat") private var exportFormat = "heic"
    @AppStorage("colorSpace") private var colorSpace = "srgb"
    @AppStorage("showSafeAreasDefault") private var showSafeAreasDefault = true
    
    var body: some View {
        Form {
            Section("Export") {
                Picker("Format", selection: $exportFormat) {
                    Text("HEIC").tag("heic")
                    Text("PNG").tag("png")
                }
                
                Picker("Color Space", selection: $colorSpace) {
                    Text("sRGB").tag("srgb")
                    Text("Display P3").tag("displayP3")
                }
            }
            
            Section("Editor") {
                Toggle("Show Safe Areas by Default", isOn: $showSafeAreasDefault)
            }
            
            Section("Shortcut") {
                Link(destination: URL(string: "https://www.icloud.com/shortcuts/duowall-apply")!) {
                    Label("Get DuoWall Apply Shortcut", systemImage: "shortcuts")
                }
                
                Button("Re-run Onboarding") {
                    UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                }
            }
            
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                
                NavigationLink("FAQ") {
                    FAQView()
                }
                
                NavigationLink("Privacy Policy") {
                    PrivacyView()
                }
            }
            
            Section("Purchase") {
                Button("Restore Purchases") {
                    // TODO: Implement restore
                }
            }
        }
        .navigationTitle("Settings")
    }
}

struct FAQView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                faqItem(
                    question: "Why can't DuoWall set my wallpaper directly?",
                    answer: "iOS doesn't provide an API for apps to set wallpapers. DuoWall creates the perfect image, and you apply it using the Shortcuts app or Settings."
                )
                
                faqItem(
                    question: "How does the reveal effect work?",
                    answer: "iPhone Duo uses one wallpaper image for both displays. The outer screen shows a cropped center portion. DuoWall helps you design images that look great on both screens."
                )
                
                faqItem(
                    question: "What size should my wallpaper be?",
                    answer: "DuoWall exports at 2670×1878 pixels (the inner display resolution). iOS automatically crops this for the outer display."
                )
                
                faqItem(
                    question: "Can I use different wallpapers for each screen?",
                    answer: "Currently, iOS uses one wallpaper for both screens. If Apple adds per-display wallpaper support, we'll update the app."
                )
                
                faqItem(
                    question: "What's included in Pro?",
                    answer: "Pro removes the watermark, unlocks all 30 bundled pairs, and adds text and gradient layers."
                )
            }
            .padding()
        }
        .navigationTitle("FAQ")
    }
    
    @ViewBuilder
    private func faqItem(question: String, answer: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question)
                .font(.headline)
            Text(answer)
                .foregroundColor(.secondary)
        }
    }
}

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Policy")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("DuoWall is designed with your privacy in mind.")
                    .font(.headline)
                
                Text("""
                    **Data Collection**
                    DuoWall does not collect any personal data. Everything stays on your device.
                    
                    **Photos**
                    We only request permission to add photos to your library (not read them). Your photos are never uploaded anywhere.
                    
                    **Analytics**
                    DuoWall does not include any analytics or tracking SDKs.
                    
                    **Network**
                    The only network requests are:
                    • StoreKit (for purchases)
                    • Opening the Shortcuts iCloud link (user-initiated)
                    
                    **Your Wallpapers**
                    All your creations are stored locally on your device. We cannot see them.
                    """)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .navigationTitle("Privacy")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
