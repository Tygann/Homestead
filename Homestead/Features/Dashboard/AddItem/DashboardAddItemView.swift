import SwiftUI

struct DashboardAddItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HAStateStore.self) private var stateStore
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @State private var mode: DashboardAddItemMode
    @State private var searchText = ""
    private let onAddItem: (UUID) -> Void

    init(initialMode: DashboardAddItemMode, onAddItem: @escaping (UUID) -> Void = { _ in }) {
        _mode = State(initialValue: initialMode)
        self.onAddItem = onAddItem
    }

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .items:
                    itemsContent
                case .cards:
                    cardsContent
                }
            }
            .navigationTitle("Add to Dashboard")
            .toolbarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top, spacing: 0) { modePicker }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", role: .confirm) { dismiss() }
                }
            }
            .navigationDestination(for: DashboardAddRoute.self) { route in
                switch route {
                case .styles(let source):
                    DashboardChooseStyleView(source: source, add: add)
                case .sources(let kind):
                    DashboardCompatibleSourcesView(kind: kind, add: add)
                case .review(let source, let kind):
                    DashboardPresentationReviewView(source: source, kind: kind, add: add)
                case .options(let source, let kind):
                    DashboardPresentationOptionsView(source: source, kind: kind, add: add)
                }
            }
            .onChange(of: mode) { _, _ in searchText = "" }
        }
        .presentationDetents([.large])
    }

    private var modePicker: some View {
        Picker("Add By", selection: $mode) {
            ForEach(DashboardAddItemMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, AppSpacing.large)
        .padding(.vertical, AppSpacing.small)
        .background(Color(.systemGroupedBackground))
    }

    private var itemsContent: some View {
        List {
            if !filteredSummaries.isEmpty {
                Section("Summaries") {
                    ForEach(filteredSummaries) { candidate in
                        sourceRow(
                            source: .summary(candidate.kind),
                            title: candidate.title,
                            subtitle: candidate.value,
                            icon: .sfSymbol(candidate.systemImage, provenance: .homesteadSemanticMapping)
                        )
                    }
                }
            }

            ForEach(filteredEntityGroups) { group in
                Section {
                    ForEach(group.candidates) { candidate in
                        sourceRow(
                            source: .entity(candidate.entityID),
                            title: candidate.displayName,
                            subtitle: candidate.entityID,
                            icon: candidate.icon
                        )
                    }
                } header: {
                    Label(group.title, systemImage: group.systemImage)
                }
            }
        }
        .overlay {
            if !stateStore.hasEntities {
                ContentUnavailableView("No Items Available", systemImage: "square.grid.2x2")
            } else if filteredSummaries.isEmpty && filteredEntityGroups.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }

    private var cardsContent: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 156, maximum: 220), spacing: AppSpacing.medium)],
                spacing: AppSpacing.xLarge
            ) {
                ForEach(filteredPresentationDescriptors) { descriptor in
                    NavigationLink(value: DashboardAddRoute.sources(descriptor.kind)) {
                        DashboardPresentationGalleryTile(descriptor: descriptor)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(AppSpacing.large)
        }
        .background(Color(.systemGroupedBackground))
        .overlay {
            if filteredPresentationDescriptors.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }

    private func sourceRow(
        source: DashboardAddSource,
        title: String,
        subtitle: String,
        icon: ResolvedIcon
    ) -> some View {
        let recommendation = recommendation(for: source)
        let isAdded = recommendation.map {
            dashboardConfiguration.contains(source: source.reference, presentationKind: $0.kind)
        } ?? false

        return HStack(spacing: AppSpacing.medium) {
            NavigationLink(value: DashboardAddRoute.styles(source)) {
                Label {
                    VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                        Text(title).font(.headline).foregroundStyle(.primary).lineLimit(1)
                        Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                } icon: {
                    HomesteadIconView(icon: icon, pointSize: 18).foregroundStyle(Color.accentColor)
                }
            }
            .accessibilityHint("Choose a style")

            Button {
                guard let recommendation else { return }
                add(source, recommendation)
            } label: {
                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isAdded ? Color.secondary : Color.accentColor)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(isAdded || recommendation == nil)
            .accessibilityLabel(
                isAdded
                    ? "\(recommendation.map { DashboardPresentationCatalog.descriptor(for: $0.kind).title } ?? "Suggested style") added"
                    : "Add \(title) as \(recommendation.map { DashboardPresentationCatalog.descriptor(for: $0.kind).title } ?? "suggested style")"
            )
            .accessibilityHint(isAdded ? "" : "Adds the suggested style")
        }
        .frame(minHeight: 48)
    }

    private var filteredPresentationDescriptors: [DashboardPresentationDescriptor] {
        let query = normalizedSearch
        return DashboardPresentationCatalog.descriptors.filter {
            query.isEmpty || $0.title.localizedCaseInsensitiveContains(query)
        }
    }

    private var filteredSummaries: [DashboardAddSummaryCandidate] {
        let presentations = DashboardSummaryProvider.makeSummaries(
            kinds: DashboardSummaryKind.allCases,
            entityBoxes: stateStore.allEntityBoxes(),
            membershipContext: stateStore.dashboardSummaryMembershipContext()
        )
        return DashboardSummaryKind.allCases.compactMap { kind in
            guard let presentation = presentations[kind] else { return nil }
            let candidate = DashboardAddSummaryCandidate(
                kind: kind,
                title: presentation.title,
                value: presentation.value,
                systemImage: presentation.systemImage
            )
            guard normalizedSearch.isEmpty || candidate.title.localizedCaseInsensitiveContains(normalizedSearch)
                    || candidate.value.localizedCaseInsensitiveContains(normalizedSearch) else { return nil }
            return candidate
        }
    }

    private var filteredEntityGroups: [DashboardAddEntityCandidateGroup] {
        let candidatesByID = Dictionary(uniqueKeysWithValues: stateStore.allEntityBoxes().compactMap { entityBox -> (String, DashboardAddEntityCandidate)? in
            guard entityBox.homeEntity.isAvailable else { return nil }
            let candidate = DashboardAddEntityCandidate(
                entityID: entityBox.entityID,
                displayName: stateStore.displayNameForDeviceGroupedEntity(entityID: entityBox.entityID) ?? entityBox.homeEntity.displayName,
                state: entityBox.homeEntity.state,
                domain: entityBox.domain,
                icon: entityBox.homeEntity.resolvedIcon
            )
            guard normalizedSearch.isEmpty
                    || candidate.displayName.localizedCaseInsensitiveContains(normalizedSearch)
                    || candidate.entityID.localizedCaseInsensitiveContains(normalizedSearch)
                    || candidate.state.localizedCaseInsensitiveContains(normalizedSearch) else { return nil }
            return (entityBox.entityID, candidate)
        })

        if !stateStore.entityIDGroupsByDevice.isEmpty {
            return stateStore.entityIDGroupsByDevice.compactMap { group in
                let candidates = group.entityIDs.compactMap { candidatesByID[$0] }
                guard !candidates.isEmpty else { return nil }
                return DashboardAddEntityCandidateGroup(
                    id: "item-device-\(group.id)",
                    title: group.title,
                    systemImage: "laptopcomputer.and.iphone",
                    candidates: candidates
                )
            }
        }

        return stateStore.entityIDGroupsByDomain.compactMap { group in
            let candidates = group.entityIDs.compactMap { candidatesByID[$0] }
            guard !candidates.isEmpty else { return nil }
            return DashboardAddEntityCandidateGroup(
                id: "item-domain-\(group.domain.rawValue)",
                title: group.domain.displayName,
                systemImage: group.domain.systemImage,
                candidates: candidates
            )
        }
    }

    private var normalizedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func recommendation(for source: DashboardAddSource) -> DashboardPresentationConfiguration? {
        switch source {
        case .summary:
            .chip
        case .entity(let entityID):
            stateStore.entityBox(for: entityID).map(DashboardPresentationCatalog.recommendation(for:))
        }
    }

    private func add(_ source: DashboardAddSource, _ presentation: DashboardPresentationConfiguration) {
        guard let itemID = dashboardConfiguration.add(source: source.reference, presentation: presentation) else { return }
        HapticFeedback.selection()
        onAddItem(itemID)
    }
}

private struct DashboardPresentationGalleryTile: View {
    let descriptor: DashboardPresentationDescriptor

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            DashboardPresentationGalleryPreview(kind: descriptor.kind)
                .frame(height: DashboardPresentationGalleryPreview.previewHeight)

            Text(descriptor.title)
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .contentShape(Rectangle())
    }
}

