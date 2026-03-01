import SwiftUI
import MapKit

// MARK: - Match Results View
// Shows all matches with expandable detail sheets.
// Luma-like: stacked cards with spring expand, score breakdown drawer.

struct MatchResultsView: View {
    @Bindable var appState: AppState
    @State private var selectedMatch: MatchResult?
    @State private var showExplainSheet = false
    @State private var showSMSPreview = false
    @State private var selectedForSMS: MatchResult?
    @State private var appeared = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PantriSpacing.lg) {
                headerSection

                if appState.matchResults.isEmpty {
                    emptyState
                } else {
                    mapSection
                    matchCards
                }
            }
            .padding(.horizontal, PantriSpacing.md)
            .padding(.bottom, PantriSpacing.xxl)
        }
        .background(PantriColors.background)
        .navigationTitle("Your Matches")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedMatch) { match in
            MatchDetailSheet(match: match, appState: appState, onSMS: {
                selectedForSMS = match
                showSMSPreview = true
            })
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSMSPreview) {
            if let match = selectedForSMS {
                SMSPreviewView(source: match.source, appState: appState)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
        .onAppear {
            withAnimation(PantriAnimation.smooth) {
                appeared = true
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: PantriSpacing.xs) {
            Text("We found \(appState.matchResults.count) matches")
                .font(PantriFonts.title2)
                .foregroundStyle(PantriColors.black)

            Text("Sorted by best match for \(appState.selectedNeedType.rawValue.lowercased())")
                .font(PantriFonts.subheadline)
                .foregroundStyle(PantriColors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, PantriSpacing.sm)
        .opacity(appeared ? 1 : 0)
    }

    private var mapSection: some View {
        MapSnippetView(
            sources: appState.matchResults.map(\.source),
            userLocation: appState.locationManager.effectiveLocation,
            height: 180
        )
        .opacity(appeared ? 1 : 0)
    }

    private var matchCards: some View {
        VStack(spacing: PantriSpacing.md) {
            ForEach(Array(appState.matchResults.enumerated()), id: \.element.id) { index, match in
                Button {
                    Haptics.tap()
                    selectedMatch = match
                } label: {
                    MatchCardView(match: match, rank: index + 1)
                }
                .buttonStyle(.plain)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : CGFloat(20 + index * 10))
                .animation(PantriAnimation.smooth.delay(Double(index) * 0.1), value: appeared)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: PantriSpacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(PantriColors.secondaryText)
            Text("No matches found")
                .font(PantriFonts.title3)
                .foregroundStyle(PantriColors.black)
            Text("Try adjusting your preferences or expanding your search area.")
                .font(PantriFonts.body)
                .foregroundStyle(PantriColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, PantriSpacing.xxl)
    }
}

// MARK: - Match Card

struct MatchCardView: View {
    let match: MatchResult
    let rank: Int

    var body: some View {
        VStack(alignment: .leading, spacing: PantriSpacing.sm) {
            HStack {
                // Rank badge
                Text("#\(rank)")
                    .font(PantriFonts.headline)
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(PantriColors.green)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(match.source.name)
                        .font(PantriFonts.headline)
                        .foregroundStyle(PantriColors.black)
                    Text(match.source.fullAddress)
                        .font(PantriFonts.caption)
                        .foregroundStyle(PantriColors.secondaryText)
                        .lineLimit(2)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.0f%%", match.score * 100))
                        .font(PantriFonts.title3)
                        .foregroundStyle(PantriColors.green)
                    Text(String(format: "%.1f mi", match.distanceKm))
                        .font(PantriFonts.caption)
                        .foregroundStyle(PantriColors.secondaryText)
                }
            }

            HStack(spacing: PantriSpacing.xs) {
                ForEach(match.source.foodTypes) { type in
                    BadgeView(text: type.rawValue, icon: type.icon, color: PantriColors.green)
                }
                StatusBadge(isOpen: match.source.isOpen)
                AvailabilityBadge(availability: match.source.availability)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(PantriColors.secondaryText)
            }
        }
        .pantriCard(padding: PantriSpacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Match \(rank): \(match.source.name), \(String(format: "%.0f", match.score * 100)) percent match, \(String(format: "%.1f", match.distanceKm)) miles away")
        .accessibilityHint("Tap for details")
    }
}

// MARK: - Match Detail Sheet

struct MatchDetailSheet: View {
    let match: MatchResult
    let appState: AppState
    var onSMS: () -> Void
    @State private var showBreakdown = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PantriSpacing.lg) {
                    // Map
                    MapSnippetView(
                        sources: [match.source],
                        userLocation: appState.locationManager.effectiveLocation,
                        height: 200
                    )

                    // Info
                    VStack(alignment: .leading, spacing: PantriSpacing.md) {
                        Text(match.source.name)
                            .font(PantriFonts.title2)
                            .foregroundStyle(PantriColors.black)

                        InfoRow(icon: "mappin", text: match.source.fullAddress)
                        InfoRow(icon: "phone", text: match.source.phone)
                        InfoRow(icon: "clock", text: match.source.hoursOfOperation)
                        InfoRow(icon: "figure.walk", text: String(format: "%.1f mi away", match.distanceKm))

                        if let wait = match.source.waitTimeEstimate {
                            InfoRow(icon: "hourglass", text: "~\(wait) min wait")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Badges
                    HStack(spacing: PantriSpacing.xs) {
                        ForEach(match.source.foodTypes) { type in
                            BadgeView(text: type.rawValue, icon: type.icon, color: PantriColors.green)
                        }
                        StatusBadge(isOpen: match.source.isOpen)
                        AvailabilityBadge(availability: match.source.availability)
                        if match.source.publicTransitAccessible {
                            BadgeView(text: "Transit", icon: "bus", color: PantriColors.green)
                        }
                    }

                    // Score breakdown
                    DisclosureGroup(isExpanded: $showBreakdown) {
                        ScoreBreakdownView(breakdown: match.scoreBreakdown, totalScore: match.score)
                            .padding(.top, PantriSpacing.sm)
                    } label: {
                        HStack {
                            Image(systemName: "chart.bar")
                            Text("Explain my match")
                                .font(PantriFonts.subheadline)
                        }
                        .foregroundStyle(PantriColors.green)
                    }

                    // Action buttons
                    VStack(spacing: PantriSpacing.sm) {
                        Button {
                            Haptics.tap()
                            openDirections()
                        } label: {
                            HStack(spacing: PantriSpacing.sm) {
                                Image(systemName: "arrow.triangle.turn.up.right.diamond")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Get Directions")
                                    .font(PantriFonts.headline)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(PantriColors.green)
                            .clipShape(RoundedRectangle(cornerRadius: PantriRadius.md, style: .continuous))
                        }
                        .accessibilityHint("Opens Apple Maps with directions to this location")

                        Button {
                            Haptics.tap()
                            onSMS()
                            dismiss()
                        } label: {
                            HStack(spacing: PantriSpacing.sm) {
                                Image(systemName: "message")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Share via SMS")
                                    .font(PantriFonts.headline)
                            }
                            .foregroundStyle(PantriColors.green)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(PantriColors.lightGreen)
                            .clipShape(RoundedRectangle(cornerRadius: PantriRadius.md, style: .continuous))
                        }
                        .accessibilityHint("Preview an SMS with pickup instructions")
                    }
                }
                .padding(.horizontal, PantriSpacing.md)
                .padding(.bottom, PantriSpacing.xxl)
            }
            .background(PantriColors.background)
            .navigationTitle("Match Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(PantriColors.green)
                }
            }
        }
    }

    private func openDirections() {
        let destination = MKMapItem(placemark: MKPlacemark(coordinate: match.source.coordinate))
        destination.name = match.source.name
        destination.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDefault
        ])
    }
}

