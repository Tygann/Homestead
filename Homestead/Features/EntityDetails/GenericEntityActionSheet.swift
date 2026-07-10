import SwiftUI

struct GenericEntityActionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var textValues: [String: String] = [:]
    @State private var booleanValues: [String: Bool] = [:]
    @State private var isRunning = false

    let action: HAEntityAction
    let entity: HomeEntity

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(action.fields) { field in
                        fieldEditor(field)
                    }
                } footer: {
                    if let description = action.description.description, !description.isEmpty {
                        Text(description)
                    }
                }
            }
            .navigationTitle(action.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Run", role: .confirm) {
                        Task { await run() }
                    }
                    .disabled(isRunning || !hasRequiredValues)
                }
            }
        }
    }

    @ViewBuilder
    private func fieldEditor(_ field: HAEntityActionField) -> some View {
        switch field.kind {
        case .boolean:
            Toggle(field.displayName, isOn: Binding(
                get: { booleanValues[field.key, default: false] },
                set: { booleanValues[field.key] = $0 }
            ))
        case .number:
            LabeledContent(field.displayName) {
                TextField("Value", text: textBinding(for: field.key))
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
            }
        case .select(let options):
            Picker(field.displayName, selection: textBinding(for: field.key)) {
                if !field.isRequired {
                    Text("Default").tag("")
                }
                ForEach(options, id: \.self) { Text($0.displayStateText).tag($0) }
            }
        case .text:
            LabeledContent(field.displayName) {
                TextField(field.isRequired ? "Required" : "Default", text: textBinding(for: field.key))
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private func textBinding(for key: String) -> Binding<String> {
        Binding(
            get: { textValues[key, default: ""] },
            set: { textValues[key] = $0 }
        )
    }

    private var hasRequiredValues: Bool {
        action.fields.allSatisfy { field in
            guard field.isRequired else { return true }
            if case .boolean = field.kind { return true }
            return !(textValues[field.key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    @MainActor
    private func run() async {
        isRunning = true
        let succeeded = await homeAssistantService.callService(
            domain: action.domain,
            service: action.service,
            entityID: entity.entityID,
            serviceData: serviceData,
            successTitle: action.displayName
        )
        isRunning = false
        if succeeded { dismiss() }
    }

    private var serviceData: [String: JSONValue] {
        action.fields.reduce(into: [:]) { result, field in
            switch field.kind {
            case .boolean:
                if field.isRequired || booleanValues[field.key] != nil {
                    result[field.key] = .bool(booleanValues[field.key, default: false])
                }
            case .number:
                if let value = Double(textValues[field.key] ?? "") {
                    result[field.key] = .number(value)
                }
            case .select, .text:
                let value = (textValues[field.key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty { result[field.key] = .string(value) }
            }
        }
    }
}
