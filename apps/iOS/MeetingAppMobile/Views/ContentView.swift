import Core
import SwiftUI

struct ContentView: View {
    private let module: CoreModule

    init(module: CoreModule = CoreModule()) {
        self.module = module
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Meeting Second Brain")
                .font(.title2)
                .fontWeight(.semibold)

            Text("\(module.name) mobile scaffold ready")
                .foregroundStyle(.secondary)
        }
        .padding(24)
    }
}

#Preview {
    ContentView()
}
