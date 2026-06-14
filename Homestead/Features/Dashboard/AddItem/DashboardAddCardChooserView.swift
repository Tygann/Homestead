import SwiftUI

struct DashboardAddCardChooserView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HAStateStore.self) private var stateStore
    @State private var featureVisibility: DashboardCardFeatureVisibility = .automatic

    let candidate: DashboardAddCardCandidate
    let add: (DashboardCardSize, DashboardCardFeatureVisibility) -> Void

    init(
        candidate: DashboardAddCardCandidate,
        add: @escaping (DashboardCardSize, DashboardCardFeatureVisibility) -> Void
    ) {
        self.candidate = candidate
        self.add = add
        _featureVisibility = State(initialValue: candidate.recommendedFeatureVisibility)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                    chooserHeader

                    if hasFeatureChoices {
                        featureVisibilityPicker
                    }

                    if let entityBox = stateStore.entityBox(for: candidate.entityID) {
                        VStack(alignment: .leading, spacing: AppSpacing.large) {
                            ForEach(DashboardAddCardPresentation.makeSizeChoices(for: entityBox)) { choice in
                                DashboardAddCardSizeChoiceView(
                                    candidate: candidate,
                                    choice: choice,
                                    featureVisibility: featureVisibility,
                                    add: {
                                        add(choice.size, featureVisibility)
                                        dismiss()
                                    }
                                )
                            }
                        }
                    } else {
                        ContentUnavailableView("Entity Unavailable", systemImage: "questionmark.circle")
                    }
                }
                .padding(AppSpacing.large)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Choose Card")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var chooserHeader: some View {
        Label {
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(candidate.displayName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(candidate.entityID)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        } icon: {
            CardIconView(systemName: candidate.iconName, isActive: false)
        }
    }

    private var hasFeatureChoices: Bool {
        guard let entityBox = stateStore.entityBox(for: candidate.entityID) else {
            return false
        }

        let presentation = DashboardEntityPresentation(entityBox: entityBox)
        return !DashboardCardFeatureProvider.features(for: entityBox, presentation: presentation).isEmpty
    }

    private var featureVisibilityPicker: some View {
        Picker("Card Features", selection: $featureVisibility) {
            ForEach(DashboardCardFeatureVisibility.allCases, id: \.self) { option in
                Label(option.displayName, systemImage: option.systemImage)
                    .tag(option)
            }
        }
        .pickerStyle(.segmented)
    }
}

private struct DashboardAddCardSizeChoiceView: View {
    let candidate: DashboardAddCardCandidate
    let choice: DashboardAddCardSizeChoice
    let featureVisibility: DashboardCardFeatureVisibility
    let add: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HStack(alignment: .center, spacing: AppSpacing.medium) {
                Image(systemName: choice.size.systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 28)

                Text(choice.size.chooserTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if choice.isRecommended {
                    Text("Suggested")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, AppSpacing.small)
                        .frame(height: 24)
                        .background(Color.accentColor.opacity(0.14), in: Capsule())
                        .foregroundStyle(Color.accentColor)
                }

                Spacer(minLength: AppSpacing.small)

                Button("Add", action: add)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .accessibilityHint(accessibilityHint)
            }

            CardGrid {
                DashboardCardView(
                    entityID: candidate.entityID,
                    size: choice.size,
                    featureVisibility: featureVisibility,
                    isPreview: true
                )
                .cardGridSpan(choice.size.layoutMetadata)
            }
            .accessibilityLabel("\(choice.size.chooserTitle) preview")
            .accessibilityHint(accessibilityHint)
        }
        .padding(.vertical, AppSpacing.small)
    }

    private var accessibilityHint: String {
        if featureVisibility == .hidden, !choice.featureTitles.isEmpty {
            return "Features hidden for this card."
        }

        return choice.summary
    }
}
