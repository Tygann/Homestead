import SwiftUI

struct PeopleSettingsView: View {
    @Environment(HAStateStore.self) private var stateStore

    var body: some View {
        let records = stateStore.presenceRecords()
        let presentation = HAPersonPresencePresentation.make(
            records: records,
            searchText: ""
        )

        List {
            if !presentation.people.isEmpty {
                PeopleLandingHeader(records: presentation.people)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 6, trailing: 20))
                    .listRowSeparator(.hidden)

                Section {
                    ForEach(presentation.people) { record in
                        NavigationLink {
                            PersonPresenceDetailView(entityID: record.entityID)
                        } label: {
                            PeoplePresenceRow(record: record)
                        }
                    }
                }
            }
        }
        .overlay {
            if records.filter(\.isPerson).isEmpty || presentation.people.isEmpty {
                ContentUnavailableView("No People", systemImage: "person.2")
            }
        }
        .navigationTitle("")
        .toolbarTitleDisplayMode(.inline)
    }
}

private struct PeopleLandingHeader: View {
    let records: [HAPresenceRecord]

    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            PeoplePresenceAvatarStackView(records: records, size: 68)

            Text("People")
//                .font(.title2.weight(.semibold))
//                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 2)
    }
}

private struct PeoplePresenceRow: View {
    let record: HAPresenceRecord

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            PeoplePresenceAvatarView(record: record, size: 40)

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(record.displayName)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
            }

            Spacer(minLength: AppSpacing.medium)

            PeoplePresenceStatusBadge(status: record.status)
        }
        .padding(.vertical, AppSpacing.xSmall)
    }
}

struct PersonPresenceDetailView: View {
    @Environment(HAStateStore.self) private var stateStore
    @Environment(HomeAssistantService.self) private var homeAssistantService

    let entityID: String
    var presentationStyle: EntityDetailPresentationStyle = .navigation

    var body: some View {
        Group {
            if let record {
                Form {
                    headerSection(record)
                    detailsSection(record)
                    relationshipsSection(record)
                    contextSection(record)
                    activitySection(record)
                    entityDetailsSection(record)
                }
            } else {
                ContentUnavailableView("Presence Missing", systemImage: "person.2")
                    .background(Color(.systemGroupedBackground))
            }
        }
        .entityDetailPresentation(
            title: record?.displayName ?? "Presence",
            style: presentationStyle
        )
    }

    private var record: HAPresenceRecord? {
        stateStore.presenceRecord(for: entityID)
    }

    private var detailState: EntityDetailStatePresentation? {
        stateStore.entityBox(for: entityID).map {
            EntityDetailStatePresentation.resolve(
                entityBox: $0,
                service: homeAssistantService
            )
        }
    }

    private func headerSection(_ record: HAPresenceRecord) -> some View {
        Section {
            HStack(spacing: AppSpacing.medium) {
                PeoplePresenceAvatarView(record: record, size: 56)

                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(record.displayName)
                        .font(.title3.weight(.semibold))
                        .lineLimit(2)

                    Text(record.status.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(record.status.tint)
                        .lineLimit(1)
                }

                Spacer(minLength: AppSpacing.medium)
            }
            .padding(.vertical, AppSpacing.xSmall)

            if let detailState,
               let message = detailState.message {
                EntityDetailStateMessage(
                    state: detailState.operationalState,
                    message: message
                )
            }
        }
    }

    @ViewBuilder
    private func detailsSection(_ record: HAPresenceRecord) -> some View {
        if record.hasPresenceDetails {
            Section("Details") {
                if let gpsAccuracyText = record.gpsAccuracyText {
                    LabeledContent("Accuracy", value: gpsAccuracyText)
                }

                if let lastChanged = record.lastChanged {
                    LabeledContent("Changed") {
                        Text(lastChanged.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                }

                if let lastUpdated = record.lastUpdated, record.lastUpdated != record.lastChanged {
                    LabeledContent("Updated") {
                        Text(lastUpdated.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func relationshipsSection(_ record: HAPresenceRecord) -> some View {
        if record.isPerson {
            Section("Trackers") {
                if record.linkedTrackers.isEmpty {
                    Label("No active tracker", systemImage: "location.slash")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(record.linkedTrackers) { tracker in
                        if let trackerBox = stateStore.entityBox(for: tracker.entityID) {
                            NavigationLink {
                                EntityDetailSheet(
                                    entityBox: trackerBox,
                                    presentationStyle: .navigation
                                )
                            } label: {
                                trackerLabel(tracker)
                            }
                        } else {
                            trackerLabel(tracker)
                        }
                    }
                }
            }
        } else if let linkedPersonName = record.linkedPersonName {
            Section("Person") {
                Label(linkedPersonName, systemImage: "person.fill")
            }
        }
    }

    private func trackerLabel(_ tracker: HAPresenceTrackerSummary) -> some View {
        Label {
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(tracker.displayName)
                Text(tracker.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        } icon: {
            Image(systemName: tracker.status.systemImage)
                .foregroundStyle(tracker.status.tint)
        }
    }

    @ViewBuilder
    private func contextSection(_ record: HAPresenceRecord) -> some View {
        if record.hasContext {
            Section("Context") {
                if let areaName = record.context.areaName {
                    LabeledContent("Area", value: areaName)
                }

                if let floorName = record.context.floorName {
                    LabeledContent("Floor", value: floorName)
                }

                if let deviceName = record.context.deviceName {
                    LabeledContent("Device", value: deviceName)
                }
            }
        }
    }

    private func activitySection(_ record: HAPresenceRecord) -> some View {
        Section {
            EntityActivityPreview(
                entityID: record.entityID,
                source: .stateHistory,
                tint: record.status.tint
            )
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private func entityDetailsSection(_ record: HAPresenceRecord) -> some View {
        if let entityBox = stateStore.entityBox(for: record.entityID) {
            Section {
                NavigationLink {
                    EntityDiagnosticsView(
                        entityBox: entityBox,
                        presentationStyle: .navigation
                    )
                } label: {
                    SettingsNavigationRowLabel("Entity Details", systemImage: "info.circle")
                }
            }
        }
    }
}

private struct PeoplePresenceStatusBadge: View {
    let status: HAPresenceStatus

    var body: some View {
        Text(status.shortTitle)
            .font(.caption.weight(.semibold))
            .foregroundStyle(status.tint)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.tint.opacity(0.12), in: Capsule())
    }
}

private extension HAPresenceRecord {
    var hasPresenceDetails: Bool {
        gpsAccuracyText != nil || lastChanged != nil || (lastUpdated != nil && lastUpdated != lastChanged)
    }

    var hasContext: Bool {
        context.areaName != nil || context.floorName != nil || context.deviceName != nil
    }
}

#if DEBUG
#Preview("People Settings") {
    NavigationStack {
        PeopleSettingsView()
    }
    .withPreviewEnvironment()
}
#endif
