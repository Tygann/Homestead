import SwiftUI

struct DashboardItemEditorView: View {
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration

    let reference: DashboardItemReference
    var onEntityReplaced: ((String) -> Void)?

    var body: some View {
        switch dashboardConfiguration.item(for: reference)?.role {
        case .card:
            DashboardCardEditorView(
                reference: reference,
                onEntityReplaced: onEntityReplaced
            )
        case .chip:
            DashboardChipEditorView(
                reference: reference,
                onEntityReplaced: onEntityReplaced
            )
        case .heading, nil:
            ContentUnavailableView(
                "Dashboard Item Unavailable",
                systemImage: "rectangle.slash",
                description: Text("This dashboard item was removed or is no longer editable.")
            )
        }
    }
}
