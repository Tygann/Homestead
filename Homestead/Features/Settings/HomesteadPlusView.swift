import StoreKit
import SwiftUI
import UIKit

enum HomesteadPlusPresentationContext {
    case additionalDashboard
    case additionalServer
    case iCloudSync

    var title: String {
        switch self {
        case .additionalDashboard:
            "Create more dashboards with Homestead+"
        case .additionalServer:
            "Connect another home with Homestead+"
        case .iCloudSync:
            "Keep Homestead in sync with Homestead+"
        }
    }

    var systemImage: String {
        switch self {
        case .additionalDashboard:
            "rectangle.stack"
        case .additionalServer:
            "server.rack"
        case .iCloudSync:
            "icloud"
        }
    }
}

struct HomesteadPlusSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HomesteadEntitlementStore.self) private var entitlementStore

    let context: HomesteadPlusPresentationContext?

    init(context: HomesteadPlusPresentationContext? = nil) {
        self.context = context
    }

    var body: some View {
        NavigationStack {
            HomesteadPlusView(context: context)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel("Close Homestead Plus")
                    }
                }
        }
        .onChange(of: entitlementStore.hasPlus) { hadPlus, hasPlus in
            guard context != nil, !hadPlus, hasPlus else { return }
            dismiss()
        }
    }
}

struct HomesteadPlusView: View {
    @Environment(HomesteadEntitlementStore.self) private var entitlementStore
    @State private var isRedeemingCode = false
    @State private var isConfirmingLifetimePurchase = false
    @State private var actionErrorMessage: String?
    @State private var selectedPlan: HomesteadPlusProduct = .annual

    let context: HomesteadPlusPresentationContext?

    init(context: HomesteadPlusPresentationContext? = nil) {
        self.context = context
    }

    var body: some View {
        List {
            heroSection
            currentPlanSection
            purchaseSection
            featuresSection
            accountSection
            legalSection
        }
        .navigationTitle("Homestead+")
        .toolbarTitleDisplayMode(.inline)
        .listSectionSpacing(.custom(AppSpacing.xLarge))
        .safeAreaInset(edge: .bottom) {
            purchaseBar
        }
        .task {
            if entitlementStore.availableProducts.isEmpty {
                await entitlementStore.prepare()
            }
            normalizeSelectedPlan()
        }
        .onInAppPurchaseCompletion { _, result in
            await entitlementStore.handlePurchaseResult(result)
        }
        .offerCodeRedemption(isPresented: $isRedeemingCode) { result in
            Task {
                if case .failure = result {
                    actionErrorMessage = "The code could not be redeemed. Check it and try again."
                }
                await entitlementStore.refreshEntitlements()
            }
        }
        .alert("Homestead+", isPresented: actionErrorBinding) {
            Button("OK", role: .cancel) {
                actionErrorMessage = nil
                entitlementStore.clearError()
            }
        } message: {
            Text(actionErrorMessage ?? purchaseErrorMessage ?? "Please try again.")
        }
        .alert("Keep Your Subscription in Mind", isPresented: $isConfirmingLifetimePurchase) {
            Button("Not Now", role: .cancel) {}
            Button("Buy Lifetime") {
                purchaseLifetime()
            }
        } message: {
            Text(
                "Lifetime access does not automatically cancel your current subscription. "
                    + "Unless you cancel it separately, the subscription may continue renewing."
            )
        }
        .onChange(of: entitlementStore.purchaseState) { _, state in
            if case .failed(let message) = state {
                actionErrorMessage = message
            }
        }
        .onChange(of: availablePlanChoices) { _, choices in
            normalizeSelectedPlan(choices)
        }
    }

