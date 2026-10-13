import SwiftUI

struct SessionView: View {
    @Environment(AppStore.self) private var store
    let session: RemoteSession
    @State private var keyboardText = ""
    @FocusState private var keyboardFocused: Bool

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if session.streamURL.scheme == "demo" {
                VStack(spacing: 22) {
                    Image(systemName: "macwindow.on.rectangle").font(.system(size: 64)).foregroundStyle(.mint)
                    Text(session.application.name).font(.largeTitle.bold())
                    Text("Demo session\nConnect a Windows host for live video and input.")
                        .multilineTextAlignment(.center).foregroundStyle(.secondary)
                }
            } else { MJPEGStreamView(url: session.streamURL).ignoresSafeArea() }
            Rectangle().fill(.clear).contentShape(Rectangle()).gesture(pointerGesture)
            VStack {
                HStack {
                    Label(session.application.name, systemImage: "lock.fill").font(.subheadline.bold())
                    Spacer()
                    Button { store.activeSession = nil } label: { Image(systemName: "xmark.circle.fill").font(.title2) }
                }
                .padding(12).background(.ultraThinMaterial, in: Capsule()).padding()
                Spacer()
                HStack(spacing: 20) {
                    Button { keyboardFocused = true } label: { Label("Keyboard", systemImage: "keyboard") }
                    Button { Task { await store.send(PointerEvent(kind: .scroll, x: 0.5, y: 0.5, deltaY: -160)) } } label: { Label("Scroll", systemImage: "arrow.up.and.down") }
                }
                .buttonStyle(.borderedProminent).tint(.mint).foregroundStyle(.black).padding(.bottom)
            }
            TextField("", text: $keyboardText)
                .focused($keyboardFocused).frame(width: 1, height: 1).opacity(0.01)
                .onChange(of: keyboardText) { _, value in
                    guard !value.isEmpty else { return }
                    Task { await store.send(text: value); keyboardText = "" }
                }
        }
        .statusBarHidden()
    }

    private var pointerGesture: some Gesture {
        DragGesture(minimumDistance: 0).onEnded { value in
            let size = UIScreen.main.bounds.size
            let event = PointerEvent(kind: .down, x: value.location.x / size.width, y: value.location.y / size.height, deltaY: nil)
            Task {
                await store.send(event)
                await store.send(PointerEvent(kind: .up, x: event.x, y: event.y, deltaY: nil))
            }
        }
    }
}

