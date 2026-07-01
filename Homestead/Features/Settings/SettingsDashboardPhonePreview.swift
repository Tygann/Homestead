import SwiftUI
import UIKit

struct SettingsDashboardPhonePreview: View {
    private static let viewportWidth: CGFloat = 178
    private static let viewportHeight: CGFloat = viewportWidth / 0.49
    private static let contentPadding: CGFloat = 11

    let items: [DashboardItemConfiguration]
    let dashboardTitle: String?
    let wallpaperURL: URL?
    let wallpaperRevision: Int
    let accessibilityLabel: String

    @State private var previewImage: UIImage?

    init(
        items: [DashboardItemConfiguration],
        dashboardTitle: String? = nil,
        wallpaperURL: URL? = nil,
        wallpaperRevision: Int = 0,
        accessibilityLabel: String = "Dashboard Preview"
    ) {
        self.items = items
        self.dashboardTitle = dashboardTitle
        self.wallpaperURL = wallpaperURL
        self.wallpaperRevision = wallpaperRevision
        self.accessibilityLabel = accessibilityLabel
    }

    var body: some View {
        Color.clear
        .aspectRatio(0.49, contentMode: .fit)
        .overlay {
            GeometryReader { proxy in
                let scale = proxy.size.width / Self.viewportWidth

                previewCanvas
                    .frame(width: Self.viewportWidth, height: Self.viewportHeight)
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            }
        }
        .shadow(color: .black.opacity(0.08), radius: 14, y: 8)
        .accessibilityLabel(accessibilityLabel)
        .task(id: previewTaskID) {
            loadPreviewImage()
        }
    }

    private var previewCanvas: some View {
        let phoneShape = RoundedRectangle(cornerRadius: 28, style: .continuous)

        return ZStack {
            ZStack {
                previewBackground(in: Self.viewportSize)

                VStack(spacing: 0) {
                    previewHeader
                        .padding(.bottom, 15)

                    SettingsDashboardLayoutMiniature(
                        items: items,
                        contentWidth: Self.contentWidth
                    )
                    .frame(maxHeight: .infinity, alignment: .top)
                }
                .padding(Self.contentPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .clipShape(phoneShape)

            previewBottomChrome
                .padding(.horizontal, 10)
                .padding(.bottom, Self.contentPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

            phoneShape
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        }
    }

    private static var viewportSize: CGSize {
        CGSize(width: viewportWidth, height: viewportHeight)
    }

    private static var contentWidth: CGFloat {
        viewportWidth - (contentPadding * 2)
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

    private var previewBottomChrome: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.thinMaterial)
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
                    }

                Capsule()
                    .fill(Color(.tertiarySystemGroupedBackground).opacity(0.70))
                    .frame(width: 42)
                    .padding(3)

                HStack {
                    Image(systemName: "house.fill")
                    Spacer()
                    Image(systemName: "square.split.bottomrightquarter.fill")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 17)
            }
            .frame(height: 31)

            Spacer(minLength: 6)

            Circle()
                .fill(.thinMaterial)
                .overlay {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
                }
                .overlay {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 31, height: 31)
        }
    }

    private var previewHeader: some View {
        HStack(alignment: .center, spacing: 6) {
            if let title = normalizedDashboardTitle {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            } else {
                Capsule()
                    .fill(Color.white.opacity(0.76))
                    .frame(width: 56, height: 7)
            }

            Spacer(minLength: 6)

            HStack(spacing: 5) {
                Circle()
                    .fill(Color.white.opacity(0.22))
                    .overlay {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
                    }
                    .frame(width: 17, height: 17)

                Circle()
                    .fill(Color.white.opacity(0.22))
                    .overlay {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
                    }
                    .frame(width: 17, height: 17)
            }
        }
        .frame(height: 28)
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

    private let maximumVisibleItems = 24
    private let miniatureScale: CGFloat = 0.40

    private var spacing: CGFloat {
        AppSpacing.medium * miniatureScale
    }

    private var rowHeight: CGFloat {
        DashboardCardSize.renderedGridUnitHeight(cardPadding: AppSpacing.medium) * miniatureScale
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
                        SettingsDashboardLayoutPreviewTile(item: placement.item)
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
        HStack(spacing: 4) {
            ForEach(chipItems.prefix(4)) { chip in
                Capsule()
                    .fill(chipColor(for: chip).opacity(0.26))
                    .overlay {
                        Capsule()
                            .strokeBorder(chipColor(for: chip).opacity(0.18), lineWidth: 0.5)
                    }
                    .frame(width: chipWidth(for: chip), height: 13)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .frame(maxWidth: .infinity)
            .frame(height: 126)
            .overlay {
                Text("No Cards")
                    .font(.caption.weight(.medium))
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

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(fillStyle)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(strokeStyle, lineWidth: 0.5)
            }
            .overlay(alignment: .topLeading) {
                if item.role == .card {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(.tertiarySystemGroupedBackground).opacity(0.60))
                        .frame(width: 13, height: 13)
                        .padding(5)
                } else if item.role == .heading {
                    Capsule()
                        .fill(.secondary.opacity(0.45))
                        .frame(width: 44, height: 5)
                        .padding(.top, 7)
                        .padding(.leading, 2)
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
        item.role == .chip ? 10 : 8
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
