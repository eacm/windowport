import SwiftUI

struct AppCatalogView: View {
    @Environment(AppStore.self) private var store
    @State private var search = ""

    private var filtered: [RemoteApplication] {
        let apps = search.isEmpty ? store.applications : store.applications.filter { $0.name.localizedCaseInsensitiveContains(search) }
        return apps.sorted {
            let left = store.favoriteIDs.contains($0.id), right = store.favoriteIDs.contains($1.id)
            return left == right ? $0.name < $1.name : left && !right
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.isLoading && store.applications.isEmpty { ProgressView("Loading apps…") }
                else if filtered.isEmpty { ContentUnavailableView("No published apps", systemImage: "app.dashed", description: Text("Publish apps on the Windows host, or try the demo host.")) }
                else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 16)], spacing: 16) {
                            ForEach(filtered) { app in AppTile(app: app) }
                        }.padding()
                    }
                }
            }
            .navigationTitle("WindowPort")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Host", selection: Bindable(store).selectedHost) {
                            ForEach(store.hosts) { Text($0.name).tag($0) }
                        }
                    } label: { Label(store.selectedHost.name, systemImage: "desktopcomputer") }
                }
            }
            .searchable(text: $search, prompt: "Find an app")
            .task(id: store.selectedHost) { await store.loadApps() }
            .refreshable { await store.loadApps() }
        }
    }
}

private struct AppTile: View {
    @Environment(AppStore.self) private var store
    let app: RemoteApplication

    var body: some View {
        Button { Task { await store.launch(app) } } label: {
            VStack(alignment: .leading, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 17).fill(Color.mint.gradient)
                    Image(systemName: symbol).font(.system(size: 34, weight: .semibold)).foregroundStyle(.black)
                }.frame(width: 62, height: 62)
                VStack(alignment: .leading, spacing: 3) {
                    Text(app.name).font(.headline).lineLimit(1)
                    Text(app.category ?? "Windows app").font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { store.toggleFavorite(app) } label: {
                Label(store.favoriteIDs.contains(app.id) ? "Unfavorite" : "Favorite", systemImage: "star")
            }
        }
    }

    private var symbol: String {
        switch app.category?.lowercased() {
        case "browser": "globe"
        case "games": "gamecontroller.fill"
        case "communication": "bubble.left.and.bubble.right.fill"
        default: "macwindow"
        }
    }
}

