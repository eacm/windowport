import SwiftUI

struct SessionView: View {
    @Environment(AppStore.self) private var store
    let session: RemoteSession
    @State private var keyboardText = ""
    @State private var cursorPosition: CGPoint?
    @State private var lastFingerPosition: CGPoint?
    @State private var totalMovement: CGFloat = 0
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
                            .position(clamped(cursorPosition ?? CGPoint(x: surface.width / 2, y: surface.height / 2), to: surface))
                            .allowsHitTesting(false)
                    }
                    .frame(width: surface.width, height: surface.height)
                    .contentShape(Rectangle())
                    .gesture(trackpadGesture(in: surface))
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

    private func trackpadGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard let previous = lastFingerPosition else {
                    lastFingerPosition = value.location
                    totalMovement = 0
                    if cursorPosition == nil {
                        cursorPosition = CGPoint(x: size.width / 2, y: size.height / 2)
                    }
                    return
                }

                let deltaX = value.location.x - previous.x
                let deltaY = value.location.y - previous.y
                totalMovement += hypot(deltaX, deltaY)
                lastFingerPosition = value.location

                let current = clamped(cursorPosition ?? CGPoint(x: size.width / 2, y: size.height / 2), to: size)
                let speed = pointerSpeed(for: hypot(deltaX, deltaY))
                let next = clamped(
                    CGPoint(x: current.x + deltaX * speed, y: current.y + deltaY * speed),
                    to: size
                )
                cursorPosition = next
                Task { await store.send(event(.move, at: next, in: size)) }
            }
            .onEnded { _ in
                let point = cursorPosition ?? CGPoint(x: size.width / 2, y: size.height / 2)
                let shouldClick = totalMovement < 10
                lastFingerPosition = nil
                totalMovement = 0
                if shouldClick {
                    Task {
                        await store.send(event(.down, at: point, in: size))
                        await store.send(event(.up, at: point, in: size))
                    }
                }
            }
    }

    private func event(_ kind: PointerEventKind, at point: CGPoint, in size: CGSize) -> PointerEvent {
        PointerEvent(kind: kind, x: point.x / size.width, y: point.y / size.height, deltaY: nil)
    }

    private func clamped(_ point: CGPoint, to size: CGSize) -> CGPoint {
        CGPoint(x: min(max(point.x, 0), size.width), y: min(max(point.y, 0), size.height))
    }

    private func pointerSpeed(for fingerDelta: CGFloat) -> CGFloat {
        switch fingerDelta {
        case ..<2: 0.9
        case ..<8: 1.35
        default: 1.8
        }
    }

    private func fittedSize(in container: CGSize) -> CGSize {
        let width = CGFloat(session.width ?? 16)
        let height = CGFloat(session.height ?? 9)
        let scale = min(container.width / width, container.height / height)
        return CGSize(width: width * scale, height: height * scale)
    }
}

