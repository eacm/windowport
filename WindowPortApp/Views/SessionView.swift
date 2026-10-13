import SwiftUI

struct SessionView: View {
    @Environment(AppStore.self) private var store
    let session: RemoteSession
    @State private var showsKeyboardEntry = false
    @State private var cursorPosition: CGPoint?
    @State private var joystickOrigin: CGPoint?
    @State private var joystickVector = CGVector.zero
    @State private var gestureDistance: CGFloat = 0
    @State private var surfaceSize = CGSize.zero
    @State private var lastPointerSend = Date.distantPast
    @State private var streamRevision = 0
    @State private var joystickTask: Task<Void, Never>?
    @State private var resizeTask: Task<Void, Never>?
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
                    ZStack {
                        MJPEGStreamView(url: session.streamURL)
                            .id(streamRevision)
                            .allowsHitTesting(false)
                        Rectangle()
                            .fill(Color.white.opacity(0.001))
                            .contentShape(Rectangle())
                            .gesture(joystickGesture(in: geometry.size), including: .gesture)
                        Image(systemName: "cursorarrow")
                            .font(.system(size: 25, weight: .semibold))
                            .foregroundStyle(.white)
                            .shadow(color: .black, radius: 2, x: 1, y: 1)
                            .position(clamped(cursorPosition ?? CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2), to: geometry.size))
                            .allowsHitTesting(false)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .onAppear { updateSurface(geometry.size) }
                    .onChange(of: geometry.size) { _, size in updateSurface(size) }
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
                if showsKeyboardEntry {
                    HStack(spacing: 12) {
                        Button("Esc") { sendKey("escape") }
                        Button("Tab") { sendKey("tab") }
                        Button { sendKey("left") } label: { Image(systemName: "arrow.left") }
                        Button { sendKey("right") } label: { Image(systemName: "arrow.right") }
                        Button("Done") {
                            keyboardFocused = false
                            showsKeyboardEntry = false
                        }
                    }
                    .padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                } else {
                    HStack(spacing: 20) {
                        Button {
                            showsKeyboardEntry = true
                            Task { await Task.yield(); keyboardFocused = true }
                        } label: { Label("Keyboard", systemImage: "keyboard") }
                        Button { Task { await store.send(PointerEvent(kind: .scroll, x: 0.5, y: 0.5, deltaY: -160)) } } label: { Label("Scroll", systemImage: "arrow.up.and.down") }
                    }
                    .buttonStyle(.borderedProminent).tint(.mint).foregroundStyle(.black)
                }
                Spacer().frame(height: 8)
            }
            RemoteKeyboardView(
                isFocused: Binding(get: { keyboardFocused }, set: { keyboardFocused = $0 }),
                onText: { text in Task { await store.send(text: text) } },
                onKey: { key in Task { await store.send(key: key) } }
            )
            .frame(width: 1, height: 1)
            .opacity(0.01)
        }
        .statusBarHidden()
        .onDisappear {
            joystickTask?.cancel()
            resizeTask?.cancel()
        }
    }

    private func sendKey(_ key: String) {
        Task { await store.send(key: RemoteKeyEvent(key: key)) }
    }

    private func joystickGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard let origin = joystickOrigin else {
                    joystickOrigin = value.location
                    gestureDistance = 0
                    if cursorPosition == nil {
                        cursorPosition = CGPoint(x: size.width / 2, y: size.height / 2)
                    }
                    return
                }
                let dx = value.location.x - origin.x
                let dy = value.location.y - origin.y
                let distance = hypot(dx, dy)
                gestureDistance = max(gestureDistance, distance)
                let radius: CGFloat = 70
                let scale = distance > radius ? radius / distance : 1
                joystickVector = CGVector(dx: dx * scale / radius, dy: dy * scale / radius)
                startJoystick()
            }
            .onEnded { _ in
                let point = cursorPosition ?? CGPoint(x: size.width / 2, y: size.height / 2)
                let shouldClick = gestureDistance < 8
                joystickOrigin = nil
                joystickVector = .zero
                joystickTask?.cancel()
                joystickTask = nil
                gestureDistance = 0
                if shouldClick {
                    Task {
                        await store.send(event(.down, at: point, in: size))
                        await store.send(event(.up, at: point, in: size))
                    }
                }
            }
    }

    private func startJoystick() {
        guard joystickTask == nil else { return }
        joystickTask = Task { @MainActor in
            while !Task.isCancelled {
                advancePointer()
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    private func advancePointer() {
        guard surfaceSize.width > 0, surfaceSize.height > 0,
              abs(joystickVector.dx) > 0.01 || abs(joystickVector.dy) > 0.01 else { return }
        let current = clamped(cursorPosition ?? CGPoint(x: surfaceSize.width / 2, y: surfaceSize.height / 2), to: surfaceSize)
        let maximumSpeed: CGFloat = 24
        let next = clamped(CGPoint(
            x: current.x + joystickVector.dx * maximumSpeed,
            y: current.y + joystickVector.dy * maximumSpeed
        ), to: surfaceSize)
        cursorPosition = next

        let now = Date()
        if now.timeIntervalSince(lastPointerSend) >= 1.0 / 30.0 {
            lastPointerSend = now
            Task { await store.send(event(.move, at: next, in: surfaceSize)) }
        }
    }

    private func event(_ kind: PointerEventKind, at point: CGPoint, in size: CGSize) -> PointerEvent {
        PointerEvent(kind: kind, x: point.x / size.width, y: point.y / size.height, deltaY: nil)
    }

    private func clamped(_ point: CGPoint, to size: CGSize) -> CGPoint {
        CGPoint(x: min(max(point.x, 0), size.width), y: min(max(point.y, 0), size.height))
    }

    private func updateSurface(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        surfaceSize = size
        cursorPosition = clamped(cursorPosition ?? CGPoint(x: size.width / 2, y: size.height / 2), to: size)
        resizeTask?.cancel()
        resizeTask = Task { @MainActor in
            await store.resizeSession(to: size)
            guard !Task.isCancelled else { return }
            // An MJPEG decoder keeps the dimensions of its first frame. Recreate it
            // after Windows has resized the source window for the new orientation.
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            streamRevision += 1
        }
    }
}