private struct DashboardPresentationGalleryPreview: View {
    static let previewHeight = DashboardCardSize.square.renderedHeight(
        rowSpacing: AppSpacing.medium,
        cardPadding: AppSpacing.medium
    )

    let kind: DashboardPresentationKind

    @ViewBuilder
    var body: some View {
        if kind == .chip {
            DashboardChipView(presentation: DashboardPresentationGallerySamples.chip)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        } else if let entityID = DashboardPresentationGallerySamples.entityID(for: kind) {
            DashboardCardView(
                entityID: entityID,
                size: .square,
                presentationKind: kind,
                featureVisibility: .automatic,
                isPreview: true
            )
            .environment(DashboardPresentationGallerySamples.stateStore)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

@MainActor
private enum DashboardPresentationGallerySamples {
    static let stateStore: HAStateStore = {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(
                entityID: "light.gallery",
                state: "on",
                attributes: [
                    "friendly_name": .string("Living Room"),
                    "brightness": .number(184)
                ]
            ),
            HAEntityDTO(
                entityID: "sensor.gallery_temperature",
                state: "72",
                attributes: [
                    "friendly_name": .string("Hallway"),
                    "device_class": .string("temperature"),
                    "unit_of_measurement": .string("°F")
                ]
            ),
            HAEntityDTO(
                entityID: "sensor.gallery_battery",
                state: "74",
                attributes: [
                    "friendly_name": .string("Front Door Battery"),
                    "device_class": .string("battery"),
                    "unit_of_measurement": .string("%")
                ]
            ),
            HAEntityDTO(
                entityID: "camera.gallery",
                state: "idle",
                attributes: ["friendly_name": .string("Driveway")]
            ),
            HAEntityDTO(
                entityID: "weather.gallery",
                state: "partlycloudy",
                attributes: [
                    "friendly_name": .string("Home Weather"),
                    "temperature": .number(73),
                    "temperature_unit": .string("°F"),
                    "humidity": .number(56),
                    "wind_speed": .number(8),
                    "wind_speed_unit": .string("mph")
                ]
            ),
            HAEntityDTO(
                entityID: "media_player.gallery",
                state: "playing",
                attributes: [
                    "friendly_name": .string("Living Room TV"),
                    "volume_level": .number(0.42),
                    "media_title": .string("Morning Mix"),
                    "media_artist": .string("Homestead Radio")
                ]
            ),
            HAEntityDTO(
                entityID: "scene.gallery",
                state: "scening",
                attributes: ["friendly_name": .string("Movie Night")]
            )
        ])
        return store
    }()

    static let chip = DashboardChipPresentation(
        title: "Living Room",
        value: "On",
        systemImage: "lightbulb.fill",
        isActive: true,
        isAvailable: true
    )

    static func entityID(for kind: DashboardPresentationKind) -> String? {
        switch kind {
        case .chip:
            nil
        case .control:
            "light.gallery"
        case .status, .graph:
            "sensor.gallery_temperature"
        case .gauge:
            "sensor.gallery_battery"
        case .camera:
            "camera.gallery"
        case .weather:
            "weather.gallery"
        case .media:
            "media_player.gallery"
        case .action:
            "scene.gallery"
        }
    }
}

private struct DashboardCompatibleSourcesView: View {
    @Environment(HAStateStore.self) private var stateStore
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @State private var searchText = ""
    let kind: DashboardPresentationKind
    let add: (DashboardAddSource, DashboardPresentationConfiguration) -> Void

