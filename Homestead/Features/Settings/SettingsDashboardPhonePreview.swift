import SwiftUI
import UIKit

nonisolated enum SettingsDashboardPhonePreviewMetrics {
    static let aspectRatio: CGFloat = 0.49

    static func size(forWidth width: CGFloat) -> CGSize {
        let resolvedWidth = max(0, width)
        return CGSize(width: resolvedWidth, height: resolvedWidth / aspectRatio)
    }
}

struct SettingsDashboardPhonePreview: View {
    private static let referenceWidth: CGFloat = 178

    let width: CGFloat
    let items: [DashboardItemConfiguration]
    let dashboardTitle: String?
    let wallpaperURL: URL?
    let wallpaperRevision: Int
    let accessibilityLabel: String

    @State private var previewImage: UIImage?

    init(
        width: CGFloat = 178,
        items: [DashboardItemConfiguration],
        dashboardTitle: String? = nil,
        wallpaperURL: URL? = nil,
        wallpaperRevision: Int = 0,
        accessibilityLabel: String = "Dashboard Preview"
    ) {
        self.width = width
        self.items = items
        self.dashboardTitle = dashboardTitle
        self.wallpaperURL = wallpaperURL
        self.wallpaperRevision = wallpaperRevision
        self.accessibilityLabel = accessibilityLabel
    }

    var body: some View {
        let size = SettingsDashboardPhonePreviewMetrics.size(forWidth: width)

        previewCanvas(size: size)
            .frame(width: size.width, height: size.height)
            .shadow(color: .black.opacity(0.08), radius: 14, y: 8)
            .accessibilityLabel(accessibilityLabel)
            .task(id: previewTaskID) {
                loadPreviewImage()
            }
    }

