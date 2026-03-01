import SwiftUI

// MARK: - Settings View
// User preferences, demo controls, developer panel, about section.

struct SettingsView: View {
    @Bindable var appState: AppState
    @State private var showDeveloperPanel = false

    var body: some View {
        NavigationStack {
            List {
                // Preferences
                Section {
                    Picker(selection: Binding(
                        get: { appState.language },
                        set: { appState.language = $0 }
                    )) {
                        Text("English").tag("English")
                        Text("Español").tag("Español")
                    } label: {
                        Label("Language", systemImage: "globe")
                    }
                } header: {
                    Text("Preferences")
                        .font(PantriFonts.caption)
                }

                Section {
                    HStack {
                        Label("Default City", systemImage: "building.2")
                        Spacer()
                        TextField("City", text: $appState.defaultCity)
                            .multilineTextAlignment(.trailing)
                            .font(PantriFonts.body)
                            .foregroundStyle(PantriColors.secondaryText)
                    }

                    Picker(selection: $appState.selectedTransport) {
                        ForEach(TransportMode.allCases) { mode in
                            Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                        }
                    } label: {
                        Label("Transportation", systemImage: "figure.walk")
                    }
                } header: {
                    Text("Location")
                        .font(PantriFonts.caption)
                }

                // Privacy
                Section {
                    VStack(alignment: .leading, spacing: PantriSpacing.sm) {
                        Label("Anonymous Mode", systemImage: "eye.slash")
                            .font(PantriFonts.headline)

                        Text("Pantri operates anonymously by default. No personal data is stored or shared. Your location is only used to find nearby food sources and is never saved.")
                            .font(PantriFonts.footnote)
                            .foregroundStyle(PantriColors.secondaryText)
                    }
                    .padding(.vertical, PantriSpacing.xs)
                } header: {
                    Text("Privacy")
                        .font(PantriFonts.caption)
                }

                // Developer
                Section {
                    Button {
                        showDeveloperPanel = true
                    } label: {
                        Label("Developer Panel", systemImage: "wrench.and.screwdriver")
                            .foregroundStyle(PantriColors.green)
                    }
                } header: {
                    Text("Developer")
                        .font(PantriFonts.caption)
                }

                // About
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0 (Hackathon)")
                            .foregroundStyle(PantriColors.secondaryText)
                    }
                    HStack {
                        Text("Credits")
                        Spacer()
                        Text("Pantri Team")
                            .foregroundStyle(PantriColors.secondaryText)
                    }

                    Button {
                        Haptics.tap()
                        appState.resetOnboarding()
                    } label: {
                        Label("Switch Mode", systemImage: "arrow.left.arrow.right")
                            .foregroundStyle(PantriColors.destructive)
                    }
                } header: {
                    Text("About")
                        .font(PantriFonts.caption)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showDeveloperPanel) {
                DeveloperPanelView(engine: appState.matchingEngine)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

// MARK: - Developer Panel (Weights Editor)

struct DeveloperPanelView: View {
    @Bindable var engine: MatchingEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    WeightSlider(label: "Distance (w1)", value: Binding(
                        get: { engine.weights.w1 },
                        set: { engine.weights.w1 = $0 }
                    ))
                    WeightSlider(label: "Type Match (w2)", value: Binding(
                        get: { engine.weights.w2 },
                        set: { engine.weights.w2 = $0 }
                    ))
                    WeightSlider(label: "Verified (w3)", value: Binding(
                        get: { engine.weights.w3 },
                        set: { engine.weights.w3 = $0 }
                    ))
                    WeightSlider(label: "Capacity (w4)", value: Binding(
                        get: { engine.weights.w4 },
                        set: { engine.weights.w4 = $0 }
                    ))
                    WeightSlider(label: "Open Now (w5)", value: Binding(
                        get: { engine.weights.w5 },
                        set: { engine.weights.w5 = $0 }
                    ))
                    WeightSlider(label: "Urgency (w6)", value: Binding(
                        get: { engine.weights.w6 },
                        set: { engine.weights.w6 = $0 }
                    ))
                } header: {
                    Text("Match Scoring Weights")
                        .font(PantriFonts.caption)
                } footer: {
                    Text("Adjust weights to change how matches are ranked. Changes apply immediately.")
                        .font(PantriFonts.caption)
                }

                Section {
                    Button("Reset to Defaults") {
                        Haptics.tap()
                        engine.weights = MatchWeights()
                    }
                    .foregroundStyle(PantriColors.destructive)
                }
            }
            .navigationTitle("Developer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(PantriColors.green)
                }
            }
        }
    }
}

struct WeightSlider: View {
    let label: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(PantriFonts.subheadline)
                Spacer()
                Text(String(format: "%.2f", value))
                    .font(PantriFonts.footnote)
                    .foregroundStyle(PantriColors.secondaryText)
                    .monospacedDigit()
            }
            Slider(value: $value, in: 0...1, step: 0.01)
                .tint(PantriColors.green)
        }
    }
}

#Preview {
    SettingsView(appState: AppState.shared)
}