    var body: some View {
        List {
            if !filteredSummaryCandidates.isEmpty {
                Section("Summaries") {
                    ForEach(filteredSummaryCandidates) { candidate in
                        sourceLink(
                            .summary(candidate.kind),
                            title: candidate.title,
                            subtitle: candidate.value,
                            icon: .sfSymbol(candidate.systemImage, provenance: .homesteadSemanticMapping)
                        )
                    }
                }
            }

            if !filteredEntityBoxes.isEmpty {
                Section("Entities") {
                    ForEach(filteredEntityBoxes, id: \.entityID) { entityBox in
                        sourceLink(
                            .entity(entityBox.entityID),
                            title: entityBox.homeEntity.displayName,
                            subtitle: entityBox.entityID,
                            icon: entityBox.homeEntity.resolvedIcon
                        )
                    }
                }
            }
        }
        .overlay {
            if filteredSummaryCandidates.isEmpty && filteredEntityBoxes.isEmpty {
                if normalizedSearch.isEmpty {
                    ContentUnavailableView("No Compatible Items", systemImage: "square.grid.2x2")
                } else {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: "Search"
        )
        .navigationTitle(DashboardPresentationCatalog.descriptor(for: kind).title)
    }

    private var filteredEntityBoxes: [HAEntityState] {
        stateStore.allEntityBoxes().filter { entityBox in
            guard entityBox.homeEntity.isAvailable,
                  DashboardPresentationCatalog.isCompatible(kind, with: entityBox) else { return false }
            return normalizedSearch.isEmpty
                || entityBox.homeEntity.displayName.localizedCaseInsensitiveContains(normalizedSearch)
                || entityBox.entityID.localizedCaseInsensitiveContains(normalizedSearch)
                || entityBox.homeEntity.state.localizedCaseInsensitiveContains(normalizedSearch)
        }
    }

    private var filteredSummaryCandidates: [DashboardAddSummaryCandidate] {
        guard kind == .chip else { return [] }
        let summaries = DashboardSummaryProvider.makeSummaries(
            kinds: DashboardSummaryKind.allCases,
            entityBoxes: stateStore.allEntityBoxes(),
            membershipContext: stateStore.dashboardSummaryMembershipContext()
        )
        return DashboardSummaryKind.allCases.compactMap { summaryKind in
            guard let summary = summaries[summaryKind] else { return nil }
            let candidate = DashboardAddSummaryCandidate(
                kind: summaryKind,
                title: summary.title,
                value: summary.value,
                systemImage: summary.systemImage
            )
            guard normalizedSearch.isEmpty
                    || candidate.title.localizedCaseInsensitiveContains(normalizedSearch)
                    || candidate.value.localizedCaseInsensitiveContains(normalizedSearch) else { return nil }
            return candidate
        }
    }

    private var normalizedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @ViewBuilder
    private func sourceLink(
        _ source: DashboardAddSource,
        title: String,
        subtitle: String,
        icon: ResolvedIcon
    ) -> some View {
        let isAdded = dashboardConfiguration.contains(source: source.reference, presentationKind: kind)

        if isAdded {
            HStack {
                sourceLabel(title: title, subtitle: subtitle, icon: icon)
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityValue("Added")
        } else {
            NavigationLink(value: DashboardAddRoute.review(source, kind)) {
                HStack {
                    sourceLabel(title: title, subtitle: subtitle, icon: icon)
                    Spacer()
                }
            }
            .accessibilityHint("Preview and add \(DashboardPresentationCatalog.descriptor(for: kind).title)")
        }
    }

    private func sourceLabel(title: String, subtitle: String, icon: ResolvedIcon) -> some View {
        Label {
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(title).foregroundStyle(.primary).lineLimit(1)
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        } icon: {
            HomesteadIconView(icon: icon, pointSize: 18)
                .foregroundStyle(Color.accentColor)
        }
    }
}
