import SwiftUI

// MARK: - Settings View
// User preferences, demo controls, developer panel, about section.

struct SettingsView: View {
    @Bindable var appState: AppState
    @State private var showDeveloperPanel = false
    @State private var showDemoPanel = false

    var body: some View {
        NavigationStack {
            List {
                // Preferences
                Section {
                    HStack {
                        Label("Demo Mode", systemImage: "play.circle")
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { appState.isDemoMode },
                            set: { newValue in
                                Haptics.toggle()
                                appState.isDemoMode = newValue
                                appState.api.mode = newValue ? .mock : .live
                            }
                        ))
                        .tint(PantriColors.green)
                    }
                    .accessibilityLabel("Demo mode, currently \(appState.isDemoMode ? "on" : "off")")

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

                // Demo Tools
                Section {
                    Button {
                        showDemoPanel = true
                    } label: {
                        Label("Demo Controls", systemImage: "play.rectangle")
                            .foregroundStyle(PantriColors.green)
                    }

                    Button {
                        showDeveloperPanel = true
                    } label: {
                        Label("Developer Panel", systemImage: "wrench.and.screwdriver")
                            .foregroundStyle(PantriColors.green)
                    }
                } header: {
                    Text("Demo & Developer")
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
            .sheet(isPresented: $showDemoPanel) {
                DemoPanelView(appState: appState)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showDeveloperPanel) {
                DeveloperPanelView(engine: appState.matchingEngine)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

// MARK: - Demo Panel

struct DemoPanelView: View {
    let appState: AppState
    @State private var demoStep: Int = 0
    @State private var isRunningDemo = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: PantriSpacing.lg) {
                Text("Demo Controls")
                    .font(PantriFonts.title2)

                VStack(spacing: PantriSpacing.sm) {
                    DemoButton(title: "Seed Demo Data", icon: "arrow.clockwise") {
                        Haptics.tap()
                        appState.store.seedDemoData()
                    }

                    DemoButton(title: "Simulate Restaurant Excess", icon: "fork.knife") {
                        Haptics.tap()
                        let newSource = FoodSource(
                            id: UUID(),
                            name: "Tony's Italian Kitchen",
                            phone: "(213) 555-9999",
                            address: "789 Broadway, Los Angeles, CA 90014",
                            latitude: 34.0445,
                            longitude: -118.2490,
                            sourceType: .restaurant,
                            foodTypes: [.cookedMeals],
                            hoursOfOperation: "Daily 11AM-9PM",
                            duration: .permanent,
                            publicTransitAccessible: true,
                            availability: .high,
                            hasExcessFood: true,
                            isVerified: false,
                            isOpen: true,
                            lastVerified: nil,
                            waitTimeEstimate: 5
                        )
                        appState.store.addSource(newSource)
                        Haptics.notification(.success)
                    }

                    DemoButton(title: "Simulate Verification", icon: "checkmark.seal") {
                        Haptics.tap()
                        isRunningDemo = true
                        Task {
                            if let unverified = appState.store.sources.first(where: { !$0.isVerified }) {
                                try? await appState.api.verifySource(id: unverified.id)
                                await MainActor.run {
                                    isRunningDemo = false
                                    Haptics.notification(.success)
                                }
                            } else {
                                await MainActor.run {
                                    isRunningDemo = false
                                }
                            }
                        }
                    }

                    DemoButton(title: "Run Full Demo Flow", icon: "play.fill") {
                        Haptics.tap()
                        isRunningDemo = true
                        Task {
                            // Step 1: Add restaurant
                            let newSource = FoodSource(
                                id: UUID(),
                                name: "Demo Restaurant",
                                phone: "(213) 555-0000",
                                address: "100 Main St, Los Angeles, CA 90012",
                                latitude: 34.0520,
                                longitude: -118.2430,
                                sourceType: .restaurant,
                                foodTypes: [.cookedMeals],
                                hoursOfOperation: "Daily 10AM-8PM",
                                duration: .permanent,
                                publicTransitAccessible: true,
                                availability: .high,
                                hasExcessFood: true,
                                isVerified: false,
                                isOpen: true,
                                lastVerified: nil,
                                waitTimeEstimate: 5
                            )
                            appState.store.addSource(newSource)

                            try? await Task.sleep(for: .seconds(1))

                            // Step 2: Verify it
                            try? await appState.api.verifySource(id: newSource.id)

                            // Step 3: Trigger search
                            await appState.performSearch()

                            await MainActor.run {
                                isRunningDemo = false
                                Haptics.notification(.success)
                            }
                        }
                    }
                }
                .padding(.horizontal, PantriSpacing.md)

                if isRunningDemo {
                    HStack(spacing: PantriSpacing.sm) {
                        ProgressView()
                            .tint(PantriColors.green)
                        Text("Running demo...")
                            .font(PantriFonts.subheadline)
                            .foregroundStyle(PantriColors.secondaryText)
                    }
                }

                Spacer()
            }
            .padding(.top, PantriSpacing.lg)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(PantriColors.green)
                }
            }
        }
    }
}

struct DemoButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: PantriSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 24)
                Text(title)
                    .font(PantriFonts.subheadline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PantriColors.secondaryText)
            }
            .foregroundStyle(PantriColors.black)
            .padding(PantriSpacing.md)
            .background(PantriColors.card)
            .clipShape(RoundedRectangle(cornerRadius: PantriRadius.md, style: .continuous))
            .shadow(
                color: PantriShadow.sm.color,
                radius: PantriShadow.sm.radius,
                y: PantriShadow.sm.y
            )
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
