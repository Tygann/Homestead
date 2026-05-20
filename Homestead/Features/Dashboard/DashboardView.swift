import SwiftUI

struct DashboardView: View {
    @Environment(HAStateStore.self) private var stateStore
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService

    private let adaptiveColumns = [
        GridItem(.adaptive(minimum: 160, maximum: 240), spacing: AppSpacing.large)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                header

                if stateStore.allEntities.isEmpty {
                    EmptyDashboardCard()
                } else {
                    lightsSection
                    sensorsSection
                }
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.xLarge)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Home")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await homeAssistantService.connectIfPossible(settings: connectionSettings) }
                } label: {
                    Image(systemName: homeAssistantService.connectionStatus.systemImage)
                }
                .accessibilityLabel(homeAssistantService.connectionStatus.title)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text("Homestead")
                .font(.largeTitle.bold())
            Text(homeAssistantService.connectionStatus.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var lightsSection: some View {
        DashboardSection(title: "Lights", isEmpty: stateStore.lightEntityIDs.isEmpty) {
            LazyVGrid(columns: adaptiveColumns, spacing: AppSpacing.large) {
                ForEach(stateStore.lightEntityIDs.prefix(8), id: \.self) { entityID in
                    LightCard(entityID: entityID)
                }
            }
        }
    }

    private var sensorsSection: some View {
        DashboardSection(title: "Sensors", isEmpty: stateStore.sensorEntityIDs.isEmpty) {
            LazyVGrid(columns: adaptiveColumns, spacing: AppSpacing.large) {
                ForEach(stateStore.sensorEntityIDs.prefix(6), id: \.self) { entityID in
                    SensorCard(entityID: entityID)
                }
            }
        }
    }
}

private struct DashboardSection<Content: View>: View {
    let title: String
    let isEmpty: Bool
    @ViewBuilder var content: Content

    var body: some View {
        if !isEmpty {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                Text(title)
                    .font(.title2.bold())

                content
            }
        }
    }
}

private struct EmptyDashboardCard: View {
    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                CardIconView(systemName: "house")
                Text("No Home Assistant entities yet")
                    .font(.headline)
                Text("Add your server URL and token in Settings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        DashboardView()
    }
    .withPreviewEnvironment()
}
#endif
