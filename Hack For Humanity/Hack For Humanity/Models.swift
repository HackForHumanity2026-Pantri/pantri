import Foundation
import CoreLocation

// MARK: - Enumerations

enum FoodSourceType: String, Codable, CaseIterable, Identifiable {
    case restaurant = "Restaurant"
    case foodBank = "Food Bank"
    case popup = "Pop-up"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .restaurant: return "fork.knife"
        case .foodBank: return "building.2"
        case .popup: return "tent"
        }
    }
}

enum FoodType: String, Codable, CaseIterable, Identifiable {
    case groceries = "Groceries"
    case cookedMeals = "Cooked Meals"
    case freshProduce = "Fresh Produce"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .groceries: return "cart"
        case .cookedMeals: return "takeoutbag.and.cup.and.straw"
        case .freshProduce: return "leaf"
        }
    }
}

enum Availability: String, Codable, CaseIterable, Identifiable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    var id: String { rawValue }

    var normalized: Double {
        switch self {
        case .high: return 1.0
        case .medium: return 0.5
        case .low: return 0.2
        }
    }
}

enum Duration: String, Codable, CaseIterable, Identifiable {
    case permanent = "Permanent"
    case popup = "Pop-up"

    var id: String { rawValue }
}

enum TransportMode: String, Codable, CaseIterable, Identifiable {
    case walk = "Walk"
    case bike = "Bike"
    case publicTransit = "Public Transit"
    case car = "Car"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .walk: return "figure.walk"
        case .bike: return "bicycle"
        case .publicTransit: return "bus"
        case .car: return "car"
        }
    }
}

enum Urgency: String, Codable, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var id: String { rawValue }
}

enum UserMode: String, Codable {
    case user
    case provider
}

// MARK: - Food Source Model (mirrors Postgres schema)

struct FoodSource: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var phone: String
    var address: String
    var city: String
    var state: String
    var latitude: Double
    var longitude: Double
    var sourceType: FoodSourceType
    var foodTypes: [FoodType]
    var hoursOfOperation: String
    var duration: Duration
    var publicTransitAccessible: Bool
    var availability: Availability
    var hasExcessFood: Bool
    var isVerified: Bool
    var isOpen: Bool
    var lastVerified: Date?
    var waitTimeEstimate: Int? // minutes

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var fullAddress: String {
        [address, city, state].filter { !$0.isEmpty }.joined(separator: ", ")
    }

    func distance(from location: CLLocationCoordinate2D) -> Double {
        let sourceLocation = CLLocation(latitude: latitude, longitude: longitude)
        let userLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        return sourceLocation.distance(from: userLocation) / 1609.34 // miles
    }
}

// MARK: - User Request

struct UserRequest: Identifiable, Codable {
    let id: UUID
    var needType: FoodType
    var urgency: Urgency
    var latitude: Double
    var longitude: Double
    var transportMode: TransportMode
    var city: String

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Match Result

struct MatchResult: Identifiable {
    let id = UUID()
    let source: FoodSource
    let score: Double
    let distanceKm: Double
    let scoreBreakdown: ScoreBreakdown
}

struct ScoreBreakdown {
    let distanceScore: Double
    let typeMatch: Double
    let verified: Double
    let capacity: Double
    let openingMatch: Double
    let urgencyBoost: Double
    let weights: MatchWeights
}

struct MatchWeights: Codable {
    var w1: Double = 0.35 // distance
    var w2: Double = 0.25 // type match
    var w3: Double = 0.15 // verified
    var w4: Double = 0.15 // capacity
    var w5: Double = 0.08 // opening match
    var w6: Double = 0.02 // urgency boost
}

// MARK: - Chat Message

struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let content: String
    let isUser: Bool
    let timestamp: Date
    var quickReplies: [String]

    init(id: UUID = UUID(), content: String, isUser: Bool, timestamp: Date = Date(), quickReplies: [String] = []) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.quickReplies = quickReplies
    }
}
