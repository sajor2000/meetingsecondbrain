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
                .font(.title)
                .fontWeight(.semibold)

            Text("\(module.name) foundation scaffold ready")
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 520, minHeight: 360)
        .padding(32)
    }
}

#Preview {
    ContentView()
}