    private func previewCanvas(size: CGSize) -> some View {
        let scale = size.width / Self.referenceWidth
        let contentPadding = 11 * scale
        let phoneShape = RoundedRectangle(cornerRadius: 28 * scale, style: .continuous)

        return ZStack {
            ZStack {
                previewBackground(in: size)

                VStack(spacing: 0) {
                    previewHeader(scale: scale)
                        .padding(.bottom, 15 * scale)

                    SettingsDashboardLayoutMiniature(
                        items: items,
                        contentWidth: size.width - (contentPadding * 2),
                        renderScale: scale
                    )
                    .frame(maxHeight: .infinity, alignment: .top)
                }
                .padding(contentPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .clipShape(phoneShape)

            previewBottomChrome(scale: scale)
                .padding(.horizontal, 10 * scale)
                .padding(.bottom, contentPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

            phoneShape
                .strokeBorder(Color.white.opacity(0.18), lineWidth: max(0.5, scale))
        }
        .frame(width: size.width, height: size.height)
        .clipShape(phoneShape)
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

    private func previewBottomChrome(scale: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: 8 * scale) {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.thinMaterial)
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
                    }

                Capsule()
                    .fill(Color(.tertiarySystemGroupedBackground).opacity(0.70))
                    .frame(width: 42 * scale)
                    .padding(3 * scale)

                HStack {
                    Image(systemName: "house.fill")
                    Spacer()
                    Image(systemName: "square.split.bottomrightquarter.fill")
                }
                .font(.system(size: 11 * scale, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 17 * scale)
            }
            .frame(height: 31 * scale)

            Spacer(minLength: 6 * scale)

            Circle()
                .fill(.thinMaterial)
                .overlay {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
                }
                .overlay {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11 * scale, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 31 * scale, height: 31 * scale)
        }
    }

    private func previewHeader(scale: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 6 * scale) {
            if let title = normalizedDashboardTitle {
                Text(title)
                    .font(.system(size: 13 * scale, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            } else {
                Capsule()
                    .fill(Color.white.opacity(0.76))
                    .frame(width: 56 * scale, height: 7 * scale)
            }

            Spacer(minLength: 6 * scale)

            HStack(spacing: 5 * scale) {
                Circle()
                    .fill(Color.white.opacity(0.22))
                    .overlay {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
                    }
                    .frame(width: 17 * scale, height: 17 * scale)

                Circle()
                    .fill(Color.white.opacity(0.22))
                    .overlay {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
                    }
                    .frame(width: 17 * scale, height: 17 * scale)
            }
        }
        .frame(height: 28 * scale)
    }

    private var normalizedDashboardTitle: String? {
        let trimmedTitle = dashboardTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedTitle.isEmpty ? nil : trimmedTitle
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
    let contentWidth: CGFloat
    let renderScale: CGFloat

    private let maximumVisibleItems = 24

    private var spacing: CGFloat {
        AppSpacing.medium * miniatureScale
    }

    private var rowHeight: CGFloat {
        DashboardCardSize.renderedGridUnitHeight(cardPadding: AppSpacing.medium) * miniatureScale
    }

    private var miniatureScale: CGFloat {
        0.40 * renderScale
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large * miniatureScale) {
            if !chipItems.isEmpty {
                chipRow
            }

            if cardGridItems.isEmpty {
                emptyState
            } else {
                let layout = SettingsDashboardPreviewLayout(
                    items: Array(cardGridItems.prefix(maximumVisibleItems)),
                    width: contentWidth,
                    spacing: spacing,
                    rowHeight: rowHeight
                )

                ZStack(alignment: .topLeading) {
                    ForEach(layout.placements) { placement in
                        SettingsDashboardLayoutPreviewTile(
                            item: placement.item,
                            renderScale: renderScale
                        )
                            .frame(width: placement.frame.width, height: placement.frame.height)
                            .offset(x: placement.frame.minX, y: placement.frame.minY)
                    }
                }
                .frame(width: contentWidth, height: layout.height, alignment: .topLeading)
                .frame(maxHeight: .infinity, alignment: .top)
                .clipped()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Dashboard layout preview")
            }
        }
        .frame(width: contentWidth, alignment: .topLeading)
    }

    private var chipItems: [DashboardItemConfiguration] {
        items.filter { $0.role == .chip }
    }

    private var cardGridItems: [DashboardItemConfiguration] {
        items.filter { $0.role != .chip }
    }

    private var chipRow: some View {
        HStack(spacing: 4 * renderScale) {
            ForEach(chipItems.prefix(4)) { chip in
                Capsule()
                    .fill(chipColor(for: chip).opacity(0.26))
                    .overlay {
                        Capsule()
                            .strokeBorder(chipColor(for: chip).opacity(0.18), lineWidth: 0.5)
                    }
                    .frame(width: chipWidth(for: chip) * renderScale, height: 13 * renderScale)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        RoundedRectangle(cornerRadius: 16 * renderScale, style: .continuous)
            .stroke(
                .secondary.opacity(0.35),
                style: StrokeStyle(
                    lineWidth: max(0.5, renderScale),
                    dash: [4 * renderScale, 4 * renderScale]
                )
            )
            .frame(maxWidth: .infinity)
            .frame(height: 126 * renderScale)
            .overlay {
                Text("No Cards")
                    .font(.system(size: 12 * renderScale, weight: .medium))
                    .foregroundStyle(.secondary)
            }
    }

    private func chipWidth(for chip: DashboardItemConfiguration) -> CGFloat {
        switch chip.source {
        case .summary:
            34
        case .entity:
            42
        case nil:
            34
        }
    }

    private func chipColor(for chip: DashboardItemConfiguration) -> Color {
        guard case .summary(let summaryKind) = chip.source else {
            return Color(.tertiaryLabel)
        }

        switch summaryKind {
        case .climate:
            return .blue
        case .lights:
            return .yellow
        case .security:
            return .mint
        case .media:
            return .indigo
        case .maintenance:
            return .gray
        }
    }
}

private struct SettingsDashboardLayoutPreviewTile: View {
    let item: DashboardItemConfiguration
    let renderScale: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(fillStyle)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(strokeStyle, lineWidth: 0.5)
            }
            .overlay(alignment: .topLeading) {
                if item.role == .card {
                    RoundedRectangle(cornerRadius: 6 * renderScale, style: .continuous)
                        .fill(Color(.tertiarySystemGroupedBackground).opacity(0.60))
                        .frame(width: 13 * renderScale, height: 13 * renderScale)
                        .padding(5 * renderScale)
                } else if item.role == .heading {
                    Capsule()
                        .fill(.secondary.opacity(0.45))
                        .frame(width: 44 * renderScale, height: 5 * renderScale)
                        .padding(.top, 7 * renderScale)
                        .padding(.leading, 2 * renderScale)
                }
            }
    }

    private var fillStyle: Color {
        switch item.role {
        case .card:
            Color(.secondarySystemGroupedBackground).opacity(0.78)
        case .heading:
            Color.clear
        case .chip:
            Color.accentColor.opacity(0.18)
        }
    }

    private var strokeStyle: Color {
        switch item.role {
        case .card:
            Color(.separator).opacity(0.22)
        case .heading:
            Color.clear
        case .chip:
            Color.accentColor.opacity(0.10)
        }
    }

    private var cornerRadius: CGFloat {
        (item.role == .chip ? 10 : 8) * renderScale
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
