import RecallOSCore
import SwiftUI

struct LoadingStateView: View {
    let syncError: String?

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            if let syncError {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(Color.appDanger)
                Text("Could not load meetings")
                    .font(AppFont.sectionHeader)
                Text(syncError)
                    .font(AppFont.secondary)
                    .foregroundStyle(Color.appMutedText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            } else {
                ProgressView("Loading meetings")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppSpacing.xl)
    }
}

enum MacNavigation: Hashable {
    case meeting
    case today
    case allMeetings
    case tasks
    case secondBrain
    case people
    case folder(String)
}
