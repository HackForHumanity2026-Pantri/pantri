import Foundation
import CoreLocation

// MARK: - Matching Engine
// Implements the explainable scoring function for matching users to food sources.
// All weights are visible and editable in the Developer panel.

@Observable
final class MatchingEngine {
    static let shared = MatchingEngine()

    var weights = MatchWeights()

    func findMatches(
        for request: UserRequest,
        from sources: [FoodSource],
        limit: Int? = nil
    ) -> [MatchResult] {
        let userLocation = CLLocationCoordinate2D(
            latitude: request.latitude,
            longitude: request.longitude
        )

        let scored = sources.compactMap { source -> MatchResult? in
            let distanceKm = source.distance(from: userLocation)
            let breakdown = computeBreakdown(
                source: source,
                distanceKm: distanceKm,
                needType: request.needType,
                urgency: request.urgency
            )
            let score = computeScore(breakdown: breakdown)

            return MatchResult(
                source: source,
                score: score,
                distanceKm: distanceKm,
                scoreBreakdown: breakdown
            )
        }
        .sorted { $0.score > $1.score }

        if let limit {
            return Array(scored.prefix(limit))
        }
        return scored
    }

    private func computeBreakdown(
        source: FoodSource,
        distanceKm: Double,
        needType: FoodType,
        urgency: Urgency
    ) -> ScoreBreakdown {
        let distanceScore = max(0, 1.0 - (distanceKm / 20.0))
        let typeMatch: Double = source.foodTypes.contains(needType) ? 1.0 : 0.0
        let verified: Double = source.isVerified ? 1.0 : 0.0
        let capacity = source.availability.normalized
        let openingMatch: Double = source.isOpen ? 1.0 : 0.0

        var urgencyBoost: Double = 0.0
        if urgency == .high && source.isOpen && source.foodTypes.contains(.cookedMeals) {
            urgencyBoost = 0.5
        } else if urgency == .medium {
            urgencyBoost = 0.2
        }

        return ScoreBreakdown(
            distanceScore: distanceScore,
            typeMatch: typeMatch,
            verified: verified,
            capacity: capacity,
            openingMatch: openingMatch,
            urgencyBoost: urgencyBoost,
            weights: weights
        )
    }

    private func computeScore(breakdown: ScoreBreakdown) -> Double {
        let w = breakdown.weights
        return w.w1 * breakdown.distanceScore
            + w.w2 * breakdown.typeMatch
            + w.w3 * breakdown.verified
            + w.w4 * breakdown.capacity
            + w.w5 * breakdown.openingMatch
            + w.w6 * breakdown.urgencyBoost
    }
}
