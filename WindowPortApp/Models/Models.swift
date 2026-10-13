import Foundation

struct WindowsHost: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var baseURL: URL
    var isDemo: Bool = false

    static let demo = WindowsHost(
        id: UUID(uuidString: "F5E79AE2-4C17-47D6-9AE6-8869F65FF1B1")!,
        name: "Gaming PC (Demo)",
        baseURL: URL(string: "demo://windowport")!,
        isDemo: true
    )

    static let workstation = WindowsHost(
        id: UUID(uuidString: "A119C872-52B4-4C2E-9232-58F8C2F2B2A2")!,
        name: "Workstation",
        baseURL: URL(string: "http://192.168.0.156:47821")!
    )
}

struct RemoteApplication: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let executable: String
    let arguments: String?
    let category: String?
    let iconURL: URL?

    enum CodingKeys: String, CodingKey {
        case id, name, executable, arguments, category
        case iconURL = "iconUrl"
    }
}

struct RemoteSession: Identifiable, Codable, Hashable {
    let id: UUID
    let application: RemoteApplication
    let streamURL: URL
    let width: Int?
    let height: Int?

    enum CodingKeys: String, CodingKey {
        case id, application, width, height
        case streamURL = "streamUrl"
    }
}

enum PointerEventKind: String, Codable { case move, down, up, click, scroll }

struct PointerEvent: Codable {
    let kind: PointerEventKind
    let x: Double
    let y: Double
    let deltaY: Double?
}

struct RemoteKeyEvent: Codable {
    let key: String
    var control = false
    var alt = false
    var shift = false
    var command = false
}

