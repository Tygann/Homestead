import XCTest
@testable import Homestead

@MainActor
final class EntityCapabilityProfileTests: XCTestCase {
    func testCardEditorNameDraftUsesReplacementCanonicalNameWithoutOverride() {
        var draft = DashboardCardEditorDraft(
            item: DashboardCardItem(
                id: UUID(),
                entityID: "sensor.hall_temperature",
                configuration: .status(layout: .compact),
                displayNameOverride: nil,
                iconNameOverride: nil,
                gaugeZoneConfiguration: nil,
                chartConfiguration: .default
            ),
            canonicalName: "Hall Temperature"
        )
        draft.replaceEntity(
            with: "sensor.bedroom_temperature",
            replacementCanonicalName: "Bedroom Temperature",
            preservesGaugeConfiguration: true
        )

        XCTAssertEqual(draft.displayName, "Bedroom Temperature")
        XCTAssertFalse(draft.usesCustomDisplayName)
        XCTAssertNil(draft.update(canonicalName: "Bedroom Temperature Updated").displayNameOverride)
    }

    func testCardEditorNameDraftPreservesExplicitOverrideAfterReplacement() {
        var draft = DashboardCardEditorDraft(
            item: DashboardCardItem(
                id: UUID(),
                entityID: "sensor.hall_temperature",
                configuration: .status(layout: .compact),
                displayNameOverride: "Comfort",
                iconNameOverride: nil,
                gaugeZoneConfiguration: nil,
                chartConfiguration: .default
            ),
            canonicalName: "Hall Temperature"
        )
        draft.replaceEntity(
            with: "sensor.bedroom_temperature",
            replacementCanonicalName: "Bedroom Temperature",
            preservesGaugeConfiguration: true
        )

        XCTAssertEqual(draft.displayName, "Comfort")
        XCTAssertTrue(draft.usesCustomDisplayName)
        XCTAssertEqual(draft.update(canonicalName: "Bedroom Temperature").displayNameOverride, "Comfort")
    }

    func testChipEditorNameDraftUsesReplacementCanonicalNameWithoutOverride() {
        var draft = DashboardChipEditorDraft(
            item: DashboardChipItem(
                id: UUID(),
                source: .entity("person.tyler"),
                displayNameOverride: nil,
                iconNameOverride: nil
            ),
            canonicalName: "Tyler"
        )
        draft.replaceEntity(
            with: "person.quinn",
            replacementCanonicalName: "Quinn"
        )

        XCTAssertEqual(draft.displayName, "Quinn")
        XCTAssertFalse(draft.usesCustomDisplayName)
        XCTAssertNil(draft.update(canonicalName: "Quinn Updated").displayNameOverride)
    }

    func testChipEditorNameDraftPreservesExplicitOverrideAfterReplacement() {
        var draft = DashboardChipEditorDraft(
            item: DashboardChipItem(
                id: UUID(),
                source: .entity("person.tyler"),
                displayNameOverride: "Someone Home",
                iconNameOverride: nil
            ),
            canonicalName: "Tyler"
        )
        draft.replaceEntity(
            with: "person.quinn",
            replacementCanonicalName: "Quinn"
        )

        XCTAssertEqual(draft.displayName, "Someone Home")
        XCTAssertTrue(draft.usesCustomDisplayName)
        XCTAssertEqual(
            draft.update(canonicalName: "Quinn").displayNameOverride,
            "Someone Home"
        )
    }

    func testPersonChipPrefersHomeAssistantProfilePicture() throws {
        let store = HAStateStore()
        store.applyInitialStates([
            HAEntityDTO(
                entityID: "person.tyler",
                state: "home",
                attributes: [
                    "friendly_name": .string("Tyler"),
                    "entity_picture": .string("/api/image/tyler")
                ]
            )
        ])

        let chip = DashboardSummaryProvider.makeEntityChip(
            entityBox: try XCTUnwrap(store.entityBox(for: "person.tyler"))
        )
        guard case .personProfilePicture(let path, let fallbackIcon) = chip.iconPresentation else {
            return XCTFail("Expected the person chip to prefer its Home Assistant profile picture")
        }

        XCTAssertEqual(path, "/api/image/tyler")
        XCTAssertEqual(fallbackIcon.sfSymbolName, "person.fill")
        XCTAssertEqual(chip.icon, fallbackIcon)
    }

