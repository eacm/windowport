import SwiftUI

struct HostsView: View {
    @Environment(AppStore.self) private var store
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            List {
                Section("Computers") {
                    ForEach(store.hosts) { host in
                        HStack(spacing: 14) {
                            Image(systemName: host.isDemo ? "sparkles.rectangle.stack" : "desktopcomputer")
                                .font(.title2).foregroundStyle(.mint)
                            VStack(alignment: .leading) {
                                Text(host.name).font(.headline)
                                Text(host.isDemo ? "Built-in preview" : host.baseURL.absoluteString)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if host == store.selectedHost { Image(systemName: "checkmark.circle.fill").foregroundStyle(.mint) }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { store.selectedHost = host }
                    }
                    .onDelete { store.removeHosts(at: $0) }
                }
                Section("Private network first") {
                    Label("Use a trusted Wi-Fi network or Tailscale. Do not expose port 47821 to the internet.", systemImage: "lock.shield")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Hosts")
            .toolbar { Button { showingAdd = true } label: { Label("Add Host", systemImage: "plus") } }
            .sheet(isPresented: $showingAdd) { AddHostView() }
        }
    }
}

private struct AddHostView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var address = ""
    @State private var testing = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Windows computer") {
                    TextField("Name (optional)", text: $name)
                    TextField("http://192.168.1.25:47821", text: $address)
                        .textInputAutocapitalization(.never).keyboardType(.URL)
                }
                Section { Text("Start the Port host on your PC, then enter its private IP address.").font(.footnote).foregroundStyle(.secondary) }
            }
            .navigationTitle("Add Host")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(testing ? "Testing…" : "Add") {
                        testing = true
                        Task {
                            if await store.addHost(name: name, address: address) { dismiss() }
                            testing = false
                        }
                    }.disabled(address.isEmpty || testing)
                }
            }
        }
    }
}

