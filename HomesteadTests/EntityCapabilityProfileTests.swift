import XCTest
@testable import Homestead

@MainActor
final class EntityCapabilityProfileTests: XCTestCase {
    func testReferenceDomainsUseDistinctFamiliesAndRoutes() {
        let sensor = EntityCapabilityRegistry.profile(for: .sensor)
        let cover = EntityCapabilityRegistry.profile(for: .cover)
        let climate = EntityCapabilityRegistry.profile(for: .climate)
        let weather = EntityCapabilityRegistry.profile(for: .weather)

        XCTAssertEqual(sensor.family, .metric)
        XCTAssertEqual(sensor.detailRoute, .sensor)
        XCTAssertEqual(sensor.heroKind, .metric)
        XCTAssertTrue(sensor.supports(.showHistory))

        XCTAssertEqual(cover.family, .positionalSecurity)
        XCTAssertEqual(cover.detailRoute, .cover)
        XCTAssertTrue(cover.supports(.setPosition))

        XCTAssertEqual(climate.family, .environmental)
        XCTAssertEqual(climate.detailRoute, .climate)
        XCTAssertTrue(climate.supports(.setTemperature))

        XCTAssertEqual(weather.family, .informationContent)
        XCTAssertEqual(weather.detailRoute, .weather)
        XCTAssertEqual(weather.heroKind, .environment)
    }

    func testEveryDomainHasACompleteProfile() {
        for domain in EntityDomain.allCases {
            let profile = EntityCapabilityRegistry.profile(for: domain)

            XCTAssertEqual(profile.domain, domain)
            XCTAssertFalse(profile.categoryTitle.isEmpty)
        }
    }

    func testDashboardDetailKindsAdaptFromNeutralRoutes() {
        XCTAssertEqual(DashboardEntityDomainRegistry.capability(for: .light).detailKind, .light)
        XCTAssertEqual(DashboardEntityDomainRegistry.capability(for: .automation).detailKind, .toggle)
        XCTAssertEqual(DashboardEntityDomainRegistry.capability(for: .person).detailKind, .entity)
    }

    func testHistoryUsesPreferredBoundedDomainAndReportsPartialCoverage() {
        let interval = DateInterval(
            start: Date(timeIntervalSince1970: 0),
            end: Date(timeIntervalSince1970: 86_400)
        )
        let series = HAHistoryChartSeries(
            entityID: "sensor.battery",
            displayName: "Battery",
            unit: "%",
            range: .day,
            samples: [
                HAHistorySample(occurredAt: Date(timeIntervalSince1970: 10_000), value: 85),
                HAHistorySample(occurredAt: Date(timeIntervalSince1970: 86_000), value: 72)
            ],
            requestedInterval: interval
        )

        XCTAssertEqual(series.valueDomain(preferredRange: 0...100), 0...100)
        XCTAssertNotNil(series.coverageNotice)
    }

    func testOperationalStateDefaultsToLiveWithoutExceptionalSignals() {
        let presentation = operationalStatePresentation()

        XCTAssertEqual(presentation.operationalState, .live)
        XCTAssertNil(presentation.status)
        XCTAssertNil(presentation.message)
        XCTAssertFalse(presentation.blocksControlInteraction)
    }

    func testOperationalStatePrioritizesUnavailableAndPendingSignals() {
        let unavailable = operationalStatePresentation(isAvailable: false)
        let pending = operationalStatePresentation(
            pendingCommand: HAEntityPendingCommand(entityID: "light.kitchen", expectedState: "on")
        )

        XCTAssertEqual(unavailable.operationalState, .unavailable)
        XCTAssertEqual(unavailable.status?.text, "Unavailable")
        XCTAssertTrue(unavailable.blocksControlInteraction)
        XCTAssertEqual(pending.operationalState, .pending)
        XCTAssertEqual(pending.status?.text, "Updating")
        XCTAssertTrue(pending.blocksControlInteraction)
    }

    func testOperationalStateRepresentsStaleDisconnectedData() {
        let presentation = operationalStatePresentation(
            dataFreshness: .stale("Connection lost", lastUpdated: Date(timeIntervalSince1970: 100)),
            connectionStatus: .reconnecting
        )

        XCTAssertEqual(presentation.operationalState, .stale)
        XCTAssertEqual(presentation.status?.text, "Offline")
        XCTAssertNotNil(presentation.message)
        XCTAssertTrue(presentation.blocksControlInteraction)
    }

    func testOperationalStateScopesFailuresToTheMatchingEntity() {
        let matchingFailure = HAServiceFeedback(
            title: "Could Not Turn On Light",
            message: "Home Assistant rejected the action.",
            style: .failure,
            entityID: "light.kitchen"
        )
        let unrelatedFailure = HAServiceFeedback(
            title: "Could Not Lock Door",
            message: "Home Assistant rejected the action.",
            style: .failure,
            entityID: "lock.front_door"
        )

        let failed = operationalStatePresentation(serviceFeedback: matchingFailure)
        let unaffected = operationalStatePresentation(serviceFeedback: unrelatedFailure)

        XCTAssertEqual(failed.operationalState, .failed)
        XCTAssertEqual(failed.status?.text, "Action Failed")
        XCTAssertEqual(failed.message, matchingFailure.message)
        XCTAssertFalse(failed.blocksControlInteraction)
        XCTAssertEqual(unaffected.operationalState, .live)
    }

