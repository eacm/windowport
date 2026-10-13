import XCTest
@testable import WindowPort

final class WindowPortTests: XCTestCase {
    func testDemoHostIsStable() {
        XCTAssertTrue(WindowsHost.demo.isDemo)
        XCTAssertEqual(WindowsHost.demo.baseURL.scheme, "demo")
    }

    func testDemoCatalogHasUniqueIdentifiers() {
        let ids = WindowPortClient.demoApps.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testHostSessionResponseDecodesCamelCaseURL() throws {
        let json = #"{"id":"33fb9d30-68c1-47d6-bb16-54ac0f869631","application":{"id":"brave","name":"Brave","executable":"brave.exe","arguments":null,"category":"Browser","iconUrl":null},"streamUrl":"http://192.168.0.156:47821/api/sessions/33fb9d30-68c1-47d6-bb16-54ac0f869631/stream"}"#.data(using: .utf8)!
        let session = try JSONDecoder().decode(RemoteSession.self, from: json)
        XCTAssertEqual(session.application.name, "Brave")
        XCTAssertEqual(session.streamURL.host, "192.168.0.156")
    }
}

