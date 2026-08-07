import Foundation
import Testing
@testable import Homestead

struct WidgetInfrastructureContractTests {
    @Test func snapshotMergeReplacesOnlyMatchingServerAndKeepsRemovedServerData() {
        let firstID = UUID(uuidString: "F486CB8D-85CC-412C-8582-53D311413915")!
        let secondID = UUID(uuidString: "73FAE8ED-1DE8-44AC-A1A6-18EE224AE2E7")!
        let first = snapshot(profileID: firstID, serverName: "Lake House", generatedAt: .distantPast)
        let second = snapshot(profileID: secondID, serverName: "Main Home", generatedAt: .distantPast)
        let replacement = snapshot(profileID: firstID, serverName: "Lake House", generatedAt: .now)

        let merged = WidgetServerSnapshotStore.merging(replacement, into: [first, second])

        #expect(merged.count == 2)
        #expect(merged.first(where: { $0.profileID == firstID })?.generatedAt == replacement.generatedAt)
        #expect(merged.contains(where: { $0.profileID == secondID }))
    }

    @Test func batchedHistoryRequestUsesOfficialPeriodEndpointAndAllEntityIDs() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let end = start.addingTimeInterval(21_600)
        let url = try #require(WidgetHistoryRequest.url(
            baseURLString: "https://example.com/homeassistant",
            entityIDs: ["sensor.one", "sensor.two"],
            startDate: start,
            endDate: end
        ))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))

        #expect(components.path.contains("/homeassistant/api/history/period/"))
        #expect(components.queryItems?.first(where: { $0.name == "filter_entity_id" })?.value == "sensor.one,sensor.two")
        #expect(components.queryItems?.contains(where: { $0.name == "minimal_response" }) == true)
        #expect(components.queryItems?.contains(where: { $0.name == "no_attributes" }) == true)
    }

    @Test func historyRequestKeepsLocalHTTPAndUpgradesRemoteHTTP() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let local = try #require(WidgetHistoryRequest.url(
            baseURLString: "http://homeassistant.local:8123",
            entityIDs: ["sensor.one"],
            startDate: start,
            endDate: start
        ))
        let remote = try #require(WidgetHistoryRequest.url(
            baseURLString: "http://example.com",
            entityIDs: ["sensor.one"],
            startDate: start,
            endDate: start
        ))

        #expect(local.scheme == "http")
        #expect(remote.scheme == "https")
    }

    @Test func widgetHistoryExtendsAStableBoundaryValueThroughTheRequestedEnd() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let end = start.addingTimeInterval(6 * 60 * 60)
        let samples = [HAWidgetHistorySample(occurredAt: start, value: 33.5)]

        let extended = samples.extendingLastKnownValue(to: end)

        #expect(extended.count == 2)
        #expect(extended.first?.occurredAt == start)
        #expect(extended.last?.occurredAt == end)
        #expect(extended.map(\.value) == [33.5, 33.5])
    }

    @Test func widgetHistoryKeepsHomeAssistantsInitialStateAtTheRequestedBoundary() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let interval = DateInterval(start: start, duration: 6 * 60 * 60)

        let sampleDate = WidgetHistoryRequest.sampleDate(
            lastChanged: start.addingTimeInterval(-60 * 60),
            isFirstResponseState: true,
            interval: interval
        )
        let laterPreBoundaryDate = WidgetHistoryRequest.sampleDate(
            lastChanged: start.addingTimeInterval(-30 * 60),
            isFirstResponseState: false,
            interval: interval
        )

        #expect(sampleDate == start)
        #expect(laterPreBoundaryDate == nil)
    }

    @Test func widgetHistoryDoesNotDuplicateASampleAlreadyAtTheRequestedEnd() {
        let end = Date(timeIntervalSince1970: 1_800_021_600)
        let samples = [HAWidgetHistorySample(occurredAt: end, value: 33.5)]

        #expect(samples.extendingLastKnownValue(to: end) == samples)
    }

    @Test func controlActionResolutionIsIndependentOfRenderedStateText() {
        #expect(WidgetControlActionResolver.action(
            domain: "cover",
            isConfigured: true,
            isAvailable: true,
            isActive: false
        ) == .resolveCover)
        #expect(WidgetControlActionResolver.action(
            domain: "lock",
            isConfigured: true,
            isAvailable: true,
            isActive: true
        ) == nil)
        #expect(WidgetControlActionResolver.action(
            domain: "light",
            isConfigured: true,
            isAvailable: false,
            isActive: true
        ) == nil)
    }

    @Test func snapshotChangesReloadOnlyAffectedWidgetProducts() {
        let original = WidgetSnapshotPersistence.Payload(
            lights: [],
            switches: [],
            covers: [],
            fans: [],
            locks: [],
            sensors: [],
            presence: [],
            actions: []
        )
        var sensorUpdate = original
        sensorUpdate.sensors = [
            WidgetSensorSnapshot(
                entityID: "sensor.temperature",
                displayName: "Temperature",
                valueText: "72°F",
                subtitle: "Temperature",
                systemImage: "thermometer",
                unit: "°F",
                isNumeric: true,
                isAlerting: false,
                isAvailable: true,
                areaName: nil,
                deviceName: nil
            )
        ]
        var actionUpdate = original
        actionUpdate.actions = [
            WidgetActionSnapshot(
                entityID: "scene.good_night",
                displayName: "Good Night",
                domain: "scene",
                systemImage: "moon",
                areaName: nil,
                deviceName: nil
            )
        ]

        #expect(WidgetSnapshotPersistence.changedWidgetKinds(
            from: original,
            to: sensorUpdate
        ) == [.sensor, .sensorBoard, .largeSensorBoard])
        #expect(WidgetSnapshotPersistence.changedWidgetKinds(
            from: original,
            to: actionUpdate
        ) == [.action])
        #expect(WidgetSnapshotPersistence.changedWidgetKinds(
            from: nil,
            to: original
        ) == Set(HomesteadWidgetKind.allCases))
    }

    private func snapshot(
        profileID: UUID,
        serverName: String,
        generatedAt: Date
    ) -> WidgetServerSnapshot {
        WidgetServerSnapshot(
            profileID: profileID,
            serverName: serverName,
            generatedAt: generatedAt,
            lights: [],
            switches: [],
            covers: [],
            fans: [],
            locks: [],
            sensors: [],
            presence: [],
            actions: []
        )
    }
}
