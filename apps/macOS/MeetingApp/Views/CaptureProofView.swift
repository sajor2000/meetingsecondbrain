import SwiftUI

struct CaptureProofView: View {
    @StateObject private var viewModel: RecordingSessionViewModel
    @StateObject private var transcriptionViewModel: TranscriptionProofViewModel

    init(
        viewModel: RecordingSessionViewModel = RecordingSessionViewModel(),
        transcriptionViewModel: TranscriptionProofViewModel = TranscriptionProofViewModel()
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _transcriptionViewModel = StateObject(wrappedValue: transcriptionViewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                controls
                meters
                artifactSummary
                transcriptionSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(32)
        }
        .frame(minWidth: 720, minHeight: 480)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Meeting Second Brain")
                .font(.title)
                .fontWeight(.semibold)

            Text(viewModel.statusText)
                .font(.headline)
                .foregroundStyle(statusColor)
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                Task {
                    await viewModel.start()
                }
            } label: {
                Label("Start", systemImage: "record.circle")
            }
            .disabled(!viewModel.canStart)
            .keyboardShortcut("r", modifiers: [.command])

            Button {
                Task {
                    await viewModel.stop()
                }
            } label: {
                Label("Stop", systemImage: "stop.circle")
            }
            .disabled(!viewModel.canStop)
            .keyboardShortcut(".", modifiers: [.command])
        }
        .buttonStyle(.borderedProminent)
    }

    private var meters: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
            GridRow {
                Text("System")
                    .foregroundStyle(.secondary)
                ProgressView(value: viewModel.activity.systemAudioLevel)
                    .frame(width: 240)
            }

            GridRow {
                Text("Mic")
                    .foregroundStyle(.secondary)
                ProgressView(value: viewModel.activity.microphoneLevel)
                    .frame(width: 240)
            }
        }
    }

    @ViewBuilder
    private var artifactSummary: some View {
        switch viewModel.state {
        case let .recording(snapshot):
            VStack(alignment: .leading, spacing: 8) {
                Text("Session \(snapshot.sessionId)")
                    .font(.subheadline)
                Text(snapshot.artifact.directoryURL.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        case let .completed(artifact):
            VStack(alignment: .leading, spacing: 8) {
                Text("Saved")
                    .font(.subheadline)
                    .fontWeight(.medium)
                artifactPath("System", artifact.systemAudioURL)
                artifactPath("Mic", artifact.microphoneAudioURL)
                artifactPath("Mixed", artifact.mixedAudioURL)
                artifactPath("Metadata", artifact.metadataURL)
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var transcriptionSection: some View {
        if let artifact = viewModel.completedArtifact {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Button {
                        Task {
                            await transcriptionViewModel.transcribe(artifact: artifact)
                        }
                    } label: {
                        Label("Transcribe", systemImage: "waveform.and.magnifyingglass")
                    }
                    .disabled(!transcriptionViewModel.canTranscribe(artifact: artifact))

                    Text(transcriptionStatus(for: artifact))
                        .foregroundStyle(transcriptionStatusColor)
                }

                TranscriptPanelView(state: transcriptionViewModel.state)
            }
        }
    }

    private func transcriptionStatus(for artifact: RecordingArtifact) -> String {
        transcriptionViewModel.unavailableReason(for: artifact) ?? transcriptionViewModel.statusText
    }

    @ViewBuilder
    private func artifactPath(_ label: String, _ url: URL?) -> some View {
        if let url {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(label)
                    .foregroundStyle(.secondary)
                    .frame(width: 64, alignment: .leading)
                Text(url.path)
                    .font(.caption)
                    .textSelection(.enabled)
            }
        }
    }

    private var statusColor: Color {
        switch viewModel.state {
        case .failed:
            return .red
        case .recording:
            return .green
        default:
            return .secondary
        }
    }

    private var transcriptionStatusColor: Color {
        switch transcriptionViewModel.state {
        case .failed:
            return .red
        case .completed:
            return .green
        default:
            return .secondary
        }
    }
}

#Preview {
    CaptureProofView()
}
