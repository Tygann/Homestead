import SwiftUI

// Bookmarks live above adaptive layout branches without invalidating the summary on every scroll update.
@MainActor
final class SummaryScrollBookmark {
    private(set) var offset: CGFloat = 0

    func record(_ offset: CGFloat) {
        guard offset.isFinite else { return }
        self.offset = max(0, offset)
    }

    func restoredOffset(maximumOffset: CGFloat) -> CGFloat {
        guard maximumOffset.isFinite else { return offset }
        return min(offset, max(0, maximumOffset))
    }
}

private struct SummaryScrollMetrics: Equatable {
    let offset: CGFloat
    let maximumOffset: CGFloat
    let isReady: Bool

    init(_ geometry: ScrollGeometry) {
        offset = max(0, geometry.contentOffset.y + geometry.contentInsets.top)
        maximumOffset = max(0, geometry.contentSize.height + geometry.contentInsets.top
            + geometry.contentInsets.bottom - geometry.containerSize.height)
        isReady = geometry.contentSize.height > 0 && geometry.containerSize.height > 0
    }
}

private struct SummaryScrollRestoration: ViewModifier {
    let bookmark: SummaryScrollBookmark
    @State private var position = ScrollPosition()
    @State private var isRestoring = true

    func body(content: Content) -> some View {
        content
            .scrollPosition($position)
            .onScrollGeometryChange(for: SummaryScrollMetrics.self) { geometry in
                SummaryScrollMetrics(geometry)
            } action: { _, metrics in
                guard metrics.isReady else { return }
                if isRestoring {
                    let target = bookmark.restoredOffset(maximumOffset: metrics.maximumOffset)
                    if abs(metrics.offset - target) < 0.5 {
                        // A lazy stack may still be estimating its height. Keep the original bookmark
                        // until it is reachable, so a temporary clamp does not erase a deeper position.
                        if target == bookmark.offset {
                            isRestoring = false
                        }
                    } else {
                        position.scrollTo(y: bookmark.offset)
                    }
                } else {
                    bookmark.record(metrics.offset)
                }
            }
            .onScrollPhaseChange { _, phase in
                if phase == .tracking || phase == .interacting {
                    isRestoring = false
                }
            }
    }
}

extension View {
    func restoringSummaryScroll(_ bookmark: SummaryScrollBookmark) -> some View {
        modifier(SummaryScrollRestoration(bookmark: bookmark))
    }
}
