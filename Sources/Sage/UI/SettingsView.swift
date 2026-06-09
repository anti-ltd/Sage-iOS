import SwiftUI

#Preview {
    let model = AppModel()
    return SettingsView()
        .environment(model.settings)
        .environment(model)
}

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if settings.canChooseMLX {
                    backendSection
                }

                // Model picker — shown whenever MLX is the active backend
                if model.mlxBackend != nil {
                    modelSection
                }

                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Sections

    private var backendSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { settings.preferMLX },
                set: { model.switchBackend(preferMLX: $0) }
            )) {
                Label("Use Local MLX Model", systemImage: "cpu")
            }
            .disabled(model.isGenerating)
        } header: {
            Text("AI Backend")
        } footer: {
            Text(settings.preferMLX
                 ? "Running a local model on-device — fully private, no internet required after download."
                 : "Using Apple Intelligence (Foundation Models) — fast, on-device, and always available on iOS 26+.")
        }
    }

    private var modelSection: some View {
        Section {
            ForEach(MLXModelCatalog.all) { option in
                Button {
                    guard option.isCompatible, !model.isGenerating else { return }
                    model.switchMLXModel(to: option)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(option.name)
                                    .foregroundStyle(option.isCompatible ? .primary : .secondary)
                                Text(option.tag)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.secondary.opacity(0.15))
                                    .clipShape(Capsule())
                                    .foregroundStyle(.secondary)
                            }
                            HStack(spacing: 4) {
                                Text(option.sizeLabel)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                if !option.isCompatible {
                                    Text("· A17+ required")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        Spacer()
                        if settings.selectedMLXModelID == option.id {
                            Image(systemName: "checkmark")
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.accentColor)
                        } else if !option.isCompatible {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!option.isCompatible || model.isGenerating)
                .opacity(option.isCompatible ? 1 : 0.45)
            }
        } header: {
            Text("Local Model")
        } footer: {
            Text("Switching models clears the current conversation and starts a new download if needed.")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: appVersion)
            LabeledContent("Build", value: appBuild)
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }
}
