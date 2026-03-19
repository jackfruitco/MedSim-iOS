import Networking
import SwiftUI

struct EnvironmentSwitcherView: View {
    @ObservedObject var store: APIEnvironmentStore
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Picker("Environment", selection: $store.selection) {
                    Text("Production").tag(APIEnvironmentSelection.production)
                    Text("Staging").tag(APIEnvironmentSelection.staging)
                    Text("Local (HTTP)").tag(APIEnvironmentSelection.local)
                    Text("Custom HTTPS").tag(APIEnvironmentSelection.custom)
                }

                if store.selection == .custom {
                    TextField("https://...", text: $store.customURLString)
                        .customURLFieldModifiers()
                }
            }
            .navigationTitle("API Environment")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.persist()
                        onSave()
                        dismiss()
                    }
                }
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func customURLFieldModifiers() -> some View {
        #if os(iOS)
            textInputAutocapitalization(.never)
        #else
            self
        #endif
    }
}
