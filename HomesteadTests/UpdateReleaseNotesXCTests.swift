import XCTest
@testable import Homestead

final class UpdateReleaseNotesXCTests: XCTestCase {
    func testRequestEncodesHomeAssistantShape() throws {
        let request = HAWebSocketRequest.updateReleaseNotes(
            id: 22,
            entityID: "update.matter_server"
        )

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try JSONEncoder().encode(request)) as? [String: Any]
        )

        XCTAssertEqual(object["id"] as? Int, 22)
        XCTAssertEqual(object["type"] as? String, "update/release_notes")
        XCTAssertEqual(object["entity_id"] as? String, "update.matter_server")
    }

    func testEntityMapperRecognizesReleaseNotesFeature() throws {
        let changedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let update = try XCTUnwrap(EntityMapper.updateEntity(from: HAEntityDTO(
            entityID: "update.matter_server",
            state: "on",
            attributes: [
                "friendly_name": .string("Matter Server"),
                "supported_features": .number(25)
            ],
            lastChanged: changedAt
        )))

        XCTAssertTrue(update.supportsBackup)
        XCTAssertTrue(update.supportsReleaseNotes)
        XCTAssertEqual(update.lastChanged, changedAt)
    }

    func testEntityPresentationSuppressesOnlyRedundantDeviceName() throws {
        let duplicateContext = try XCTUnwrap(EntityMapper.updateEntity(
            from: HAEntityDTO(
                entityID: "update.matter_server",
                state: "on",
                attributes: [
                    "friendly_name": .string("Matter Server Update"),
                    "title": .string("Matter Server")
                ]
            ),
            deviceName: "Matter Server"
        ))
        let usefulContext = try XCTUnwrap(EntityMapper.updateEntity(
            from: HAEntityDTO(
                entityID: "update.router_firmware",
                state: "on",
                attributes: ["friendly_name": .string("Router Firmware Update")]
            ),
            deviceName: "Network Rack"
        ))

        XCTAssertEqual(duplicateContext.displayTitle, "Matter Server")
        XCTAssertNil(duplicateContext.distinctDeviceName)
        XCTAssertEqual(usefulContext.distinctDeviceName, "Network Rack")
    }

    func testInstallActionRequiresEntityInstallFeature() throws {
        let readOnlyUpdate = try XCTUnwrap(EntityMapper.updateEntity(from: HAEntityDTO(
            entityID: "update.read_only",
            state: "on",
            attributes: ["supported_features": .number(16)]
        )))
        let installableUpdate = try XCTUnwrap(EntityMapper.updateEntity(from: HAEntityDTO(
            entityID: "update.installable",
            state: "on",
            attributes: ["supported_features": .number(17)]
        )))

        let readOnlyActions = HAUpdateSettingsActionAvailability.make(
            update: readOnlyUpdate,
            serviceActionAvailable: { $1 == "install" }
        )
        let installableActions = HAUpdateSettingsActionAvailability.make(
            update: installableUpdate,
            serviceActionAvailable: { $1 == "install" }
        )

        XCTAssertFalse(readOnlyActions.canInstall)
        XCTAssertTrue(installableActions.canInstall)
    }

    func testDocumentPreservesCommonMarkdownStructure() {
        let document = HAUpdateReleaseNotesDocument(markdown: """
        ## 9.1.1

        - **Important:** Review the [release notes](https://example.com).
          - Nested detail
        2. Second step

        > Back up first.

        ```text
        configuration: safe
        ```
        """)

        XCTAssertEqual(document.blocks, [
            .heading(level: 2, text: "9.1.1"),
            .unorderedListItem(
                depth: 0,
                text: "**Important:** Review the [release notes](https://example.com)."
            ),
            .unorderedListItem(depth: 1, text: "Nested detail"),
            .orderedListItem(depth: 0, ordinal: 2, text: "Second step"),
            .quote("Back up first."),
            .code("configuration: safe")
        ])
    }

    func testDocumentCanOmitRedundantLeadingVersionHeading() {
        let document = HAUpdateReleaseNotesDocument(markdown: """
        ## 9.1.1

        - Compatibility fixes
        """)

        XCTAssertEqual(
            document.omittingLeadingHeading(matching: "9.1.1").blocks,
            [.unorderedListItem(depth: 0, text: "Compatibility fixes")]
        )
        XCTAssertEqual(
            document.omittingLeadingHeading(matching: "9.2.0"),
            document
        )
    }

    @MainActor
    func testServiceFetchesFullNotesThroughWebSocket() async throws {
        let webSocketClient = StubHAWebSocketClient()
        webSocketClient.updateReleaseNotes = "## 9.1.1\n\n- Compatibility fixes"
        let service = HomeAssistantService(
            stateStore: HAStateStore(),
            client: webSocketClient,
            connectionStatus: .connected
        )

        let releaseNotes = try await service.fetchUpdateReleaseNotes(entityID: "update.matter_server")

        XCTAssertEqual(releaseNotes, "## 9.1.1\n\n- Compatibility fixes")
        XCTAssertEqual(webSocketClient.updateReleaseNotesEntityIDs, ["update.matter_server"])
    }
}
