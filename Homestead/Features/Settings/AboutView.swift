import SwiftUI

struct AboutView: View {
    @State private var showMailView = false

    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as! String

    var body: some View {
        List {
            // Header
            Section {
                VStack {
//                    Image(systemName: "house.fill")
                    Image("HomesteadLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .foregroundStyle(.blue.gradient)


                    Text("Homestead")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Version \(version)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)

            // About Description
            Section {
                HStack {
                    Spacer()

                    Text("Homestead is your ultimate companion for controlling your Home Assistant system. The app is as user friendly as it is powerful, designed by a passionate home owner just like yourself.")
                        .multilineTextAlignment(.center)

                    Spacer()
                }
            }
//            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            Spacer()
                .listRowBackground(Color.clear)

            // Email Support Button
            Section {
                Button(action: {
                    self.showMailView.toggle()
                }) {
                    Label {
                        Text("Contact Support")
                            .foregroundColor(.primary)
                    } icon: {
                        Image(systemName: "exclamationmark.bubble")
                    }
                }
            }

            // Footer Section
            Section {
                VStack {
                    // Copyright
                    Text("© 2026 Homestead. All rights reserved.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
        .frame(maxHeight: .infinity)
        .navigationBarTitle("About", displayMode: .inline)
        .scrollBounceBehavior(.basedOnSize, axes: [.vertical])
//        .sheet(isPresented: $showMailView) {
//            MailView(
//                recipients: ["support@renfo.app"],
//                subject: "Support Request",
//                body: """
//                Version: \(version)
//                Build: \(build)
//                Device: \(UIDevice.current.name)
//                iOS: \(UIDevice.current.systemVersion)
//
//                Please describe your issue or request:
//                """
//            )
//        }
    }
}

// MARK: - Preview Provider
#Preview {
    NavigationStack {
        AboutView()
    }
}
