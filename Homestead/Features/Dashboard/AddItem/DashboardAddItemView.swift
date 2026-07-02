import SwiftUI

struct DashboardAddItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HAStateStore.self) private var stateStore
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @State private var mode: DashboardAddItemMode
    @State private var searchText = ""
    private let onAddItem: (UUID) -> Void

    init(initialMode: DashboardAddItemMode, onAddItem: @escaping (UUID) -> Void = { _ in }) {
        _mode = State(initialValue: initialMode)
        self.onAddItem = onAddItem
    }

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .items:
                    itemsContent
                case .cards:
                    cardsContent
                }
            }
            .navigationTitle("Add to Dashboard")
            .toolbarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top, spacing: 0) { modePicker }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", role: .confirm) { dismiss() }
                }
            }
            .navigationDestination(for: DashboardAddRoute.self) { route in
                switch route {
                case .styles(let source):
                    DashboardChooseStyleView(source: source, add: add)
                case .sources(let kind):
                    DashboardCompatibleSourcesView(kind: kind, add: add)
                case .review(let source, let kind):
                    DashboardPresentationReviewView(source: source, kind: kind, add: add)
                case .options(let source, let kind):
                    DashboardPresentationOptionsView(source: source, kind: kind, add: add)
                }
            }
            .onChange(of: mode) { _, _ in searchText = "" }
        }
        .presentationDetents([.large])
    }

    private var modePicker: some View {
        Picker("Add By", selection: $mode) {
            ForEach(DashboardAddItemMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, AppSpacing.large)
        .padding(.vertical, AppSpacing.small)
        .background(Color(.systemGroupedBackground))
    }

    private var itemsContent: some View {
        List {
            if !filteredSummaries.isEmpty {
                Section("Summaries") {
                    ForEach(filteredSummaries) { candidate in
                        sourceRow(
                            source: .summary(candidate.kind),
                            title: candidate.title,
                            subtitle: candidate.value,
                            icon: .sfSymbol(candidate.systemImage, provenance: .homesteadSemanticMapping)
                        )
                    }
                }
            }

            ForEach(filteredEntityGroups) { group in
                Section {
                    ForEach(group.candidates) { candidate in
                        sourceRow(
                            source: .entity(candidate.entityID),
                            title: candidate.displayName,
                            subtitle: candidate.entityID,
                            icon: candidate.icon
                        )
                    }
                } header: {
                    Label(group.title, systemImage: group.systemImage)
                }
            }
        }
        .overlay {
            if !stateStore.hasEntities {
                ContentUnavailableView("No Items Available", systemImage: "square.grid.2x2")
            } else if filteredSummaries.isEmpty && filteredEntityGroups.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }

    private var cardsContent: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: AppSpacing.medium)], spacing: AppSpacing.medium) {
                ForEach(filteredPresentationDescriptors) { descriptor in
                    NavigationLink(value: DashboardAddRoute.sources(descriptor.kind)) {
                        DashboardPresentationGalleryTile(descriptor: descriptor)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(AppSpacing.large)
        }
        .background(Color(.systemGroupedBackground))
        .overlay {
            if filteredPresentationDescriptors.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }

    private func sourceRow(
        source: DashboardAddSource,
        title: String,
        subtitle: String,
        icon: ResolvedIcon
    ) -> some View {
        let recommendation = recommendation(for: source)
        let isAdded = recommendation.map {
            dashboardConfiguration.contains(source: source.reference, presentationKind: $0.kind)
        } ?? false

        return HStack(spacing: AppSpacing.medium) {
            NavigationLink(value: DashboardAddRoute.styles(source)) {
                Label {
                    VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                        Text(title).font(.headline).foregroundStyle(.primary).lineLimit(1)
                        Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                } icon: {
                    HomesteadIconView(icon: icon, pointSize: 18).foregroundStyle(Color.accentColor)
                }
            }
            .accessibilityHint("Choose a style")

            Button {
                guard let recommendation else { return }
                add(source, recommendation)
            } label: {
                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isAdded ? Color.secondary : Color.accentColor)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(isAdded || recommendation == nil)
            .accessibilityLabel(
                isAdded
                    ? "\(recommendation.map { DashboardPresentationCatalog.descriptor(for: $0.kind).title } ?? "Suggested style") added"
                    : "Add \(title) as \(recommendation.map { DashboardPresentationCatalog.descriptor(for: $0.kind).title } ?? "suggested style")"
            )
            .accessibilityHint(isAdded ? "" : "Adds the suggested style")
        }
        .frame(minHeight: 48)
    }

    private var filteredPresentationDescriptors: [DashboardPresentationDescriptor] {
        let query = normalizedSearch
        return DashboardPresentationCatalog.descriptors.filter {
            query.isEmpty || $0.title.localizedCaseInsensitiveContains(query)
        }
    }

    private var filteredSummaries: [DashboardAddSummaryCandidate] {
        let presentations = DashboardSummaryProvider.makeSummaries(
            kinds: DashboardSummaryKind.allCases,
            entityBoxes: stateStore.allEntityBoxes(),
            membershipContext: stateStore.dashboardSummaryMembershipContext()
        )
        return DashboardSummaryKind.allCases.compactMap { kind in
            guard let presentation = presentations[kind] else { return nil }
            let candidate = DashboardAddSummaryCandidate(
                kind: kind,
                title: presentation.title,
                value: presentation.value,
                systemImage: presentation.systemImage
            )
            guard normalizedSearch.isEmpty || candidate.title.localizedCaseInsensitiveContains(normalizedSearch)
                    || candidate.value.localizedCaseInsensitiveContains(normalizedSearch) else { return nil }
            return candidate
        }
    }

    private var filteredEntityGroups: [DashboardAddEntityCandidateGroup] {
        let candidatesByID = Dictionary(uniqueKeysWithValues: stateStore.allEntityBoxes().compactMap { entityBox -> (String, DashboardAddEntityCandidate)? in
            guard entityBox.homeEntity.isAvailable else { return nil }
            let candidate = DashboardAddEntityCandidate(
                entityID: entityBox.entityID,
                displayName: stateStore.displayNameForDeviceGroupedEntity(entityID: entityBox.entityID) ?? entityBox.homeEntity.displayName,
                state: entityBox.homeEntity.state,
                domain: entityBox.domain,
                icon: entityBox.homeEntity.resolvedIcon
            )
            guard normalizedSearch.isEmpty
                    || candidate.displayName.localizedCaseInsensitiveContains(normalizedSearch)
                    || candidate.entityID.localizedCaseInsensitiveContains(normalizedSearch)
                    || candidate.state.localizedCaseInsensitiveContains(normalizedSearch) else { return nil }
            return (entityBox.entityID, candidate)
        })

        if !stateStore.entityIDGroupsByDevice.isEmpty {
            return stateStore.entityIDGroupsByDevice.compactMap { group in
                let candidates = group.entityIDs.compactMap { candidatesByID[$0] }
                guard !candidates.isEmpty else { return nil }
                return DashboardAddEntityCandidateGroup(
                    id: "item-device-\(group.id)",
                    title: group.title,
                    systemImage: "laptopcomputer.and.iphone",
                    candidates: candidates
                )
            }
        }

        return stateStore.entityIDGroupsByDomain.compactMap { group in
            let candidates = group.entityIDs.compactMap { candidatesByID[$0] }
            guard !candidates.isEmpty else { return nil }
            return DashboardAddEntityCandidateGroup(
                id: "item-domain-\(group.domain.rawValue)",
                title: group.domain.displayName,
                systemImage: group.domain.systemImage,
                candidates: candidates
            )
        }
    }

    private var normalizedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func recommendation(for source: DashboardAddSource) -> DashboardPresentationConfiguration? {
        switch source {
        case .summary:
            .chip
        case .entity(let entityID):
            stateStore.entityBox(for: entityID).map(DashboardPresentationCatalog.recommendation(for:))
        }
    }

    private func add(_ source: DashboardAddSource, _ presentation: DashboardPresentationConfiguration) {
        guard let itemID = dashboardConfiguration.add(source: source.reference, presentation: presentation) else { return }
        HapticFeedback.selection()
        onAddItem(itemID)
    }
}

private struct DashboardPresentationGalleryTile: View {
    let descriptor: DashboardPresentationDescriptor

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))
                .frame(height: 92)
                .overlay {
                    DashboardPresentationGalleryPreview(kind: descriptor.kind)
                        .padding(AppSpacing.medium)
                }

            Text(descriptor.title)
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .padding(AppSpacing.medium)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }
}

