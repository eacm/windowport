import SwiftUI
import UIKit

struct RemoteTouchSurface: UIViewRepresentable {
    let onClick: (CGPoint, CGSize) -> Void
    let onRightClick: (CGPoint, CGSize) -> Void
    let onScroll: (Double) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onClick: onClick, onRightClick: onRightClick, onScroll: onScroll)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tap(_:)))
        let longPress = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.longPress(_:)))
        longPress.minimumPressDuration = 0.55
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.pan(_:)))
        pan.maximumNumberOfTouches = 1

        tap.require(toFail: longPress)
        tap.require(toFail: pan)
        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(longPress)
        view.addGestureRecognizer(pan)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.onClick = onClick
        context.coordinator.onRightClick = onRightClick
        context.coordinator.onScroll = onScroll
    }

    final class Coordinator: NSObject {
        var onClick: (CGPoint, CGSize) -> Void
        var onRightClick: (CGPoint, CGSize) -> Void
        var onScroll: (Double) -> Void

        init(
            onClick: @escaping (CGPoint, CGSize) -> Void,
            onRightClick: @escaping (CGPoint, CGSize) -> Void,
            onScroll: @escaping (Double) -> Void
        ) {
            self.onClick = onClick
            self.onRightClick = onRightClick
            self.onScroll = onScroll
        }

        @objc func tap(_ recognizer: UITapGestureRecognizer) {
            guard let view = recognizer.view else { return }
            onClick(recognizer.location(in: view), view.bounds.size)
        }

        @objc func longPress(_ recognizer: UILongPressGestureRecognizer) {
            guard recognizer.state == .began, let view = recognizer.view else { return }
            onRightClick(recognizer.location(in: view), view.bounds.size)
        }

        @objc func pan(_ recognizer: UIPanGestureRecognizer) {
            guard recognizer.state == .ended, let view = recognizer.view else { return }
            let translation = recognizer.translation(in: view)
            guard abs(translation.y) > abs(translation.x), abs(translation.y) > 12 else { return }
            onScroll(Double(translation.y * 4))
        }
    }
}
