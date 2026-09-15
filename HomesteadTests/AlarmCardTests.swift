import Foundation
import Testing
@testable import Homestead

@MainActor
struct AlarmCardTests {
    @Test func mapsOnlySupportedAlarmModes() throws {
        for (mask, expected) in [(0, [AlarmServiceAction.disarm]), (1, [.disarm, .armHome]), (6, [.disarm, .armAway, .armNight]), (55, AlarmServiceAction.allCases)] {
            let model = try #require(EntityMapper.alarmEntity(from: fixture(features: mask)))
            #expect(model.actions == expected)
        }
        #expect(EntityMapper.alarmEntity(from: HAEntityDTO(entityID: "switch.alarm", state: "on")) == nil)
    }

    @Test func codeRequirementsFollowFormatAndArmPolicy() throws {
        for format in ["number", "text"] {
            let required = try #require(EntityMapper.alarmEntity(from: fixture(format: format)))
            #expect(required.requiresCode(for: .disarm))
            #expect(required.requiresCode(for: .armAway))
            let armWithoutCode = try #require(EntityMapper.alarmEntity(from: fixture(format: format, armRequired: false)))
            #expect(armWithoutCode.requiresCode(for: .disarm))
            #expect(!armWithoutCode.requiresCode(for: .armAway))
        }
        let noCode = try #require(EntityMapper.alarmEntity(from: fixture()))
        #expect(!noCode.requiresCode(for: .disarm))
        #expect(!noCode.requiresCode(for: .armHome))
    }

    @Test func alarmActionsExposeStableUserFacingModeNames() {
        #expect(AlarmServiceAction.armHome.title == "Home")
        #expect(AlarmServiceAction.armAway.title == "Away")
        #expect(AlarmServiceAction.armNight.title == "Night")
        #expect(AlarmServiceAction.armVacation.title == "Vacation")
        #expect(AlarmServiceAction.armCustomBypass.title == "Custom Bypass")
        #expect(AlarmServiceAction.disarm.expectedState == "disarmed")
        #expect(AlarmServiceAction.disarm.title(isSelected: false) == "Disarm")
        #expect(AlarmServiceAction.disarm.title(isSelected: true) == "Disarmed")
        #expect(AlarmEntity.modeTitle(for: "armed_home") == "Home")
        #expect(AlarmEntity.modeTitle(for: "armed_custom_bypass") == "Custom Bypass")
        #expect(AlarmEntity.modeTitle(for: "triggered") == "Triggered")
    }

    @Test func alarmCapabilitiesRefreshOnExistingEntityBox() throws {
        let store = HAStateStore()
        store.applyInitialStates([fixture(features: 1)])
        let box = try #require(store.entityBox(for: "alarm_control_panel.home"))
        store.applySnapshot([fixture(features: 6, format: "text")])
        #expect(store.entityBox(for: box.entityID) === box)
        #expect(box.alarmEntity?.actions == [.disarm, .armAway, .armNight])
        #expect(box.alarmEntity?.codeFormat == "text")
    }

    @Test func catalogRecommendsAlarmAndRejectsOtherDomains() throws {
        let store = HAStateStore()
        store.applyInitialStates([fixture(), HAEntityDTO(entityID: "lock.front_door", state: "locked")])
        let box = try #require(store.entityBox(for: "alarm_control_panel.home"))
        #expect(DashboardPresentationCatalog.recommendation(for: box) == .card(.alarm(layout: .row)))
        #expect(DashboardPresentationCatalog.isCompatible(.alarm, with: box))
        #expect(!DashboardPresentationCatalog.isCompatible(.alarm, with: try #require(store.entityBox(for: "lock.front_door"))))
        #expect(DashboardAddGalleryFilter.controls.matches(.presentation(DashboardPresentationCatalog.descriptor(for: .alarm))))
        #expect(DashboardPresentationGallerySamples.stateStore.entityBox(for: "alarm_control_panel.home")?.alarmEntity != nil)
    }

    @Test func alarmCardsRoundTripAlongsideExistingStatusCards() throws {
        let defaults = testUserDefaults()
        let configuration = DashboardConfiguration(defaults: defaults)
        let legacy = try #require(configuration.add(source: .entity("alarm_control_panel.home"), presentation: .card(.status(layout: .row))))
        let alarm = try #require(configuration.add(source: .entity("alarm_control_panel.home"), presentation: .card(.alarm(layout: .large))))
        configuration.renameDisplayItem(id: alarm, displayNameOverride: "Security")
        let selectedID = configuration.selectedDashboardID
        let restored = DashboardConfiguration(defaults: defaults)
        #expect(restored.selectedDashboardID == selectedID)
        #expect(restored.items.map(\.id) == [legacy, alarm])
        #expect(restored.items[0].cardConfiguration == .status(layout: .row))
        #expect(restored.items[1].cardConfiguration == .alarm(layout: .large))
        #expect(restored.items[1].displayNameOverride == "Security")
        for layout in DashboardPresentationKind.alarm.supportedLayouts {
            let card = DashboardCardConfiguration.alarm(layout: layout)
            #expect(try JSONDecoder().decode(DashboardCardConfiguration.self, from: JSONEncoder().encode(card)) == card)
        }
    }

    @Test func alarmServicePreservesCodesAndUsesWebSocketContract() async throws {
        let store = HAStateStore()
        store.applySnapshot([fixture()])
        let client = StubHAWebSocketClient()
        let service = HomeAssistantService(
            stateStore: store, client: client,
            mobileAppClient: StubHAMobileAppClient(),
            mobileAppRegistrationStore: InMemoryHAMobileAppRegistrationStore(),
            authManager: HAOAuthManager(tokenStore: InMemoryHAOAuthTokenStore(credential: HAOAuthCredential(baseURLString: "http://homeassistant.local:8123", clientID: HAOAuthClientMetadata.clientID, refreshToken: "test-refresh", accessToken: "alarm-test", accessTokenExpiresAt: .distantFuture, tokenType: "Bearer", updatedAt: .now)))
        )
        await service.setAlarmControlPanelMode(entityID: "alarm_control_panel.home", service: "alarm_disarm", code: "0012")
        await service.setAlarmControlPanelMode(entityID: "alarm_control_panel.home", service: "alarm_arm_custom_bypass", code: " text code ")
        await service.setAlarmControlPanelMode(entityID: "alarm_control_panel.home", service: "alarm_arm_vacation", code: "")
        #expect(client.callServiceInvocations.map(\.domain) == Array(repeating: "alarm_control_panel", count: 3))
        #expect(client.callServiceInvocations.map(\.service) == ["alarm_disarm", "alarm_arm_custom_bypass", "alarm_arm_vacation"])
        #expect(client.callServiceInvocations[0].serviceData["code"] == .string("0012"))
        #expect(client.callServiceInvocations[1].serviceData["code"] == .string(" text code "))
        #expect(client.callServiceInvocations[2].serviceData["code"] == nil)
        #expect(store.entityBox(for: "alarm_control_panel.home")?.pendingCommand?.expectedState == "armed_vacation")
    }

    private func fixture(features: Int = 7, format: String? = nil, armRequired: Bool? = nil) -> HAEntityDTO {
        var attributes: [String: JSONValue] = ["supported_features": .number(Double(features))]
        attributes["code_format"] = format.map(JSONValue.string)
        attributes["code_arm_required"] = armRequired.map(JSONValue.bool)
        return HAEntityDTO(entityID: "alarm_control_panel.home", state: "disarmed", attributes: attributes)
    }
}