private struct DashboardPresentationGalleryPreview: View {
    let kind: DashboardPresentationKind

    var body: some View {
        Group {
            switch kind {
            case .chip:
                HStack(spacing: AppSpacing.small) {
                    previewIcon("lightbulb.fill")
                    previewLines
                }
                .padding(.horizontal, AppSpacing.medium)
                .frame(height: 38)
                .background(Color(.secondarySystemGroupedBackground), in: Capsule())
            case .control:
                miniCard {
                    HStack {
                        previewIcon("lightbulb.fill")
                        previewLines
                        Spacer(minLength: AppSpacing.small)
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 22, height: 22)
                            .overlay {
                                Circle().fill(.white).frame(width: 8, height: 8)
                            }
                    }
                }
            case .status:
                miniCard {
                    HStack {
                        previewIcon("thermometer.medium")
                        previewLines
                        Spacer(minLength: AppSpacing.small)
                        Text("72°")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            case .gauge:
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: 0.72)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("72")
                        .font(.headline.monospacedDigit())
                }
                .frame(width: 62, height: 62)
            case .graph:
                graphPreview
            case .camera:
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                        .fill(Color.secondary.opacity(0.12))
                    Image(systemName: "camera.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    previewLines
                        .padding(AppSpacing.small)
                }
            case .weather:
                miniCard {
                    HStack(spacing: AppSpacing.medium) {
                        Image(systemName: "cloud.sun.fill")
                            .font(.title)
                            .symbolRenderingMode(.multicolor)
                        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                            Text("72°").font(.title3.weight(.semibold))
                            previewBar(width: 44)
                        }
                    }
                }
            case .media:
                miniCard {
                    HStack(spacing: AppSpacing.medium) {
                        Image(systemName: "play.circle.fill")
                            .font(.title)
                            .foregroundStyle(Color.accentColor)
                        VStack(alignment: .leading, spacing: AppSpacing.small) {
                            previewLines
                            previewBar(width: 68)
                        }
                    }
                }
            case .action:
                Button {} label: {
                    Label("Run", systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .disabled(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityHidden(true)
    }

    private func miniCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(AppSpacing.medium)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
    }

    private func previewIcon(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.accentColor)
            .frame(width: 28, height: 28)
            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous))
    }

    private var previewLines: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            previewBar(width: 56)
            previewBar(width: 38)
                .opacity(0.55)
        }
    }

    private func previewBar(width: CGFloat) -> some View {
        Capsule()
            .fill(Color.secondary.opacity(0.32))
            .frame(width: width, height: 5)
    }

    private var graphPreview: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))

                Path { path in
                    path.move(to: CGPoint(x: 8, y: proxy.size.height * 0.72))
                    path.addLine(to: CGPoint(x: proxy.size.width * 0.28, y: proxy.size.height * 0.48))
                    path.addLine(to: CGPoint(x: proxy.size.width * 0.48, y: proxy.size.height * 0.62))
                    path.addLine(to: CGPoint(x: proxy.size.width * 0.68, y: proxy.size.height * 0.30))
                    path.addLine(to: CGPoint(x: proxy.size.width - 8, y: proxy.size.height * 0.40))
                }
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

