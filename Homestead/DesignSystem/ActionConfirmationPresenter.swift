import SwiftUI

struct ActionConfirmationRequest: Identifiable {
    let id = UUID()
    let presentation: ActionConfirmationPresentation
    let perform: () -> Void
}

extension View {
    func actionConfirmationDialog(request: Binding<ActionConfirmationRequest?>) -> some View {
        modifier(ActionConfirmationDialogModifier(request: request))
    }
}

private struct ActionConfirmationDialogModifier: ViewModifier {
    @Binding var request: ActionConfirmationRequest?

    func body(content: Content) -> some View {
        content.confirmationDialog(
            request?.presentation.title ?? "",
            isPresented: isPresented,
            titleVisibility: .visible
        ) {
            if let request {
                Button(
                    request.presentation.confirmTitle,
                    role: request.presentation.isDestructive ? .destructive : nil
                ) {
                    let action = request.perform
                    self.request = nil
                    action()
                }
            }

            Button("Cancel", role: .cancel) {
                request = nil
            }
        } message: {
            if let message = request?.presentation.message {
                Text(message)
            }
        }
    }

    private var isPresented: Binding<Bool> {
        Binding(
            get: { request != nil },
            set: { newValue in
                if !newValue {
                    request = nil
                }
            }
        )
    }
}
