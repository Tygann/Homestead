import SwiftUI
import UIKit

struct SettingsDashboardPhonePreview: View {
    let items: [DashboardItemConfiguration]
    let wallpaperURL: URL?
    let wallpaperRevision: Int
    let accessibilityLabel: String

    @State private var previewImage: UIImage?

    init(
        items: [DashboardItemConfiguration],
        wallpaperURL: URL? = nil,
        wallpaperRevision: Int = 0,
        accessibilityLabel: String = "Dashboard Preview"
    ) {
        self.items = items
        self.wallpaperURL = wallpaperURL
        self.wallpaperRevision = wallpaperRevision
        self.accessibilityLabel = accessibilityLabel
    }

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                ZStack {
                    previewBackground(in: proxy.size)

                    VStack(spacing: 0) {
                        SettingsDashboardLayoutMiniature(items: items)

                        Spacer(minLength: AppSpacing.small)

                        previewTabBar
                    }
                    .padding(11)
                }
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            }

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        }
        .aspectRatio(0.49, contentMode: .fit)
        .shadow(color: .black.opacity(0.08), radius: 14, y: 8)
        .accessibilityLabel(accessibilityLabel)
        .task(id: previewTaskID) {
            loadPreviewImage()
        }
    }

    private var previewTaskID: String {
        [
            wallpaperRevision.description,
            wallpaperURL?.path ?? "none"
        ].joined(separator: "|")
    }

    @ViewBuilder
    private func previewBackground(in size: CGSize) -> some View {
        if let previewImage {
            Image(uiImage: previewImage)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipped()

            Color.black.opacity(0.10)
            Color(.systemGroupedBackground).opacity(0.12)
        } else {
            LinearGradient(
                colors: [
                    Color(.tertiarySystemGroupedBackground),
                    Color(.secondarySystemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var previewTabBar: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(.thinMaterial)

            Capsule()
                .fill(Color(.tertiarySystemGroupedBackground).opacity(0.70))
                .frame(width: 42)
                .padding(3)

            HStack {
                Image(systemName: "house.fill")
                Spacer()
                Image(systemName: "square.split.bottomrightquarter.fill")
                Spacer()
                Image(systemName: "magnifyingglass")
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 17)
        }
        .frame(height: 31)
    }

    private func loadPreviewImage() {
        guard let wallpaperURL,
              let image = UIImage(contentsOfFile: wallpaperURL.path) else {
            previewImage = nil
            return
        }

        previewImage = image
    }
}

private struct SettingsDashboardLayoutMiniature: View {
    let items: [DashboardItemConfiguration]

    private let spacing: CGFloat = 5
    private let rowHeight: CGFloat = 23
    private let maximumVisibleItems = 24

    var body: some View {
        if items.isEmpty {
            emptyState
        } else {
            GeometryReader { proxy in
                let layout = SettingsDashboardPreviewLayout(
                    items: Array(items.prefix(maximumVisibleItems)),
                    width: proxy.size.width,
                    spacing: spacing,
                    rowHeight: rowHeight
                )

                ZStack(alignment: .topLeading) {
                    ForEach(layout.placements) { placement in
                        SettingsDashboardLayoutPreviewTile(item: placement.item)
                            .frame(width: placement.frame.width, height: placement.frame.height)
                            .offset(x: placement.frame.minX, y: placement.frame.minY)
                    }
                }
                .frame(width: proxy.size.width, height: layout.height, alignment: .topLeading)
                .frame(maxHeight: .infinity, alignment: .top)
                .clipped()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Dashboard layout preview")
        }
    }

    private var emptyState: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .frame(maxWidth: .infinity)
            .frame(height: 150)
            .overlay {
                Text("No Cards")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
    }
}

private struct SettingsDashboardLayoutPreviewTile: View {
    let item: DashboardItemConfiguration

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(fillStyle)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(strokeStyle, lineWidth: 0.5)
            }
            .overlay(alignment: .topLeading) {
                if item.type == .entity {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(.tertiarySystemGroupedBackground).opacity(0.60))
                        .frame(width: 13, height: 13)
                        .padding(5)
                } else if item.type == .header {
                    Capsule()
                        .fill(.secondary.opacity(0.45))
                        .frame(width: 44, height: 5)
                        .padding(.top, 7)
                        .padding(.leading, 2)
                }
            }
    }

    private var fillStyle: Color {
        switch item.type {
        case .entity:
            Color(.secondarySystemGroupedBackground).opacity(0.78)
        case .header:
            Color.clear
        case .chip:
            Color.accentColor.opacity(0.18)
        }
    }

    private var strokeStyle: Color {
        switch item.type {
        case .entity:
            Color(.separator).opacity(0.22)
        case .header:
            Color.clear
        case .chip:
            Color.accentColor.opacity(0.10)
        }
    }

    private var cornerRadius: CGFloat {
        item.type == .chip ? 10 : 8
    }
}

private struct SettingsDashboardPreviewLayout {
    let placements: [SettingsDashboardPreviewPlacement]
    let height: CGFloat

    init(
        items: [DashboardItemConfiguration],
        width: CGFloat,
        spacing: CGFloat,
        rowHeight: CGFloat
    ) {
        let columnCount = 4
        let trackWidth = max(0, (width - (spacing * CGFloat(columnCount - 1))) / CGFloat(columnCount))
        var occupancy: [[Bool]] = []
        var placements: [SettingsDashboardPreviewPlacement] = []

        for item in items {
            let metadata = item.layoutMetadata
            let columnSpan = min(max(metadata.columnSpan, 1), columnCount)
            let rowSpan = max(metadata.rowSpan, 1)
            let origin = Self.firstAvailableOrigin(
                columnSpan: columnSpan,
                rowSpan: rowSpan,
                columnCount: columnCount,
                occupancy: &occupancy
            )

            Self.markOccupied(
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

            placements.append(SettingsDashboardPreviewPlacement(item: item, frame: frame))
        }

        let usedRowCount = occupancy.lastIndex { row in
            row.contains(true)
        }.map { $0 + 1 } ?? 0
        let height = usedRowCount > 0
            ? (CGFloat(usedRowCount) * rowHeight) + (CGFloat(usedRowCount - 1) * spacing)
            : 0

        self.placements = placements
        self.height = height
    }

    private static func firstAvailableOrigin(
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

    private static func isAvailable(
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

    private static func markOccupied(
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

    private static func ensureRows(upTo row: Int, columnCount: Int, occupancy: inout [[Bool]]) {
        guard row >= occupancy.count else {
            return
        }

        occupancy.append(contentsOf: Array(
            repeating: Array(repeating: false, count: columnCount),
            count: row - occupancy.count + 1
        ))
    }
}

private struct SettingsDashboardPreviewPlacement: Identifiable {
    let item: DashboardItemConfiguration
    let frame: CGRect

    var id: UUID {
        item.id
    }
}