    func testMotionSensorMDIUsesRenderableMotionSymbol() {
        let icon = IconResolver.resolveEntity(
            EntityIconResolutionInput(
                domain: "binary_sensor",
                state: "on",
                explicitIcon: "mdi:motion-sensor"
            )
        )

        XCTAssertEqual(icon.asset, .sfSymbol("figure.walk.motion"))
        XCTAssertEqual(icon.sfSymbolName, "figure.walk.motion")
    }

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

    func testEntityDetailDestinationsPreserveHomeSurfaceWhenFocusingHistory() {
        let dashboardID = UUID()
        let itemID = UUID()
        let reference = DashboardItemReference(dashboardID: dashboardID, itemID: itemID)
        let destination = EntityDetailDestination(
            entityID: "sensor.temperature",
            surfaceContext: .home,
            dashboardItemReference: reference,
            transitionSourceID: "dashboard-card-\(itemID)"
        )

        XCTAssertEqual(destination.entityID, "sensor.temperature")
        XCTAssertEqual(destination.initialSection, .overview)
        XCTAssertEqual(destination.surfaceContext, .home)
        XCTAssertEqual(destination.dashboardItemReference, reference)
        let historyDestination = destination.focusing(.history(initialRange: .week))
        XCTAssertEqual(historyDestination.initialSection, .history(initialRange: .week))
        XCTAssertEqual(historyDestination.surfaceContext, .home)
        XCTAssertEqual(EntityCapabilityRegistry.profile(for: .sensor).detailRoute, .sensor)
    }

    func testEntityDetailDestinationsDefaultToStandardSurface() {
        let destination = EntityDetailDestination(entityID: "sensor.temperature")

        XCTAssertEqual(destination.surfaceContext, .standard)
    }

    func testOnlyChartCardsFocusCanonicalHistory() {
        let destination = EntityDetailDestination(entityID: "sensor.temperature")

        XCTAssertEqual(
            DashboardCardDetailFocusPolicy.destination(
                from: destination,
                presentationKind: .chart,
                chartRange: .month
            ).initialSection,
            .history(initialRange: .month)
        )

        for presentationKind in [
            DashboardPresentationKind.control,
            .status,
            .segmentedGauge,
            .weather,
            .media
        ] {
            XCTAssertEqual(
                DashboardCardDetailFocusPolicy.destination(
                    from: destination,
                    presentationKind: presentationKind,
                    chartRange: .month
                ).initialSection,
                .overview
            )
        }
    }

    func testEntityDetailPresentationIgnoresDashboardOverrides() throws {
        let stateStore = HAStateStore()
        stateStore.applyInitialStates([
            HAEntityDTO(
                entityID: "sensor.outdoor_temperature",
                state: "72",
                attributes: [
                    "friendly_name": .string("Outdoor Temperature"),
                    "device_class": .string("temperature"),
                    "unit_of_measurement": .string("°F")
                ]
            )
        ])
        let entityBox = try XCTUnwrap(stateStore.entityBox(for: "sensor.outdoor_temperature"))
        let detail = EntityDetailPresentationModel(entityBox: entityBox)
        let dashboard = DashboardEntityPresentation(
            entityBox: entityBox,
            displayNameOverride: "Patio",
            iconNameOverride: "sun.max.fill"
        )

        XCTAssertEqual(detail.title, "Outdoor Temperature")
        XCTAssertEqual(detail.icon, entityBox.homeEntity.resolvedIcon)
        XCTAssertEqual(dashboard.title, "Patio")
        XCTAssertNotEqual(dashboard.icon, detail.icon)
    }

