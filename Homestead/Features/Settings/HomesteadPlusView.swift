import StoreKit
import SwiftUI
import UIKit

struct HomesteadPlusView: View {
    @Environment(HomesteadEntitlementStore.self) private var entitlementStore
    @Environment(\.dismiss) private var dismiss
    @State private var isRedeemingCode = false
    @State private var actionErrorMessage: String?

    var body: some View {
        List {
            heroSection
            featuresSection
            purchaseSection
            accountSection
            legalSection
        }
        .navigationTitle("Homestead Plus")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if entitlementStore.hasPlus {
                    Button("Done") { dismiss() }
                }
            }
        }
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
        .alert("Homestead Plus", isPresented: actionErrorBinding) {
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

                Text(entitlementStore.hasPlus ? "Homestead Plus is active" : "More ways to make Homestead yours")
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text(
                    entitlementStore.hasPlus
                        ? "\(entitlementStore.statusTitle) access is available on this device."
                        : "Core daily home control stays free. Plus supports continued native development and unlocks advanced personalization and Apple integrations."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.large)
            .listRowBackground(Color.clear)
        }
    }

    private var featuresSection: some View {
        Section("Included with Plus") {
            PlusFeatureRow(title: "Multiple Dashboards", systemImage: "rectangle.stack")
            PlusFeatureRow(title: "Multiple Servers", systemImage: "server.rack")
            PlusFeatureRow(title: "iCloud Sync", systemImage: "icloud")
            PlusFeatureRow(title: "Sensor Boards and Advanced Widgets", systemImage: "gauge.with.dots.needle.50percent")
            PlusFeatureRow(title: "Future Apple Integrations", systemImage: "apple.logo")
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
                ProductView(id: HomesteadPlusProduct.annual.rawValue)
                    .productViewStyle(.compact)
            } header: {
                Text(annualSectionTitle)
            } footer: {
                Text(annualDisclosure)
            }

            Section {
                ProductView(id: HomesteadPlusProduct.monthly.rawValue)
                    .productViewStyle(.compact)
                ProductView(id: HomesteadPlusProduct.lifetime.rawValue)
                    .productViewStyle(.compact)
            } header: {
                Text("Other Options")
            } footer: {
                Text("Monthly renews automatically. Lifetime is one payment for permanent access to on-device Plus features.")
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
        Group {
            Section {
                PlusPreviewProductRow(
                    title: "Homestead Plus Annual",
                    detail: "14 days free, then $24.99/year",
                    price: "$24.99"
                )
            } header: {
                Text(annualSectionTitle)
            }

            Section {
                PlusPreviewProductRow(
                    title: "Homestead Plus Monthly",
                    detail: "Renews monthly",
                    price: "$4.99"
                )
                PlusPreviewProductRow(
                    title: "Homestead Plus Lifetime",
                    detail: "One-time purchase",
                    price: "$69.99"
                )
            } header: {
                Text("Other Options")
            }
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

    private var annualSectionTitle: String {
        entitlementStore.isEligibleForAnnualTrial == true
            ? "Best Value • 14-Day Trial"
            : "Best Value"
    }

    private var annualDisclosure: String {
        if entitlementStore.isEligibleForAnnualTrial == true {
            return "Try annual free for 14 days, then it renews yearly unless canceled at least 24 hours before renewal."
        }
        return "The annual plan renews automatically unless canceled at least 24 hours before renewal."
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
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .foregroundStyle(.primary)
    }
}

#if DEBUG
private struct PlusPreviewProductRow: View {
    let title: String
    let detail: String
    let price: String

    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(price)
                .font(.headline)
        }
        .padding(.vertical, AppSpacing.xSmall)
    }
}
#endif

nonisolated enum HomesteadPlusLinks {
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacy = URL(string: "https://github.com/Tygann/Homestead/blob/main/PRIVACY.md")!
}

#if DEBUG
#Preview("Homestead Plus — Free") {
    NavigationStack {
        HomesteadPlusView()
    }
    .environment(HomesteadEntitlementStore(previewPlan: .free))
}

#Preview("Homestead Plus — Lifetime") {
    NavigationStack {
        HomesteadPlusView()
    }
    .environment(HomesteadEntitlementStore(previewPlan: .lifetime))
}

#Preview("Homestead Plus — Annual") {
    NavigationStack {
        HomesteadPlusView()
    }
    .environment(HomesteadEntitlementStore(previewPlan: .annual))
}

#Preview("Homestead Plus — Unavailable") {
    NavigationStack {
        HomesteadPlusView()
    }
    .environment(HomesteadEntitlementStore(
        previewPlan: .free,
        purchaseState: .unavailable("The App Store is unavailable in this preview.")
    ))
}

#Preview("Homestead Plus — Error") {
    NavigationStack {
        HomesteadPlusView()
    }
    .environment(HomesteadEntitlementStore(
        previewPlan: .free,
        purchaseState: .failed("The purchase could not be completed in this preview.")
    ))
}
#endif
