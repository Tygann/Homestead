import SwiftUI

struct DashboardAddItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HAStateStore.self) private var stateStore
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @State private var mode: DashboardAddItemMode
    @State private var searchText = ""
    @State private var galleryFilter: DashboardAddGalleryFilter = .all
    @State private var plannedCardNotice: DashboardPlannedGalleryCard?
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
//            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
            .searchable(text: $searchText)
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
                case .header:
                    DashboardAddHeaderView(add: addHeader)
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
        let presentation = DashboardAddItemPresentation.make(
            stateStore: stateStore,
            searchText: searchText
        )
        let addedPresentationIdentities = dashboardConfiguration.presentationIdentities

        return List {
            if !presentation.summaryCandidates.isEmpty {
                Section("Summaries") {
                    ForEach(presentation.summaryCandidates) { candidate in
                        sourceRow(
                            source: .summary(candidate.kind),
                            title: candidate.title,
                            subtitle: candidate.value,
                            icon: .sfSymbol(candidate.systemImage, provenance: .homesteadSemanticMapping),
                            recommendation: .chip,
                            addedPresentationIdentities: addedPresentationIdentities
                        )
                    }
                }
            }

            ForEach(presentation.entityGroups) { group in
                Section {
                    ForEach(group.candidates) { candidate in
                        sourceRow(
                            source: .entity(candidate.entityID),
                            title: candidate.displayName,
                            subtitle: candidate.entityID,
                            icon: candidate.icon,
                            recommendation: candidate.suggestedPresentation,
                            addedPresentationIdentities: addedPresentationIdentities
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
            } else if presentation.summaryCandidates.isEmpty && presentation.entityGroups.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }

    private var cardsContent: some View {
        VStack(spacing: 0) {
            galleryFilters

            ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.xxLarge) {
                ForEach(filteredGallerySections) { section in
                    VStack(alignment: .leading, spacing: AppSpacing.large) {
                        Text(section.title)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, AppSpacing.xSmall)

                        LazyVGrid(columns: galleryColumns, spacing: AppSpacing.xLarge) {
                            ForEach(section.items) { item in
                                galleryItem(item)
                            }
                        }
                    }
                }
            }
            .padding(AppSpacing.large)
        }
        .background(Color(.systemGroupedBackground))
        .overlay {
            if filteredGallerySections.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
            }
        }
        .alert("Not Available Yet", isPresented: plannedNoticeIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(plannedNoticeMessage)
        }
    }

    private var galleryFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.small) {
                ForEach(DashboardAddGalleryFilter.allCases) { filter in
                    Button {
                        galleryFilter = filter
                        HapticFeedback.selection()
                    } label: {
                        Text(filter.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(galleryFilter == filter ? .white : .primary)
                            .padding(.horizontal, AppSpacing.medium)
                            .frame(minHeight: 36)
                            .background(
                                galleryFilter == filter ? Color.accentColor : Color(.secondarySystemGroupedBackground),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(galleryFilter == filter ? "Selected" : "")
                }
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.small)
        }
        .background(Color(.systemGroupedBackground))
    }

    @ViewBuilder
    private func galleryItem(_ item: DashboardAddGalleryItem) -> some View {
        switch item {
        case .planned(let card):
            Button {
                plannedCardNotice = card
            } label: {
                DashboardPresentationGalleryTile(item: item)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Not available yet")
        case .presentation, .header:
            if let route = route(for: item) {
                NavigationLink(value: route) {
                    DashboardPresentationGalleryTile(item: item)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func sourceRow(
        source: DashboardAddSource,
        title: String,
        subtitle: String,
        icon: ResolvedIcon,
        recommendation: DashboardPresentationConfiguration,
        addedPresentationIdentities: Set<DashboardPresentationIdentity>
    ) -> some View {
        let identity = DashboardPresentationIdentity(
            source: source.reference,
            presentation: recommendation
        )
        let isAdded = addedPresentationIdentities.contains(identity)

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
                add(source, recommendation)
            } label: {
                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isAdded ? Color.secondary : Color.accentColor)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(isAdded)
            .accessibilityLabel(
                isAdded
                    ? "\(DashboardPresentationCatalog.descriptor(for: recommendation.kind).title) added"
                    : "Add \(title) as \(DashboardPresentationCatalog.descriptor(for: recommendation.kind).title)"
            )
            .accessibilityHint(isAdded ? "" : "Adds the suggested style")
        }
        .frame(minHeight: 48)
    }

    private var galleryColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 156, maximum: 220), spacing: AppSpacing.medium)]
    }

    private var filteredGallerySections: [DashboardAddGallerySectionContent] {
        let query = normalizedSearch
        return DashboardAddGalleryCatalog.sections.compactMap { section in
            let items = section.items.filter {
                galleryFilter.matches($0)
                    && (query.isEmpty || $0.title.localizedCaseInsensitiveContains(query))
            }
            guard !items.isEmpty else { return nil }
            return DashboardAddGallerySectionContent(section: section, items: items)
        }
    }

    private var normalizedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func add(_ source: DashboardAddSource, _ presentation: DashboardPresentationConfiguration) {
        guard let itemID = dashboardConfiguration.add(source: source.reference, presentation: presentation) else { return }
        HapticFeedback.selection()
        onAddItem(itemID)
    }

    private func addHeader(_ title: String) {
        let itemID = dashboardConfiguration.addHeader(title: title)
        HapticFeedback.selection()
        onAddItem(itemID)
    }

    private func route(for item: DashboardAddGalleryItem) -> DashboardAddRoute? {
        switch item {
        case .presentation(let descriptor):
            .sources(descriptor.kind)
        case .header:
            .header
        case .planned:
            nil
        }
    }

    private var plannedNoticeIsPresented: Binding<Bool> {
        Binding(
            get: { plannedCardNotice != nil },
            set: { isPresented in
                if !isPresented { plannedCardNotice = nil }
            }
        )
    }

    private var plannedNoticeMessage: String {
        guard let plannedCardNotice else { return "This card hasn’t been built yet." }
        return "\(plannedCardNotice.title) hasn’t been built yet."
    }
}

