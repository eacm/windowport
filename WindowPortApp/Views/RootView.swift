import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        TabView {
            AppCatalogView()
                .tabItem { Label("Apps", systemImage: "square.grid.2x2.fill") }
            HostsView()
                .tabItem { Label("Hosts", systemImage: "desktopcomputer") }
        }
        .tint(.mint)
        .fullScreenCover(item: $store.activeSession) { SessionView(session: $0) }
        .alert("WindowPort", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) { Button("OK") { store.errorMessage = nil } } message: {
            Text(store.errorMessage ?? "")
        }
    }
}

