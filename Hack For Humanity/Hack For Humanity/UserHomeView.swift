import SwiftUI
import MapKit

// MARK: - User Home View
// Hero card with need selection, location input, transport picker, and nearby sources.
// Luma-like: scroll-driven layout, springy card transitions, generous whitespace.

struct UserHomeView: View {
    @Bindable var appState: AppState
    @State private var locationText: String = ""
    @State private var showLocationPermission = false
    @State private var nearbySources: [FoodSource] = []
    @State private var isLoadingNearby = true
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: PantriSpacing.lg) {
                    headerSection
                    heroCard
                    locationSection
                    transportSection
                    findMatchesButton
                    nearbySection
                }
                .padding(.horizontal, PantriSpacing.md)
                .padding(.bottom, PantriSpacing.xxl)
            }
            .background(PantriColors.background)
            .navigationDestination(isPresented: $appState.showMatchResults) {
                MatchResultsView(appState: appState)
            }
            .task {
                await loadNearbySources()
            }
            .onAppear {
                withAnimation(PantriAnimation.smooth) {
                    appeared = true
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: PantriSpacing.sm) {
            HStack {
                Button {
                    Haptics.tap()
                    withAnimation(PantriAnimation.snappy) {
                        appState.hasCompletedOnboarding = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(PantriFonts.subheadline)
                    }
                    .foregroundStyle(PantriColors.green)
                }
                Spacer()
                // Location badge
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 12))
                    Text(appState.defaultCity)
                        .font(PantriFonts.footnote)
                }
                .foregroundStyle(PantriColors.green)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(PantriColors.lightGreen)
                .clipShape(Capsule())
            }

            Image("PantriLogo")
                .resizable()
                .scaledToFit()
                .frame(height: 56)
        }
        .padding(.top, PantriSpacing.md)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -10)
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        VStack(spacing: PantriSpacing.md) {
            Text("What do you need today?")
                .font(PantriFonts.title2)
                .foregroundStyle(PantriColors.black)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: PantriSpacing.sm) {
                NeedTypeButton(
                    type: .groceries,
                    isSelected: appState.selectedNeedType == .groceries
                ) {
                    Haptics.selection()
                    withAnimation(PantriAnimation.snappy) {
                        appState.selectedNeedType = .groceries
                    }
                }

                NeedTypeButton(
                    type: .cookedMeals,
                    isSelected: appState.selectedNeedType == .cookedMeals
                ) {
                    Haptics.selection()
                    withAnimation(PantriAnimation.snappy) {
                        appState.selectedNeedType = .cookedMeals
                    }
                }
            }

            // Urgency
            VStack(alignment: .leading, spacing: PantriSpacing.xs) {
                Text("How urgent?")
                    .font(PantriFonts.footnote)
                    .foregroundStyle(PantriColors.secondaryText)

                HStack(spacing: PantriSpacing.sm) {
                    ForEach(Urgency.allCases) { urgency in
                        Button {
                            Haptics.selection()
                            withAnimation(PantriAnimation.snappy) {
                                appState.selectedUrgency = urgency
                            }
                        } label: {
                            Text(urgency.rawValue)
                                .font(PantriFonts.footnote)
                                .foregroundStyle(
                                    appState.selectedUrgency == urgency ? .white : PantriColors.black
                                )
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    appState.selectedUrgency == urgency ? PantriColors.green : PantriColors.border.opacity(0.5)
                                )
                                .clipShape(Capsule())
                        }
                        .accessibilityLabel("Urgency: \(urgency.rawValue)")
                    }
                }
            }
        }
        .pantriCard(padding: PantriSpacing.lg)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    // MARK: - Location

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: PantriSpacing.sm) {
            Text("Your location")
                .font(PantriFonts.headline)
                .foregroundStyle(PantriColors.black)

            HStack(spacing: PantriSpacing.sm) {
                Button {
                    Haptics.tap()
                    appState.locationManager.requestPermission()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 14))
                        Text("Use my location")
                            .font(PantriFonts.subheadline)
                    }
                    .foregroundStyle(PantriColors.green)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(PantriColors.lightGreen)
                    .clipShape(RoundedRectangle(cornerRadius: PantriRadius.sm, style: .continuous))
                }
                .accessibilityHint("Request location permission to find nearby food sources")

                Text("or")
                    .font(PantriFonts.footnote)
                    .foregroundStyle(PantriColors.secondaryText)

                TextField("ZIP or City", text: $locationText)
                    .font(PantriFonts.subheadline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(PantriColors.card)
                    .clipShape(RoundedRectangle(cornerRadius: PantriRadius.sm, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: PantriRadius.sm, style: .continuous)
                            .stroke(PantriColors.border, lineWidth: 1)
                    )
                    .accessibilityLabel("Enter ZIP code or city name")
            }
        }
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Transport

    private var transportSection: some View {
        VStack(alignment: .leading, spacing: PantriSpacing.sm) {
            Text("Transportation")
                .font(PantriFonts.headline)
                .foregroundStyle(PantriColors.black)

            HStack(spacing: PantriSpacing.sm) {
                ForEach(TransportMode.allCases) { mode in
                    Button {
                        Haptics.selection()
                        withAnimation(PantriAnimation.snappy) {
                            appState.selectedTransport = mode
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 20, weight: .medium))
                            Text(mode.rawValue)
                                .font(PantriFonts.caption)
                        }
                        .foregroundStyle(
                            appState.selectedTransport == mode ? .white : PantriColors.black
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            appState.selectedTransport == mode ? PantriColors.green : PantriColors.card
                        )
                        .clipShape(RoundedRectangle(cornerRadius: PantriRadius.sm, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: PantriRadius.sm, style: .continuous)
                                .stroke(
                                    appState.selectedTransport == mode ? Color.clear : PantriColors.border,
                                    lineWidth: 1
                                )
                        )
                    }
                    .accessibilityLabel("Transportation: \(mode.rawValue)")
                }
            }
        }
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - CTA

    private var findMatchesButton: some View {
        Button {
            Task {
                await appState.performSearch()
            }
        } label: {
            HStack(spacing: PantriSpacing.sm) {
                if appState.isSearching {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.system(size: 18, weight: .semibold))
                }
                Text(appState.isSearching ? "Searching..." : "Find Matches")
                    .font(PantriFonts.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(PantriColors.green)
            .clipShape(RoundedRectangle(cornerRadius: PantriRadius.md, style: .continuous))
            .shadow(color: PantriColors.green.opacity(0.3), radius: 12, y: 4)
        }
        .disabled(appState.isSearching)
        .accessibilityHint("Search for food sources matching your preferences")
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Nearby

    private var nearbySection: some View {
        VStack(alignment: .leading, spacing: PantriSpacing.sm) {
            Text("Nearby sources")
                .font(PantriFonts.headline)
                .foregroundStyle(PantriColors.black)

            if isLoadingNearby {
                VStack(spacing: PantriSpacing.sm) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: PantriRadius.lg)
                            .fill(PantriColors.border.opacity(0.3))
                            .frame(height: 100)
                            .skeleton()
                    }
                }
            } else {
                // Mini map
                MapSnippetView(
                    sources: nearbySources,
                    userLocation: appState.locationManager.effectiveLocation,
                    height: 160
                )

                ForEach(nearbySources) { source in
                    SourceCardView(
                        source: source,
                        distanceKm: source.distance(from: appState.locationManager.effectiveLocation)
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            }
        }
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Load Data

    private func loadNearbySources() async {
        do {
            let sources = try await appState.api.fetchSources()
            withAnimation(PantriAnimation.smooth) {
                nearbySources = sources
                isLoadingNearby = false
            }
        } catch {
            withAnimation {
                isLoadingNearby = false
            }
        }
    }
}

// MARK: - Need Type Button

struct NeedTypeButton: View {
    let type: FoodType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: PantriSpacing.sm) {
                Image(systemName: type.icon)
                    .font(.system(size: 28, weight: .medium))
                Text(type.rawValue)
                    .font(PantriFonts.subheadline)
            }
            .foregroundStyle(isSelected ? .white : PantriColors.black)
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(isSelected ? PantriColors.green : PantriColors.card)
            .clipShape(RoundedRectangle(cornerRadius: PantriRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PantriRadius.md, style: .continuous)
                    .stroke(isSelected ? Color.clear : PantriColors.border, lineWidth: 1.5)
            )
            .shadow(
                color: isSelected ? PantriColors.green.opacity(0.2) : .clear,
                radius: 8, y: 2
            )
        }
        .accessibilityLabel("Need type: \(type.rawValue)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    UserHomeView(appState: AppState.shared)
}
