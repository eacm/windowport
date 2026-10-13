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
    @State private var bannerOffset = CGSize.zero
    @State private var bannerDragOrigin = CGSize.zero
    @State private var bannerCollapsed = false
    @State private var bannerCollapseTask: Task<Void, Never>?
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
                        PointerCursor()
                            .frame(width: 24, height: 32)
                            .position(pointerDisplayPosition(in: geometry.size))
                            .allowsHitTesting(false)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .onAppear { updateSurface(geometry.size) }
                    .onChange(of: geometry.size) { _, size in updateSurface(size) }
                }
                .ignoresSafeArea()
            }
            VStack {
                movableBanner
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
            bannerCollapseTask?.cancel()
        }
        .onAppear { scheduleBannerCollapse() }
    }

    @ViewBuilder
    private var movableBanner: some View {
        if bannerCollapsed {
            HStack {
                Spacer()
                closeButton
                    .padding(8)
                    .background(.ultraThinMaterial, in: Circle())
                    .padding()
                    .offset(bannerOffset)
                    .simultaneousGesture(bannerDragGesture)
                    .transition(.scale.combined(with: .opacity))
            }
        } else {
            HStack {
                Label(session.application.name, systemImage: "lock.fill")
                    .font(.subheadline.bold())
                Spacer()
                closeButton
            }
            .padding(12)
            .background(.ultraThinMaterial, in: Capsule())
            .padding()
            .offset(bannerOffset)
            .simultaneousGesture(bannerDragGesture)
            .onTapGesture {
                withAnimation(.snappy) { bannerCollapsed = true }
                bannerCollapseTask?.cancel()
            }
            .transition(.scale.combined(with: .opacity))
        }
    }

    private var closeButton: some View {
        Image(systemName: "xmark.circle.fill")
            .font(.system(size: 34, weight: .semibold))
            .foregroundStyle(.blue)
            .contentShape(Circle())
            .onTapGesture { store.activeSession = nil }
            .accessibilityLabel("Close session")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { store.activeSession = nil }
    }

    private var bannerDragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                bannerCollapseTask?.cancel()
                if bannerCollapsed {
                    withAnimation(.snappy) { bannerCollapsed = false }
                }
                bannerOffset = CGSize(
                    width: bannerDragOrigin.width + value.translation.width,
                    height: bannerDragOrigin.height + value.translation.height
                )
            }
            .onEnded { _ in
                bannerDragOrigin = bannerOffset
                scheduleBannerCollapse()
            }
    }

    private func scheduleBannerCollapse() {
        bannerCollapseTask?.cancel()
        bannerCollapseTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            withAnimation(.snappy) { bannerCollapsed = true }
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
        let magnitude = min(hypot(joystickVector.dx, joystickVector.dy), 1)
        let deadZone: CGFloat = 0.08
        guard magnitude > deadZone else { return }
        let normalizedMagnitude = (magnitude - deadZone) / (1 - deadZone)
        let easedMagnitude = pow(normalizedMagnitude, 1.6)
        let speed: CGFloat = 1.2 + 7.8 * easedMagnitude
        let directionX = joystickVector.dx / magnitude
        let directionY = joystickVector.dy / magnitude
        let next = clamped(CGPoint(
            x: current.x + directionX * speed,
            y: current.y + directionY * speed
        ), to: surfaceSize)
        cursorPosition = next

        let now = Date()
        if now.timeIntervalSince(lastPointerSend) >= 1.0 / 30.0 {
            lastPointerSend = now
            Task { await store.send(event(.move, at: next, in: surfaceSize)) }
        }
    }

    private func event(_ kind: PointerEventKind, at point: CGPoint, in size: CGSize) -> PointerEvent {
        let bounded = clamped(point, to: size)
        return PointerEvent(kind: kind, x: bounded.x / size.width, y: bounded.y / size.height, deltaY: nil)
    }

    private func clamped(_ point: CGPoint, to size: CGSize) -> CGPoint {
        CGPoint(x: min(max(point.x, 0), size.width), y: min(max(point.y, 0), size.height))
    }

    private func pointerDisplayPosition(in size: CGSize) -> CGPoint {
        let clickPoint = clamped(cursorPosition ?? CGPoint(x: size.width / 2, y: size.height / 2), to: size)
        // PointerCursor's hotspot is its top-left tip; position() addresses the
        // center of the view, so offset by half its dimensions.
        return CGPoint(x: clickPoint.x + 12, y: clickPoint.y + 16)
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

private struct PointerCursor: View {
    var body: some View {
        Canvas { context, _ in
            var pointer = Path()
            pointer.move(to: .zero)
            pointer.addLine(to: CGPoint(x: 3, y: 25))
            pointer.addLine(to: CGPoint(x: 9, y: 18))
            pointer.addLine(to: CGPoint(x: 15, y: 31))
            pointer.addLine(to: CGPoint(x: 20, y: 28))
            pointer.addLine(to: CGPoint(x: 14, y: 16))
            pointer.addLine(to: CGPoint(x: 24, y: 15))
            pointer.closeSubpath()
            context.fill(pointer, with: .color(.white))
            context.stroke(pointer, with: .color(.black), lineWidth: 2)
        }
        .shadow(color: .black.opacity(0.5), radius: 2, x: 1, y: 1)
    }
}

