import SwiftUI

struct DashboardCardView: View {
    let entityID: String

    @Environment(HAStateStore.self) private var stateStore

    var body: some View {
        if let entity = stateStore.entity(for: entityID) {
            switch entity.domain {
            case .light:
                LightCard(entityID: entityID)
            case .sensor:
                SensorCard(entityID: entityID)
            default:
                EntitySummaryCard(entity: entity)
            }
        }
    }
}

private struct EntitySummaryCard: View {
    let entity: HomeEntity

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                CardIconView(systemName: entity.iconName)

                Spacer(minLength: AppSpacing.small)

                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(entity.displayName)
                        .font(.headline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    Text(entity.state.capitalized)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(entity.isAvailable ? .secondary : Color.red)
                        .lineLimit(1)
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    DashboardCardView(entityID: "cover.primary_shades")
        .frame(width: 180, height: 180)
        .padding()
        .withPreviewEnvironment()
}
#endif
