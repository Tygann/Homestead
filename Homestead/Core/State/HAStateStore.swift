import Foundation
import Observation
import WidgetKit

@MainActor
@Observable
final class HAStateStore {
    // MARK: - Properties

    @ObservationIgnored private(set) var entitiesByID: [String: HomeEntity] = [:]
    private(set) var allEntities: [HomeEntity] = []
    private(set) var entitiesByDomain: [(domain: EntityDomain, entities: [HomeEntity])] = []
    private(set) var entityIDGroupsByDomain: [EntityDomainGroup] = []
    private(set) var entityIDGroupsByDevice: [EntityDeviceGroup] = []
    private(set) var entityIDsByDisplayName: [String] = []
    private(set) var availableEntityIDs: Set<String> = []
    private(set) var entityCatalogSignature = ""
    private(set) var hasEntities = false
    private(set) var hasLoadedInitialSnapshot = false
    private(set) var weatherSolarPhase: WeatherSolarPhase?
    private(set) var dataSourceID: String?
    @ObservationIgnored private(set) var lightEntitiesByID: [String: LightEntity] = [:]
    @ObservationIgnored private(set) var climateEntitiesByID: [String: ClimateEntity] = [:]
    @ObservationIgnored private(set) var coverEntitiesByID: [String: CoverEntity] = [:]
    @ObservationIgnored private(set) var fanEntitiesByID: [String: FanEntity] = [:]
    @ObservationIgnored private(set) var mediaPlayerEntitiesByID: [String: MediaPlayerEntity] = [:]
    @ObservationIgnored private(set) var sensorEntitiesByID: [String: SensorEntity] = [:]
    @ObservationIgnored private(set) var binarySensorEntitiesByID: [String: BinarySensorEntity] = [:]
    @ObservationIgnored private(set) var weatherEntitiesByID: [String: WeatherEntity] = [:]
    @ObservationIgnored private(set) var selectEntitiesByID: [String: SelectEntity] = [:]
    @ObservationIgnored private(set) var numberEntitiesByID: [String: NumberEntity] = [:]
    private(set) var updateEntities: [HAUpdateEntity] = []
    @ObservationIgnored private var rawEntitiesByID: [String: HAEntityDTO] = [:]
    @ObservationIgnored private var iconResolutionInputsByID: [String: EntityIconResolutionInput] = [:]
    @ObservationIgnored private var resolvedIconsByID: [String: ResolvedIcon] = [:]
    @ObservationIgnored private(set) var iconResolutionCount = 0
    @ObservationIgnored private var entityBoxesByID: [String: HAEntityState] = [:]
    @ObservationIgnored private var pendingCommandsByID: [String: HAEntityPendingCommand] = [:]
    @ObservationIgnored private var entityRegistryByID: [String: HAEntityRegistryDisplayDTO] = [:]
    @ObservationIgnored private var deviceRegistryByID: [String: HADeviceRegistryDTO] = [:]
    @ObservationIgnored private var areaRegistryByID: [String: HAAreaRegistryDTO] = [:]
    @ObservationIgnored private var floorRegistryByID: [String: HAFloorRegistryDTO] = [:]
    @ObservationIgnored private var organizationByEntityID: [String: HAEntityOrganizationDTO] = [:]
    @ObservationIgnored private var labelRegistryByID: [String: HALabelRegistryDTO] = [:]
    @ObservationIgnored private var categoryRegistryByKey: [String: HACategoryRegistryDTO] = [:]
    @ObservationIgnored private var floorSortOrderByID: [String: Int] = [:]
    @ObservationIgnored private var cachedDashboardSummaryMembershipContext: DashboardSummaryMembershipContext?
    @ObservationIgnored private var cachedDashboardSummaryWorkspace: DashboardSummaryWorkspace?
    @ObservationIgnored private var isApplyingSnapshotBatch = false
    @ObservationIgnored private var snapshotBatchNeedsWidgetSave = false
    @ObservationIgnored private var isApplyingLiveStateBatch = false
    @ObservationIgnored private var liveStateBatchNeedsWidgetSave = false
    @ObservationIgnored private var widgetSnapshotSequence: UInt64 = 0
    @ObservationIgnored private var lastPersistedWidgetPayloadByProfileID: [UUID: WidgetSnapshotPersistence.Payload] = [:]
    @ObservationIgnored private let widgetSnapshotPersistenceCoordinator = WidgetSnapshotPersistenceCoordinator()
    @ObservationIgnored private var pendingWidgetReloadKinds: Set<HomesteadWidgetKind> = []
    @ObservationIgnored private var widgetReloadTask: Task<Void, Never>?
    @ObservationIgnored private var lastWidgetReloadDate: Date?

    // MARK: - Public API

    var lightEntityIDs: [String] {
        entityIDs(for: .light)
    }

    var sensorEntityIDs: [String] {
        entityIDs(for: .sensor)
    }

    func entities(for domain: EntityDomain) -> [HomeEntity] {
        allEntities.filter { $0.domain == domain }
    }

    func entity(for entityID: String) -> HomeEntity? {
        entitiesByID[entityID]
    }

    func displayName(for entityID: String) -> String? {
        entitiesByID[entityID]?.displayName
    }

    func entityBox(for entityID: String) -> HAEntityState? {
        entityBoxesByID[entityID]
    }

    func rawEntity(for entityID: String) -> HAEntityDTO? {
        rawEntitiesByID[entityID]
    }

    func rawEntitySnapshot() -> [HAEntityDTO] {
        rawEntitiesByID.values.sorted { lhs, rhs in
            lhs.entityID.localizedCaseInsensitiveCompare(rhs.entityID) == .orderedAscending
        }
    }

    func registryMetadataSnapshot() -> HARegistryMetadataSnapshot? {
        guard !entityRegistryByID.isEmpty || !deviceRegistryByID.isEmpty || !areaRegistryByID.isEmpty || !floorRegistryByID.isEmpty else {
            return nil
        }

        return HARegistryMetadataSnapshot(
            entities: entityRegistryByID.values.sorted {
                $0.entityID.localizedCaseInsensitiveCompare($1.entityID) == .orderedAscending
            },
            devices: deviceRegistryByID.values.sorted {
                $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending
            },
            areas: areaRegistryByID.values.sorted {
                $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending
            },
            floors: floorRegistryByID.values.sorted {
                floorSortOrderByID[$0.id, default: Int.max] < floorSortOrderByID[$1.id, default: Int.max]
            }
        )
    }

    func allEntityBoxes() -> [HAEntityState] {
        allEntities.compactMap { entityBoxesByID[$0.entityID] }
    }

    func dashboardSuggestionCandidates() -> [DashboardSuggestionCandidate] {
        allEntityBoxes().map { entityBox in
            let metadata = entityRegistryByID[entityBox.entityID]
            return DashboardSuggestionCandidate(
                entityID: entityBox.entityID,
                domain: entityBox.domain,
                displayName: entityBox.homeEntity.displayName,
                isAvailable: entityBox.homeEntity.isAvailable,
                isHidden: metadata?.hiddenBy == true,
                entityCategory: metadata?.entityCategory?.nonEmptyValue
                    ?? metadata?.entityCategoryIndex.map(String.init),
                deviceClass: entityBox.sensorEntity?.deviceClass ?? entityBox.coverEntity?.deviceClass,
                presentation: DashboardPresentationCatalog.recommendation(for: entityBox)
            )
        }
    }

    func pendingCommand(for entityID: String) -> HAEntityPendingCommand? {
        pendingCommandsByID[entityID]
    }

    func entityRegistryMetadata(for entityID: String) -> HAEntityRegistryDisplayDTO? {
        entityRegistryByID[entityID]
    }

    func entityRegistryUniqueID(for entityID: String) -> String? {
        organizationByEntityID[entityID]?.uniqueID
    }

    func deviceRegistryMetadata(for deviceID: String) -> HADeviceRegistryDTO? {
        deviceRegistryByID[deviceID]
    }

    func deviceName(forDeviceID deviceID: String) -> String? {
        guard let device = deviceRegistryByID[deviceID] else { return nil }
        return device.nameByUser?.nonEmptyValue
            ?? device.name?.nonEmptyValue
            ?? device.manufacturer?.nonEmptyValue
    }

    func deviceRegistryMetadata(forEntityID entityID: String) -> HADeviceRegistryDTO? {
        entityRegistryByID[entityID]?.deviceID.flatMap { deviceRegistryByID[$0] }
    }

    func managementAreaName(for entityID: String) -> String? {
        managementArea(for: entityID)?.name.nonEmptyValue
    }

    func managementArea(for entityID: String) -> HAAreaRegistryDTO? {
        areaID(for: entityID)?.nonEmptyValue.flatMap { areaRegistryByID[$0] }
    }

    func managementCategory(for entityID: String, scope: HAOrganizationScope) -> HACategoryRegistryDTO? {
        guard let categoryID = organizationByEntityID[entityID]?.categories[scope.rawValue] else { return nil }
        return categoryRegistryByKey[Self.categoryKey(scope: scope, id: categoryID)]
    }

