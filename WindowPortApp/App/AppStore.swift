import Foundation
import Observation

@MainActor
@Observable
final class AppStore {
    var hosts: [WindowsHost]
    var selectedHost: WindowsHost
    var applications: [RemoteApplication] = []
    var favoriteIDs: Set<String>
    var activeSession: RemoteSession?
    var isLoading = false
    var errorMessage: String?

    private let client: any WindowPortServing
    private let defaults: UserDefaults

    init(client: any WindowPortServing = WindowPortClient(), defaults: UserDefaults = .standard) {
        self.client = client
        self.defaults = defaults
        let savedHosts = defaults.data(forKey: "hosts").flatMap { try? JSONDecoder().decode([WindowsHost].self, from: $0) } ?? []
        let bundledHosts: [WindowsHost] = [.workstation, .demo]
        let bundledIDs = Set(bundledHosts.map(\.id))
        let allHosts = bundledHosts + savedHosts.filter { !bundledIDs.contains($0.id) }
        hosts = allHosts
        selectedHost = .workstation
        favoriteIDs = Set(defaults.stringArray(forKey: "favorites") ?? [])
    }

    func loadApps() async {
        isLoading = true
        defer { isLoading = false }
        do {
            applications = try await client.applications(on: selectedHost)
            errorMessage = nil
        } catch {
            applications = []
            errorMessage = "Couldn’t reach \(selectedHost.name). Check the address and make sure the host is running."
        }
    }

    func addHost(name: String, address: String) async -> Bool {
        let normalized = address.contains("://") ? address : "http://\(address)"
        guard let url = URL(string: normalized), url.host != nil else {
            errorMessage = "Enter a valid address, such as http://192.168.1.25:47821."
            return false
        }
        let host = WindowsHost(id: UUID(), name: name.isEmpty ? (url.host ?? "Windows PC") : name, baseURL: url)
        do {
            try await client.health(on: host)
            hosts.append(host)
            selectedHost = host
            saveHosts()
            await loadApps()
            return true
        } catch {
            errorMessage = "No WindowPort host responded at that address."
            return false
        }
    }

    func removeHosts(at offsets: IndexSet) {
        let removable = hosts.indices.filter { !hosts[$0].isDemo }
        for offset in offsets.sorted(by: >) where offset < removable.count { hosts.remove(at: removable[offset]) }
        if !hosts.contains(selectedHost) { selectedHost = .demo }
        saveHosts()
    }

    func toggleFavorite(_ app: RemoteApplication) {
        if favoriteIDs.contains(app.id) { favoriteIDs.remove(app.id) } else { favoriteIDs.insert(app.id) }
        defaults.set(Array(favoriteIDs), forKey: "favorites")
    }

    func launch(_ app: RemoteApplication) async {
        isLoading = true
        defer { isLoading = false }
        do { activeSession = try await client.launch(app, on: selectedHost) }
        catch { errorMessage = "\(app.name) couldn’t be launched." }
    }

    func send(_ event: PointerEvent) async {
        guard let activeSession else { return }
        try? await client.send(pointer: event, sessionID: activeSession.id, to: selectedHost)
    }

    func send(text: String) async {
        guard let activeSession else { return }
        try? await client.send(text: text, sessionID: activeSession.id, to: selectedHost)
    }

    func resizeSession(to size: CGSize) async {
        guard let activeSession else { return }
        try? await client.resize(sessionID: activeSession.id, width: Int(size.width), height: Int(size.height), on: selectedHost)
    }

    private func saveHosts() {
        defaults.set(try? JSONEncoder().encode(hosts.filter { !$0.isDemo }), forKey: "hosts")
    }
}

