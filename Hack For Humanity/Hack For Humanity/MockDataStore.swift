import Foundation

// MARK: - Mock Data Store
// Provides seeded demo data that mirrors the Postgres schema.
// All data is in-memory for the hackathon demo.

@Observable
final class MockDataStore {
    static let shared = MockDataStore()

    var sources: [FoodSource] = []

    init() {
        seedDemoData()
    }

    func seedDemoData() {
        sources = Self.defaultSources
    }

    func addSource(_ source: FoodSource) {
        sources.append(source)
    }

    func updateSource(_ source: FoodSource) {
        if let index = sources.firstIndex(where: { $0.id == source.id }) {
            sources[index] = source
        }
    }

    func toggleOpen(id: UUID) {
        if let index = sources.firstIndex(where: { $0.id == id }) {
            sources[index].isOpen.toggle()
        }
    }

    func toggleVerified(id: UUID) {
        if let index = sources.firstIndex(where: { $0.id == id }) {
            sources[index].isVerified.toggle()
            if sources[index].isVerified {
                sources[index].lastVerified = Date()
            }
        }
    }

    // MARK: - Seeded Demo Data (Los Angeles area)

    static let defaultSources: [FoodSource] = [
        FoodSource(
            id: UUID(),
            name: "LA Food Bank - Downtown",
            phone: "(213) 555-0101",
            address: "1734 E 41st St",
            city: "Los Angeles",
            state: "CA",
            latitude: 34.0012,
            longitude: -118.2140,
            sourceType: .foodBank,
            foodTypes: [.groceries],
            hoursOfOperation: "Mon-Fri 8AM-4PM",
            duration: .permanent,
            publicTransitAccessible: true,
            availability: .high,
            hasExcessFood: false,
            isVerified: true,
            isOpen: true,
            lastVerified: Date().addingTimeInterval(-3600),
            waitTimeEstimate: 15
        ),
        FoodSource(
            id: UUID(),
            name: "Midnight Mission Kitchen",
            phone: "(213) 555-0202",
            address: "601 S San Pedro St",
            city: "Los Angeles",
            state: "CA",
            latitude: 34.0422,
            longitude: -118.2467,
            sourceType: .foodBank,
            foodTypes: [.cookedMeals],
            hoursOfOperation: "Daily 6AM-8PM",
            duration: .permanent,
            publicTransitAccessible: true,
            availability: .medium,
            hasExcessFood: false,
            isVerified: true,
            isOpen: true,
            lastVerified: Date().addingTimeInterval(-7200),
            waitTimeEstimate: 25
        ),
        FoodSource(
            id: UUID(),
            name: "Green Garden Bistro",
            phone: "(310) 555-0303",
            address: "415 S Fairfax Ave",
            city: "Los Angeles",
            state: "CA",
            latitude: 34.0665,
            longitude: -118.3617,
            sourceType: .restaurant,
            foodTypes: [.cookedMeals],
            hoursOfOperation: "Daily 11AM-10PM",
            duration: .permanent,
            publicTransitAccessible: true,
            availability: .high,
            hasExcessFood: true,
            isVerified: true,
            isOpen: true,
            lastVerified: Date().addingTimeInterval(-1800),
            waitTimeEstimate: 10
        ),
        FoodSource(
            id: UUID(),
            name: "Community Pop-Up Pantry",
            phone: "(323) 555-0404",
            address: "2200 W Temple St",
            city: "Los Angeles",
            state: "CA",
            latitude: 34.0712,
            longitude: -118.2651,
            sourceType: .popup,
            foodTypes: [.groceries, .cookedMeals],
            hoursOfOperation: "Sat 9AM-1PM",
            duration: .popup,
            publicTransitAccessible: true,
            availability: .medium,
            hasExcessFood: false,
            isVerified: false,
            isOpen: false,
            lastVerified: nil,
            waitTimeEstimate: nil
        ),
        FoodSource(
            id: UUID(),
            name: "Harvest Fresh Market",
            phone: "(818) 555-0505",
            address: "3820 Riverside Dr",
            city: "Burbank",
            state: "CA",
            latitude: 34.1508,
            longitude: -118.3374,
            sourceType: .restaurant,
            foodTypes: [.groceries],
            hoursOfOperation: "Mon-Sat 7AM-9PM",
            duration: .permanent,
            publicTransitAccessible: false,
            availability: .high,
            hasExcessFood: true,
            isVerified: true,
            isOpen: true,
            lastVerified: Date().addingTimeInterval(-600),
            waitTimeEstimate: 5
        ),
        FoodSource(
            id: UUID(),
            name: "St. Mary's Community Kitchen",
            phone: "(213) 555-0606",
            address: "520 N Mission Rd",
            city: "Los Angeles",
            state: "CA",
            latitude: 34.0567,
            longitude: -118.2195,
            sourceType: .foodBank,
            foodTypes: [.cookedMeals, .groceries],
            hoursOfOperation: "Tue-Thu 10AM-3PM",
            duration: .permanent,
            publicTransitAccessible: true,
            availability: .low,
            hasExcessFood: false,
            isVerified: true,
            isOpen: false,
            lastVerified: Date().addingTimeInterval(-86400),
            waitTimeEstimate: 40
        ),
        FoodSource(
            id: UUID(),
            name: "Echo Park Weekend Giveaway",
            phone: "(323) 555-0707",
            address: "751 Echo Park Ave",
            city: "Los Angeles",
            state: "CA",
            latitude: 34.0782,
            longitude: -118.2606,
            sourceType: .popup,
            foodTypes: [.groceries],
            hoursOfOperation: "Sun 10AM-2PM",
            duration: .popup,
            publicTransitAccessible: true,
            availability: .high,
            hasExcessFood: false,
            isVerified: false,
            isOpen: false,
            lastVerified: nil,
            waitTimeEstimate: nil
        )
    ]
}
