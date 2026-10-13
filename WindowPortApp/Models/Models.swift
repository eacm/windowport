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
}

struct RemoteApplication: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let executable: String
    let arguments: String?
    let category: String?
    let iconURL: URL?
}

struct RemoteSession: Identifiable, Codable, Hashable {
    let id: UUID
    let application: RemoteApplication
    let streamURL: URL
}

enum PointerEventKind: String, Codable { case move, down, up, scroll }

struct PointerEvent: Codable {
    let kind: PointerEventKind
    let x: Double
    let y: Double
    let deltaY: Double?
}

