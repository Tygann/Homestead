import SwiftUI

struct CardGrid<Content: View>: View {
    let spacing: CGFloat
    let cardPadding: CGFloat
    let content: Content

    init(
        spacing: CGFloat = AppSpacing.medium,
        cardPadding: CGFloat = AppSpacing.medium,
        @ViewBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.cardPadding = cardPadding
        self.content = content()
    }

    var body: some View {
        CardGridLayout(spacing: spacing, cardPadding: cardPadding) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct CardGridLayout: Layout {
    let spacing: CGFloat
    let cardPadding: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache _: inout ()
    ) -> CGSize {
        let width = proposal.width ?? 0
        let layout = makeLayout(in: width, subviews: subviews)
        return CGSize(width: width, height: layout.height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal _: ProposedViewSize,
        subviews: Subviews,
        cache _: inout ()
    ) {
        let layout = makeLayout(in: bounds.width, subviews: subviews)

        for placement in layout.placements {
            let origin = CGPoint(
                x: bounds.minX + placement.frame.minX,
                y: bounds.minY + placement.frame.minY
            )

            subviews[placement.index].place(
                at: origin,
                anchor: .topLeading,
                proposal: ProposedViewSize(placement.frame.size)
            )
        }
    }

    private func makeLayout(in width: CGFloat, subviews: Subviews) -> CardGridLayoutResult {
        let columnCount = adaptiveColumnCount(for: width)
        let trackWidth = trackWidth(totalWidth: width, columnCount: columnCount)
        let rowHeight = DashboardCardSize.renderedGridUnitHeight(cardPadding: cardPadding)
        var occupancy: [[Bool]] = []
        var placements: [CardGridPlacement] = []

        for index in subviews.indices {
            let requestedColumnSpan = subviews[index][CardGridColumnSpanKey.self]
            let columnSpan = min(max(requestedColumnSpan, 1), columnCount)
            let rowSpan = max(subviews[index][CardGridRowSpanKey.self], 1)
            let origin = firstAvailableOrigin(
                columnSpan: columnSpan,
                rowSpan: rowSpan,
                columnCount: columnCount,
                occupancy: &occupancy
            )

            markOccupied(
                column: origin.column,
                row: origin.row,
                columnSpan: columnSpan,
                rowSpan: rowSpan,
                columnCount: columnCount,
                occupancy: &occupancy
            )

            let frame = CGRect(
                x: CGFloat(origin.column) * (trackWidth + spacing),
                y: CGFloat(origin.row) * (rowHeight + spacing),
                width: (trackWidth * CGFloat(columnSpan)) + (spacing * CGFloat(columnSpan - 1)),
                height: (rowHeight * CGFloat(rowSpan)) + (spacing * CGFloat(rowSpan - 1))
            )

            placements.append(CardGridPlacement(index: index, frame: frame))
        }

        let usedRowCount = occupancy.lastIndex { row in
            row.contains(true)
        }.map { $0 + 1 } ?? 0
        let height = usedRowCount > 0
            ? (CGFloat(usedRowCount) * rowHeight) + (CGFloat(usedRowCount - 1) * spacing)
            : 0

        return CardGridLayoutResult(placements: placements, height: height)
    }

    private func firstAvailableOrigin(
        columnSpan: Int,
        rowSpan: Int,
        columnCount: Int,
        occupancy: inout [[Bool]]
    ) -> (column: Int, row: Int) {
        var row = 0

        while true {
            ensureRows(upTo: row + rowSpan - 1, columnCount: columnCount, occupancy: &occupancy)

            for column in 0...(columnCount - columnSpan) where isAvailable(
                column: column,
                row: row,
                columnSpan: columnSpan,
                rowSpan: rowSpan,
                occupancy: occupancy
            ) {
                return (column, row)
            }

            row += 1
        }
    }

    private func isAvailable(
        column: Int,
        row: Int,
        columnSpan: Int,
        rowSpan: Int,
        occupancy: [[Bool]]
    ) -> Bool {
        for occupiedRow in row..<(row + rowSpan) {
            for occupiedColumn in column..<(column + columnSpan) where occupancy[occupiedRow][occupiedColumn] {
                return false
            }
        }

        return true
    }

    private func markOccupied(
        column: Int,
        row: Int,
        columnSpan: Int,
        rowSpan: Int,
        columnCount: Int,
        occupancy: inout [[Bool]]
    ) {
        ensureRows(upTo: row + rowSpan - 1, columnCount: columnCount, occupancy: &occupancy)

        for occupiedRow in row..<(row + rowSpan) {
            for occupiedColumn in column..<(column + columnSpan) {
                occupancy[occupiedRow][occupiedColumn] = true
            }
        }
    }

    private func ensureRows(upTo row: Int, columnCount: Int, occupancy: inout [[Bool]]) {
        guard row >= occupancy.count else {
            return
        }

        occupancy.append(contentsOf: Array(
            repeating: Array(repeating: false, count: columnCount),
            count: row - occupancy.count + 1
        ))
    }

    private func adaptiveColumnCount(for width: CGFloat) -> Int {
        let baseColumnCount = 4
        let minimumTrackWidth: CGFloat = 76
        let candidateCount = max(
            baseColumnCount,
            Int((width + spacing) / (minimumTrackWidth + spacing))
        )

        return max(baseColumnCount, (candidateCount / baseColumnCount) * baseColumnCount)
    }

    private func trackWidth(totalWidth: CGFloat, columnCount: Int) -> CGFloat {
        guard columnCount > 0 else {
            return 0
        }

        return max(0, (totalWidth - (spacing * CGFloat(columnCount - 1))) / CGFloat(columnCount))
    }
}

nonisolated private struct CardGridColumnSpanKey: LayoutValueKey {
    static let defaultValue = DashboardCardSize.compact.columnSpan
}

nonisolated private struct CardGridRowSpanKey: LayoutValueKey {
    static let defaultValue = DashboardCardSize.compact.rowSpan
}

extension View {
    func cardGridSpan(_ metadata: DashboardCardLayoutMetadata) -> some View {
        layoutValue(key: CardGridColumnSpanKey.self, value: metadata.columnSpan)
            .layoutValue(key: CardGridRowSpanKey.self, value: metadata.rowSpan)
    }
}

private struct CardGridLayoutResult {
    let placements: [CardGridPlacement]
    let height: CGFloat
}

private struct CardGridPlacement {
    let index: Int
    let frame: CGRect
}