    func managementLabels(for entityID: String) -> [HALabelRegistryDTO] {
        (organizationByEntityID[entityID]?.labels ?? []).compactMap { labelRegistryByID[$0] }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func managementOrganizationDetail(for entityID: String, scope: HAOrganizationScope?) -> String? {
        let values = [
            managementAreaName(for: entityID),
            scope.flatMap { managementCategory(for: entityID, scope: $0)?.name }
        ].compactMap { $0?.nonEmptyValue }
        return values.isEmpty ? entityRegistryAdminDetail(for: entityID) : values.joined(separator: " • ")
    }

    func managementSearchMetadata(for entityID: String, scope: HAOrganizationScope?) -> String {
        [
            managementAreaName(for: entityID),
            scope.flatMap { managementCategory(for: entityID, scope: $0)?.name },
            managementLabels(for: entityID).map(\.name).joined(separator: " ")
        ].compactMap { $0?.nonEmptyValue }.joined(separator: " ")
    }

    func managementActivityDate(for entityID: String) -> Date? {
        guard let dto = rawEntitiesByID[entityID] else { return nil }
        if let value = dto.attributes["last_triggered"]?.stringValue {
            return HADateParser.date(from: value)
        }
        if entityID.hasPrefix("scene."), let date = HADateParser.date(from: dto.state) {
            return date
        }
        return nil
    }

    func allManagementLabels(among entityIDs: Set<String>) -> [HALabelRegistryDTO] {
        let usedIDs = Set(entityIDs.flatMap { organizationByEntityID[$0]?.labels ?? [] })
        return usedIDs.compactMap { labelRegistryByID[$0] }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func deviceManagementSummaries() -> [HADeviceManagementSummary] {
        let entityMetadataByDeviceID = Dictionary(
            grouping: entityRegistryByID.values.compactMap { metadata -> (String, HAEntityRegistryDisplayDTO)? in
                guard let deviceID = metadata.deviceID?.nonEmptyValue else { return nil }
                return (deviceID, metadata)
            },
            by: { $0.0 }
        ).mapValues { entries in entries.map { $0.1 } }

        return deviceRegistryByID.values
            .map { device in
                let areaName = device.areaID?.nonEmptyValue.flatMap { areaRegistryByID[$0]?.name.nonEmptyValue }
                let manufacturer = device.manufacturer?.nonEmptyValue
                let model = device.model?.nonEmptyValue
                let metadataEntries = entityMetadataByDeviceID[device.id, default: []]
                let entityIDs = metadataEntries
                    .map(\.entityID)
                    .filter { entitiesByID[$0] != nil }
                    .sortedByEntityDisplayName(in: entitiesByID)
                let platform = primaryPlatform(from: metadataEntries)

                return HADeviceManagementSummary(
                    id: device.id,
                    title: device.displayName,
                    subtitle: deviceManagementSubtitle(
                        manufacturer: manufacturer,
                        model: model,
                        areaName: areaName
                    ),
                    areaName: areaName,
                    manufacturer: manufacturer,
                    model: model,
                    platform: platform,
                    labels: device.labels.compactMap { labelRegistryByID[$0]?.name }.sorted(),
                    entityIDs: entityIDs,
                    unavailableEntityCount: entityIDs.filter { entitiesByID[$0]?.isAvailable == false }.count
                )
            }
            .sorted { lhs, rhs in
                lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    func integrationManagementSummaries() -> [HAIntegrationManagementSummary] {
        let devicesByID = Dictionary(uniqueKeysWithValues: deviceManagementSummaries().map { ($0.id, $0) })

        return Dictionary(grouping: entityRegistryByID.values) { metadata in
            metadata.platform?.nonEmptyValue ?? "unknown"
        }
        .map { platform, metadataEntries in
            let entityIDs = metadataEntries.map(\.entityID).filter { entitiesByID[$0] != nil }
            let deviceIDs = Set(metadataEntries.compactMap { $0.deviceID?.nonEmptyValue })
            let devices = deviceIDs
                .compactMap { devicesByID[$0] }
                .sorted { lhs, rhs in
                    lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
            let unavailableCount = entityIDs.filter { entitiesByID[$0]?.isAvailable == false }.count
            let hiddenCount = metadataEntries.filter { $0.hiddenBy == true }.count
            let configEntityCount = metadataEntries.filter { $0.entityCategory == "config" || $0.entityCategoryIndex == 0 }.count
            let diagnosticEntityCount = metadataEntries.filter { $0.entityCategory == "diagnostic" || $0.entityCategoryIndex == 1 }.count

            return HAIntegrationManagementSummary(
                id: platform,
                title: Self.displayName(forIntegrationPlatform: platform),
                platform: platform,
                entityIDs: entityIDs.sortedByEntityDisplayName(in: entitiesByID),
                devices: devices,
                unavailableEntityCount: unavailableCount,
                hiddenEntityCount: hiddenCount,
                configEntityCount: configEntityCount,
                diagnosticEntityCount: diagnosticEntityCount
            )
        }
        .filter { !$0.entityIDs.isEmpty }
        .sorted { lhs, rhs in
            lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    func helperEntityIDs() -> Set<String> {
        Set(allEntities.compactMap { entity in
            HAHelperDomain(entityID: entity.entityID) == nil ? nil : entity.entityID
        })
    }

    func helperManagementSummaries() -> [HAHelperManagementSummary] {
        Dictionary(grouping: allEntities.filter { HAHelperDomain(entityID: $0.entityID) != nil }) { entity in
            HAHelperDomain(entityID: entity.entityID) ?? .inputBoolean
        }
        .map { helperDomain, entities in
            HAHelperManagementSummary(
                domain: helperDomain,
                entityIDs: entities.sortedByDisplayName.map(\.entityID),
                unavailableEntityCount: entities.filter { !$0.isAvailable }.count
            )
        }
        .sorted { lhs, rhs in
            lhs.domain.displayName.localizedCaseInsensitiveCompare(rhs.domain.displayName) == .orderedAscending
        }
    }

    func entityRegistryAdminDetail(for entityID: String) -> String? {
        guard let entity = entitiesByID[entityID] else {
            return nil
        }

        let registry = entityRegistryByID[entityID]
        let deviceName = registry?.deviceID?.nonEmptyValue.flatMap { deviceRegistryByID[$0]?.displayName.nonEmptyValue }
        let areaName = areaName(for: entityID)

        var parts: [String] = []

        if let areaName {
            parts.append(areaName)
        }

        if let deviceName {
            parts.append(deviceName)
        }

        if let entityCategory = registry?.entityCategory?.nonEmptyValue {
            parts.append(entityCategory.replacingOccurrences(of: "_", with: " ").capitalized)
        }

        if registry?.hiddenBy == true {
            parts.append("Hidden")
        }

        if !entity.isAvailable {
            parts.append("Unavailable")
        }

        return parts.isEmpty ? entity.domain.displayName : parts.joined(separator: " • ")
    }

    func areaName(for entityID: String) -> String? {
        areaContext(for: entityID)?.name
    }

    func areaName(forAreaID areaID: String) -> String? {
        areaRegistryByID[areaID]?.name.nonEmptyValue
    }

    func automationTargetName(for registryID: String) -> String? {
        areaRegistryByID[registryID]?.name.nonEmptyValue
            ?? floorRegistryByID[registryID]?.name.nonEmptyValue
            ?? labelRegistryByID[registryID]?.name.nonEmptyValue
    }

    func areaContext(for entityID: String) -> DashboardAreaContext? {
        guard let areaID = areaID(for: entityID),
              let areaName = areaRegistryByID[areaID]?.name.nonEmptyValue else {
            return nil
        }

        let floorID = areaRegistryByID[areaID]?.floorID?.nonEmptyValue
        let floor = floorID.flatMap { floorRegistryByID[$0] }

        return DashboardAreaContext(
            areaID: areaID,
            name: areaName,
            icon: areaRegistryByID[areaID]?.icon?.nonEmptyValue,
            floorID: floor?.id,
            floorName: floor?.name.nonEmptyValue,
            floorLevel: floor?.level,
            floorSortOrder: floor.flatMap { floorSortOrderByID[$0.id] }
        )
    }

    func areaID(for entityID: String) -> String? {
        if let areaID = entityRegistryByID[entityID]?.areaID?.nonEmptyValue {
            return areaID
        }

        guard let deviceID = entityRegistryByID[entityID]?.deviceID?.nonEmptyValue,
              let areaID = deviceRegistryByID[deviceID]?.areaID?.nonEmptyValue else {
            return nil
        }

        return areaID
    }

    func preferredClimateReadingEntityIDs() -> Set<String> {
        Set(areaRegistryByID.values.flatMap { area in
            [area.temperatureEntityID, area.humidityEntityID].compactMap { $0?.nonEmptyValue }
        })
    }

    private func preferredClimateReadingEntityIDByAreaID() -> [String: String] {
        Dictionary(uniqueKeysWithValues: areaRegistryByID.values.compactMap { area in
            area.temperatureEntityID?.nonEmptyValue.map { (area.id, $0) }
        })
    }

    private func areaIDByEntityID() -> [String: String] {
        Dictionary(uniqueKeysWithValues: rawEntitiesByID.keys.compactMap { entityID in
            areaID(for: entityID).map { (entityID, $0) }
        })
    }

    func dashboardSummaryMembershipContext() -> DashboardSummaryMembershipContext {
        if let cachedDashboardSummaryMembershipContext {
            return cachedDashboardSummaryMembershipContext
        }

        let metadataByID = entityRegistryByID.mapValues { metadata in
            let deviceID = metadata.deviceID?.nonEmptyValue
            let device = deviceID.flatMap { deviceRegistryByID[$0] }
            return DashboardSummaryEntityMetadata(
                isHidden: metadata.hiddenBy == true,
                entityCategory: metadata.entityCategory?.nonEmptyValue,
                deviceID: deviceID,
                deviceName: device?.registryDisplayName
            )
        }
        let chargingDeviceIDs = Set(entityRegistryByID.values.compactMap { metadata -> String? in
            guard let deviceID = metadata.deviceID?.nonEmptyValue,
                  let entity = rawEntitiesByID[metadata.entityID],
                  entity.attributes["device_class"]?.stringValue == "battery_charging",
                  entity.state == "on" else {
                return nil
            }
            return deviceID
        })

        let context = DashboardSummaryMembershipContext(
            entityMetadataByID: metadataByID,
            preferredClimateReadingEntityIDs: preferredClimateReadingEntityIDs(),
            preferredClimateReadingEntityIDByAreaID: preferredClimateReadingEntityIDByAreaID(),
            areaIDByEntityID: areaIDByEntityID(),
            chargingDeviceIDs: chargingDeviceIDs
        )
        cachedDashboardSummaryMembershipContext = context
        return context
    }

    func dashboardSummaryWorkspace() -> DashboardSummaryWorkspace {
        if let cachedDashboardSummaryWorkspace {
            return cachedDashboardSummaryWorkspace
        }

        let workspace = DashboardSummaryWorkspace(
            entityBoxes: allEntityBoxes(),
            membershipContext: dashboardSummaryMembershipContext()
        )
        cachedDashboardSummaryWorkspace = workspace
        return workspace
    }

    func lightEntity(for entityID: String) -> LightEntity? {
        lightEntitiesByID[entityID]
    }

    func climateEntity(for entityID: String) -> ClimateEntity? {
        climateEntitiesByID[entityID]
    }

    func coverEntity(for entityID: String) -> CoverEntity? {
        coverEntitiesByID[entityID]
    }

    func fanEntity(for entityID: String) -> FanEntity? {
        fanEntitiesByID[entityID]
    }

    func mediaPlayerEntity(for entityID: String) -> MediaPlayerEntity? {
        mediaPlayerEntitiesByID[entityID]
    }

    func sensorEntity(for entityID: String) -> SensorEntity? {
        sensorEntitiesByID[entityID]
    }

    func binarySensorEntity(for entityID: String) -> BinarySensorEntity? {
        binarySensorEntitiesByID[entityID]
    }

    func weatherEntity(for entityID: String) -> WeatherEntity? {
        weatherEntitiesByID[entityID]
    }

    func selectEntity(for entityID: String) -> SelectEntity? {
        selectEntitiesByID[entityID]
    }

    func updateEntity(for entityID: String) -> HAUpdateEntity? {
        updateEntities.first { $0.entityID == entityID }
    }

    func updateEntity(forSupervisorAppSlug slug: String) -> HAUpdateEntity? {
        let normalizedSlug = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedSlug.isEmpty else { return nil }

        return updateEntities.first { update in
            supervisorAppSlug(forUpdateEntityID: update.entityID) == normalizedSlug
        }
    }

    func supervisorAppSlug(forUpdateEntityID entityID: String) -> String? {
        if let entityPicturePath = updateEntity(for: entityID)?.entityPicturePath,
           let slug = Self.supervisorAppSlug(fromEntityPicturePath: entityPicturePath) {
            return slug
        }

        guard entityRegistryByID[entityID]?.platform?.lowercased() == "hassio" else {
            return nil
        }

        if let deviceID = entityRegistryByID[entityID]?.deviceID,
           let device = deviceRegistryByID[deviceID],
           let identifier = device.identifiers.first(where: { identifier in
               identifier.count >= 2 && identifier[0].lowercased() == "hassio"
           }) {
            return identifier[1].nonEmptyValue
        }

        let suffix = "_version_latest"
        guard let uniqueID = organizationByEntityID[entityID]?.uniqueID?.nonEmptyValue,
              uniqueID.hasSuffix(suffix) else {
            return nil
        }

        return String(uniqueID.dropLast(suffix.count)).nonEmptyValue
    }

    private static func supervisorAppSlug(fromEntityPicturePath value: String) -> String? {
        let path = URL(string: value)?.path ?? value
        let components = path.split(separator: "/", omittingEmptySubsequences: true)

        guard components.count == 5,
              components[0] == "api",
              components[1] == "hassio",
              components[2] == "addons",
              components[4] == "icon" else {
            return nil
        }

        return String(components[3]).nonEmptyValue
    }

    func presenceRecords() -> [HAPresenceRecord] {
        let presenceDTOs = rawEntitiesByID.values.filter { dto in
            let domain = EntityDomain(entityID: dto.entityID)
            return domain == .person || domain == .deviceTracker
        }

        let trackerDTOsByID = Dictionary(
            uniqueKeysWithValues: presenceDTOs
                .filter { EntityDomain(entityID: $0.entityID) == .deviceTracker }
                .map { ($0.entityID, $0) }
        )

        let personDTOs = presenceDTOs.filter { EntityDomain(entityID: $0.entityID) == .person }
        let personBySourceTrackerID = personDTOs.reduce(into: [String: HAEntityDTO]()) { peopleByTrackerID, person in
            guard let sourceEntityID = person.attributes["source"]?.stringValue?.nonEmptyValue,
                  trackerDTOsByID[sourceEntityID] != nil,
                  peopleByTrackerID[sourceEntityID] == nil else {
                return
            }

            peopleByTrackerID[sourceEntityID] = person
        }

        return presenceDTOs.compactMap { dto -> HAPresenceRecord? in
            let domain = EntityDomain(entityID: dto.entityID)
            let context = presenceContext(for: dto.entityID)

            if domain == .person {
                let linkedTrackers = linkedTrackerSummaries(for: dto, trackerDTOsByID: trackerDTOsByID)
                return EntityMapper.presenceRecord(
                    from: dto,
                    context: context,
                    linkedTrackers: linkedTrackers,
                    resolvedIcon: entitiesByID[dto.entityID]?.resolvedIcon
                )
            }

            let linkedPerson = personBySourceTrackerID[dto.entityID]
            return EntityMapper.presenceRecord(
                from: dto,
                context: context,
                linkedPersonEntityID: linkedPerson?.entityID,
                linkedPersonName: linkedPerson.map { EntityMapper.displayName(for: $0) },
                resolvedIcon: entitiesByID[dto.entityID]?.resolvedIcon
            )
        }
        .sorted { lhs, rhs in
            if lhs.domain != rhs.domain {
                return lhs.domain == .person
            }

            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    func presenceRecord(for entityID: String) -> HAPresenceRecord? {
        presenceRecords().first { $0.entityID == entityID }
    }

    func personDisplayName(forUserID userID: String) -> String? {
        let trimmedUserID = userID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUserID.isEmpty else {
            return nil
        }

        return rawEntitiesByID.values
            .filter { EntityDomain(entityID: $0.entityID) == .person }
            .first { dto in
                dto.attributes["user_id"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedUserID
            }
            .map(EntityMapper.displayName(for:))
    }

    // MARK: - State Updates

    func replaceDataSourceIfNeeded(_ dataSourceID: String) {
        guard self.dataSourceID != dataSourceID else {
            return
        }

        clearAllEntities()
        self.dataSourceID = dataSourceID
    }

    func applyInitialStates(_ entities: [HAEntityDTO], dataSourceID: String? = nil) {
        if let dataSourceID {
            replaceDataSourceIfNeeded(dataSourceID)
        }
        applySnapshot(entities)
    }

    func applySnapshot(_ entities: [HAEntityDTO], dataSourceID: String? = nil) {
        if let dataSourceID {
            replaceDataSourceIfNeeded(dataSourceID)
        }
        hasLoadedInitialSnapshot = true
        isApplyingSnapshotBatch = true
        snapshotBatchNeedsWidgetSave = false

        let snapshotEntityIDs = Set(entities.map(\.entityID))
        let removedEntityIDs = Set(rawEntitiesByID.keys).subtracting(snapshotEntityIDs)

        for entityID in removedEntityIDs {
            removeEntity(entityID)
        }

        for dto in entities {
            let wasApplied = applyConfirmedDTO(dto)

            if wasApplied, pendingCommandsByID[dto.entityID]?.isSatisfied(by: dto) == true {
                clearPendingCommand(entityID: dto.entityID)
            }
        }

        isApplyingSnapshotBatch = false
        refreshEntityIndexes(previousCatalogSignature: entityCatalogSignature)

        if snapshotBatchNeedsWidgetSave {
            saveWidgetSnapshots(immediately: true)
        }
        snapshotBatchNeedsWidgetSave = false
    }

    func applyRegistryMetadata(
        entities: [HAEntityRegistryDisplayDTO],
        devices: [HADeviceRegistryDTO],
        areas: [HAAreaRegistryDTO] = [],
        floors: [HAFloorRegistryDTO] = [],
        organization: [HAEntityOrganizationDTO] = [],
        labels: [HALabelRegistryDTO] = [],
        categories: [HACategoryRegistryDTO] = []
    ) {
        let previousEntityRegistryByID = entityRegistryByID
        entityRegistryByID = Dictionary(uniqueKeysWithValues: entities.map { ($0.entityID, $0) })
        deviceRegistryByID = Dictionary(uniqueKeysWithValues: devices.map { ($0.id, $0) })
        areaRegistryByID = Dictionary(uniqueKeysWithValues: areas.map { ($0.id, $0) })
        floorRegistryByID = Dictionary(uniqueKeysWithValues: floors.map { ($0.id, $0) })
        organizationByEntityID = Dictionary(uniqueKeysWithValues: organization.map { ($0.entityID, $0) })
        labelRegistryByID = Dictionary(uniqueKeysWithValues: labels.map { ($0.id, $0) })
        categoryRegistryByKey = Dictionary(uniqueKeysWithValues: categories.map {
            (Self.categoryKey(scope: $0.scope, id: $0.id), $0)
        })
        floorSortOrderByID = Dictionary(uniqueKeysWithValues: floors.enumerated().map { index, floor in
            (floor.id, index)
        })
        invalidateDashboardSummaryMembershipContext()
        refreshIconsAfterRegistryUpdate(previousEntityRegistryByID: previousEntityRegistryByID)
        refreshEntityIndexes(previousCatalogSignature: entityCatalogSignature)
    }

    func applyRegistryMetadata(_ metadata: HARegistryMetadataSnapshot) {
        applyRegistryMetadata(
            entities: metadata.entities,
            devices: metadata.devices,
            areas: metadata.areas,
            floors: metadata.floors,
            organization: metadata.organization,
            labels: metadata.labels,
            categories: metadata.categories
        )
    }

    func apply(event: HAEventDTO) {
        guard let stateChanged = event.stateChanged else { return }
        applyStateChanged(stateChanged)
    }

    func applyStateChanged(_ stateChanged: HAStateChangedEventDTO) {
        if let newState = stateChanged.newState {
            if applyConfirmedDTO(newState) {
                if pendingCommandsByID[newState.entityID]?.isSatisfied(by: newState) == true {
                    clearPendingCommand(entityID: newState.entityID)
                }
            }
        } else {
            removeEntity(stateChanged.entityID)
        }
    }

    func applyStateChanges(_ changes: [HAStateChangedEventDTO]) {
        performLiveStateBatch {
            for change in changes {
                applyStateChanged(change)
            }
        }
    }

    func applyLiveStateUpdates(_ updates: [HAEntityDTO]) {
        performLiveStateBatch {
            for update in updates {
                if applyConfirmedDTO(update) {
                    if pendingCommandsByID[update.entityID]?.isSatisfied(by: update) == true {
                        clearPendingCommand(entityID: update.entityID)
                    }
                }
            }
        }
    }

    func setPendingCommand(_ pendingCommand: HAEntityPendingCommand) {
        pendingCommandsByID[pendingCommand.entityID] = pendingCommand
        entityBoxesByID[pendingCommand.entityID]?.pendingCommand = pendingCommand
    }

    func clearPendingCommand(entityID: String) {
        pendingCommandsByID[entityID] = nil
        entityBoxesByID[entityID]?.pendingCommand = nil
    }

    // MARK: - Presentation Helpers

    func displayNameForDeviceGroupedEntity(entityID: String) -> String? {
        guard let entity = entitiesByID[entityID],
              let registry = entityRegistryByID[entityID] else {
            return nil
        }

        let deviceName = registry.deviceID
            .flatMap { deviceRegistryByID[$0]?.displayName.nonEmptyValue }

        if let name = registry.name?.nonEmptyValue {
            return name.removingDeviceNamePrefix(deviceName)
        }

        if let originalName = registry.originalName?.nonEmptyValue {
            return originalName.removingDeviceNamePrefix(deviceName)
        }

        return entity.displayName.removingDeviceNamePrefix(deviceName)
    }

    // MARK: - Icon Resolution

    private func resolvedIcon(for dto: HAEntityDTO) -> ResolvedIcon {
        let input = EntityIconResolutionInput(
            domain: dto.entityID.split(separator: ".").first.map(String.init) ?? "unknown",
            deviceClass: dto.attributes["device_class"]?.stringValue,
            state: dto.state,
            registryIcon: entityRegistryByID[dto.entityID]?.icon,
            explicitIcon: dto.attributes["icon"]?.stringValue
        )

        if iconResolutionInputsByID[dto.entityID] == input,
           let cachedIcon = resolvedIconsByID[dto.entityID] {
            return cachedIcon
        }

        let icon = IconResolver.resolveEntity(input)
        iconResolutionCount += 1
        iconResolutionInputsByID[dto.entityID] = input
        resolvedIconsByID[dto.entityID] = icon
        return icon
    }

    private func refreshIconsAfterRegistryUpdate(
        previousEntityRegistryByID: [String: HAEntityRegistryDisplayDTO]
    ) {
        let entityIDs = Set(previousEntityRegistryByID.keys).union(entityRegistryByID.keys)
        let iconChangedEntityIDs = entityIDs.filter { entityID in
            previousEntityRegistryByID[entityID]?.icon != entityRegistryByID[entityID]?.icon
        }
        var needsWidgetSave = false

        for entityID in iconChangedEntityIDs {
            guard let dto = rawEntitiesByID[entityID],
                  let previousEntity = entitiesByID[entityID] else { continue }

            let icon = resolvedIcon(for: dto)
            guard icon != previousEntity.resolvedIcon else { continue }

            let updatedEntity = EntityMapper.homeEntity(from: dto, resolvedIcon: icon)
            entitiesByID[entityID] = updatedEntity
            entityBoxesByID[entityID]?.homeEntity = updatedEntity
            updateCachedEntity(updatedEntity)
            needsWidgetSave = needsWidgetSave || updatedEntity.domain.isWidgetSnapshotDomain
        }

        if needsWidgetSave {
            saveWidgetSnapshots()
        }
    }

    private func entityIDs(for domain: EntityDomain) -> [String] {
        entitiesByID.values
            .filter { $0.domain == domain }
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            .map(\.entityID)
    }

    private func deviceManagementSubtitle(
        manufacturer: String?,
        model: String?,
        areaName: String?
    ) -> String {
        let parts = [manufacturer, model, areaName].compactMap { $0 }
        return parts.isEmpty ? "No additional details" : parts.joined(separator: " • ")
    }

    private func primaryPlatform(from metadataEntries: [HAEntityRegistryDisplayDTO]) -> String? {
        Dictionary(grouping: metadataEntries.compactMap { $0.platform?.nonEmptyValue }, by: { $0 })
            .max { lhs, rhs in
                if lhs.value.count == rhs.value.count {
                    return lhs.key.localizedCaseInsensitiveCompare(rhs.key) == .orderedDescending
                }

                return lhs.value.count < rhs.value.count
            }?
            .key
    }

    private func presenceContext(for entityID: String) -> HAPresenceContext {
        let registry = entityRegistryByID[entityID]
        let deviceID = registry?.deviceID?.nonEmptyValue
        let device = deviceID.flatMap { deviceRegistryByID[$0] }
        let areaContext = areaContext(for: entityID)

        return HAPresenceContext(
            deviceID: deviceID,
            deviceName: device?.displayName.nonEmptyValue,
            areaID: areaContext?.areaID,
            areaName: areaContext?.name,
            floorID: areaContext?.floorID,
            floorName: areaContext?.floorName
        )
    }

    private func linkedTrackerSummaries(
        for person: HAEntityDTO,
        trackerDTOsByID: [String: HAEntityDTO]
    ) -> [HAPresenceTrackerSummary] {
        guard let sourceEntityID = person.attributes["source"]?.stringValue?.nonEmptyValue,
              let tracker = trackerDTOsByID[sourceEntityID] else {
            return []
        }

        return EntityMapper.presenceTrackerSummary(
            from: tracker,
            context: presenceContext(for: tracker.entityID)
        ).map { [$0] } ?? []
    }

    // MARK: - Private State Mutation

    private func clearAllEntities() {
        entitiesByID.removeAll()
        allEntities.removeAll()
        entitiesByDomain.removeAll()
        entityIDGroupsByDomain.removeAll()
        entityIDGroupsByDevice.removeAll()
        entityIDsByDisplayName.removeAll()
        availableEntityIDs.removeAll()
        entityCatalogSignature = ""
        hasEntities = false
        hasLoadedInitialSnapshot = false
        lightEntitiesByID.removeAll()
        climateEntitiesByID.removeAll()
        coverEntitiesByID.removeAll()
        fanEntitiesByID.removeAll()
        mediaPlayerEntitiesByID.removeAll()
        sensorEntitiesByID.removeAll()
        binarySensorEntitiesByID.removeAll()
        weatherEntitiesByID.removeAll()
        weatherSolarPhase = nil
        selectEntitiesByID.removeAll()
        numberEntitiesByID.removeAll()
        updateEntities.removeAll()
        rawEntitiesByID.removeAll()
        iconResolutionInputsByID.removeAll()
        resolvedIconsByID.removeAll()
        iconResolutionCount = 0
        entityBoxesByID.removeAll()
        pendingCommandsByID.removeAll()
        entityRegistryByID.removeAll()
        deviceRegistryByID.removeAll()
        areaRegistryByID.removeAll()
        floorRegistryByID.removeAll()
        organizationByEntityID.removeAll()
        labelRegistryByID.removeAll()
        categoryRegistryByKey.removeAll()
        floorSortOrderByID.removeAll()
        invalidateDashboardSummaryMembershipContext()
        isApplyingSnapshotBatch = false
        snapshotBatchNeedsWidgetSave = false
        saveWidgetSnapshots(immediately: true)
    }

    private func rebuildMappedEntities(from entities: [HAEntityDTO]) {
        entitiesByID = Dictionary(uniqueKeysWithValues: entities.map { dto in
            let icon = resolvedIcon(for: dto)
            return (dto.entityID, EntityMapper.homeEntity(from: dto, resolvedIcon: icon))
        })
        lightEntitiesByID = Dictionary(uniqueKeysWithValues: entities.compactMap { dto in
            EntityMapper.lightEntity(from: dto).map { ($0.entityID, $0) }
        })
        climateEntitiesByID = Dictionary(uniqueKeysWithValues: entities.compactMap { dto in
            EntityMapper.climateEntity(from: dto).map { ($0.entityID, $0) }
        })
        coverEntitiesByID = Dictionary(uniqueKeysWithValues: entities.compactMap { dto in
            EntityMapper.coverEntity(from: dto).map { ($0.entityID, $0) }
        })
        fanEntitiesByID = Dictionary(uniqueKeysWithValues: entities.compactMap { dto in
            EntityMapper.fanEntity(from: dto).map { ($0.entityID, $0) }
        })
        mediaPlayerEntitiesByID = Dictionary(uniqueKeysWithValues: entities.compactMap { dto in
            EntityMapper.mediaPlayerEntity(from: dto).map { ($0.entityID, $0) }
        })
        sensorEntitiesByID = Dictionary(uniqueKeysWithValues: entities.compactMap { dto in
            EntityMapper.sensorEntity(from: dto).map { ($0.entityID, $0) }
        })
        binarySensorEntitiesByID = Dictionary(uniqueKeysWithValues: entities.compactMap { dto in
            EntityMapper.binarySensorEntity(from: dto).map { ($0.entityID, $0) }
        })
        weatherEntitiesByID = Dictionary(uniqueKeysWithValues: entities.compactMap { dto in
            EntityMapper.weatherEntity(from: dto).map { ($0.entityID, $0) }
        })
        weatherSolarPhase = entities
            .first(where: { $0.entityID == "sun.sun" })
            .flatMap(EntityMapper.weatherSolarPhase(from:))
        selectEntitiesByID = Dictionary(uniqueKeysWithValues: entities.compactMap { dto in
            EntityMapper.selectEntity(from: dto).map { ($0.entityID, $0) }
        })
        numberEntitiesByID = Dictionary(uniqueKeysWithValues: entities.compactMap { dto in
            EntityMapper.numberEntity(from: dto).map { ($0.entityID, $0) }
        })
        refreshUpdateEntities()
        var updatedEntityBoxesByID: [String: HAEntityState] = [:]
        for dto in entities {
            let homeEntity = EntityMapper.homeEntity(from: dto, resolvedIcon: resolvedIcon(for: dto))

            if let entityBox = entityBoxesByID[dto.entityID] {
                entityBox.update(
                    homeEntity: homeEntity,
                    lightEntity: EntityMapper.lightEntity(from: dto),
                    climateEntity: EntityMapper.climateEntity(from: dto),
                    coverEntity: EntityMapper.coverEntity(from: dto),
                    fanEntity: EntityMapper.fanEntity(from: dto),
                    mediaPlayerEntity: EntityMapper.mediaPlayerEntity(from: dto),
                    sensorEntity: EntityMapper.sensorEntity(from: dto),
                    binarySensorEntity: EntityMapper.binarySensorEntity(from: dto),
                    weatherEntity: EntityMapper.weatherEntity(from: dto),
                    selectEntity: EntityMapper.selectEntity(from: dto),
                    numberEntity: EntityMapper.numberEntity(from: dto),
                    textEntity: EntityMapper.textEntity(from: dto),
                    temporalEntity: EntityMapper.temporalEntity(from: dto),
                    presenceRecord: EntityMapper.presenceRecord(
                        from: dto,
                        resolvedIcon: homeEntity.resolvedIcon
                    ),
                    pendingCommand: pendingCommandsByID[dto.entityID]
                )
                updatedEntityBoxesByID[dto.entityID] = entityBox
            } else {
                updatedEntityBoxesByID[dto.entityID] = HAEntityState(
                    homeEntity: homeEntity,
                    lightEntity: EntityMapper.lightEntity(from: dto),
                    climateEntity: EntityMapper.climateEntity(from: dto),
                    coverEntity: EntityMapper.coverEntity(from: dto),
                    fanEntity: EntityMapper.fanEntity(from: dto),
                    mediaPlayerEntity: EntityMapper.mediaPlayerEntity(from: dto),
                    sensorEntity: EntityMapper.sensorEntity(from: dto),
                    binarySensorEntity: EntityMapper.binarySensorEntity(from: dto),
                    weatherEntity: EntityMapper.weatherEntity(from: dto),
                    selectEntity: EntityMapper.selectEntity(from: dto),
                    numberEntity: EntityMapper.numberEntity(from: dto),
                    textEntity: EntityMapper.textEntity(from: dto),
                    temporalEntity: EntityMapper.temporalEntity(from: dto),
                    presenceRecord: EntityMapper.presenceRecord(
                        from: dto,
                        resolvedIcon: homeEntity.resolvedIcon
                    ),
                    pendingCommand: pendingCommandsByID[dto.entityID]
                )
            }
        }
        entityBoxesByID = updatedEntityBoxesByID
        refreshEntityIndexes()
    }

    // MARK: - Incremental Updates

    @discardableResult
    private func applyConfirmedDTO(_ dto: HAEntityDTO) -> Bool {
        guard shouldApply(dto) else {
            return false
        }

        if dashboardSummaryMembershipChanged(
            from: rawEntitiesByID[dto.entityID],
            to: dto
        ) {
            invalidateDashboardSummaryMembershipContext()
        }
        rawEntitiesByID[dto.entityID] = dto
        if dto.entityID == "sun.sun" {
            weatherSolarPhase = EntityMapper.weatherSolarPhase(from: dto)
        }
        apply(dto: dto)
        return true
    }

    private func apply(dto: HAEntityDTO) {
        let previousCatalogSignature = entityCatalogSignature
        let previousEntity = entitiesByID[dto.entityID]
        let homeEntity = EntityMapper.homeEntity(from: dto, resolvedIcon: resolvedIcon(for: dto))

        entitiesByID[dto.entityID] = homeEntity
        lightEntitiesByID[dto.entityID] = EntityMapper.lightEntity(from: dto)
        climateEntitiesByID[dto.entityID] = EntityMapper.climateEntity(from: dto)
        coverEntitiesByID[dto.entityID] = EntityMapper.coverEntity(from: dto)
        fanEntitiesByID[dto.entityID] = EntityMapper.fanEntity(from: dto)
        mediaPlayerEntitiesByID[dto.entityID] = EntityMapper.mediaPlayerEntity(from: dto)
        sensorEntitiesByID[dto.entityID] = EntityMapper.sensorEntity(from: dto)
        binarySensorEntitiesByID[dto.entityID] = EntityMapper.binarySensorEntity(from: dto)
        weatherEntitiesByID[dto.entityID] = EntityMapper.weatherEntity(from: dto)
        selectEntitiesByID[dto.entityID] = EntityMapper.selectEntity(from: dto)
        numberEntitiesByID[dto.entityID] = EntityMapper.numberEntity(from: dto)
        if !isApplyingSnapshotBatch, previousEntity?.domain == .update || homeEntity.domain == .update {
            refreshUpdateEntities()
        }
        updateEntityBox(
            entityID: dto.entityID,
            homeEntity: homeEntity,
            lightEntity: lightEntitiesByID[dto.entityID],
            climateEntity: climateEntitiesByID[dto.entityID],
            coverEntity: coverEntitiesByID[dto.entityID],
            fanEntity: fanEntitiesByID[dto.entityID],
            mediaPlayerEntity: mediaPlayerEntitiesByID[dto.entityID],
            sensorEntity: sensorEntitiesByID[dto.entityID],
            binarySensorEntity: binarySensorEntitiesByID[dto.entityID],
            weatherEntity: weatherEntitiesByID[dto.entityID],
            selectEntity: selectEntitiesByID[dto.entityID],
            numberEntity: numberEntitiesByID[dto.entityID],
            textEntity: EntityMapper.textEntity(from: dto),
            temporalEntity: EntityMapper.temporalEntity(from: dto),
            presenceRecord: EntityMapper.presenceRecord(
                from: dto,
                resolvedIcon: homeEntity.resolvedIcon
            ),
            pendingCommand: pendingCommandsByID[dto.entityID]
        )

        if isApplyingSnapshotBatch {
            // Snapshot batches refresh the catalog once after all entity changes are applied.
        } else if previousEntity?.domain == homeEntity.domain,
           previousEntity?.displayName == homeEntity.displayName {
            updateCachedEntity(homeEntity)
        } else {
            refreshEntityIndexes(previousCatalogSignature: previousCatalogSignature)
        }

        if homeEntity.domain.isWidgetSnapshotDomain {
            if isApplyingSnapshotBatch {
                snapshotBatchNeedsWidgetSave = true
            } else if isApplyingLiveStateBatch {
                liveStateBatchNeedsWidgetSave = true
            } else {
                saveWidgetSnapshots()
            }
        }
    }

    private func shouldApply(_ dto: HAEntityDTO) -> Bool {
        guard let incomingLastUpdated = dto.lastUpdated,
              let currentLastUpdated = rawEntitiesByID[dto.entityID]?.lastUpdated else {
            return true
        }

        return incomingLastUpdated >= currentLastUpdated
    }

    func removeEntity(_ entityID: String) {
        let previousCatalogSignature = entityCatalogSignature
        let removedEntity = entitiesByID.removeValue(forKey: entityID)

        rawEntitiesByID.removeValue(forKey: entityID)
        invalidateDashboardSummaryMembershipContext()
        iconResolutionInputsByID.removeValue(forKey: entityID)
        resolvedIconsByID.removeValue(forKey: entityID)
        lightEntitiesByID.removeValue(forKey: entityID)
        climateEntitiesByID.removeValue(forKey: entityID)
        coverEntitiesByID.removeValue(forKey: entityID)
        fanEntitiesByID.removeValue(forKey: entityID)
        mediaPlayerEntitiesByID.removeValue(forKey: entityID)
        sensorEntitiesByID.removeValue(forKey: entityID)
        binarySensorEntitiesByID.removeValue(forKey: entityID)
        weatherEntitiesByID.removeValue(forKey: entityID)
        if entityID == "sun.sun" {
            weatherSolarPhase = nil
        }
        selectEntitiesByID.removeValue(forKey: entityID)
        if removedEntity?.domain == .update {
            refreshUpdateEntities()
        }
        entityBoxesByID.removeValue(forKey: entityID)
        pendingCommandsByID.removeValue(forKey: entityID)

        if removedEntity != nil {
            if isApplyingSnapshotBatch {
                if removedEntity?.domain.isWidgetSnapshotDomain == true {
                    snapshotBatchNeedsWidgetSave = true
                }
            } else if isApplyingLiveStateBatch {
                if removedEntity?.domain.isWidgetSnapshotDomain == true {
                    liveStateBatchNeedsWidgetSave = true
                }
            } else {
                refreshEntityIndexes(previousCatalogSignature: previousCatalogSignature)
                if removedEntity?.domain.isWidgetSnapshotDomain == true {
                    saveWidgetSnapshots()
                }
            }
        }
    }

    private func refreshEntityIndexes(previousCatalogSignature: String? = nil) {
        allEntities = entitiesByID.values.sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
        entityIDsByDisplayName = allEntities.map(\.entityID)
        entitiesByDomain = Dictionary(grouping: allEntities, by: \.domain)
            .map { domain, entities in
                (domain: domain, entities: entities)
            }
            .sorted { lhs, rhs in
                if lhs.domain.dashboardPriority != rhs.domain.dashboardPriority {
                    return lhs.domain.dashboardPriority < rhs.domain.dashboardPriority
                }

                return lhs.domain.displayName.localizedCaseInsensitiveCompare(rhs.domain.displayName) == .orderedAscending
            }
        entityIDGroupsByDomain = entitiesByDomain.map { group in
            EntityDomainGroup(
                domain: group.domain,
                entityIDs: group.entities.map(\.entityID)
            )
        }
        entityIDGroupsByDevice = makeDeviceGroups()
        availableEntityIDs = Set(entitiesByID.keys)
        hasEntities = !availableEntityIDs.isEmpty
        refreshUpdateEntities()

        let signature = availableEntityIDs.sorted().joined(separator: "|")
        if previousCatalogSignature == nil || signature != previousCatalogSignature {
            entityCatalogSignature = signature
        }
    }

    private func updateCachedEntity(_ entity: HomeEntity) {
        guard let entityIndex = allEntities.firstIndex(where: { $0.entityID == entity.entityID }) else {
            refreshEntityIndexes(previousCatalogSignature: entityCatalogSignature)
            return
        }

        allEntities[entityIndex] = entity

        guard let groupIndex = entitiesByDomain.firstIndex(where: { $0.domain == entity.domain }),
              let groupedEntityIndex = entitiesByDomain[groupIndex].entities.firstIndex(where: { $0.entityID == entity.entityID }) else {
            refreshEntityIndexes(previousCatalogSignature: entityCatalogSignature)
            return
        }

        entitiesByDomain[groupIndex].entities[groupedEntityIndex] = entity
    }

    private func invalidateDashboardSummaryMembershipContext() {
        cachedDashboardSummaryMembershipContext = nil
        cachedDashboardSummaryWorkspace = nil
    }

    private func dashboardSummaryMembershipChanged(
        from previous: HAEntityDTO?,
        to current: HAEntityDTO
    ) -> Bool {
        dashboardSummaryMembershipSignature(for: previous) !=
            dashboardSummaryMembershipSignature(for: current)
    }

    private func dashboardSummaryMembershipSignature(
        for dto: HAEntityDTO?
    ) -> DashboardSummaryMembershipSignature? {
        guard let dto else {
            return nil
        }

        let deviceClass = dto.attributes["device_class"]?.stringValue
        return DashboardSummaryMembershipSignature(
            domain: EntityDomain(entityID: dto.entityID),
            deviceClass: deviceClass,
            isCharging: deviceClass == "battery_charging" && dto.state == "on"
        )
    }

    private func updateEntityBox(
        entityID: String,
        homeEntity: HomeEntity,
        lightEntity: LightEntity?,
        climateEntity: ClimateEntity?,
        coverEntity: CoverEntity?,
        fanEntity: FanEntity?,
        mediaPlayerEntity: MediaPlayerEntity?,
        sensorEntity: SensorEntity?,
        binarySensorEntity: BinarySensorEntity?,
        weatherEntity: WeatherEntity?,
        selectEntity: SelectEntity?,
        numberEntity: NumberEntity?,
        textEntity: TextEntity?,
        temporalEntity: TemporalEntity?,
        presenceRecord: HAPresenceRecord?,
        pendingCommand: HAEntityPendingCommand?
    ) {
        if let entityBox = entityBoxesByID[entityID] {
            entityBox.update(
                homeEntity: homeEntity,
                lightEntity: lightEntity,
                climateEntity: climateEntity,
                coverEntity: coverEntity,
                fanEntity: fanEntity,
                mediaPlayerEntity: mediaPlayerEntity,
                sensorEntity: sensorEntity,
                binarySensorEntity: binarySensorEntity,
                weatherEntity: weatherEntity,
                selectEntity: selectEntity,
                numberEntity: numberEntity,
                textEntity: textEntity,
                temporalEntity: temporalEntity,
                presenceRecord: presenceRecord,
                pendingCommand: pendingCommand
            )
        } else {
            entityBoxesByID[entityID] = HAEntityState(
                homeEntity: homeEntity,
                lightEntity: lightEntity,
                climateEntity: climateEntity,
                coverEntity: coverEntity,
                fanEntity: fanEntity,
                mediaPlayerEntity: mediaPlayerEntity,
                sensorEntity: sensorEntity,
                binarySensorEntity: binarySensorEntity,
                weatherEntity: weatherEntity,
                selectEntity: selectEntity,
                numberEntity: numberEntity,
                textEntity: textEntity,
                temporalEntity: temporalEntity,
                presenceRecord: presenceRecord,
                pendingCommand: pendingCommand
            )
        }
    }

    private func performLiveStateBatch(_ updates: () -> Void) {
        let wasApplyingLiveStateBatch = isApplyingLiveStateBatch
        if !wasApplyingLiveStateBatch {
            liveStateBatchNeedsWidgetSave = false
        }
        isApplyingLiveStateBatch = true
        updates()
        isApplyingLiveStateBatch = wasApplyingLiveStateBatch

        guard !wasApplyingLiveStateBatch else { return }
        if liveStateBatchNeedsWidgetSave {
            saveWidgetSnapshots()
        }
        liveStateBatchNeedsWidgetSave = false
    }

    private func saveWidgetSnapshots(immediately: Bool = false) {
        guard let dataSourceID,
              dataSourceID.hasPrefix("profile-"),
              let profileID = UUID(uuidString: String(dataSourceID.dropFirst("profile-".count))) else {
            return
        }

        let contextualEntityIDs = Set(
            entitiesByID.values.lazy
                .filter { $0.domain.isWidgetSnapshotDomain }
                .map(\.entityID)
        )
        .union(lightEntitiesByID.keys)
        .union(coverEntitiesByID.keys)
        .union(fanEntitiesByID.keys)
        .union(sensorEntitiesByID.keys)
        let contextByEntityID = Dictionary(uniqueKeysWithValues: contextualEntityIDs.map { entityID in
            (entityID, WidgetEntityContext(
                areaName: self.areaName(for: entityID),
                deviceName: self.deviceRegistryMetadata(forEntityID: entityID)?.displayName.nonEmptyValue
            ))
        })
        let request = WidgetSnapshotPersistence.Request(
            profileID: profileID,
            serverName: WidgetSharedStore.serverDisplayName(profileID: profileID),
            entitiesByID: entitiesByID,
            lightEntitiesByID: lightEntitiesByID,
            coverEntitiesByID: coverEntitiesByID,
            fanEntitiesByID: fanEntitiesByID,
            sensorEntitiesByID: sensorEntitiesByID,
            contextByEntityID: contextByEntityID
        )
        widgetSnapshotSequence &+= 1
        let sequence = widgetSnapshotSequence

        Task { [weak self] in
            guard let self else { return }
            await widgetSnapshotPersistenceCoordinator.schedule(
                sequence: sequence,
                request: request,
                immediately: immediately
            ) { [weak self] persistedProfileID, payload in
                guard let self else { return }
                let changedKinds = WidgetSnapshotPersistence.changedWidgetKinds(
                    from: lastPersistedWidgetPayloadByProfileID[persistedProfileID],
                    to: payload
                )
                lastPersistedWidgetPayloadByProfileID[persistedProfileID] = payload
                scheduleWidgetReload(for: changedKinds)
            }
        }
    }

    private func scheduleWidgetReload(for kinds: Set<HomesteadWidgetKind>) {
        guard !kinds.isEmpty else { return }
        pendingWidgetReloadKinds.formUnion(kinds)
        guard widgetReloadTask == nil else { return }

        let minimumReloadInterval: TimeInterval = 30
        let now = Date()
        let nextReloadDate = lastWidgetReloadDate?
            .addingTimeInterval(minimumReloadInterval) ?? now.addingTimeInterval(1)
        let delay = max(nextReloadDate.timeIntervalSince(now), 1)

        widgetReloadTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled else { return }
            let kinds = pendingWidgetReloadKinds
            pendingWidgetReloadKinds.removeAll()
            lastWidgetReloadDate = Date()
            widgetReloadTask = nil
            for kind in kinds {
                WidgetCenter.shared.reloadTimelines(ofKind: kind.rawValue)
            }
        }
    }

    private func refreshUpdateEntities() {
        updateEntities = rawEntitiesByID.values
            .compactMap { dto in
                updateEntity(from: dto)
            }
            .sorted { lhs, rhs in
                lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    private func updateEntity(from dto: HAEntityDTO) -> HAUpdateEntity? {
        let registry = entityRegistryByID[dto.entityID]
        let deviceID = registry?.deviceID?.nonEmptyValue
        let device = deviceID.flatMap { deviceRegistryByID[$0] }
        let areaContext = areaContext(for: dto.entityID)

        return EntityMapper.updateEntity(
            from: dto,
            integrationPlatform: registry?.platform,
            deviceID: deviceID,
            deviceName: device?.displayName,
            deviceManufacturer: device?.manufacturer,
            deviceModel: device?.model,
            areaID: areaContext?.areaID,
            areaName: areaContext?.name,
            floorID: areaContext?.floorID,
            floorName: areaContext?.floorName,
            resolvedIcon: entitiesByID[dto.entityID]?.resolvedIcon
        )
    }

    private func makeDeviceGroups() -> [EntityDeviceGroup] {
        var groupsByDeviceID: [String: [HomeEntity]] = [:]
        var unassignedEntities: [HomeEntity] = []

        for entity in allEntities {
            guard let deviceID = entityRegistryByID[entity.entityID]?.deviceID?.nonEmptyValue else {
                unassignedEntities.append(entity)
                continue
            }

            groupsByDeviceID[deviceID, default: []].append(entity)
        }

        var groups = groupsByDeviceID.map { deviceID, entities in
            EntityDeviceGroup(
                id: deviceID,
                title: deviceRegistryByID[deviceID]?.displayName ?? "Unknown Device",
                entityIDs: entities.sortedByDisplayName.map(\.entityID)
            )
        }
        .sorted { lhs, rhs in
            lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }

        if !unassignedEntities.isEmpty {
            groups.append(
                EntityDeviceGroup(
                    id: "unassigned",
                    title: "Other Entities",
                    entityIDs: unassignedEntities.sortedByDisplayName.map(\.entityID)
                )
            )
        }

        return groups
    }
}

// MARK: - Entity Group Models

struct EntityDomainGroup: Equatable, Sendable {
    let domain: EntityDomain
    let entityIDs: [String]
}

struct EntityDeviceGroup: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let entityIDs: [String]
}

private struct DashboardSummaryMembershipSignature: Equatable {
    let domain: EntityDomain?
    let deviceClass: String?
    let isCharging: Bool
}

// MARK: - Management Summaries

struct HADeviceManagementSummary: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let areaName: String?
    let manufacturer: String?
    let model: String?
    let platform: String?
    let labels: [String]
    let entityIDs: [String]
    let unavailableEntityCount: Int

    var entityCount: Int { entityIDs.count }

    func matches(query: String) -> Bool {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return true
        }

        let searchableText = [
            id,
            title,
            subtitle,
            areaName,
            manufacturer,
            model,
            platform,
            labels.joined(separator: " "),
            entityCountText
        ]
            .compactMap { $0 }
            .joined(separator: " ")

        return searchableText.localizedCaseInsensitiveContains(trimmedQuery)
    }

    var rowSubtitle: String {
        entityCountText
    }

    var detailSubtitle: String {
        let detail = subtitle == "No additional details" ? nil : subtitle

        return [
            detail,
            entityCountText,
            unavailableEntityCount > 0 ? "\(unavailableEntityCount) unavailable" : nil
        ]
            .compactMap { $0 }
            .joined(separator: " • ")
    }

    var entityCountText: String {
        entityCount == 1 ? "1 entity" : "\(entityCount) entities"
    }
}

enum HAHelperDomain: String, CaseIterable, Identifiable, Sendable {
    case inputBoolean = "input_boolean"
    case inputButton = "input_button"
    case inputDatetime = "input_datetime"
    case inputNumber = "input_number"
    case inputSelect = "input_select"
    case inputText = "input_text"
    case counter
    case timer
    case schedule

    var id: String { rawValue }

    init?(entityID: String) {
        guard let domain = entityID.split(separator: ".").first else {
            return nil
        }

        self.init(rawValue: String(domain))
    }

    var displayName: String {
        switch self {
        case .inputBoolean:
            "Toggle Helpers"
        case .inputButton:
            "Button Helpers"
        case .inputDatetime:
            "Date & Time Helpers"
        case .inputNumber:
            "Number Helpers"
        case .inputSelect:
            "Dropdown Helpers"
        case .inputText:
            "Text Helpers"
        case .counter:
            "Counters"
        case .timer:
            "Timers"
        case .schedule:
            "Schedules"
        }
    }

    var systemImage: String {
        switch self {
        case .inputBoolean:
            "switch.2"
        case .inputButton:
            "button.programmable"
        case .inputDatetime:
            "calendar.badge.clock"
        case .inputNumber:
            "number"
        case .inputSelect:
            "filemenu.and.selection"
        case .inputText:
            "text.cursor"
        case .counter:
            "number.circle"
        case .timer:
            "timer"
        case .schedule:
            "calendar"
        }
    }
}

struct HAIntegrationManagementSummary: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let platform: String
    let entityIDs: [String]
    let devices: [HADeviceManagementSummary]
    let unavailableEntityCount: Int
    let hiddenEntityCount: Int
    let configEntityCount: Int
    let diagnosticEntityCount: Int

    var entityCount: Int { entityIDs.count }
    var deviceCount: Int { devices.count }

    var unassignedEntityIDs: [String] {
        let deviceEntityIDs = Set(devices.flatMap(\.entityIDs))
        return entityIDs.filter { !deviceEntityIDs.contains($0) }
    }

    var subtitle: String {
        if deviceCount > 0 {
            return deviceCount == 1 ? "1 device" : "\(deviceCount) devices"
        }

        return entityCount == 1 ? "1 entity" : "\(entityCount) entities"
    }

    var detailSubtitle: String {
        [
            entityCount == 1 ? "1 entity" : "\(entityCount) entities",
            deviceCount == 1 ? "1 device" : deviceCount > 1 ? "\(deviceCount) devices" : nil,
            unavailableEntityCount > 0 ? "\(unavailableEntityCount) unavailable" : nil
        ]
            .compactMap { $0 }
            .joined(separator: " • ")
    }

    func matches(query: String) -> Bool {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return true
        }

        return [
            title,
            platform,
            subtitle
        ]
            .joined(separator: " ")
            .localizedCaseInsensitiveContains(trimmedQuery)
    }
}

struct HAHelperManagementSummary: Equatable, Identifiable, Sendable {
    let domain: HAHelperDomain
    let entityIDs: [String]
    let unavailableEntityCount: Int

    var id: String { domain.rawValue }
    var entityCount: Int { entityIDs.count }
}

private extension HADeviceRegistryDTO {
    var registryDisplayName: String {
        nameByUser?.nonEmptyValue ?? name?.nonEmptyValue ?? manufacturer?.nonEmptyValue ?? "Unknown Device"
    }

    var displayName: String {
        registryDisplayName
    }
}

private extension Array where Element == String {
    func sortedByEntityDisplayName(in entitiesByID: [String: HomeEntity]) -> [String] {
        sorted { lhs, rhs in
            let lhsName = entitiesByID[lhs]?.displayName ?? lhs
            let rhsName = entitiesByID[rhs]?.displayName ?? rhs
            return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
        }
    }
}

private extension Array where Element == HomeEntity {
    var sortedByDisplayName: [HomeEntity] {
        sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }
}

private extension String {
    var nonEmptyValue: String? {
        let trimmedValue = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    func removingDeviceNamePrefix(_ deviceName: String) -> String {
        let trimmedName = trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDeviceName = deviceName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedDeviceName.isEmpty,
              trimmedName.localizedCaseInsensitiveContains(trimmedDeviceName),
              trimmedName.lowercased().hasPrefix(trimmedDeviceName.lowercased()) else {
            return trimmedName
        }

        let suffix = trimmedName.dropFirst(trimmedDeviceName.count)
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))

        return suffix.isEmpty ? trimmedName : suffix
    }

    func removingDeviceNamePrefix(_ deviceName: String?) -> String {
        guard let deviceName else {
            return trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return removingDeviceNamePrefix(deviceName)
    }
}

private extension HAStateStore {
    static func displayName(forIntegrationPlatform platform: String) -> String {
        let trimmedPlatform = platform.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPlatform.isEmpty, trimmedPlatform != "unknown" else {
            return "Unknown Integration"
        }

        return trimmedPlatform
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { word in
                let lowercased = word.lowercased()
                return lowercased.prefix(1).uppercased() + lowercased.dropFirst()
            }
            .joined(separator: " ")
    }

    private static func categoryKey(scope: HAOrganizationScope, id: String) -> String {
        "\(scope.rawValue)|\(id)"
    }
}

struct HAEntityPendingCommand: Equatable, Sendable {
    let entityID: String
    let expectedState: String?
    let expectedAttributes: [String: JSONValue]
    let startedAt: Date

    init(
        entityID: String,
        expectedState: String? = nil,
        expectedAttributes: [String: JSONValue] = [:],
        startedAt: Date = Date()
    ) {
        self.entityID = entityID
        self.expectedState = expectedState
        self.expectedAttributes = expectedAttributes
        self.startedAt = startedAt
    }

    func isSatisfied(by dto: HAEntityDTO) -> Bool {
        guard dto.entityID == entityID else {
            return false
        }

        if let expectedState, dto.state != expectedState {
            return false
        }

        return expectedAttributes.allSatisfy { key, expectedValue in
            dto.attributes[key]?.matchesCommandExpectation(expectedValue) == true
        }
    }
}

private extension JSONValue {
    func matchesCommandExpectation(_ expectedValue: JSONValue) -> Bool {
        switch (self, expectedValue) {
        case (.number(let actual), .number(let expected)):
            abs(actual - expected) < 0.5
        default:
            self == expectedValue
        }
    }
}

private extension EntityDomain {
    var isWidgetSnapshotDomain: Bool {
        self == .light
            || self == .switch
            || self == .cover
            || self == .fan
            || self == .lock
            || self == .sensor
            || self == .person
            || self == .scene
            || self == .script
    }
}

@MainActor
@Observable
final class HAEntityState: Identifiable {
    var homeEntity: HomeEntity
    var lightEntity: LightEntity?
    var climateEntity: ClimateEntity?
    var coverEntity: CoverEntity?
    var fanEntity: FanEntity?
    var mediaPlayerEntity: MediaPlayerEntity?
    var sensorEntity: SensorEntity?
    var binarySensorEntity: BinarySensorEntity?
    var weatherEntity: WeatherEntity?
    var selectEntity: SelectEntity?
    var numberEntity: NumberEntity?
    var textEntity: TextEntity?
    var temporalEntity: TemporalEntity?
    var presenceRecord: HAPresenceRecord?
    var pendingCommand: HAEntityPendingCommand?
    private(set) var weatherForecastsByType: [WeatherForecastType: WeatherForecastSnapshot] = [:]
    private(set) var loadingWeatherForecastTypes: Set<WeatherForecastType> = []
    private(set) var weatherForecastErrorsByType: [WeatherForecastType: String] = [:]

    var id: String { homeEntity.entityID }
    var entityID: String { homeEntity.entityID }
    var domain: EntityDomain { homeEntity.domain }

    init(
        homeEntity: HomeEntity,
        lightEntity: LightEntity? = nil,
        climateEntity: ClimateEntity? = nil,
        coverEntity: CoverEntity? = nil,
        fanEntity: FanEntity? = nil,
        mediaPlayerEntity: MediaPlayerEntity? = nil,
        sensorEntity: SensorEntity? = nil,
        binarySensorEntity: BinarySensorEntity? = nil,
        weatherEntity: WeatherEntity? = nil,
        selectEntity: SelectEntity? = nil,
        numberEntity: NumberEntity? = nil,
        textEntity: TextEntity? = nil,
        temporalEntity: TemporalEntity? = nil,
        presenceRecord: HAPresenceRecord? = nil,
        pendingCommand: HAEntityPendingCommand? = nil
    ) {
        self.homeEntity = homeEntity
        self.lightEntity = lightEntity
        self.climateEntity = climateEntity
        self.coverEntity = coverEntity
        self.fanEntity = fanEntity
        self.mediaPlayerEntity = mediaPlayerEntity
        self.sensorEntity = sensorEntity
        self.binarySensorEntity = binarySensorEntity
        self.weatherEntity = weatherEntity
        self.selectEntity = selectEntity
        self.numberEntity = numberEntity
        self.textEntity = textEntity
        self.temporalEntity = temporalEntity
        self.presenceRecord = presenceRecord
        self.pendingCommand = pendingCommand
    }

    func update(
        homeEntity: HomeEntity,
        lightEntity: LightEntity?,
        climateEntity: ClimateEntity?,
        coverEntity: CoverEntity?,
        fanEntity: FanEntity?,
        mediaPlayerEntity: MediaPlayerEntity?,
        sensorEntity: SensorEntity?,
        binarySensorEntity: BinarySensorEntity?,
        weatherEntity: WeatherEntity?,
        selectEntity: SelectEntity?,
        numberEntity: NumberEntity?,
        textEntity: TextEntity?,
        temporalEntity: TemporalEntity?,
        presenceRecord: HAPresenceRecord?,
        pendingCommand: HAEntityPendingCommand?
    ) {
        self.homeEntity = homeEntity
        self.lightEntity = lightEntity
        self.climateEntity = climateEntity
        self.coverEntity = coverEntity
        self.fanEntity = fanEntity
        self.mediaPlayerEntity = mediaPlayerEntity
        self.sensorEntity = sensorEntity
        self.binarySensorEntity = binarySensorEntity
        self.weatherEntity = weatherEntity
        self.selectEntity = selectEntity
        self.numberEntity = numberEntity
        self.textEntity = textEntity
        self.temporalEntity = temporalEntity
        self.presenceRecord = presenceRecord
        self.pendingCommand = pendingCommand
    }

    func beginLoadingWeatherForecast(_ type: WeatherForecastType) {
        loadingWeatherForecastTypes.insert(type)
        weatherForecastErrorsByType.removeValue(forKey: type)
    }

    func applyWeatherForecast(_ snapshot: WeatherForecastSnapshot) {
        weatherForecastsByType[snapshot.type] = snapshot
        loadingWeatherForecastTypes.remove(snapshot.type)
        weatherForecastErrorsByType.removeValue(forKey: snapshot.type)
    }

    func failLoadingWeatherForecast(_ type: WeatherForecastType, message: String) {
        loadingWeatherForecastTypes.remove(type)
        weatherForecastErrorsByType[type] = message
    }

    func clearWeatherForecastLoadingState() {
        loadingWeatherForecastTypes.removeAll()
    }
}