    private var heroSection: some View {
        Section {
            VStack(spacing: AppSpacing.xSmall) {
                Image(systemName: context?.systemImage ?? "house.and.flag.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)

                Text(heroTitle)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text(
                    entitlementStore.hasPlus
                        ? "\(entitlementStore.statusTitle) access is available on this device."
                        : "Add more dashboards, homes, sync, and advanced widgets. Core home control always stays free."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.xSmall)
            .listRowBackground(Color.clear)
        }
    }

    private var heroTitle: String {
        if entitlementStore.hasPlus {
            return "Homestead+ is active"
        }
        return context?.title ?? "Make Homestead yours"
    }

    private var featuresSection: some View {
        Section("Included with Homestead+") {
            SettingsManagementOverviewRow(
                title: "More Dashboards and Homes",
                subtitle: "Create more dashboards and connect more Home Assistant servers.",
                systemImage: "rectangle.stack"
            )
            SettingsManagementOverviewRow(
                title: "Sync Across Devices",
                subtitle: "Keep Homestead preferences in sync with iCloud.",
                systemImage: "icloud"
            )
            SettingsManagementOverviewRow(
                title: "Advanced Sensors and Widgets",
                subtitle: "Use Sensor Boards, charts, gauges, zones, and more.",
                systemImage: "gauge.with.dots.needle.50percent"
            )
            SettingsManagementOverviewRow(
                title: "Family Sharing",
                subtitle: "Available for up to five additional family members.",
                systemImage: "person.2"
            )
        }
    }

    @ViewBuilder
    private var currentPlanSection: some View {
        if entitlementStore.hasPlus {
            Section("Your Plan") {
                HStack(spacing: AppSpacing.medium) {
                    Label(currentPlanTitle, systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.primary)

                    Spacer(minLength: AppSpacing.small)

                    Label("Active", systemImage: "checkmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }

                if entitlementStore.activeSubscriptionPlan != nil {
                    Button {
                        manageSubscription()
                    } label: {
                        Label(
                            entitlementStore.plan == .lifetime
                                ? "Manage Existing Subscription"
                                : "Manage Subscription",
                            systemImage: "person.crop.circle"
                        )
                    }
                }
            }
        }
    }

    private var currentPlanTitle: String {
        switch entitlementStore.plan {
        case .free:
            "Free"
        case .trial:
            "Annual Trial"
        case .monthly:
            "Monthly"
        case .annual:
            "Annual"
        case .lifetime:
            "Lifetime"
        }
    }

    @ViewBuilder
    private var purchaseSection: some View {
        if entitlementStore.plan != .lifetime, !entitlementStore.availableProducts.isEmpty {
            Section(entitlementStore.activeSubscriptionPlan == nil ? "Choose a Plan" : "Other Plans") {
                ForEach(availablePlanChoices, id: \.self) { plan in
                    if let product = entitlementStore.product(plan) {
                        planChoice(
                            plan: plan,
                            detail: planDetail(plan, product: product)
                        )
                    }
                }
            }
        } else if entitlementStore.plan != .lifetime {
#if DEBUG
            if entitlementStore.purchaseState == .available {
                previewPurchaseOptions
            } else {
                productLoadingSection
            }
#else
            productLoadingSection
#endif
        }
    }

    @ViewBuilder
    private var productLoadingSection: some View {
        Section {
            switch entitlementStore.purchaseState {
            case .loading:
                HStack {
                    ProgressView()
                    Text("Loading purchase options…")
                        .foregroundStyle(.secondary)
                }
            case .unavailable(let message), .failed(let message):
                ContentUnavailableView(
                    "App Store Unavailable",
                    systemImage: "cart.badge.questionmark",
                    description: Text(message)
                )
                Button("Try Again") {
                    Task { await entitlementStore.prepare() }
                }
                .frame(maxWidth: .infinity)
            case .pending:
                ContentUnavailableView(
                    "Awaiting Approval",
                    systemImage: "clock.badge.checkmark",
                    description: Text("The purchase will unlock automatically after it is approved.")
                )
            case .available, .purchasing, .restoring:
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
    }

#if DEBUG
    private var previewPurchaseOptions: some View {
        Section(entitlementStore.activeSubscriptionPlan == nil ? "Choose a Plan" : "Other Plans") {
            ForEach(availablePlanChoices, id: \.self) { plan in
                switch plan {
                case .annual:
                    planChoice(plan: plan, detail: "14 days free, then $24.99/year")
                case .monthly:
                    planChoice(plan: plan, detail: "$4.99/month, renews monthly")
                case .lifetime:
                    planChoice(plan: plan, detail: "$69.99 one-time purchase")
                }
            }
        }
    }
#endif

    private var availablePlanChoices: [HomesteadPlusProduct] {
        var choices: [HomesteadPlusProduct] = []
        if entitlementStore.activeSubscriptionPlan != .annual,
           entitlementStore.activeSubscriptionPlan != .trial {
            choices.append(.annual)
        }
        if entitlementStore.activeSubscriptionPlan != .monthly {
            choices.append(.monthly)
        }
        choices.append(.lifetime)
        guard !entitlementStore.availableProducts.isEmpty else { return choices }
        return choices.filter { entitlementStore.product($0) != nil }
    }

    private func normalizeSelectedPlan(_ choices: [HomesteadPlusProduct]? = nil) {
        let choices = choices ?? availablePlanChoices
        guard !choices.contains(selectedPlan), let firstChoice = choices.first else { return }
        selectedPlan = firstChoice
    }

    private func planChoice(plan: HomesteadPlusProduct, detail: String) -> some View {
        Button {
            selectedPlan = plan
        } label: {
            HomesteadPlusPlanChoice(
                title: plan.purchaseTitle,
                detail: detail,
                isBestValue: plan == .annual,
                isSelected: selectedPlan == plan
            )
        }
        .buttonStyle(.plain)
        .listRowInsets(
            EdgeInsets(
                top: AppSpacing.xSmall,
                leading: 2,
                bottom: AppSpacing.xSmall,
                trailing: 2
            )
        )
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .accessibilityLabel("\(plan.purchaseTitle), \(detail)")
        .accessibilityValue(selectedPlan == plan ? "Selected" : "Not selected")
        .accessibilityHint("Selects this Homestead Plus plan.")
    }

    @ViewBuilder
    private var purchaseBar: some View {
        if entitlementStore.plan != .lifetime,
           shouldShowPurchaseBar,
           availablePlanChoices.contains(selectedPlan) {
            VStack(spacing: AppSpacing.small) {
                Text(selectedPlanSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button(action: purchaseSelectedPlan) {
                    Text(selectedPlanActionTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.small)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .disabled(isBusy)
                .accessibilityHint("Purchases the selected Homestead Plus plan.")
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.top, AppSpacing.small)
            .padding(.bottom, AppSpacing.xSmall)
            .background(.bar)
            .overlay(alignment: .top) {
                Divider()
            }
        }
    }

    private var shouldShowPurchaseBar: Bool {
        if !entitlementStore.availableProducts.isEmpty {
            return true
        }
#if DEBUG
        return entitlementStore.purchaseState == .available
#else
        return false
#endif
    }

    private var selectedPlanSummary: String {
        if let product = entitlementStore.product(selectedPlan) {
            switch selectedPlan {
            case .annual where entitlementStore.isEligibleForAnnualTrial == true:
                return "14 days free, then \(product.displayPrice)/year"
            case .annual:
                return "\(product.displayPrice)/year, renews yearly"
            case .monthly:
                return "\(product.displayPrice)/month, renews monthly"
            case .lifetime:
                return "\(product.displayPrice) one-time purchase"
            }
        }
#if DEBUG
        switch selectedPlan {
        case .annual: return "14 days free, then $24.99/year"
        case .monthly: return "$4.99/month, renews monthly"
        case .lifetime: return "$69.99 one-time purchase"
        }
#else
        return ""
#endif
    }

    private var selectedPlanActionTitle: String {
        if let product = entitlementStore.product(selectedPlan) {
            switch selectedPlan {
            case .annual where entitlementStore.isEligibleForAnnualTrial == true:
                return "Start Free Trial"
            case .annual:
                return "Subscribe for \(product.displayPrice)/year"
            case .monthly:
                return "Subscribe for \(product.displayPrice)/month"
            case .lifetime:
                return "Purchase for \(product.displayPrice)"
            }
        }
#if DEBUG
        switch selectedPlan {
        case .annual: return "Start Free Trial"
        case .monthly: return "Subscribe for $4.99/month"
        case .lifetime: return "Purchase for $69.99"
        }
#else
        return "Continue"
#endif
    }

    private func planDetail(_ plan: HomesteadPlusProduct, product: Product) -> String {
        switch plan {
        case .annual: annualDetail(for: product)
        case .monthly: "\(product.displayPrice)/month, renews monthly"
        case .lifetime: "\(product.displayPrice) one-time purchase"
        }
    }

    private func purchaseSelectedPlan() {
        if selectedPlan == .lifetime, entitlementStore.activeSubscriptionPlan != nil {
            isConfirmingLifetimePurchase = true
            return
        }
        guard let product = entitlementStore.product(selectedPlan) else {
#if DEBUG
            return
#else
            actionErrorMessage = "This plan is not available from the App Store right now."
            return
#endif
        }
        Task {
            await entitlementStore.purchase(product)
        }
    }

    private var accountSection: some View {
        Section("Purchases") {
            Button {
                Task { await entitlementStore.restorePurchases() }
            } label: {
                Label("Restore Purchases", systemImage: "arrow.clockwise")
            }
            .disabled(isBusy)

            Button {
                isRedeemingCode = true
            } label: {
                Label("Redeem Code", systemImage: "ticket")
            }
            .disabled(isBusy)

            if isBusy {
                HStack {
                    ProgressView()
                    Text(progressTitle)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func annualDetail(for product: Product) -> String {
        if entitlementStore.isEligibleForAnnualTrial == true {
            return "14 days free, then \(product.displayPrice)/year"
        }
        return "Renews yearly"
    }

    private var legalSection: some View {
        Section {
            Link("Terms of Use", destination: HomesteadPlusLinks.terms)
            Link("Privacy Policy", destination: HomesteadPlusLinks.privacy)
        } footer: {
            Text("Payment is charged to your Apple Account. Subscriptions can be canceled in App Store account settings.")
        }
    }

    private var isBusy: Bool {
        switch entitlementStore.purchaseState {
        case .loading, .purchasing, .restoring: true
        case .available, .pending, .unavailable, .failed: false
        }
    }

    private var progressTitle: String {
        switch entitlementStore.purchaseState {
        case .restoring: "Restoring purchases…"
        case .pending: "Awaiting purchase approval…"
        default: "Contacting the App Store…"
        }
    }

    private var purchaseErrorMessage: String? {
        switch entitlementStore.purchaseState {
        case .unavailable(let message), .failed(let message): message
        default: nil
        }
    }

    private var actionErrorBinding: Binding<Bool> {
        Binding(
            get: { actionErrorMessage != nil || purchaseErrorMessage != nil },
            set: {
                if !$0 {
                    actionErrorMessage = nil
                    entitlementStore.clearError()
                }
            }
        )
    }

    private func manageSubscription() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            actionErrorMessage = "Subscription settings are not available right now."
            return
        }

        Task {
            do {
                try await AppStore.showManageSubscriptions(in: scene)
            } catch {
                actionErrorMessage = "Subscription settings could not be opened."
            }
        }
    }

    private func purchaseLifetime() {
        guard let lifetimeProduct = entitlementStore.product(.lifetime) else {
            actionErrorMessage = "Lifetime access is not available from the App Store right now."
            return
        }
        Task {
            await entitlementStore.purchase(lifetimeProduct)
        }
    }
}

private struct HomesteadPlusPlanChoice: View {
    let title: String
    let detail: String
    let isBestValue: Bool
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.medium) {
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                titleAndBadge
                detailText
            }

            Spacer(minLength: AppSpacing.small)
            selectionIndicator
        }
        .contentShape(Rectangle())
        .padding(AppSpacing.medium)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color(uiColor: .separator).opacity(0.45),
                    lineWidth: isSelected ? 2 : 1
                )
        }
    }

    private var titleAndBadge: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppSpacing.small) {
                Text(title)
                    .font(.headline)
                bestValueBadge
            }

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(title)
                    .font(.headline)
                bestValueBadge
            }
        }
    }

    private var detailText: some View {
        Text(detail)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var bestValueBadge: some View {
        if isBestValue {
            Text("Best Value")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, AppSpacing.small)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.14), in: Capsule())
                .fixedSize()
                .accessibilityLabel("Best value")
        }
    }

    private var selectionIndicator: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.title3)
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            .accessibilityHidden(true)
    }
}