// MARK: - Score Breakdown View

struct ScoreBreakdownView: View {
    let breakdown: ScoreBreakdown
    let totalScore: Double

    var body: some View {
        VStack(alignment: .leading, spacing: PantriSpacing.sm) {
            ScoreRow(label: "Distance", value: breakdown.distanceScore, weight: breakdown.weights.w1)
            ScoreRow(label: "Type match", value: breakdown.typeMatch, weight: breakdown.weights.w2)
            ScoreRow(label: "Verified", value: breakdown.verified, weight: breakdown.weights.w3)
            ScoreRow(label: "Capacity", value: breakdown.capacity, weight: breakdown.weights.w4)
            ScoreRow(label: "Open now", value: breakdown.openingMatch, weight: breakdown.weights.w5)
            ScoreRow(label: "Urgency boost", value: breakdown.urgencyBoost, weight: breakdown.weights.w6)

            Divider()

            HStack {
                Text("Total Score")
                    .font(PantriFonts.headline)
                Spacer()
                Text(String(format: "%.0f%%", totalScore * 100))
                    .font(PantriFonts.headline)
                    .foregroundStyle(PantriColors.green)
            }
        }
    }
}

struct ScoreRow: View {
    let label: String
    let value: Double
    let weight: Double

    var body: some View {
        HStack {
            Text(label)
                .font(PantriFonts.footnote)
                .foregroundStyle(PantriColors.secondaryText)
            Spacer()

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(PantriColors.border.opacity(0.5))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(PantriColors.green)
                        .frame(width: geo.size.width * value)
                }
            }
            .frame(width: 80, height: 6)

            Text(String(format: "%.2f", value * weight))
                .font(PantriFonts.caption)
                .foregroundStyle(PantriColors.secondaryText)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: PantriSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(PantriColors.green)
                .frame(width: 24)
            Text(text)
                .font(PantriFonts.subheadline)
                .foregroundStyle(PantriColors.black)
        }
    }
}

#Preview {
    MatchResultsView(appState: AppState.shared)
}
