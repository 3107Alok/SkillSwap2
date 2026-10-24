import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var config: AppConfig
    @Environment(\.dismiss) private var dismiss
    @State private var status: String?
    @State private var checking = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Backend address"),
                        footer: Text("Simulator: http://127.0.0.1:5000. Real iPhone: the Mac's Wi-Fi address, e.g. http://192.168.1.23:5000 (run ./scripts/show_ip.sh on the Mac).")) {
                    TextField("Backend address", text: $config.baseURL)
                    Button(checking ? "Checking..." : "Test connection") { testConnection() }
                        .disabled(checking)
                    if let status = status {
                        Text(status).font(.footnote)
                    }
                }
                Section(header: Text("Sign-in mode"),
                        footer: Text("Must match AUTH_MODE in backend/.env. Close and reopen the app after changing it.")) {
                    Picker("Mode", selection: $config.authMode) {
                        ForEach(AuthMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private struct Health: Decodable {
        let ok: Bool
        let authMode: String
        let store: String
    }

    private func testConnection() {
        checking = true
        status = nil
        Task {
            do {
                let h: Health = try await API.shared.get("/api/health")
                status = "Connected. Backend sign-in mode: \(h.authMode), storage: \(h.store)."
            } catch {
                status = error.localizedDescription
            }
            checking = false
        }
    }
}
