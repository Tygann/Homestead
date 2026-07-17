import SwiftUI

struct DashboardIconPickerContext: Identifiable, Equatable {
    let id: UUID
    let defaultSystemName: String
    let selectedSystemName: String?
    let recommendation: DashboardIconRecommendation
}

struct DashboardIconPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedSystemName: String?

    let defaultSystemName: String
    let recommendation: DashboardIconRecommendation
    let onSelectionChange: (String?) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 70, maximum: 92), spacing: AppSpacing.small)
    ]

    init(
        defaultSystemName: String,
        selectedSystemName: String?,
        recommendation: DashboardIconRecommendation,
        onSelectionChange: @escaping (String?) -> Void
    ) {
        self.defaultSystemName = defaultSystemName
        self.recommendation = recommendation
        self.onSelectionChange = onSelectionChange
        _selectedSystemName = State(initialValue: selectedSystemName)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                    defaultIconButton

                    if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        iconSection(
                            title: "Recommended",
                            choices: DashboardIconChoice.recommended(for: recommendation)
                        )

                        ForEach(DashboardIconCategory.allCases) { category in
                            iconSection(
                                title: category.rawValue,
                                choices: DashboardIconChoice.choices.filter { $0.category == category }
                            )
                        }
                    } else if matchingChoices.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                            .frame(maxWidth: .infinity)
                            .padding(.top, AppSpacing.xLarge)
                    } else {
                        iconSection(title: "Results", choices: matchingChoices)
                    }
                }
                .padding(.horizontal, AppSpacing.large)
                .padding(.vertical, AppSpacing.large)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Choose Icon")
            .toolbarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search symbols"
            )
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", role: .confirm) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var matchingChoices: [DashboardIconChoice] {
        DashboardIconChoice.matching(searchText)
    }

    private var defaultIconButton: some View {
        Button {
            select(nil)
        } label: {
            HStack(spacing: AppSpacing.medium) {
                Image(systemName: defaultSystemName)
                    .font(.title3.weight(.semibold))
                    .frame(width: 42, height: 42)
                    .foregroundStyle(selectedSystemName == nil ? Color.accentColor : Color.primary)
                    .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))

                Text("Use Default Icon")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                if selectedSystemName == nil {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(AppSpacing.medium)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityValue(selectedSystemName == nil ? "Selected" : "")
    }

    @ViewBuilder
    private func iconSection(title: String, choices: [DashboardIconChoice]) -> some View {
        if !choices.isEmpty {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                Text(title)
                    .font(.headline)

                LazyVGrid(columns: columns, spacing: AppSpacing.small) {
                    ForEach(choices) { choice in
                        iconButton(choice)
                    }
                }
            }
        }
    }

    private func iconButton(_ choice: DashboardIconChoice) -> some View {
        let isSelected = selectedSystemName == choice.systemName

        return Button {
            select(choice.systemName)
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: choice.systemName)
                        .font(.title2.weight(.medium))
                        .symbolRenderingMode(.monochrome)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption.weight(.bold))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.accentColor)
                            .offset(x: 5, y: -5)
                    }
                }

                Text(choice.title)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
            .padding(.horizontal, 6)
            .padding(.vertical, AppSpacing.small)
            .frame(maxWidth: .infinity, minHeight: 70)
            .background(
                isSelected ? Color.accentColor.opacity(0.14) : Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
            )
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                        .stroke(Color.accentColor, lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(choice.title)
        .accessibilityValue(isSelected ? "Selected" : "")
    }

    private func select(_ systemName: String?) {
        guard selectedSystemName != systemName else { return }
        HapticFeedback.selection()
        selectedSystemName = systemName
        onSelectionChange(systemName)
    }
}

#if DEBUG
#Preview {
    DashboardIconPickerView(
        defaultSystemName: "lightbulb.fill",
        selectedSystemName: "lamp.table.fill",
        recommendation: .domain(.light),
        onSelectionChange: { _ in }
    )
    .withPreviewAccentColor()
}
#endif
