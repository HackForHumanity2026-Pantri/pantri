import Foundation

// MARK: - API Client
// Switchable between Mock (demo) and Live modes.
// In demo mode, all calls resolve against the local MockDataStore.
// In live mode, calls would hit the REST endpoints.

enum APIMode {
    case mock
    case live
}

@Observable
final class APIClient {
    static let shared = APIClient()

    var mode: APIMode = .mock
    var baseURL: String = "https://api.pantri.app/v1"

    private let store = MockDataStore.shared

    // MARK: - Sources

    func fetchSources(
        latitude: Double? = nil,
        longitude: Double? = nil,
        type: FoodType? = nil,
        openNow: Bool? = nil
    ) async throws -> [FoodSource] {
        switch mode {
        case .mock:
            // Simulate network delay for realistic demo
            try await Task.sleep(for: .milliseconds(600))
            var results = store.sources

            if let type {
                results = results.filter { $0.foodTypes.contains(type) }
            }
            if let openNow, openNow {
                results = results.filter { $0.isOpen }
            }
            return results

        case .live:
            var urlString = "\(baseURL)/sources?"
            if let lat = latitude { urlString += "lat=\(lat)&" }
            if let lng = longitude { urlString += "lng=\(lng)&" }
            if let type { urlString += "type=\(type.rawValue)&" }
            if let openNow { urlString += "openNow=\(openNow)&" }

            guard let url = URL(string: urlString) else {
                throw APIError.invalidURL
            }
            let (data, _) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode([FoodSource].self, from: data)
        }
    }

    func createSource(_ source: FoodSource) async throws {
        switch mode {
        case .mock:
            try await Task.sleep(for: .milliseconds(400))
            store.addSource(source)

        case .live:
            guard let url = URL(string: "\(baseURL)/sources") else {
                throw APIError.invalidURL
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(source)
            _ = try await URLSession.shared.data(for: request)
        }
    }

    func verifySource(id: UUID) async throws {
        switch mode {
        case .mock:
            try await Task.sleep(for: .seconds(2)) // Simulate phone-bot delay
            store.toggleVerified(id: id)

        case .live:
            guard let url = URL(string: "\(baseURL)/verify/\(id.uuidString)") else {
                throw APIError.invalidURL
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            _ = try await URLSession.shared.data(for: request)
        }
    }

    // MARK: - Chat

    func sendChatMessage(_ message: String, context: UserRequest?) async throws -> String {
        switch mode {
        case .mock:
            try await Task.sleep(for: .milliseconds(800))
            return generateMockResponse(for: message, context: context)

        case .live:
            guard let url = URL(string: "\(baseURL)/chat") else {
                throw APIError.invalidURL
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: Any] = ["message": message]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode([String: String].self, from: data)
            return response["reply"] ?? "Sorry, I couldn't understand that."
        }
    }

    // MARK: - SMS

    func sendSMS(to phone: String, body: String) async throws {
        switch mode {
        case .mock:
            try await Task.sleep(for: .milliseconds(300))
            // SMS preview only in demo

        case .live:
            guard let url = URL(string: "\(baseURL)/sms/send") else {
                throw APIError.invalidURL
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let payload: [String: String] = ["to": phone, "body": body]
            request.httpBody = try JSONEncoder().encode(payload)
            _ = try await URLSession.shared.data(for: request)
        }
    }

    // MARK: - Mock Chat Logic

    private func generateMockResponse(for message: String, context: UserRequest?) -> String {
        let lower = message.lowercased()

        if lower.contains("hungry") || lower.contains("food") || lower.contains("eat") || lower.contains("meal") {
            let openSources = store.sources.filter { $0.isOpen && $0.foodTypes.contains(.cookedMeals) }
            if let best = openSources.first {
                return "I found a great option for you! \(best.name) at \(best.address) is open now and has \(best.availability.rawValue.lowercased()) availability for cooked meals. Would you like directions?"
            }
            return "I'm looking for cooked meal options near you. Could you share your location or ZIP code so I can find the closest options?"
        }

        if lower.contains("grocer") || lower.contains("produce") || lower.contains("fresh") {
            let openSources = store.sources.filter { $0.isOpen && $0.foodTypes.contains(.groceries) }
            if let best = openSources.first {
                return "For groceries, I'd recommend \(best.name) at \(best.address). They're open now with \(best.availability.rawValue.lowercased()) availability. Want me to show you how to get there?"
            }
            return "Let me find grocery sources near you. What's your ZIP code or neighborhood?"
        }

        if lower.contains("direction") || lower.contains("how to get") || lower.contains("map") {
            return "Tap the 'Directions' button on any match card to open Apple Maps with turn-by-turn directions. If you prefer public transit, make sure to set that in your transportation preferences!"
        }

        if lower.contains("hi") || lower.contains("hello") || lower.contains("hey") {
            return "Hi there! I'm Pantri, your food-finding assistant. I can help you find cooked meals or groceries nearby. What are you looking for today?"
        }

        if lower.contains("thank") {
            return "You're welcome! Remember, you can always come back to find more food sources. Take care! 💚"
        }

        return "I can help you find food nearby! Try asking about cooked meals, groceries, or tell me what you need and I'll find the best match for you."
    }
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidURL
    case serverError(Int)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .serverError(let code): return "Server error: \(code)"
        case .decodingError: return "Failed to decode response"
        }
    }
}
