import Foundation

protocol WindowPortServing: Sendable {
    func health(on host: WindowsHost) async throws
    func applications(on host: WindowsHost) async throws -> [RemoteApplication]
    func launch(_ app: RemoteApplication, on host: WindowsHost) async throws -> RemoteSession
    func send(pointer: PointerEvent, sessionID: UUID, to host: WindowsHost) async throws
    func send(text: String, sessionID: UUID, to host: WindowsHost) async throws
}

struct WindowPortClient: WindowPortServing {
    private let session: URLSession

    init(session: URLSession = .shared) { self.session = session }

    func health(on host: WindowsHost) async throws {
        if host.isDemo { return }
        _ = try await data(path: "/api/health", host: host)
    }

    func applications(on host: WindowsHost) async throws -> [RemoteApplication] {
        if host.isDemo { return Self.demoApps }
        let result = try await data(path: "/api/apps", host: host)
        return try JSONDecoder.windowPort.decode([RemoteApplication].self, from: result)
    }

    func launch(_ app: RemoteApplication, on host: WindowsHost) async throws -> RemoteSession {
        if host.isDemo {
            return RemoteSession(id: UUID(), application: app, streamURL: URL(string: "demo://session")!)
        }
        var request = request(path: "/api/apps/\(app.id)/launch", host: host)
        request.httpMethod = "POST"
        let (data, response) = try await session.data(for: request)
        try validate(response)
        return try JSONDecoder.windowPort.decode(RemoteSession.self, from: data)
    }

    func send(pointer: PointerEvent, sessionID: UUID, to host: WindowsHost) async throws {
        guard !host.isDemo else { return }
        try await post(pointer, path: "/api/sessions/\(sessionID)/pointer", host: host)
    }

    func send(text: String, sessionID: UUID, to host: WindowsHost) async throws {
        guard !host.isDemo else { return }
        try await post(["text": text], path: "/api/sessions/\(sessionID)/text", host: host)
    }

    private func data(path: String, host: WindowsHost) async throws -> Data {
        let (data, response) = try await session.data(for: request(path: path, host: host))
        try validate(response)
        return data
    }

    private func post<T: Encodable>(_ body: T, path: String, host: WindowsHost) async throws {
        var request = request(path: path, host: host)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.windowPort.encode(body)
        let (_, response) = try await session.data(for: request)
        try validate(response)
    }

    private func request(path: String, host: WindowsHost) -> URLRequest {
        let url = URL(string: path, relativeTo: host.baseURL)!.absoluteURL
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    static let demoApps = [
        RemoteApplication(id: "brave", name: "Brave", executable: #"C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe"#, arguments: nil, category: "Browser", iconURL: nil),
        RemoteApplication(id: "steam", name: "Steam", executable: #"C:\Program Files (x86)\Steam\Steam.exe"#, arguments: nil, category: "Games", iconURL: nil),
        RemoteApplication(id: "discord", name: "Discord", executable: #"C:\Users\User\AppData\Local\Discord\Discord.exe"#, arguments: nil, category: "Communication", iconURL: nil),
        RemoteApplication(id: "notepad", name: "Notepad", executable: "notepad.exe", arguments: nil, category: "Tools", iconURL: nil)
    ]
}

private extension JSONDecoder {
    static var windowPort: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}

private extension JSONEncoder {
    static var windowPort: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }
}

