import Foundation

struct GitHubDispatchPayload: Encodable {
    let eventType: String
    let clientPayload: ClientPayload

    enum CodingKeys: String, CodingKey {
        case eventType = "event_type"
        case clientPayload = "client_payload"
    }
}

struct ClientPayload: Encodable {
    let code: String
}
