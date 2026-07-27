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
}

struct HomesteadPlusSheet: View {
    @Environment(\.dismiss) private var dismiss

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
    }
}

struct HomesteadPlusView: View {
    @Environment(HomesteadEntitlementStore.self) private var entitlementStore
    @State private var isRedeemingCode = false
    @State private var actionErrorMessage: String?

    let context: HomesteadPlusPresentationContext?

    init(context: HomesteadPlusPresentationContext? = nil) {
        self.context = context
    }

    var body: some View {
        List {
            heroSection
            featuresSection
            purchaseSection
            accountSection
            legalSection
        }
        .navigationTitle("Homestead+")
        .toolbarTitleDisplayMode(.inline)
        .task {
            if entitlementStore.availableProducts.isEmpty {
                await entitlementStore.prepare()
            }
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
        .onChange(of: entitlementStore.purchaseState) { _, state in
            if case .failed(let message) = state {
                actionErrorMessage = message
            }
        }
    }

    private var heroSection: some View {
        Section {
            VStack(spacing: AppSpacing.medium) {
                Image(systemName: "house.and.flag.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)

                Text(heroTitle)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text(
                    entitlementStore.hasPlus
                        ? "\(entitlementStore.statusTitle) access is available on this device."
                        : "Core home control stays free. Homestead+ unlocks more personalization, synchronization, and advanced widgets."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.medium)
            .listRowBackground(Color.clear)
        }
    }

    private var heroTitle: String {
        if entitlementStore.hasPlus {
            return "Homestead+ is active"
        }
        return context?.title ?? "More ways to make Homestead yours"
    }

    private var featuresSection: some View {
        Section("Included with Homestead+") {
            PlusFeatureRow(
                title: "Multiple Dashboards",
                subtitle: "Create separate views for rooms, routines, or people.",
                systemImage: "rectangle.stack"
            )
            PlusFeatureRow(
                title: "Multiple Servers",
                subtitle: "Switch between more than one Home Assistant home.",
                systemImage: "server.rack"
            )
            PlusFeatureRow(
                title: "iCloud Sync",
                subtitle: "Keep Homestead preferences in sync across devices.",
                systemImage: "icloud"
            )
            PlusFeatureRow(
                title: "Advanced Widgets",
                subtitle: "Use Sensor Boards, charts, gauges, and zones.",
                systemImage: "gauge.with.dots.needle.50percent"
            )
            PlusFeatureRow(
                title: "Family Sharing",
                subtitle: "Available for up to five additional family members.",
                systemImage: "person.3"
            )
        }
    }

    @ViewBuilder
    private var purchaseSection: some View {
        if entitlementStore.plan == .lifetime {
            Section {
                Label("Lifetime access is active.", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Color.accentColor)
            }
        } else if !entitlementStore.availableProducts.isEmpty {
            Section {
                if let annualProduct = entitlementStore.product(.annual) {
                    ProductView(annualProduct)
                        .productViewStyle(HomesteadPlusProductRowStyle(
                            plan: .annual,
                            detail: annualDetail(for: annualProduct)
                        ))
                }
                if let monthlyProduct = entitlementStore.product(.monthly) {
                    ProductView(monthlyProduct)
                        .productViewStyle(HomesteadPlusProductRowStyle(
                            plan: .monthly,
                            detail: "Renews monthly"
                        ))
                }
                if let lifetimeProduct = entitlementStore.product(.lifetime) {
                    ProductView(lifetimeProduct)
                        .productViewStyle(HomesteadPlusProductRowStyle(
                            plan: .lifetime,
                            detail: "One-time purchase"
                        ))
                }
            } header: {
                Text("Choose a Plan")
            } footer: {
                Text("Annual and monthly renew automatically. Lifetime is one payment for permanent Homestead+ access.")
            }
        } else {
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
        Section {
            PlusPreviewProductRow(
                title: "Homestead+ Annual",
                detail: "14 days free, then $24.99/year",
                price: "$24.99",
                isBestValue: true
            )
            PlusPreviewProductRow(
                title: "Homestead+ Monthly",
                detail: "Renews monthly",
                price: "$4.99"
            )
            PlusPreviewProductRow(
                title: "Homestead+ Lifetime",
                detail: "One-time purchase",
                price: "$69.99"
            )
        } header: {
            Text("Choose a Plan")
        } footer: {
            Text("Annual and monthly renew automatically. Lifetime is one payment for permanent Homestead+ access.")
        }
    }
#endif

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

            if entitlementStore.plan == .monthly || entitlementStore.plan == .annual || entitlementStore.plan == .trial {
                Button {
                    manageSubscription()
                } label: {
                    Label("Manage Subscription", systemImage: "person.crop.circle")
                }
            }

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
}

private struct PlusFeatureRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.medium) {
            Image(systemName: systemImage)
                .font(.body)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(title)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, AppSpacing.xSmall)
    }
}

private struct HomesteadPlusProductRowStyle: ProductViewStyle {
    let plan: HomesteadPlusProduct
    let detail: String

    func makeBody(configuration: Configuration) -> some View {
        Group {
            if let product = configuration.product {
                Button {
                    configuration.purchase()
                } label: {
                    HomesteadPlusPlanRow(
                        title: product.displayName,
                        detail: detail,
                        trailingText: configuration.hasCurrentEntitlement ? "Current" : product.displayPrice,
                        isBestValue: plan == .annual,
                        isCurrent: configuration.hasCurrentEntitlement
                    )
                }
                .buttonStyle(.plain)
                .disabled(configuration.hasCurrentEntitlement)
                .accessibilityHint(
                    configuration.hasCurrentEntitlement
                        ? "This is your current plan."
                        : "Purchases this Homestead Plus plan."
                )
            } else {
                HStack {
                    ProgressView()
                    Text("Loading plan…")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct HomesteadPlusPlanRow: View {
    let title: String
    let detail: String
    let trailingText: String
    let isBestValue: Bool
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                HStack(spacing: AppSpacing.small) {
                    Text(title)
                        .font(.headline)

                    if isBestValue {
                        Text("Best Value")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, AppSpacing.small)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.14), in: Capsule())
                            .accessibilityLabel("Best value")
                    }
                }

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: AppSpacing.small)

            if isCurrent {
                Label(trailingText, systemImage: "checkmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .labelStyle(.titleAndIcon)
            } else {
                Text(trailingText)
                    .font(.headline)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, AppSpacing.xSmall)
    }
}

#if DEBUG
private struct PlusPreviewProductRow: View {
    let title: String
    let detail: String
    let price: String
    var isBestValue = false

    var body: some View {
        HomesteadPlusPlanRow(
            title: title,
            detail: detail,
            trailingText: price,
            isBestValue: isBestValue,
            isCurrent: false
        )
    }
}
#endif

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
#endif
