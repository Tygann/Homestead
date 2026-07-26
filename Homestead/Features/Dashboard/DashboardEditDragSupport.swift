import SwiftUI
import UIKit

enum DashboardGridCoordinateSpace {
    static let name = "dashboard-grid"
}

enum DashboardChipCoordinateSpace {
    static let name = "dashboard-chip-row"
}

enum DashboardDragPhase {
    case idle
    case dragging
    case dropping
}

enum DashboardDragTiming {
    static let liftDelay: TimeInterval = 0.45
    static let allowableMovement: CGFloat = 8
    static let cleanupDelay: Duration = .milliseconds(280)
    static let reducedMotionCleanupDelay: Duration = .milliseconds(80)
}

struct DashboardEditDragState {
    var itemFrames: [UUID: CGRect] = [:]
    var draggingItemID: UUID?
    var activeTranslation = CGSize.zero
    var previewItemIDs: [UUID]?
    var dragStartItemIDs: [UUID] = []
    var dragStartFrame: CGRect?
    var phase: DashboardDragPhase = .idle

    mutating func beginDragging(
        itemID: UUID,
        itemIDs: [UUID],
        frame: CGRect?
    ) {
        draggingItemID = itemID
        dragStartItemIDs = itemIDs
        previewItemIDs = itemIDs
        dragStartFrame = frame
        phase = .dragging
    }

    mutating func reset() {
        draggingItemID = nil
        activeTranslation = .zero
        previewItemIDs = nil
        dragStartItemIDs = []
        dragStartFrame = nil
        phase = .idle
    }
}

private enum DashboardDragAutoScroll {
    static let edgeLength: CGFloat = 88
    static let maximumPointsPerSecond: CGFloat = 380
}

struct DashboardGridItemFramePreferenceKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}

struct DashboardChipItemFramePreferenceKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}

extension View {
    func dashboardGridItemFrame(id: UUID) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: DashboardGridItemFramePreferenceKey.self,
                    value: [id: proxy.frame(in: .named(DashboardGridCoordinateSpace.name))]
                )
            }
        }
    }

    func dashboardChipItemFrame(id: UUID) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: DashboardChipItemFramePreferenceKey.self,
                    value: [id: proxy.frame(in: .named(DashboardChipCoordinateSpace.name))]
                )
            }
        }
    }

    func dashboardHighlightBorder(isHighlighted: Bool) -> some View {
        overlay {
            if isHighlighted {
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.72), lineWidth: 3)
                    .padding(1)
                    .allowsHitTesting(false)
            }
        }
    }

    func dashboardEditAffordance<MenuContent: View>(
        isVisible: Bool,
        accessibilityLabel: String,
        @ViewBuilder menuContent: @escaping () -> MenuContent
    ) -> some View {
        overlay(alignment: .topTrailing) {
            DashboardGridEditAffordance(
                isVisible: isVisible,
                accessibilityLabel: accessibilityLabel,
                menuContent: menuContent
            )
        }
    }

    func dashboardChipEditAffordance<MenuContent: View>(
        isVisible: Bool,
        accessibilityLabel: String,
        @ViewBuilder menuContent: @escaping () -> MenuContent
    ) -> some View {
        overlay(alignment: .topTrailing) {
            DashboardChipEditAffordance(
                isVisible: isVisible,
                accessibilityLabel: accessibilityLabel,
                menuContent: menuContent
            )
        }
    }

    func dashboardLongPressDragSurface(
        isEnabled: Bool,
        autoScrollAxes: Axis.Set = [],
        onChanged: @escaping (CGSize) -> Void,
        onEnded: @escaping (CGSize) -> Void,
        onCancelled: @escaping () -> Void
    ) -> some View {
        overlay {
            if isEnabled {
                DashboardLongPressDragSurface(
                    minimumDuration: DashboardDragTiming.liftDelay,
                    maximumMovement: DashboardDragTiming.allowableMovement,
                    autoScrollAxes: autoScrollAxes,
                    onChanged: onChanged,
                    onEnded: onEnded,
                    onCancelled: onCancelled
                )
            }
        }
    }

    func dashboardHorizontalPagingLocked(_ isLocked: Bool) -> some View {
        background {
            DashboardHorizontalPagingLock(isLocked: isLocked)
        }
    }
}

private struct DashboardHorizontalPagingLock: UIViewRepresentable {
    let isLocked: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.apply(isLocked: isLocked, from: uiView)
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.unlock()
    }

    final class Coordinator {
        private weak var scrollView: UIScrollView?
        private var requestedIsLocked = false
        private var isResolutionScheduled = false

        func apply(isLocked: Bool, from view: UIView) {
            requestedIsLocked = isLocked

            guard isLocked else {
                unlockScrollView()
                return
            }
            guard !isResolutionScheduled else { return }

            isResolutionScheduled = true
            DispatchQueue.main.async { [weak self, weak view] in
                guard let self else { return }
                self.isResolutionScheduled = false

                guard let view, self.requestedIsLocked else {
                    return
                }
                let resolvedScrollView = view.nearestAncestorScrollView()
                if self.scrollView !== resolvedScrollView {
                    self.unlockScrollView()
                }
                self.scrollView = resolvedScrollView
                resolvedScrollView?.isScrollEnabled = false
            }
        }

        func unlock() {
            requestedIsLocked = false
            unlockScrollView()
        }

        private func unlockScrollView() {
            scrollView?.isScrollEnabled = true
            scrollView = nil
        }
    }
}

