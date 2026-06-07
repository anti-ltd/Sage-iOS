import SwiftUI
import iUXiOS

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let mlx = model.mlxBackend, model.needsMLXSetup {
            ModelSetupView(mlx: mlx)
        } else {
            ChatView()
        }
    }
}
