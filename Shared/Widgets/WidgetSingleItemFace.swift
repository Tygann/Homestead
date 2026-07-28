import SwiftUI

nonisolated enum HomesteadWidgetFaceFamily: Equatable, Sendable {
    case systemSmall
    case accessoryCircular
    case accessoryRectangular
}

struct HomesteadWidgetSingleItemFace<Icon: View>: View {
    let family: HomesteadWidgetFaceFamily
    let title: String
    let value: String?
    let supportingText: String?
    let valueColor: Color
    let titleLineLimit: Int
    @ViewBuilder let icon: () -> Icon

    init(
        family: HomesteadWidgetFaceFamily,
        title: String,
        value: String? = nil,
        supportingText: String? = nil,
        valueColor: Color = .primary,
        titleLineLimit: Int = 2,
        @ViewBuilder icon: @escaping () -> Icon
    ) {
        self.family = family
        self.title = title
        self.value = value
        self.supportingText = supportingText
        self.valueColor = valueColor
        self.titleLineLimit = titleLineLimit
        self.icon = icon
    }

    var body: some View {
        switch family {
        case .systemSmall:
            HomesteadWidgetSmallTile(
                title: title,
                value: value,
                supportingText: supportingText,
                valueColor: valueColor,
                titleLineLimit: titleLineLimit,
                icon: icon
            )
        case .accessoryCircular:
            icon()
        case .accessoryRectangular:
            HomesteadWidgetRectangularTile(title: title, value: value ?? supportingText, icon: icon)
        }
    }
}
