import SwiftUI

struct SessionView: View {
    @Environment(AppStore.self) private var store
    let session: RemoteSession
    @State private var keyboardText = ""
    @State private var cursorPosition: CGPoint?
    @State private var pointerIsDown = false
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
            } else {
                GeometryReader { geometry in
                    let surface = fittedSize(in: geometry.size)
                    ZStack {
                        MJPEGStreamView(url: session.streamURL)
                        Image(systemName: "cursorarrow")
                            .font(.system(size: 25, weight: .semibold))
                            .foregroundStyle(.white)
                            .shadow(color: .black, radius: 2, x: 1, y: 1)
                            .position(cursorPosition ?? CGPoint(x: surface.width / 2, y: surface.height / 2))
                            .allowsHitTesting(false)
                    }
                    .frame(width: surface.width, height: surface.height)
                    .contentShape(Rectangle())
                    .gesture(pointerGesture(in: surface))
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
                .ignoresSafeArea()
            }
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

    private func pointerGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let point = clamped(value.location, to: size)
                cursorPosition = point
                let kind: PointerEventKind = pointerIsDown ? .move : .down
                pointerIsDown = true
                Task { await store.send(event(kind, at: point, in: size)) }
            }
            .onEnded { value in
                let point = clamped(value.location, to: size)
                cursorPosition = point
                pointerIsDown = false
                Task { await store.send(event(.up, at: point, in: size)) }
            }
    }

    private func event(_ kind: PointerEventKind, at point: CGPoint, in size: CGSize) -> PointerEvent {
        PointerEvent(kind: kind, x: point.x / size.width, y: point.y / size.height, deltaY: nil)
    }

    private func clamped(_ point: CGPoint, to size: CGSize) -> CGPoint {
        CGPoint(x: min(max(point.x, 0), size.width), y: min(max(point.y, 0), size.height))
    }

    private func fittedSize(in container: CGSize) -> CGSize {
        let width = CGFloat(session.width ?? 16)
        let height = CGFloat(session.height ?? 9)
        let scale = min(container.width / width, container.height / height)
        return CGSize(width: width * scale, height: height * scale)
    }
}

