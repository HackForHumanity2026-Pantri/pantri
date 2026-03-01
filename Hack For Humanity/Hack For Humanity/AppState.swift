import Foundation
import SwiftUI
import CoreLocation

// MARK: - App State
// Central state management for the app. Owns shared state across views.

@Observable
final class AppState {
    static let shared = AppState()

    // Mode
    var hasCompletedOnboarding: Bool = false
    var userMode: UserMode = .user

    // User preferences
    var selectedNeedType: FoodType = .cookedMeals
    var selectedTransport: TransportMode = .publicTransit
    var selectedUrgency: Urgency = .medium
    var defaultCity: String = "Santa Clara"
    var language: String = "English"

    // Navigation
    var showMatchResults: Bool = false
    var matchResults: [MatchResult] = []

    // Loading states
    var isLoading: Bool = false
    var isSearching: Bool = false

    // Shared services
    let store = MockDataStore.shared
    let api = APIClient.shared
    let matchingEngine = MatchingEngine.shared
    let locationManager = LocationManager.shared

    func performSearch() async {
        isSearching = true
        Haptics.tap()

        do {
            let sources = try await api.fetchSources(
                latitude: locationManager.effectiveLocation.latitude,
                longitude: locationManager.effectiveLocation.longitude,
                type: selectedNeedType,
                openNow: nil
            )

            let request = UserRequest(
                id: UUID(),
                needType: selectedNeedType,
                urgency: selectedUrgency,
                latitude: locationManager.effectiveLocation.latitude,
                longitude: locationManager.effectiveLocation.longitude,
                transportMode: selectedTransport,
                city: defaultCity
            )

            let results = matchingEngine.findMatches(for: request, from: sources)

            await MainActor.run {
                withAnimation(PantriAnimation.snappy) {
                    self.matchResults = results
                    self.isSearching = false
                    self.showMatchResults = true
                }
                Haptics.match()
            }
        } catch {
            await MainActor.run {
                self.isSearching = false
            }
        }
    }

    // MARK: - Startup

    /// Fetches food sources from the backend and populates the local store.
    func loadSourcesFromBackend() async {
        do {
            let sources = try await api.fetchSources(
                latitude: locationManager.effectiveLocation.latitude,
                longitude: locationManager.effectiveLocation.longitude
            )
            await MainActor.run {
                if !sources.isEmpty {
                    store.sources = sources
                }
            }
        } catch {
            // Keep existing mock data as fallback
        }
    }

    func resetOnboarding() {
        hasCompletedOnboarding = false
    }
}
