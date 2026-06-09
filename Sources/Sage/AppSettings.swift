import Foundation

@Observable
final class AppSettings {
    /// Persisted user preference to use the local MLX model instead of Foundation Models.
    /// Only honoured when `canChooseMLX` is true.
    var preferMLX: Bool {
        didSet { UserDefaults.standard.set(preferMLX, forKey: "preferMLX") }
    }

    /// ID of the currently selected MLX model (matches `MLXModelOption.id`).
    var selectedMLXModelID: String {
        didSet { UserDefaults.standard.set(selectedMLXModelID, forKey: "selectedMLXModelID") }
    }

    /// Resolved model option from the catalog, falling back to the default if the saved ID is stale.
    var selectedMLXModel: MLXModelOption {
        MLXModelCatalog.all.first { $0.id == selectedMLXModelID } ?? MLXModelCatalog.defaultModel
    }

    /// `true` when the device is iOS 26+ with an A17 Pro chip or newer,
    /// meaning the user can pick between Foundation Models and MLX.
    var canChooseMLX: Bool {
        if #available(iOS 26.0, *) {
            return DeviceCapability.isA17OrNewer
        }
        return false
    }

    init() {
        preferMLX = UserDefaults.standard.bool(forKey: "preferMLX")
        selectedMLXModelID = UserDefaults.standard.string(forKey: "selectedMLXModelID")
            ?? MLXModelCatalog.defaultModel.id
    }
}
