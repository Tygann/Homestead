import SwiftUI

struct DashboardChartSettingsContext: Identifiable {
    let item: DashboardCardItem

    var id: UUID { item.id }
}

struct DashboardChartSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var configuration: DashboardChartConfiguration

    let context: DashboardChartSettingsContext
    let onSave: (DashboardChartConfiguration) -> Void

    init(
        context: DashboardChartSettingsContext,
        onSave: @escaping (DashboardChartConfiguration) -> Void
    ) {
        self.context = context
        self.onSave = onSave
        _configuration = State(initialValue: context.item.chartConfiguration)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DashboardCardView(
                        entityID: context.item.entityID,
                        size: context.item.size,
                        presentationKind: .chart,
                        displayNameOverride: context.item.displayNameOverride,
                        iconNameOverride: context.item.iconNameOverride,
                        chartRange: configuration.range,
                        isPreview: true
                    )
                    .frame(height: context.item.size.renderedHeight(
                        rowSpacing: AppSpacing.medium,
                        cardPadding: AppSpacing.medium
                    ))
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .accessibilityLabel("Chart preview")
                }

                Section {
                    Picker("History Range", selection: $configuration.range) {
                        ForEach(HAHistoryRangePreset.dashboardChartPresets) { range in
                            Text(range.accessibilityTitle)
                                .tag(range)
                        }
                    }
                    .pickerStyle(.navigationLink)
                } header: {
                    Text("Dashboard Range")
                } footer: {
                    Text("Sets the chart shown on this dashboard card. You can explore other ranges in the detail view.")
                }

                if configuration != .default {
                    Section {
                        Button("Restore Default") {
                            configuration = .default
                        }
                    }
                }
            }
            .navigationTitle("Chart Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave(configuration)
                        dismiss()
                    }
                    .disabled(!configuration.isValid)
                }
            }
        }
    }
}
