import Core
import SwiftUI

struct TranscriptPanelView: View {
    let state: TranscriptionProofState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transcript")
                .font(.headline)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .idle:
            EmptyTranscriptView(message: "No transcript")
        case .transcribing:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Transcribing")
                    .foregroundStyle(.secondary)
            }
        case let .completed(_, artifact):
            VStack(alignment: .leading, spacing: 12) {
                outputPaths(for: artifact)
                transcriptRows(TranscriptPanelViewModel(transcript: artifact.transcript))
            }
        case let .failed(_, reason):
            EmptyTranscriptView(message: reason.errorDescription ?? "Transcription failed")
        }
    }

    private func outputPaths(for artifact: TranscriptionArtifact) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            artifactValue("Duration", durationText(for: artifact))
            artifactPath("JSON", artifact.jsonURL)
            artifactPath("Markdown", artifact.markdownURL)
        }
    }

    @ViewBuilder
    private func transcriptRows(_ viewModel: TranscriptPanelViewModel) -> some View {
        if viewModel.isEmpty {
            EmptyTranscriptView(message: "No transcript segments")
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(viewModel.rows) { row in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(row.timestamp)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 48, alignment: .leading)

                            if let speaker = row.speaker {
                                Text(speaker)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .frame(width: 56, alignment: .leading)
                            }

                            Text(row.text)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .frame(minHeight: 120, maxHeight: 260)
        }
    }

    private func artifactPath(_ label: String, _ url: URL) -> some View {
        artifactValue(label, url.path)
    }

    private func artifactValue(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.caption)
                .textSelection(.enabled)
        }
    }

    private func durationText(for artifact: TranscriptionArtifact) -> String {
        let elapsed = max(0, artifact.completedAt.timeIntervalSince(artifact.startedAt))
        return String(format: "%.1fs", elapsed)
    }
}

private struct EmptyTranscriptView: View {
    let message: String

    var body: some View {
        Text(message)
            .foregroundStyle(.secondary)
    }
}

#Preview {
    TranscriptPanelView(state: .idle)
}
