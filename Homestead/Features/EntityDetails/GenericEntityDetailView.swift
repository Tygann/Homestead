import SwiftUI

struct GenericEntityDetailView: View {
    let entityBox: HAEntityState
    var presentationStyle: EntityDetailPresentationStyle = .sheet

    private var entity: HomeEntity {
        entityBox.homeEntity
    }

    private var presentation: DashboardEntityPresentation {
        DashboardEntityPresentation(entityBox: entityBox)
    }

    var body: some View {
        EntityDetailScaffold(title: navigationTitle, presentationStyle: presentationStyle) {
            header
            currentStatePanel
            contextDetails
        }
    }

    private var header: some View {
        EntityDetailHeader(
            iconName: presentation.iconName,
            title: presentation.title,
            subtitle: entity.entityID,
            badge: presentation.subtitle,
            iconColor: iconColor,
            badgeColor: entity.isAvailable ? iconColor : .red,
            iconBackground: iconBackground,
            badgeBackground: badgeBackground
        )
    }

    private var currentStatePanel: some View {
        EntityControlPanel(title: "Current State", systemImage: "waveform.path.ecg") {
            Text(presentation.subtitle)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(stateColor)
                .lineLimit(2)
                .minimumScaleFactor(0.55)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var contextDetails: some View {
        EntityMetadataDisclosure(
            entityBox: entityBox,
            title: "Home Assistant",
            systemImage: "house.and.flag",
            rows: [
                EntityMetadataRow(title: "Entity ID", value: entity.entityID),
                EntityMetadataRow(title: "Domain", value: entity.domain.displayName),
                EntityMetadataRow(title: "State", value: entity.state.displayStateText)
            ]
        )
    }

    private var navigationTitle: String {
        entity.domain == .other ? "Entity" : entity.domain.displayName
    }

    private var iconColor: Color {
        guard entity.isAvailable else { return .secondary }
        return presentation.isActive ? presentation.accentColor : .secondary
    }

    private var stateColor: Color {
        guard entity.isAvailable else { return .red }
        return presentation.isActive ? presentation.accentColor : .primary
    }

    private var iconBackground: Color {
        guard entity.isAvailable else { return Color(.tertiarySystemGroupedBackground) }
        return presentation.isActive ? presentation.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground)
    }

    private var badgeBackground: Color {
        guard entity.isAvailable else { return Color.red.opacity(0.12) }
        return presentation.isActive ? presentation.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground)
    }
}

#if DEBUG
#Preview {
    GenericEntityDetailView(
        entityBox: HAEntityState(
            homeEntity: HomeEntity(
                entityID: "weather.home",
                domain: .weather,
                displayName: "Home Weather",
                state: "partlycloudy",
                iconName: "cloud.sun.fill",
                isAvailable: true,
                lastUpdated: .now
            )
        )
    )
    .withPreviewEnvironment()
}
#endif
