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
}

