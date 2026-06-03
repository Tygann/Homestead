import SwiftUI

enum EntityDetailPresentationStyle {
    case sheet
    case navigation
    case navigationStack
}

extension View {
    func entityDetailPresentation(
        title: String,
        style: EntityDetailPresentationStyle
    ) -> some View {
        modifier(EntityDetailPresentationModifier(title: title, style: style))
    }
}

private struct EntityDetailPresentationModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let style: EntityDetailPresentationStyle

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
