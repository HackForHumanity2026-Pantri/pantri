import SwiftUI
import MapKit

// MARK: - Map Snippet View
// A compact, rounded map preview showing food source locations.
// Uses MapKit with annotation markers.

struct MapSnippetView: View {
    let sources: [FoodSource]
    let userLocation: CLLocationCoordinate2D
    var height: CGFloat = 200

    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $cameraPosition) {
            // User location marker
            Annotation("You", coordinate: userLocation) {
                ZStack {
                    Circle()
                        .fill(PantriColors.green.opacity(0.2))
                        .frame(width: 32, height: 32)
                    Circle()
                        .fill(PantriColors.green)
                        .frame(width: 14, height: 14)
                    Circle()
                        .stroke(.white, lineWidth: 2)
                        .frame(width: 14, height: 14)
                }
            }

            // Source markers
            ForEach(sources) { source in
                Annotation(source.name, coordinate: source.coordinate) {
                    ZStack {
                        Circle()
                            .fill(source.isOpen ? PantriColors.green : PantriColors.secondaryText)
                            .frame(width: 30, height: 30)
                        Image(systemName: source.sourceType.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel("\(source.name), \(source.isOpen ? "open" : "closed")")
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: PantriRadius.lg, style: .continuous))
        .allowsHitTesting(false)
    }
}

// MARK: - Source Card View
// Reusable card for displaying a food source with badges.

struct SourceCardView: View {
    let source: FoodSource
    var distanceKm: Double?
    var showScore: Bool = false
    var score: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: PantriSpacing.sm) {
            HStack(alignment: .top) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: PantriRadius.sm, style: .continuous)
                        .fill(PantriColors.lightGreen)
                        .frame(width: 44, height: 44)
                    Image(systemName: source.sourceType.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(PantriColors.green)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(source.name)
                        .font(PantriFonts.headline)
                        .foregroundStyle(PantriColors.black)
                        .lineLimit(2)

                    Text(source.fullAddress)
                        .font(PantriFonts.caption)
                        .foregroundStyle(PantriColors.secondaryText)
                        .lineLimit(2)
                }

                Spacer()

                if let distanceKm {
                    Text(String(format: "%.1f km", distanceKm))
                        .font(PantriFonts.footnote)
                        .foregroundStyle(PantriColors.secondaryText)
                }
            }

            // Phone
            if !source.phone.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(PantriColors.green)
                    Text(source.phone)
                        .font(PantriFonts.footnote)
                        .foregroundStyle(PantriColors.secondaryText)
                }
            }

            // Hours
            if !source.hoursOfOperation.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(PantriColors.green)
                    Text(source.hoursOfOperation)
                        .font(PantriFonts.caption)
                        .foregroundStyle(PantriColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Badges row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PantriSpacing.xs) {
                    ForEach(source.foodTypes) { type in
                        BadgeView(text: type.rawValue, icon: type.icon, color: PantriColors.green)
                    }

                    if source.isVerified {
                        BadgeView(text: "Verified", icon: "checkmark.seal.fill", color: PantriColors.green)
                    }

                    StatusBadge(isOpen: source.isOpen)

                    AvailabilityBadge(availability: source.availability)
                }
            }

            if showScore, let score {
                HStack {
                    Text("Match Score")
                        .font(PantriFonts.caption)
                        .foregroundStyle(PantriColors.secondaryText)
                    Spacer()
                    Text(String(format: "%.0f%%", score * 100))
                        .font(PantriFonts.headline)
                        .foregroundStyle(PantriColors.green)
                }
            }
        }
        .pantriCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(source.name), \(source.sourceType.rawValue), \(source.isOpen ? "open" : "closed"), availability \(source.availability.rawValue)")
    }
}

// MARK: - Badge Components

struct BadgeView: View {
    let text: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(PantriFonts.caption)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

struct StatusBadge: View {
    let isOpen: Bool

    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(isOpen ? PantriColors.availabilityHigh : PantriColors.destructive)
                .frame(width: 6, height: 6)
            Text(isOpen ? "Open" : "Closed")
                .font(PantriFonts.caption)
        }
        .foregroundStyle(isOpen ? PantriColors.availabilityHigh : PantriColors.destructive)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background((isOpen ? PantriColors.availabilityHigh : PantriColors.destructive).opacity(0.1))
        .clipShape(Capsule())
    }
}

struct AvailabilityBadge: View {
    let availability: Availability

    var color: Color {
        switch availability {
        case .high: return PantriColors.availabilityHigh
        case .medium: return PantriColors.availabilityMed
        case .low: return PantriColors.availabilityLow
        }
    }

    var body: some View {
        Text(availability.rawValue)
            .font(PantriFonts.caption)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }
}
