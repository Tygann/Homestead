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
            .searchable(text: $searchText, prompt: searchPrompt)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", role: .confirm) { dismiss() }
                }
            }
            .navigationDestination(for: DashboardAddRoute.self) { route in
                switch route {
                case .cards(let source):
                    DashboardChooseCardView(source: source, add: add)
                case .configure(let kind):
                    DashboardPresentationReviewView(kind: kind, add: addAndDismiss)
                case .review(let source, let kind):
                    DashboardPresentationReviewView(source: source, kind: kind, add: addAndDismiss)
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

    private var searchPrompt: String {
        switch mode {
        case .items:
            "Search items"
        case .cards:
            "Search cards"
        }
    }

    private var itemsContent: some View {
        let presentation = DashboardAddItemPresentation.make(
            stateStore: stateStore,
            searchText: searchText
        )
        let sourceCounts = dashboardConfiguration.sourceCounts

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
                            sourceCounts: sourceCounts
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
                            sourceCounts: sourceCounts
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
        sourceCounts: [DashboardSourceReference: Int]
    ) -> some View {
        let sourceCount = sourceCounts[source.reference, default: 0]
        let isAdded = sourceCount > 0
        let canAddAnother = source.isEntity

        return HStack(spacing: AppSpacing.medium) {
            NavigationLink(value: DashboardAddRoute.cards(source)) {
                Label {
                    VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                        HStack(spacing: AppSpacing.small) {
                            Text(title).font(.headline).foregroundStyle(.primary).lineLimit(1)

                            if isAdded {
                                Text(sourceCount == 1 ? "On Dashboard" : "\(sourceCount) on Dashboard")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
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
                Image(systemName: isAdded && !canAddAnother ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isAdded && !canAddAnother ? Color.secondary : Color.accentColor)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(isAdded && !canAddAnother)
            .accessibilityLabel(
                addAccessibilityLabel(
                    title: title,
                    presentation: recommendation,
                    isAdded: isAdded,
                    canAddAnother: canAddAnother
                )
            )
            .accessibilityHint(isAdded && !canAddAnother ? "" : "Adds the suggested style")
        }
        .frame(minHeight: 48)
    }

    private var galleryColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 156, maximum: 220), spacing: AppSpacing.medium)]
    }

    private func addAccessibilityLabel(
        title: String,
        presentation: DashboardPresentationConfiguration,
        isAdded: Bool,
        canAddAnother: Bool
    ) -> String {
        let style = DashboardPresentationCatalog.descriptor(for: presentation.kind).title
        if isAdded && canAddAnother {
            return "Add another \(title) as \(style)"
        }
        return isAdded ? "\(style) added" : "Add \(title) as \(style)"
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

    private func addAndDismiss(
        _ source: DashboardAddSource,
        _ presentation: DashboardPresentationConfiguration
    ) {
        guard dashboardConfiguration.add(source: source.reference, presentation: presentation) != nil else { return }
        HapticFeedback.selection()
        dismiss()
    }

    private func addHeader(_ title: String) {
        let itemID = dashboardConfiguration.addHeader(title: title)
        HapticFeedback.selection()
        onAddItem(itemID)
    }

    private func route(for item: DashboardAddGalleryItem) -> DashboardAddRoute? {
        switch item {
        case .presentation(let descriptor):
            .configure(descriptor.kind)
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
enum DashboardPresentationGallerySamples {
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
                    "wind_speed_unit": .string("mph"),
                    "supported_features": .number(3)
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
        seedWeatherForecast(in: store, entityID: "weather.gallery")
        return store
    }()

    static let chip = DashboardChipPresentation(
        title: "Living Room",
        value: "On",
        systemImage: "lightbulb.fill",
        isActive: true,
        isAvailable: true
    )

    static let configurationGaugeEntityID = "sensor.configuration_example"
    static let configurationControlEntityID = "climate.configuration_example"
    static let configurationStatusEntityID = "sensor.configuration_status_example"
    static let configurationCameraEntityID = "camera.configuration_example"
    static let configurationWeatherEntityID = "weather.configuration_example"
    static let configurationMediaEntityID = "media_player.configuration_example"
    static let configurationActionEntityID = "scene.configuration_example"

    // Keep pre-selection previews synthetic so they can't be mistaken for entities in the user's home.
    static let configurationStateStore: HAStateStore = {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(
                entityID: configurationControlEntityID,
                state: "heat",
                attributes: [
                    "friendly_name": .string("Example Thermostat"),
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
                entityID: configurationGaugeEntityID,
                state: "74",
                attributes: [
                    "friendly_name": .string("Example Sensor"),
                    "device_class": .string("battery"),
                    "unit_of_measurement": .string("%")
                ]
            ),
            HAEntityDTO(
                entityID: configurationStatusEntityID,
                state: "72",
                attributes: [
                    "friendly_name": .string("Example Sensor"),
                    "device_class": .string("temperature"),
                    "unit_of_measurement": .string("°F")
                ]
            ),
            HAEntityDTO(
                entityID: configurationCameraEntityID,
                state: "idle",
                attributes: ["friendly_name": .string("Example Camera")]
            ),
            HAEntityDTO(
                entityID: configurationWeatherEntityID,
                state: "partlycloudy",
                attributes: [
                    "friendly_name": .string("Example Weather"),
                    "temperature": .number(73),
                    "temperature_unit": .string("°F"),
                    "humidity": .number(56),
                    "supported_features": .number(3)
                ]
            ),
            HAEntityDTO(
                entityID: configurationMediaEntityID,
                state: "playing",
                attributes: [
                    "friendly_name": .string("Example Media"),
                    "volume_level": .number(0.42),
                    "media_title": .string("Example Track")
                ]
            ),
            HAEntityDTO(
                entityID: configurationActionEntityID,
                state: "scening",
                attributes: ["friendly_name": .string("Example Scene")]
            )
        ])
        seedWeatherForecast(in: store, entityID: configurationWeatherEntityID)
        return store
    }()

    private static func seedWeatherForecast(in store: HAStateStore, entityID: String) {
        let referenceDate = Date(timeIntervalSince1970: 1_784_515_200)
        store.entityBox(for: entityID)?.applyWeatherForecast(WeatherForecastSnapshot(
            type: .daily,
            entries: [
                WeatherForecastEntry(
                    datetime: referenceDate,
                    condition: .partlyCloudy,
                    temperature: 81,
                    lowTemperature: 68,
                    precipitation: nil,
                    precipitationProbability: 20,
                    humidity: 56,
                    isDaytime: true,
                    windSpeed: 8,
                    windBearing: 225
                ),
                WeatherForecastEntry(
                    datetime: referenceDate.addingTimeInterval(86_400),
                    condition: .rainy,
                    temperature: 76,
                    lowTemperature: 65,
                    precipitation: nil,
                    precipitationProbability: 70,
                    humidity: 72,
                    isDaytime: true,
                    windSpeed: 11,
                    windBearing: 180
                ),
                WeatherForecastEntry(
                    datetime: referenceDate.addingTimeInterval(172_800),
                    condition: .sunny,
                    temperature: 84,
                    lowTemperature: 67,
                    precipitation: nil,
                    precipitationProbability: 5,
                    humidity: 48,
                    isDaytime: true,
                    windSpeed: 6,
                    windBearing: 250
                )
            ],
            receivedAt: referenceDate
        ))
    }

    static func configurationEntityID(for kind: DashboardPresentationKind) -> String? {
        switch kind {
        case .chip:
            nil
        case .control:
            configurationControlEntityID
        case .status, .graph:
            configurationStatusEntityID
        case .circularGauge, .segmentedGauge, .barGauge:
            configurationGaugeEntityID
        case .camera:
            configurationCameraEntityID
        case .weather:
            configurationWeatherEntityID
        case .media:
            configurationMediaEntityID
        case .action:
            configurationActionEntityID
        }
    }

    static func entityID(for kind: DashboardPresentationKind) -> String? {
        switch kind {
        case .chip:
            nil
        case .control:
            "climate.gallery"
        case .status, .graph:
            "sensor.gallery_temperature"
        case .circularGauge, .segmentedGauge, .barGauge:
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
