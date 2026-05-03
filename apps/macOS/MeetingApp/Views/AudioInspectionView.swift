import SwiftUI

struct AudioInspectionView: View {
    @ObservedObject var viewModel: AudioInspectionViewModel

    var body: some View {
        if !viewModel.rows.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Audio")
                    .font(.headline)

                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                    ForEach(viewModel.rows) { row in
                        GridRow {
                            Button {
                                viewModel.togglePlayback(for: row)
                            } label: {
                                Image(systemName: row.isPlaying ? "stop.fill" : "play.fill")
                            }
                            .disabled(!row.exists)
                            .help(row.isPlaying ? "Stop" : "Play")

                            Text(row.label)
                                .frame(width: 48, alignment: .leading)

                            Text(statusText(for: row))
                                .foregroundStyle(row.exists ? .primary : .secondary)

                            Text(detailText(for: row))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func statusText(for row: AudioInspectionRow) -> String {
        guard row.exists else {
            return "Missing"
        }
        return row.duration.map(formatDuration) ?? "Available"
    }

    private func detailText(for row: AudioInspectionRow) -> String {
        let size = row.byteSize.map(formatBytes) ?? "size unknown"
        let modified = row.modifiedAt.map(formatDate) ?? "date unknown"
        return "\(size), \(modified)"
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded()))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func formatDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}

#Preview {
    AudioInspectionView(viewModel: AudioInspectionViewModel())
}
