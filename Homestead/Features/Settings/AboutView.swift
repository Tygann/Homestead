import SwiftUI

struct AboutView: View {
    private let version = Bundle.main.shortVersionString

    var body: some View {
        List {
            Section {
                VStack(spacing: 10) {
                    Image("HomesteadLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .accessibilityHidden(true)

                    Text("Homestead")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Version \(version)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
            }
            .listRowBackground(Color.clear)

            Section {
                Text("A native iOS frontend for Home Assistant, focused on fast access to the devices and spaces you use most.")
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Color.clear)

            Section {
                Text("© 2026 Homestead. All rights reserved.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
        .frame(maxHeight: .infinity)
        .navigationTitle("About")
        .toolbarTitleDisplayMode(.inline)
        .scrollBounceBehavior(.basedOnSize, axes: [.vertical])
    }
}

private extension Bundle {
    var shortVersionString: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}

// MARK: - Preview Provider
#Preview {
    NavigationStack {
        AboutView()
    }
}