    func testNumberEntityMapsEditingConstraintsWithoutRawViewState() throws {
        let dto = HAEntityDTO(
            entityID: "number.target_humidity",
            state: "45.5",
            attributes: [
                "friendly_name": .string("Target Humidity"),
                "min": .number(30),
                "max": .number(60),
                "step": .number(0.5),
                "unit_of_measurement": .string("%"),
                "mode": .string("slider")
            ]
        )

        let number = try XCTUnwrap(EntityMapper.numberEntity(from: dto))

        XCTAssertEqual(number.displayName, "Target Humidity")
        XCTAssertEqual(number.value, 45.5)
        XCTAssertEqual(number.valueRange, 30...60)
        XCTAssertEqual(number.step, 0.5)
        XCTAssertEqual(number.unit, "%")
        XCTAssertEqual(number.displayMode, .slider)

        let stateStore = HAStateStore()
        stateStore.applySnapshot([dto])
        XCTAssertEqual(stateStore.entityBox(for: dto.entityID)?.numberEntity, number)
    }

    func testFeatureProviderExposesOnlyImplementedHistoryAndActivity() throws {
        let numberDTO = HAEntityDTO(
            entityID: "number.target_humidity",
            state: "45",
            attributes: ["min": .number(30), "max": .number(60)]
        )
        let numberBox = HAEntityState(
            homeEntity: EntityMapper.homeEntity(from: numberDTO),
            numberEntity: try XCTUnwrap(EntityMapper.numberEntity(from: numberDTO))
        )
        let switchDTO = HAEntityDTO(entityID: "switch.coffee_maker", state: "on")
        let switchBox = HAEntityState(homeEntity: EntityMapper.homeEntity(from: switchDTO))
        let lightDTO = HAEntityDTO(entityID: "light.kitchen", state: "on")
        let lightBox = HAEntityState(homeEntity: EntityMapper.homeEntity(from: lightDTO))
        let automationDTO = HAEntityDTO(entityID: "automation.good_night", state: "on")
        let automationBox = HAEntityState(homeEntity: EntityMapper.homeEntity(from: automationDTO))

        let numberFeatures = EntityDetailFeatureProvider.features(for: numberBox)
        let switchFeatures = EntityDetailFeatureProvider.features(for: switchBox)
        let lightFeatures = EntityDetailFeatureProvider.features(for: lightBox)
        let automationFeatures = EntityDetailFeatureProvider.features(for: automationBox)

        XCTAssertTrue(numberFeatures.supports(.numericHistory))
        XCTAssertTrue(numberFeatures.supports(.nativeEditor))
        XCTAssertEqual(switchFeatures.activitySource, .stateHistory)
        XCTAssertTrue(switchFeatures.supports(.recentActivity))
        XCTAssertNil(lightFeatures.activitySource)
        XCTAssertFalse(lightFeatures.supports(.recentActivity))
        XCTAssertEqual(automationFeatures.activitySource, .automationTraces)
    }

    func testFeatureProviderRejectsNonNumericSensorHistory() {
        let numericDTO = HAEntityDTO(entityID: "sensor.temperature", state: "72")
        let textDTO = HAEntityDTO(entityID: "sensor.status", state: "Ready")
        let numericBox = HAEntityState(
            homeEntity: EntityMapper.homeEntity(from: numericDTO),
            sensorEntity: EntityMapper.sensorEntity(from: numericDTO)
        )
        let textBox = HAEntityState(
            homeEntity: EntityMapper.homeEntity(from: textDTO),
            sensorEntity: EntityMapper.sensorEntity(from: textDTO)
        )

        XCTAssertTrue(
            EntityDetailFeatureProvider.features(for: numericBox).supports(.numericHistory)
        )
        XCTAssertFalse(
            EntityDetailFeatureProvider.features(for: textBox).supports(.numericHistory)
        )
    }

    private func operationalStatePresentation(
        isAvailable: Bool = true,
        pendingCommand: HAEntityPendingCommand? = nil,
        dataFreshness: HADataFreshness = .live(Date(timeIntervalSince1970: 100)),
        connectionStatus: HAConnectionStatus = .connected,
        serviceFeedback: HAServiceFeedback? = nil
    ) -> EntityDetailStatePresentation {
        let entity = HomeEntity(
            entityID: "light.kitchen",
            domain: .light,
            displayName: "Kitchen Light",
            state: isAvailable ? "off" : "unavailable",
            iconName: "lightbulb",
            isAvailable: isAvailable,
            lastUpdated: Date(timeIntervalSince1970: 100)
        )
        let entityBox = HAEntityState(homeEntity: entity, pendingCommand: pendingCommand)

        return EntityDetailStatePresentation(
            entityBox: entityBox,
            dataFreshness: dataFreshness,
            connectionStatus: connectionStatus,
            serviceFeedback: serviceFeedback
        )
    }
}
