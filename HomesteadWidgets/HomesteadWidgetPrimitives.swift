import SwiftUI

struct HomesteadWidgetIconBadge: View {
    enum Content {
        case resolved(ResolvedIcon)
        case symbol(String)
    }

    let content: Content
    let color: Color
    var pointSize: CGFloat = 22
    var size: CGFloat = 44
    var cornerRadius: CGFloat = 14
    var background: AnyShapeStyle = AnyShapeStyle(.thinMaterial)

    var body: some View {
        icon
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(background, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    @ViewBuilder
    private var icon: some View {
        switch content {
        case .resolved(let icon):
            HomesteadIconView(icon: icon, pointSize: pointSize)
        case .symbol(let systemName):
            Image(systemName: systemName)
                .font(.system(size: pointSize, weight: .semibold))
        }
    }
}

struct HomesteadWidgetSmallTile<Icon: View>: View {
    let title: String
    var value: String?
    var supportingText: String?
    var valueColor: Color = .primary
    var titleLineLimit = 2
    var valueFont: Font = .subheadline.weight(.medium)
    let icon: Icon

    init(
        title: String,
        value: String? = nil,
        supportingText: String? = nil,
        valueColor: Color = .primary,
        titleLineLimit: Int = 2,
        valueFont: Font = .subheadline.weight(.medium),
        @ViewBuilder icon: () -> Icon
    ) {
        self.title = title
        self.value = value
        self.supportingText = supportingText
        self.valueColor = valueColor
        self.titleLineLimit = titleLineLimit
        self.valueFont = valueFont
        self.icon = icon()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            icon

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .lineLimit(titleLineLimit)
                    .minimumScaleFactor(0.82)

                if let value {
                    Text(value)
                        .font(valueFont)
                        .foregroundStyle(valueColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                if let supportingText {
                    Text(supportingText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct HomesteadWidgetRectangularTile<Icon: View>: View {
    let title: String
    var value: String?
    let icon: Icon

    init(
        title: String,
        value: String? = nil,
        @ViewBuilder icon: () -> Icon
    ) {
        self.title = title
        self.value = value
        self.icon = icon()
    }

    var body: some View {
        HStack(spacing: 8) {
            icon

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                if let value {
                    Text(value)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
            }
        }
    }
}