private struct DashboardCompatibleSourcesView: View {
    @Environment(HAStateStore.self) private var stateStore
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @State private var searchText = ""
    let kind: DashboardPresentationKind
    let add: (DashboardAddSource, DashboardPresentationConfiguration) -> Void

    var body: some View {
        List {
            if !filteredSummaryCandidates.isEmpty {
                Section("Summaries") {
                    ForEach(filteredSummaryCandidates) { candidate in
                        sourceLink(
                            .summary(candidate.kind),
                            title: candidate.title,
                            subtitle: candidate.value,
                            icon: .sfSymbol(candidate.systemImage, provenance: .homesteadSemanticMapping)
                        )
                    }
                }
            }

            if !filteredEntityBoxes.isEmpty {
                Section("Entities") {
                    ForEach(filteredEntityBoxes, id: \.entityID) { entityBox in
                        sourceLink(
                            .entity(entityBox.entityID),
                            title: entityBox.homeEntity.displayName,
                            subtitle: entityBox.entityID,
                            icon: entityBox.homeEntity.resolvedIcon
                        )
                    }
                }
            }
        }
        .overlay {
            if filteredSummaryCandidates.isEmpty && filteredEntityBoxes.isEmpty {
                if normalizedSearch.isEmpty {
                    ContentUnavailableView("No Compatible Items", systemImage: "square.grid.2x2")
                } else {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: "Search"
        )
        .navigationTitle(DashboardPresentationCatalog.descriptor(for: kind).title)
    }

    private var filteredEntityBoxes: [HAEntityState] {
        stateStore.allEntityBoxes().filter { entityBox in
            guard entityBox.homeEntity.isAvailable,
                  DashboardPresentationCatalog.isCompatible(kind, with: entityBox) else { return false }
            return normalizedSearch.isEmpty
                || entityBox.homeEntity.displayName.localizedCaseInsensitiveContains(normalizedSearch)
                || entityBox.entityID.localizedCaseInsensitiveContains(normalizedSearch)
                || entityBox.homeEntity.state.localizedCaseInsensitiveContains(normalizedSearch)
        }
    }

    private var filteredSummaryCandidates: [DashboardAddSummaryCandidate] {
        guard kind == .chip else { return [] }
        let summaries = DashboardSummaryProvider.makeSummaries(
            kinds: DashboardSummaryKind.allCases,
            entityBoxes: stateStore.allEntityBoxes(),
            membershipContext: stateStore.dashboardSummaryMembershipContext()
        )
        return DashboardSummaryKind.allCases.compactMap { summaryKind in
            guard let summary = summaries[summaryKind] else { return nil }
            let candidate = DashboardAddSummaryCandidate(
                kind: summaryKind,
                title: summary.title,
                value: summary.value,
                systemImage: summary.systemImage
            )
            guard normalizedSearch.isEmpty
                    || candidate.title.localizedCaseInsensitiveContains(normalizedSearch)
                    || candidate.value.localizedCaseInsensitiveContains(normalizedSearch) else { return nil }
            return candidate
        }
    }

    private var normalizedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @ViewBuilder
    private func sourceLink(
        _ source: DashboardAddSource,
        title: String,
        subtitle: String,
        icon: ResolvedIcon
    ) -> some View {
        let isAdded = dashboardConfiguration.contains(source: source.reference, presentationKind: kind)

        if isAdded {
            HStack {
                sourceLabel(title: title, subtitle: subtitle, icon: icon)
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityValue("Added")
        } else {
            NavigationLink(value: DashboardAddRoute.review(source, kind)) {
                HStack {
                    sourceLabel(title: title, subtitle: subtitle, icon: icon)
                    Spacer()
                }
            }
            .accessibilityHint("Preview and add \(DashboardPresentationCatalog.descriptor(for: kind).title)")
        }
    }

    private func sourceLabel(title: String, subtitle: String, icon: ResolvedIcon) -> some View {
        Label {
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(title).foregroundStyle(.primary).lineLimit(1)
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        } icon: {
            HomesteadIconView(icon: icon, pointSize: 18)
                .foregroundStyle(Color.accentColor)
        }
    }
}
