import Foundation

// MARK: - API Client
// Switchable between Mock (demo) and Live modes.
// In demo mode, all calls resolve against the local MockDataStore.
// In live mode, calls hit the Python FastAPI backend endpoints.

enum APIMode {
    case mock
    case live
}

@Observable
final class APIClient {
    static let shared = APIClient()

    var mode: APIMode = .mock
    var baseURL: String = "http://127.0.0.1:3000"

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
            var components = URLComponents(string: "\(baseURL)/sources")
            var queryItems: [URLQueryItem] = []
            if let lat = latitude { queryItems.append(URLQueryItem(name: "lat", value: String(lat))) }
            if let lng = longitude { queryItems.append(URLQueryItem(name: "lng", value: String(lng))) }
            if let type { queryItems.append(URLQueryItem(name: "type", value: type.rawValue)) }
            if let openNow { queryItems.append(URLQueryItem(name: "openNow", value: String(openNow))) }
            if !queryItems.isEmpty { components?.queryItems = queryItems }

            guard let url = components?.url else {
                throw APIError.invalidURL
            }
            let (data, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
                throw APIError.serverError(httpResponse.statusCode)
            }
            return try Self.decodeSourceArray(from: data)
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

            let payload = CreateSourcePayload(
                name: source.name,
                phone: source.phone.isEmpty ? nil : source.phone,
                address: source.address.isEmpty ? nil : source.address,
                types_json: source.foodTypes.map { $0.rawValue.lowercased() },
                duration: source.duration.rawValue.lowercased(),
                is_accessible: source.publicTransitAccessible,
                availability: source.availability.rawValue.lowercased(),
                excess_food: source.hasExcessFood
            )
            request.httpBody = try JSONEncoder().encode(payload)
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
                throw APIError.serverError(httpResponse.statusCode)
            }
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
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
                throw APIError.serverError(httpResponse.statusCode)
            }
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

            var payload: [String: Any] = ["message": message]
            if let ctx = context {
                payload["latitude"] = ctx.latitude
                payload["longitude"] = ctx.longitude
            }
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
                throw APIError.serverError(httpResponse.statusCode)
            }
            let decoded = try JSONDecoder().decode([String: String].self, from: data)
            return decoded["reply"] ?? "Sorry, I couldn't understand that."
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
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
                throw APIError.serverError(httpResponse.statusCode)
            }
        }
    }

    // MARK: - Response Decoding

    /// Decodes backend JSON array into [FoodSource], handling field name mapping.
    private static func decodeSourceArray(from data: Data) throws -> [FoodSource] {
        guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw APIError.decodingError
        }
        return jsonArray.compactMap { Self.parseFoodSource(from: $0) }
    }

    /// Parses a single backend JSON dict into a FoodSource, mapping field names.
    private static func parseFoodSource(from dict: [String: Any]) -> FoodSource? {
        guard let name = dict["name"] as? String else { return nil }

        let id: UUID
        if let idString = dict["id"] as? String, let parsed = UUID(uuidString: idString) {
            id = parsed
        } else if let intId = dict["id"] as? Int {
            // Deterministic UUID from integer ID (matches backend uuid5 approach)
            let idBytes = "pantri-source-\(intId)".data(using: .utf8)!
            id = UUID(uuid: (
                idBytes.hashValue > 0 ? UInt8(idBytes.hashValue & 0xFF) : 0,
                UInt8((idBytes.hashValue >> 8) & 0xFF),
                UInt8((idBytes.hashValue >> 16) & 0xFF),
                UInt8((idBytes.hashValue >> 24) & 0xFF),
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8(intId & 0xFF)
            ))
        } else {
            id = UUID()
        }

        let phone = dict["phone"] as? String ?? ""
        let address = dict["address"] as? String ?? ""
        let latitude = dict["latitude"] as? Double ?? 0.0
        let longitude = dict["longitude"] as? Double ?? 0.0

        let sourceType: FoodSourceType
        if let st = dict["sourceType"] as? String {
            sourceType = FoodSourceType(rawValue: st) ?? .foodBank
        } else {
            sourceType = .foodBank
        }

        let foodTypes: [FoodType]
        if let types = dict["foodTypes"] as? [String] {
            foodTypes = types.compactMap { FoodType(rawValue: $0) }
        } else {
            foodTypes = [.groceries]
        }

        let hoursOfOperation = dict["hoursOfOperation"] as? String ?? ""

        let duration: Duration
        if let d = dict["duration"] as? String {
            duration = Duration(rawValue: d) ?? .permanent
        } else {
            duration = .permanent
        }

        let publicTransitAccessible = dict["publicTransitAccessible"] as? Bool ?? false

        let availability: Availability
        if let a = dict["availability"] as? String {
            availability = Availability(rawValue: a) ?? .medium
        } else {
            availability = .medium
        }

        let hasExcessFood = dict["hasExcessFood"] as? Bool ?? false
        let isVerified = dict["isVerified"] as? Bool ?? false
        let isOpen = dict["isOpen"] as? Bool ?? true
        let waitTimeEstimate = dict["waitTimeEstimate"] as? Int

        return FoodSource(
            id: id,
            name: name,
            phone: phone,
            address: address,
            latitude: latitude,
            longitude: longitude,
            sourceType: sourceType,
            foodTypes: foodTypes.isEmpty ? [.groceries] : foodTypes,
            hoursOfOperation: hoursOfOperation,
            duration: duration,
            publicTransitAccessible: publicTransitAccessible,
            availability: availability,
            hasExcessFood: hasExcessFood,
            isVerified: isVerified,
            isOpen: isOpen,
            lastVerified: nil,
            waitTimeEstimate: waitTimeEstimate
        )
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

// MARK: - Create Source Payload (matches backend SourceCreate schema)

private struct CreateSourcePayload: Encodable {
    let name: String
    let phone: String?
    let address: String?
    let types_json: [String]?
    let duration: String?
    let is_accessible: Bool?
    let availability: String?
    let excess_food: Bool?
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
