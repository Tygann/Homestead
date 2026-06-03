import SwiftUI

enum DashboardDetailPresentationStyle {
    case sheet
    case navigation
    case navigationStack
}

extension View {
    func dashboardDetailPresentation(
        title: String,
        style: DashboardDetailPresentationStyle
    ) -> some View {
        modifier(DashboardDetailPresentationModifier(title: title, style: style))
    }
}

private struct DashboardDetailPresentationModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let style: DashboardDetailPresentationStyle

    func body(content: Content) -> some View {
        switch style {
        case .sheet:
            NavigationStack {
                detailChrome(for: content)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done", role: .close) {
                                dismiss()
                            }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        case .navigation:
            detailChrome(for: content)
        case .navigationStack:
            NavigationStack {
                detailChrome(for: content)
            }
        }
    }

    private func detailChrome(for content: Content) -> some View {
        content
            .navigationTitle(title)
            .toolbarTitleDisplayMode(.inline)
    }
}