private extension HomesteadPlusProduct {
    var purchaseTitle: String {
        switch self {
        case .monthly:
            "Monthly"
        case .annual:
            "Annual"
        case .lifetime:
            "Lifetime"
        }
    }
}

nonisolated enum HomesteadPlusLinks {
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacy = URL(string: "https://github.com/Tygann/Homestead/blob/main/PRIVACY.md")!
}

#if DEBUG
#Preview("Homestead+ — Free") {
    NavigationStack {
        HomesteadPlusView()
    }
    .environment(HomesteadEntitlementStore(previewPlan: .free))
}

#Preview("Homestead+ — Lifetime") {
    NavigationStack {
        HomesteadPlusView()
    }
    .environment(HomesteadEntitlementStore(previewPlan: .lifetime))
}

#Preview("Homestead+ — Lifetime with Subscription") {
    NavigationStack {
        HomesteadPlusView()
    }
    .environment(HomesteadEntitlementStore(
        previewPlan: .lifetime,
        previewActiveSubscriptionPlan: .monthly
    ))
}

#Preview("Homestead+ — Annual") {
    NavigationStack {
        HomesteadPlusView()
    }
    .environment(HomesteadEntitlementStore(previewPlan: .annual))
}

#Preview("Homestead+ — Unavailable") {
    NavigationStack {
        HomesteadPlusView()
    }
    .environment(HomesteadEntitlementStore(
        previewPlan: .free,
        purchaseState: .unavailable("The App Store is unavailable in this preview.")
    ))
}

#Preview("Homestead+ — Error") {
    NavigationStack {
        HomesteadPlusView()
    }
    .environment(HomesteadEntitlementStore(
        previewPlan: .free,
        purchaseState: .failed("The purchase could not be completed in this preview.")
    ))
}

#Preview("Homestead+ — Dashboard Gate") {
    HomesteadPlusSheet(context: .additionalDashboard)
        .environment(HomesteadEntitlementStore(previewPlan: .free))
}

#Preview("Homestead+ — Accessibility") {
    NavigationStack {
        HomesteadPlusView()
    }
    .environment(\.dynamicTypeSize, .accessibility3)
    .environment(HomesteadEntitlementStore(previewPlan: .free))
}
#endif
