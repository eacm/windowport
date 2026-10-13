import SwiftUI

struct SessionView: View {
    @Environment(AppStore.self) private var store
    let session: RemoteSession
    @State private var showsKeyboardEntry = false
    @State private var surfaceSize = CGSize.zero
    @State private var streamRevision = 0
    @State private var resizeTask: Task<Void, Never>?
    @State private var bannerOffset = CGSize.zero
    @State private var bannerDragOrigin = CGSize.zero
    @State private var bannerCollapsed = false
    @State private var bannerCollapseTask: Task<Void, Never>?
    @State private var keyboardFocused = false

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
                        RemoteTouchSurface(
                            onClick: { point, size in sendTouch(.click, at: point, in: size) },
                            onRightClick: { point, size in sendTouch(.rightClick, at: point, in: size) },
                            onScroll: { delta in
                                Task { await store.send(PointerEvent(kind: .scroll, x: 0.5, y: 0.5, deltaY: delta)) }
                            }
                        )
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
                            showKeyboard()
                        } label: { Label("Keyboard", systemImage: "keyboard") }
                        Button { Task { await store.send(PointerEvent(kind: .scroll, x: 0.5, y: 0.5, deltaY: -160)) } } label: { Label("Scroll", systemImage: "arrow.up.and.down") }
                    }
                    .buttonStyle(.borderedProminent).tint(.mint).foregroundStyle(.black)
                }
                Spacer().frame(height: 8)
            }
            RemoteKeyboardView(
                isFocused: $keyboardFocused,
                onText: { text in Task { await store.send(text: text) } },
                onKey: { key in Task { await store.send(key: key) } },
                onDismiss: {
                    keyboardFocused = false
                    showsKeyboardEntry = false
                }
            )
            .frame(width: 1, height: 1)
            .opacity(0.01)
        }
        .statusBarHidden()
        .ignoresSafeArea(.keyboard)
        .onDisappear {
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

    private func showKeyboard() {
        showsKeyboardEntry = true
        Task { @MainActor in
            await Task.yield()
            keyboardFocused = true
        }
    }

    private func sendTouch(_ kind: PointerEventKind, at point: CGPoint, in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let event = PointerEvent(
            kind: kind,
            x: min(max(point.x / size.width, 0), 1),
            y: min(max(point.y / size.height, 0), 1),
            deltaY: nil
        )
        Task { await store.send(event) }
    }

    private func updateSurface(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        surfaceSize = size
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