    func testPresenceDomainsShareNativeInformationRoute() {
        let person = EntityCapabilityRegistry.profile(for: .person)
        let tracker = EntityCapabilityRegistry.profile(for: .deviceTracker)

        XCTAssertEqual(person.family, .informationContent)
        XCTAssertEqual(tracker.family, .informationContent)
        XCTAssertEqual(person.detailRoute, .presence)
        XCTAssertEqual(tracker.detailRoute, .presence)
        XCTAssertEqual(person.heroKind, .status)
        XCTAssertEqual(tracker.heroKind, .status)
        XCTAssertTrue(person.supports(.showActivity))
        XCTAssertTrue(tracker.supports(.showActivity))
    }

    func testHistoryConstrainsAdaptiveDomainToPreferredBoundsAndReportsPartialCoverage() {
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

        let domain = series.valueDomain(preferredRange: 0...100)
        XCTAssertEqual(domain.lowerBound, 70.44, accuracy: 0.001)
        XCTAssertEqual(domain.upperBound, 86.56, accuracy: 0.001)
        XCTAssertNotNil(series.coverageNotice)
    }

    func testHistoryDomainUsesPreferredBoundaryWhenSamplesReachIt() {
        let series = HAHistoryChartSeries(
            entityID: "sensor.battery",
            displayName: "Battery",
            unit: "%",
            range: .day,
            samples: [
                HAHistorySample(occurredAt: .distantPast, value: 0),
                HAHistorySample(occurredAt: .distantFuture, value: 12)
            ]
        )

        let domain = series.valueDomain(preferredRange: 0...100)
        XCTAssertEqual(domain.lowerBound, 0)
        XCTAssertGreaterThan(domain.upperBound, 12)
    }

    func testEntityDetailFreshnessUsesOneReadableUnit() {
        let now = Date(timeIntervalSince1970: 100_000)

        XCTAssertEqual(EntityDetailHeroSubtitle.freshnessText(since: now.addingTimeInterval(-20), now: now), "just now")
        XCTAssertEqual(EntityDetailHeroSubtitle.freshnessText(since: now.addingTimeInterval(-2_700), now: now), "45 min ago")
        XCTAssertEqual(EntityDetailHeroSubtitle.freshnessText(since: now.addingTimeInterval(-11_400), now: now), "3 hr ago")
    }

    func testHistorySummaryUsesMappedDisplayPrecision() {
        let series = HAHistoryChartSeries(
            entityID: "sensor.temperature",
            displayName: "Temperature",
            unit: "°F",
            displayPrecision: 1,
            range: .day,
            samples: [
                HAHistorySample(occurredAt: .distantPast, value: 69.444),
                HAHistorySample(occurredAt: .distantFuture, value: 75.024)
            ]
        )

        XCTAssertEqual(series.summaryText, "Now 75°F • Low 69.4°F • High 75°F")
    }

    func testHistoryRangesAndDurationWeightedAverage() {
        XCTAssertEqual(HAHistoryRangePreset.activityPresets, [.sixHours, .day, .week, .month])
        XCTAssertEqual(HAHistoryRangePreset.sensorChartPresets, [.sixHours, .day, .week, .month])
        XCTAssertEqual(HAHistoryRangePreset.dashboardChartPresets, [.oneHour, .sixHours, .day, .week])

        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(60 * 60)
        let series = HAHistoryChartSeries(
            entityID: "sensor.temperature",
            displayName: "Temperature",
            unit: "°F",
            range: .oneHour,
            samples: [
                HAHistorySample(occurredAt: start, value: 70),
                HAHistorySample(occurredAt: start.addingTimeInterval(45 * 60), value: 74)
            ],
            requestedInterval: DateInterval(start: start, end: end)
        )

        XCTAssertEqual(series.averageValue ?? .nan, 71, accuracy: 0.001)
    }

