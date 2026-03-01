import SwiftUI

// MARK: - Provider Register View
// Form to register a restaurant, food bank, or pop-up.
// Segmented control at top, clean minimal fields.

struct ProviderRegisterView: View {
    @Bindable var appState: AppState
    @State private var sourceType: FoodSourceType = .restaurant
    @State private var name: String = ""
    @State private var phone: String = ""
    @State private var address: String = ""
    @State private var selectedFoodTypes: Set<FoodType> = [.cookedMeals]
    @State private var hours: String = ""
    @State private var duration: Duration = .permanent
    @State private var transitAccessible: Bool = true
    @State private var availability: Availability = .medium
    @State private var hasExcessFood: Bool = false
    @State private var isSubmitting: Bool = false
    @State private var showSuccess: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PantriSpacing.lg) {
                    // Source type picker
                    VStack(alignment: .leading, spacing: PantriSpacing.sm) {
                        Text("Type of source")
                            .font(PantriFonts.headline)
                            .foregroundStyle(PantriColors.black)

                        Picker("Source Type", selection: $sourceType) {
                            ForEach(FoodSourceType.allCases) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Basic info
                    VStack(spacing: PantriSpacing.sm) {
                        FormField(label: "Name", placeholder: "Organization name", text: $name)
                        FormField(label: "Phone", placeholder: "(555) 123-4567", text: $phone)
                            .keyboardType(.phonePad)
                        FormField(label: "Address", placeholder: "Full street address", text: $address)
                    }
                    .pantriCard()

                    // Food types
                    VStack(alignment: .leading, spacing: PantriSpacing.sm) {
                        Text("Food available")
                            .font(PantriFonts.headline)
                            .foregroundStyle(PantriColors.black)

                        HStack(spacing: PantriSpacing.sm) {
                            ForEach(FoodType.allCases) { type in
                                Button {
                                    Haptics.selection()
                                    if selectedFoodTypes.contains(type) {
                                        selectedFoodTypes.remove(type)
                                    } else {
                                        selectedFoodTypes.insert(type)
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: type.icon)
                                        Text(type.rawValue)
                                            .font(PantriFonts.subheadline)
                                    }
                                    .foregroundStyle(
                                        selectedFoodTypes.contains(type) ? .white : PantriColors.black
                                    )
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(
                                        selectedFoodTypes.contains(type) ? PantriColors.green : PantriColors.card
                                    )
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(
                                                selectedFoodTypes.contains(type) ? Color.clear : PantriColors.border,
                                                lineWidth: 1
                                            )
                                    )
                                }
                            }
                        }
                    }

                    // Details
                    VStack(spacing: PantriSpacing.sm) {
                        FormField(label: "Hours of Operation", placeholder: "e.g., Mon-Fri 9AM-5PM", text: $hours)

                        // Duration
                        HStack {
                            Text("Duration")
                                .font(PantriFonts.subheadline)
                                .foregroundStyle(PantriColors.black)
                            Spacer()
                            Picker("Duration", selection: $duration) {
                                ForEach(Duration.allCases) { d in
                                    Text(d.rawValue).tag(d)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 200)
                        }

                        // Transit accessible
                        HStack {
                            Text("Public transit accessible")
                                .font(PantriFonts.subheadline)
                            Spacer()
                            Toggle("", isOn: $transitAccessible)
                                .tint(PantriColors.green)
                        }

                        // Availability
                        HStack {
                            Text("Current availability")
                                .font(PantriFonts.subheadline)
                            Spacer()
                            Picker("Availability", selection: $availability) {
                                ForEach(Availability.allCases) { a in
                                    Text(a.rawValue).tag(a)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 200)
                        }

                        // Restaurant-specific
                        if sourceType == .restaurant {
                            HStack {
                                Text("Has excess food")
                                    .font(PantriFonts.subheadline)
                                Spacer()
                                Toggle("", isOn: $hasExcessFood)
                                    .tint(PantriColors.green)
                            }
                        }
                    }
                    .pantriCard()

                    // Submit
                    Button {
                        submitSource()
                    } label: {
                        HStack(spacing: PantriSpacing.sm) {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            } else if showSuccess {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18))
                            }
                            Text(showSuccess ? "Registered!" : (isSubmitting ? "Submitting..." : "Register Source"))
                                .font(PantriFonts.headline)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(showSuccess ? PantriColors.darkGreen : PantriColors.green)
                        .clipShape(RoundedRectangle(cornerRadius: PantriRadius.md, style: .continuous))
                        .shadow(color: PantriColors.green.opacity(0.3), radius: 12, y: 4)
                    }
                    .disabled(isSubmitting || name.isEmpty || address.isEmpty)
                    .accessibilityHint("Submit this food source registration")
                }
                .padding(.horizontal, PantriSpacing.md)
                .padding(.bottom, PantriSpacing.xxl)
            }
            .background(PantriColors.background)
            .navigationTitle("Register")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private func submitSource() {
        Haptics.tap()
        isSubmitting = true

        let source = FoodSource(
            id: UUID(),
            name: name,
            phone: phone,
            address: address,
            latitude: 34.0522 + Double.random(in: -0.05...0.05),
            longitude: -118.2437 + Double.random(in: -0.05...0.05),
            sourceType: sourceType,
            foodTypes: Array(selectedFoodTypes),
            hoursOfOperation: hours,
            duration: duration,
            publicTransitAccessible: transitAccessible,
            availability: availability,
            hasExcessFood: hasExcessFood,
            isVerified: false,
            isOpen: true,
            lastVerified: nil,
            waitTimeEstimate: nil
        )

        Task {
            do {
                try await appState.api.createSource(source)
                await MainActor.run {
                    withAnimation(PantriAnimation.bouncy) {
                        isSubmitting = false
                        showSuccess = true
                    }
                    Haptics.notification(.success)

                    // Reset after delay
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(2))
                        withAnimation {
                            showSuccess = false
                            resetForm()
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    Haptics.error()
                }
            }
        }
    }

    private func resetForm() {
        name = ""
        phone = ""
        address = ""
        selectedFoodTypes = [.cookedMeals]
        hours = ""
        duration = .permanent
        transitAccessible = true
        availability = .medium
        hasExcessFood = false
    }
}

// MARK: - Form Field

struct FormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(PantriFonts.footnote)
                .foregroundStyle(PantriColors.secondaryText)
            TextField(placeholder, text: $text)
                .font(PantriFonts.body)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(PantriColors.background)
                .clipShape(RoundedRectangle(cornerRadius: PantriRadius.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PantriRadius.sm, style: .continuous)
                        .stroke(PantriColors.border, lineWidth: 1)
                )
        }
    }
}

#Preview {
    ProviderRegisterView(appState: AppState.shared)
}
