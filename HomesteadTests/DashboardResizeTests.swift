import SwiftUI
import Testing
@testable import Homestead

@MainActor
struct DashboardResizeTests {
    @Test func gridUsesFiniteIntrinsicWidthForUnboundedProposals() {
        let grid = CardGridLayout(spacing: 12, cardPadding: 12)
        #expect(grid.resolvedWidth(.infinity) == 340)
        #expect(grid.resolvedWidth(.nan) == 340)
        #expect(grid.resolvedWidth(nil) == 340)
        #expect(grid.resolvedWidth(900) == 900)
        #expect(grid.resolvedWidth(-1) == 0)
    }

    @Test func unchangedViewportKeepsDragActive() {
        var session = DashboardDragGeometrySession()
        session.begin(windowSize: CGSize(width: 800, height: 600), viewportSize: CGSize(width: 720, height: 500))
        let result1 = session.accepts(windowSize: CGSize(width: 800, height: 600), viewportSize: CGSize(width: 720, height: 500))
        #expect(result1)
    }

    @Test func foldCancelsGestureUntilNewPress() {
        var session = DashboardDragGeometrySession()
        let open = CGSize(width: 800, height: 600)
        let closed = CGSize(width: 400, height: 700)
        session.begin(windowSize: open, viewportSize: open)
        let result2 = !session.accepts(windowSize: closed, viewportSize: closed)
        #expect(result2)
        let result3 = !session.accepts(windowSize: open, viewportSize: open)
        #expect(result3)
        session.begin(windowSize: closed, viewportSize: closed)
        let result4 = session.accepts(windowSize: closed, viewportSize: closed)
        #expect(result4)
    }

    @Test func barOrContainerResizeCancelsDragWithoutWindowResize() {
        var session = DashboardDragGeometrySession()
        let window = CGSize(width: 800, height: 600)
        session.begin(windowSize: window, viewportSize: CGSize(width: 720, height: 500))
        let result5 = !session.accepts(windowSize: window, viewportSize: CGSize(width: 680, height: 500))
        #expect(result5)
    }

    @Test func detachedWindowCancelsDrag() {
        var session = DashboardDragGeometrySession()
        let size = CGSize(width: 400, height: 700)
        session.begin(windowSize: size, viewportSize: size)
        let result6 = !session.accepts(windowSize: nil, viewportSize: size)
        #expect(result6)
    }
}