private struct DashboardAddGallerySectionContent: Identifiable {
    let section: DashboardAddGallerySection
    let items: [DashboardAddGalleryItem]

    var id: DashboardAddGallerySection { section }
    var title: String { section.rawValue }
}

private struct DashboardPresentationGalleryTile: View {
    let item: DashboardAddGalleryItem

    var body: some View {
        VStack(alignment: .center, spacing: AppSpacing.small) {
            Text(item.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(item.isPlanned ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .center)

            DashboardPresentationGalleryPreview(item: item)
                .frame(height: item.previewHeight)
        }
        .contentShape(Rectangle())
    }
}

private struct DashboardPresentationGalleryPreview: View {
    static let cardPreviewHeight = DashboardCardSize.square.renderedHeight(
        rowSpacing: AppSpacing.medium,
        cardPadding: AppSpacing.medium
    )
    static let layoutPreviewHeight: CGFloat = 72
    static let plannedPreviewHeight: CGFloat = 88

    let item: DashboardAddGalleryItem

    @ViewBuilder
    var body: some View {
        switch item {
        case .presentation(let descriptor) where descriptor.kind == .chip:
            DashboardChipView(presentation: DashboardPresentationGallerySamples.chip)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        case .presentation(let descriptor):
            if let entityID = DashboardPresentationGallerySamples.entityID(for: descriptor.kind) {
                DashboardCardView(
                    entityID: entityID,
                    size: .square,
                    presentationKind: descriptor.kind,
                    featureVisibility: .automatic,
                    isPreview: true
                )
                .environment(DashboardPresentationGallerySamples.stateStore)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        case .header:
            DashboardHeaderCardView(title: "Living Room")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        case .planned(let card):
            VStack(spacing: AppSpacing.xSmall) {
                Image(systemName: card.systemImage)
                    .font(.system(size: 32, weight: .medium))

                Text("Coming Later")
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(.secondary)
            .opacity(0.72)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityHidden(true)
        }
    }
}

private extension DashboardAddGalleryItem {
    var previewHeight: CGFloat {
        switch self {
        case .header:
            DashboardPresentationGalleryPreview.layoutPreviewHeight
        case .presentation(let descriptor):
            descriptor.kind == .chip
                ? DashboardPresentationGalleryPreview.layoutPreviewHeight
                : DashboardPresentationGalleryPreview.cardPreviewHeight
        case .planned:
            DashboardPresentationGalleryPreview.plannedPreviewHeight
        }
    }
}

@MainActor
private enum DashboardPresentationGallerySamples {
    static let stateStore: HAStateStore = {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(
                entityID: "climate.gallery",
                state: "heat",
                attributes: [
                    "friendly_name": .string("Thermostat"),
                    "current_temperature": .number(70),
                    "temperature": .number(72),
                    "temperature_unit": .string("°F"),
                    "min_temp": .number(50),
                    "max_temp": .number(90),
                    "target_temp_step": .number(1),
                    "hvac_modes": .array([.string("off"), .string("heat"), .string("cool")])
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
            "climate.gallery"
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

private struct DashboardAddHeaderView: View {
    @State private var title = "New Section"
    @State private var isAdded = false
    let add: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                TextField("Header Title", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)

                DashboardHeaderCardView(title: previewTitle)
                    .allowsHitTesting(false)

                Button {
                    add(normalizedTitle)
                    isAdded = true
                } label: {
                    Label(isAdded ? "Added" : "Add Header", systemImage: isAdded ? "checkmark" : "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(normalizedTitle.isEmpty || isAdded)
            }
            .padding(AppSpacing.large)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Header")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var normalizedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var previewTitle: String {
        normalizedTitle.isEmpty ? "Header" : normalizedTitle
    }
}

private struct DashboardCompatibleSourcesView: View {
    @Environment(HAStateStore.self) private var stateStore
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @State private var searchText = ""
    let kind: DashboardPresentationKind
    let add: (DashboardAddSource, DashboardPresentationConfiguration) -> Void

    var body: some View {
        let summaryCandidates = filteredSummaryCandidates
        let entityBoxes = filteredEntityBoxes
        let addedPresentationIdentities = dashboardConfiguration.presentationIdentities

        List {
            if !summaryCandidates.isEmpty {
                Section("Summaries") {
                    ForEach(summaryCandidates) { candidate in
                        sourceLink(
                            .summary(candidate.kind),
                            title: candidate.title,
                            subtitle: candidate.value,
                            icon: .sfSymbol(candidate.systemImage, provenance: .homesteadSemanticMapping),
                            addedPresentationIdentities: addedPresentationIdentities
                        )
                    }
                }
            }

            if !entityBoxes.isEmpty {
                Section("Entities") {
                    ForEach(entityBoxes, id: \.entityID) { entityBox in
                        sourceLink(
                            .entity(entityBox.entityID),
                            title: entityBox.homeEntity.displayName,
                            subtitle: entityBox.entityID,
                            icon: entityBox.homeEntity.resolvedIcon,
                            addedPresentationIdentities: addedPresentationIdentities
                        )
                    }
                }
            }
        }
        .overlay {
            if summaryCandidates.isEmpty && entityBoxes.isEmpty {
                if normalizedSearch.isEmpty {
                    ContentUnavailableView("No Compatible Items", systemImage: "square.grid.2x2")
                } else {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
//        .searchable(
//            text: $searchText,
//            placement: .navigationBarDrawer(displayMode: .automatic),
//            prompt: "Search"
//        )
        .searchable(text: $searchText)
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
        icon: ResolvedIcon,
        addedPresentationIdentities: Set<DashboardPresentationIdentity>
    ) -> some View {
        let presentation = source.defaultPresentation(kind: kind, stateStore: stateStore)
        let isAdded = presentation.map { presentation in
            addedPresentationIdentities.contains(
                DashboardPresentationIdentity(source: source.reference, presentation: presentation)
            )
        } ?? false
        let hasMultipleStyles = source.styleDescriptors(kind: kind, stateStore: stateStore).count > 1

        if isAdded && !hasMultipleStyles {
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
                    if isAdded {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                }
            }
            .accessibilityValue(isAdded ? "Default style added" : "")
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