    func testTemperatureGaugeUsesCoolColorAtLowExtreme() throws {
        let sensor = SensorEntity(
            entityID: "sensor.temperature",
            displayName: "Temperature",
            value: "75",
            unit: "F",
            deviceClass: "temperature",
            lastUpdated: nil,
            suggestedMinimumValue: 0,
            suggestedMaximumValue: 120
        )

        let presentation = try XCTUnwrap(sensor.gaugePresentation)
        XCTAssertEqual(presentation.sections.first?.status, .warning)
        XCTAssertEqual(presentation.sections.first?.color, GaugeZoneColor.standard(for: .low))
        XCTAssertEqual(presentation.sections.last?.color, nil)
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

    func testEditableHelperDomainsJoinNativeEntityFamilies() {
        XCTAssertEqual(EntityDomain(entityID: "input_select.house_mode"), .select)
        XCTAssertEqual(EntityDomain(entityID: "input_number.target_humidity"), .number)
        XCTAssertEqual(EntityDomain(entityID: "input_text.guest_message"), .text)
        XCTAssertEqual(EntityDomain(entityID: "input_datetime.quiet_hours"), .datetime)

        XCTAssertEqual(EntityCapabilityRegistry.profile(for: .text).detailRoute, .text)
        XCTAssertEqual(EntityCapabilityRegistry.profile(for: .date).detailRoute, .temporal)
        XCTAssertEqual(EntityCapabilityRegistry.profile(for: .time).detailRoute, .temporal)
        XCTAssertEqual(EntityCapabilityRegistry.profile(for: .datetime).detailRoute, .temporal)
    }

    func testTextEntityMapsConstraintsAndValidatesDrafts() throws {
        let dto = HAEntityDTO(
            entityID: "input_text.entry_code",
            state: "A123",
            attributes: [
                "friendly_name": .string("Entry Code"),
                "min": .number(4),
                "max": .number(8),
                "pattern": .string("[A-Z][0-9]+"),
                "mode": .string("password")
            ]
        )

        let text = try XCTUnwrap(EntityMapper.textEntity(from: dto))
        XCTAssertEqual(text.mode, .password)
        XCTAssertEqual(text.minimumLength, 4)
        XCTAssertEqual(text.maximumLength, 8)
        XCTAssertNil(text.validationMessage(for: "B456"))
        XCTAssertNotNil(text.validationMessage(for: "1234"))
        XCTAssertNotNil(text.validationMessage(for: "A1"))

        let stateStore = HAStateStore()
        stateStore.applySnapshot([dto])
        XCTAssertEqual(stateStore.entityBox(for: dto.entityID)?.textEntity, text)
        XCTAssertTrue(EntityDetailFeatureProvider.features(for: try XCTUnwrap(stateStore.entityBox(for: dto.entityID))).supports(.nativeEditor))
    }

    func testTemporalEntitiesMapNativeAndHelperContracts() throws {
        let dateDTO = HAEntityDTO(entityID: "date.vacation", state: "2026-07-24")
        let timeDTO = HAEntityDTO(entityID: "time.wake_up", state: "06:30:00")
        let helperDTO = HAEntityDTO(
            entityID: "input_datetime.quiet_hours",
            state: "22:30:00",
            attributes: ["has_date": .bool(false), "has_time": .bool(true)]
        )

        let date = try XCTUnwrap(EntityMapper.temporalEntity(from: dateDTO))
        let time = try XCTUnwrap(EntityMapper.temporalEntity(from: timeDTO))
        let helper = try XCTUnwrap(EntityMapper.temporalEntity(from: helperDTO))

        XCTAssertEqual(date.kind, .date)
        XCTAssertEqual(date.serviceName, "date.set_value")
        XCTAssertNotNil(date.value)
        XCTAssertEqual(time.kind, .time)
        XCTAssertEqual(time.serviceData(for: try XCTUnwrap(time.value))["time"], .string("06:30:00"))
        XCTAssertEqual(helper.kind, .time)
        XCTAssertEqual(helper.serviceName, "input_datetime.set_datetime")

        let stateStore = HAStateStore()
        stateStore.applySnapshot([dateDTO, timeDTO, helperDTO])
        XCTAssertNotNil(stateStore.entityBox(for: helperDTO.entityID)?.temporalEntity)
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
        XCTAssertEqual(lightFeatures.activitySource, .stateHistory)
        XCTAssertTrue(lightFeatures.supports(.recentActivity))
        XCTAssertEqual(automationFeatures.activitySource, .automationTraces)

        let firstDate = Date(timeIntervalSince1970: 100)
        let secondDate = Date(timeIntervalSince1970: 200)
        let interval = DateInterval(
            start: Date(timeIntervalSince1970: 0),
            end: Date(timeIntervalSince1970: 300)
        )

        let lightEntries = HAHistoryTimeline.entries(
            from: [
                HAHistoryStateDTO(entityID: "light.desk", state: "off", lastChanged: firstDate),
                HAHistoryStateDTO(entityID: "light.desk", state: "on", lastChanged: secondDate)
            ],
            fallbackEntityID: "light.desk",
            matching: "light.desk",
            interval: interval,
            domain: .entity(.light)
        )
        XCTAssertEqual(lightEntries.map(\.title), ["Turned Off", "Turned On"])
        XCTAssertEqual(lightEntries.map(\.tone), [.inactive, .active])

        let scriptEntries = HAHistoryTimeline.entries(
            from: [
                HAHistoryStateDTO(entityID: "script.arrive_home", state: "on", lastChanged: firstDate),
                HAHistoryStateDTO(entityID: "script.arrive_home", state: "off", lastChanged: secondDate)
            ],
            fallbackEntityID: "script.arrive_home",
            matching: "script.arrive_home",
            interval: interval,
            domain: .entity(.script)
        )
        XCTAssertEqual(scriptEntries.map(\.title), ["Started", "Finished"])

        let selectEntries = HAHistoryTimeline.entries(
            from: [
                HAHistoryStateDTO(entityID: "select.house_mode", state: "home", lastChanged: firstDate),
                HAHistoryStateDTO(entityID: "select.house_mode", state: "away", lastChanged: secondDate)
            ],
            fallbackEntityID: "select.house_mode",
            matching: "select.house_mode",
            interval: interval,
            domain: .entity(.select)
        )
        XCTAssertEqual(selectEntries.map(\.title), ["Home", "Away"])
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

    func testInlineHistoryDisclosureStartsWithEightEntries() {
        XCTAssertEqual(EntityHistoryDisclosurePolicy.initialVisibleEntryCount, 8)

        let timeline = HAHistoryTimeline(
            entityID: "light.kitchen",
            displayName: "Kitchen",
            range: .day,
            entries: [
                HAHistoryTimelineEntry(
                    occurredAt: .now,
                    state: "off",
                    title: "Turned Off",
                    systemImage: "lightbulb",
                    tone: .inactive
                ),
                HAHistoryTimelineEntry(
                    occurredAt: .now,
                    state: "on",
                    title: "Turned On",
                    systemImage: "lightbulb.fill",
                    tone: .active
                )
            ]
        )
        XCTAssertEqual(timeline.countText, "2 changes")
    }

    func testWeatherForecastTemperatureScaleUsesAllVisibleDailyRanges() throws {
        let entries = [
            WeatherForecastEntry(
                datetime: .now,
                condition: .sunny,
                temperature: 84,
                lowTemperature: 62,
                precipitation: nil,
                precipitationProbability: nil,
                humidity: nil,
                isDaytime: true,
                windSpeed: nil,
                windBearing: nil
            ),
            WeatherForecastEntry(
                datetime: .now.addingTimeInterval(86_400),
                condition: .rainy,
                temperature: 76,
                lowTemperature: 58,
                precipitation: nil,
                precipitationProbability: 60,
                humidity: nil,
                isDaytime: true,
                windSpeed: nil,
                windBearing: nil
            )
        ]

        XCTAssertEqual(
            try XCTUnwrap(WeatherForecastTemperatureScale.range(for: entries[0])),
            62...84
        )
        XCTAssertEqual(WeatherForecastTemperatureScale.domain(for: entries), 58...84)
        XCTAssertEqual(
            try XCTUnwrap(WeatherForecastTemperatureScale.normalizedPosition(for: 73, in: 58...84)),
            15.0 / 26.0,
            accuracy: 0.0001
        )
        XCTAssertEqual(WeatherForecastDayLabel.title(for: .now), "Today")
    }

    func testFeatureProviderExposesForecastOnlyForSupportedWeatherEntities() throws {
        let supportedDTO = HAEntityDTO(
            entityID: "weather.home",
            state: "sunny",
            attributes: ["supported_features": .number(3)]
        )
        let unsupportedDTO = HAEntityDTO(
            entityID: "weather.legacy",
            state: "sunny"
        )
        let supportedBox = HAEntityState(
            homeEntity: EntityMapper.homeEntity(from: supportedDTO),
            weatherEntity: try XCTUnwrap(EntityMapper.weatherEntity(from: supportedDTO))
        )
        let unsupportedBox = HAEntityState(
            homeEntity: EntityMapper.homeEntity(from: unsupportedDTO),
            weatherEntity: try XCTUnwrap(EntityMapper.weatherEntity(from: unsupportedDTO))
        )

        XCTAssertTrue(EntityDetailFeatureProvider.features(for: supportedBox).supports(.forecast))
        XCTAssertFalse(EntityDetailFeatureProvider.features(for: unsupportedBox).supports(.forecast))
    }

#if DEBUG
    @MainActor
    func testEntityDetailPreviewAppendsHelperOnlyFixtureOverrides() throws {
        let helper = HAEntityDTO(
            entityID: "input_number.preview_target",
            state: "45",
            attributes: [
                "min": .number(30),
                "max": .number(60),
                "step": .number(1)
            ]
        )

        let dependencies = PreviewDependencies.entityDetailSample(entityOverrides: [helper])
        let entityBox = try XCTUnwrap(dependencies.stateStore.entityBox(for: helper.entityID))

        XCTAssertEqual(entityBox.numberEntity?.value, 45)
        XCTAssertEqual(entityBox.numberEntity?.valueRange, 30...60)
    }
#endif

    @MainActor
    func testDashboardMediaAndButtonActionsUseOfficialHomeAssistantServices() async {
        let stateStore = HAStateStore()
        stateStore.applySnapshot([
            HAEntityDTO(entityID: "media_player.living_room", state: "playing"),
            HAEntityDTO(entityID: "button.restart_router", state: "2026-07-20T12:00:00Z")
        ])
        let webSocketClient = StubHAWebSocketClient()
        let service = HomeAssistantService(
            stateStore: stateStore,
            client: webSocketClient,
            mobileAppClient: StubHAMobileAppClient(),
            mobileAppRegistrationStore: InMemoryHAMobileAppRegistrationStore()
        )

        await service.playPauseMedia(entityID: "media_player.living_room")
        await service.setMediaVolume(entityID: "media_player.living_room", volumePercentage: 42)
        await service.selectMediaSource(entityID: "media_player.living_room", source: "Apple TV")
        await service.perform(.pressButton, entityID: "button.restart_router")

        XCTAssertEqual(webSocketClient.callServiceInvocations.map(\.domain), [
            "media_player", "media_player", "media_player", "button"
        ])
        XCTAssertEqual(webSocketClient.callServiceInvocations.map(\.service), [
            "media_play_pause", "volume_set", "select_source", "press"
        ])
        guard webSocketClient.callServiceInvocations.count == 4 else {
            XCTFail("Expected four Home Assistant service calls")
            return
        }
        XCTAssertEqual(webSocketClient.callServiceInvocations[1].serviceData["volume_level"], .number(0.42))
        XCTAssertEqual(webSocketClient.callServiceInvocations[2].serviceData["source"], .string("Apple TV"))
        XCTAssertEqual(webSocketClient.callServiceInvocations[3].entityID, "button.restart_router")
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
