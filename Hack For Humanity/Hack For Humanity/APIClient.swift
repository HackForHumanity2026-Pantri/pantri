import Foundation

// MARK: - API Client
// All calls hit the backend endpoints directly.

@Observable
final class APIClient {
    static let shared = APIClient()

    var baseURL: String = "http://127.0.0.1:3000"

    private let store = MockDataStore.shared

    // MARK: - Sources

    func fetchSources(
        latitude: Double? = nil,
        longitude: Double? = nil,
        type: FoodType? = nil,
        openNow: Bool? = nil
    ) async throws -> [FoodSource] {
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

    func createSource(_ source: FoodSource) async throws {
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
        // Also update local store
        store.addSource(source)
    }

    func verifySource(id: UUID) async throws {
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

    // MARK: - Chat

    func sendChatMessage(_ message: String, context: UserRequest?) async throws -> String {
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

    // MARK: - SMS

    func sendSMS(to phone: String, body: String) async throws {
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
        let city = dict["city"] as? String ?? ""
        let state = dict["state"] as? String ?? ""

        // Backend uses "lat"/"lng"
        let latitude = dict["lat"] as? Double ?? dict["latitude"] as? Double ?? 0.0
        let longitude = dict["lng"] as? Double ?? dict["longitude"] as? Double ?? 0.0

        // Backend uses "type" for source type
        let sourceType: FoodSourceType
        if let st = dict["type"] as? String {
            sourceType = FoodSourceType(rawValue: st) ?? .foodBank
        } else if let st = dict["sourceType"] as? String {
            sourceType = FoodSourceType(rawValue: st) ?? .foodBank
        } else {
            sourceType = .foodBank
        }

        // Backend uses "types_json" for food types (lowercase values)
        let foodTypes: [FoodType]
        if let types = dict["types_json"] as? [String] {
            foodTypes = types.compactMap { parseFoodType($0) }
        } else if let types = dict["foodTypes"] as? [String] {
            foodTypes = types.compactMap { parseFoodType($0) }
        } else {
            foodTypes = [.groceries]
        }

        // Backend uses "hours_json" array of {day, open, close} objects
        let hoursOfOperation: String
        if let hoursArray = dict["hours_json"] as? [[String: String]] {
            hoursOfOperation = formatHoursJSON(hoursArray)
        } else if let hours = dict["hoursOfOperation"] as? String {
            hoursOfOperation = hours
        } else {
            hoursOfOperation = ""
        }

        let duration: Duration
        if let d = dict["duration"] as? String {
            duration = Duration(rawValue: d.capitalized) ?? .permanent
        } else {
            duration = .permanent
        }

        let publicTransitAccessible = dict["publicTransitAccessible"] as? Bool
            ?? dict["is_accessible"] as? Bool ?? false

        let availability: Availability
        if let a = dict["availability"] as? String {
            availability = Availability(rawValue: a.capitalized) ?? .medium
        } else {
            availability = .medium
        }

        let hasExcessFood = dict["hasExcessFood"] as? Bool
            ?? dict["excess_food"] as? Bool ?? false
        let isVerified = dict["isVerified"] as? Bool ?? false
        let isOpen = dict["isOpen"] as? Bool ?? true
        let waitTimeEstimate = dict["waitTimeEstimate"] as? Int

        return FoodSource(
            id: id,
            name: name,
            phone: phone,
            address: address,
            city: city,
            state: state,
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

    /// Maps lowercase backend food type strings to FoodType enum.
    private static func parseFoodType(_ raw: String) -> FoodType? {
        switch raw.lowercased() {
        case "groceries": return .groceries
        case "cooked meals", "cookedmeals": return .cookedMeals
        case "fresh produce", "freshproduce": return .freshProduce
        default: return nil
        }
    }

    /// Formats the hours_json array into a readable string.
    /// Groups consecutive days with the same hours together.
    private static func formatHoursJSON(_ hours: [[String: String]]) -> String {
        // Group by day, collecting all time slots
        var daySlots: [(day: String, open: String, close: String)] = []
        for entry in hours {
            guard let day = entry["day"],
                  let open = entry["open"],
                  let close = entry["close"] else { continue }
            daySlots.append((day: day, open: open, close: close))
        }

        // Group unique day+times, merge slots per day
        var dayToSlots: [String: [String]] = [:]
        let dayOrder = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        for slot in daySlots {
            let timeStr = "\(slot.open)-\(slot.close)"
            dayToSlots[slot.day, default: []].append(timeStr)
        }

        // Build readable output per day
        var parts: [String] = []
        for day in dayOrder {
            if let slots = dayToSlots[day] {
                parts.append("\(day) \(slots.joined(separator: ", "))")
            }
        }
        return parts.joined(separator: " | ")
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