private struct DashboardLongPressDragSurface: UIViewRepresentable {
    let minimumDuration: TimeInterval
    let maximumMovement: CGFloat
    let autoScrollAxes: Axis.Set
    let onChanged: (CGSize) -> Void
    let onEnded: (CGSize) -> Void
    let onCancelled: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onChanged: onChanged,
            onEnded: onEnded,
            onCancelled: onCancelled,
            autoScrollAxes: autoScrollAxes
        )
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true

        let recognizer = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        recognizer.minimumPressDuration = minimumDuration
        recognizer.allowableMovement = maximumMovement
        recognizer.cancelsTouchesInView = true
        recognizer.delaysTouchesBegan = false
        recognizer.delaysTouchesEnded = false
        recognizer.delegate = context.coordinator
        view.addGestureRecognizer(recognizer)
        context.coordinator.recognizer = recognizer

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
        context.coordinator.onCancelled = onCancelled
        context.coordinator.autoScrollAxes = autoScrollAxes
        context.coordinator.recognizer?.minimumPressDuration = minimumDuration
        context.coordinator.recognizer?.allowableMovement = maximumMovement
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.stopAutoScroll()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onChanged: (CGSize) -> Void
        var onEnded: (CGSize) -> Void
        var onCancelled: () -> Void
        var autoScrollAxes: Axis.Set
        weak var recognizer: UILongPressGestureRecognizer?
        private weak var autoScrollView: UIScrollView?
        private var autoScrollDisplayLink: CADisplayLink?
        private var startContentOffset: CGPoint?
        private var startWindowLocation: CGPoint?
        private var lastWindowLocation: CGPoint?
        private var lastAutoScrollTimestamp: CFTimeInterval?

        init(
            onChanged: @escaping (CGSize) -> Void,
            onEnded: @escaping (CGSize) -> Void,
            onCancelled: @escaping () -> Void,
            autoScrollAxes: Axis.Set
        ) {
            self.onChanged = onChanged
            self.onEnded = onEnded
            self.onCancelled = onCancelled
            self.autoScrollAxes = autoScrollAxes
        }

        @objc func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
            let location = recognizer.location(in: nil)

            switch recognizer.state {
            case .began:
                startWindowLocation = location
                lastWindowLocation = location
                autoScrollView = recognizer.view?.nearestScrollView(for: autoScrollAxes)
                startContentOffset = autoScrollView?.contentOffset
                startAutoScroll()
                onChanged(.zero)
            case .changed:
                lastWindowLocation = location
                updateAutoScroll(at: location)
                onChanged(translation(from: location))
            case .ended:
                let finalTranslation = translation(from: location)
                stopAutoScroll()
                onEnded(finalTranslation)
                startWindowLocation = nil
                lastWindowLocation = nil
                startContentOffset = nil
            case .cancelled, .failed:
                stopAutoScroll()
                onCancelled()
                startWindowLocation = nil
                lastWindowLocation = nil
                startContentOffset = nil
            default:
                break
            }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            false
        }

        func stopAutoScroll() {
            autoScrollDisplayLink?.invalidate()
            autoScrollDisplayLink = nil
            autoScrollView = nil
            lastAutoScrollTimestamp = nil
        }

        private func translation(from location: CGPoint) -> CGSize {
            guard let startWindowLocation else {
                return .zero
            }

            let contentOffsetDelta = contentOffsetDelta()
            return CGSize(
                width: location.x - startWindowLocation.x + contentOffsetDelta.x,
                height: location.y - startWindowLocation.y + contentOffsetDelta.y
            )
        }

        private func contentOffsetDelta() -> CGPoint {
            guard let autoScrollView,
                  let startContentOffset else {
                return .zero
            }

            return CGPoint(
                x: autoScrollAxes.contains(.horizontal) ? autoScrollView.contentOffset.x - startContentOffset.x : 0,
                y: autoScrollAxes.contains(.vertical) ? autoScrollView.contentOffset.y - startContentOffset.y : 0
            )
        }

        private func startAutoScroll() {
            guard !autoScrollAxes.isEmpty, autoScrollView != nil else {
                return
            }

            autoScrollDisplayLink?.invalidate()
            let displayLink = CADisplayLink(target: self, selector: #selector(handleAutoScrollTick(_:)))
            displayLink.add(to: .main, forMode: .common)
            autoScrollDisplayLink = displayLink
        }

        @objc private func handleAutoScrollTick(_ displayLink: CADisplayLink) {
            guard let location = lastWindowLocation else {
                return
            }

            let previousTimestamp = lastAutoScrollTimestamp ?? displayLink.timestamp
            let elapsed = max(0, displayLink.timestamp - previousTimestamp)
            lastAutoScrollTimestamp = displayLink.timestamp

            guard elapsed > 0,
                  updateAutoScroll(at: location, elapsed: elapsed) else {
                return
            }

            onChanged(translation(from: location))
        }

        @discardableResult
        private func updateAutoScroll(at windowLocation: CGPoint, elapsed: TimeInterval = 0) -> Bool {
            guard let scrollView = autoScrollView else {
                return false
            }

            let velocity = autoScrollVelocity(at: windowLocation, in: scrollView)
            guard velocity != .zero else {
                return false
            }

            let duration = CGFloat(elapsed)
            guard duration > 0 else {
                return false
            }

            let proposedOffset = CGPoint(
                x: scrollView.contentOffset.x + velocity.x * duration,
                y: scrollView.contentOffset.y + velocity.y * duration
            )
            let clampedOffset = scrollView.clampedContentOffset(proposedOffset)
            guard clampedOffset != scrollView.contentOffset else {
                return false
            }

            scrollView.setContentOffset(clampedOffset, animated: false)
            return true
        }

        private func autoScrollVelocity(at windowLocation: CGPoint, in scrollView: UIScrollView) -> CGPoint {
            let frame = scrollView.convert(scrollView.bounds, to: nil)
            var velocity = CGPoint.zero

            if autoScrollAxes.contains(.horizontal) {
                velocity.x = edgeVelocity(
                    location: windowLocation.x,
                    minEdge: frame.minX,
                    maxEdge: frame.maxX
                )
            }

            if autoScrollAxes.contains(.vertical) {
                velocity.y = edgeVelocity(
                    location: windowLocation.y,
                    minEdge: frame.minY,
                    maxEdge: frame.maxY
                )
            }

            return velocity
        }

        private func edgeVelocity(location: CGFloat, minEdge: CGFloat, maxEdge: CGFloat) -> CGFloat {
            let edgeLength = DashboardDragAutoScroll.edgeLength
            if location < minEdge + edgeLength {
                let proximity = min(1, max(0, (minEdge + edgeLength - location) / edgeLength))
                return -DashboardDragAutoScroll.maximumPointsPerSecond * proximity * proximity
            }

            if location > maxEdge - edgeLength {
                let proximity = min(1, max(0, (location - (maxEdge - edgeLength)) / edgeLength))
                return DashboardDragAutoScroll.maximumPointsPerSecond * proximity * proximity
            }

            return 0
        }
    }
}

