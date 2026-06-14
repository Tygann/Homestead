import SwiftUI

struct EntityBrowserRow<Accessory: View>: View {
    let entityBox: HAEntityState
    var displayNameOverride: String?
    var detailText: String?
    let accessory: Accessory

    var body: some View {
        let entity = entityBox.homeEntity

        Label {
            HStack(alignment: .center, spacing: AppSpacing.medium) {
                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(displayNameOverride ?? entity.displayName)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(entity.entityID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if let detailText {
                        Text(detailText)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: AppSpacing.medium)

                accessory
            }
            .frame(minHeight: 48)
        } icon: {
            HomesteadIconView(icon: entity.resolvedIcon, pointSize: 18)
                .foregroundStyle(entity.isAvailable ? Color.accentColor : Color.secondary)
        }
        .padding(.vertical, AppSpacing.xSmall)
    }
}