private extension UIView {
    func nearestAncestorScrollView() -> UIScrollView? {
        sequence(first: superview, next: { $0?.superview })
            .compactMap { $0 as? UIScrollView }
            .first
    }

    func nearestScrollView(for axes: Axis.Set) -> UIScrollView? {
        sequence(first: superview, next: { $0?.superview })
            .compactMap { $0 as? UIScrollView }
            .first { scrollView in
                scrollView.isScrollable(on: axes)
            }
    }
}

private extension UIScrollView {
    func isScrollable(on axes: Axis.Set) -> Bool {
        if axes.contains(.horizontal), contentSize.width > bounds.width + 1 {
            return true
        }

        if axes.contains(.vertical), contentSize.height > bounds.height + 1 {
            return true
        }

        return false
    }

    func clampedContentOffset(_ offset: CGPoint) -> CGPoint {
        let minimumX = -adjustedContentInset.left
        let maximumX = max(
            minimumX,
            contentSize.width - bounds.width + adjustedContentInset.right
        )
        let minimumY = -adjustedContentInset.top
        let maximumY = max(
            minimumY,
            contentSize.height - bounds.height + adjustedContentInset.bottom
        )

        return CGPoint(
            x: min(max(offset.x, minimumX), maximumX),
            y: min(max(offset.y, minimumY), maximumY)
        )
    }
}

private struct DashboardGridEditAffordance<MenuContent: View>: View {
    let isVisible: Bool
    let accessibilityLabel: String
    @ViewBuilder var menuContent: () -> MenuContent

    var body: some View {
        Menu {
            menuContent()
        } label: {
            Image(systemName: "ellipsis")
                .font(.caption.weight(.bold))
                .foregroundStyle(.primary)
                .frame(width: 30, height: 30)
                .background(Color(.secondarySystemGroupedBackground), in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(Color(.separator).opacity(0.28), lineWidth: 0.5)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .offset(x: 4, y: -6)
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Shows options")
    }
}

private struct DashboardChipEditAffordance<MenuContent: View>: View {
    let isVisible: Bool
    let accessibilityLabel: String
    @ViewBuilder var menuContent: () -> MenuContent

    var body: some View {
        Menu {
            menuContent()
        } label: {
            Image(systemName: "ellipsis")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.primary)
                .frame(width: 24, height: 24)
                .background(Color(.secondarySystemGroupedBackground), in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(Color(.separator).opacity(0.28), lineWidth: 0.5)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .offset(x: 4, y: -2)
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Shows options")
    }
}
