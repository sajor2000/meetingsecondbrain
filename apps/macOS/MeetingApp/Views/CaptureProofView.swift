import AppKit
import SwiftUI

struct CaptureProofView: View {
    @StateObject private var viewModel: RecordingSessionViewModel
    @StateObject private var transcriptionViewModel: TranscriptionProofViewModel
    @StateObject private var audioInspectionViewModel: AudioInspectionViewModel
    @State private var evidenceCopyStatus: String?

    private let evidenceSummaryBuilder = ManualEvidenceSummaryBuilder()

    init(
        viewModel: RecordingSessionViewModel = RecordingSessionViewModel(),
        transcriptionViewModel: TranscriptionProofViewModel = TranscriptionProofViewModel(),
        audioInspectionViewModel: AudioInspectionViewModel = AudioInspectionViewModel()
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _transcriptionViewModel = StateObject(wrappedValue: transcriptionViewModel)
        _audioInspectionViewModel = StateObject(wrappedValue: audioInspectionViewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                controls
                meters
                artifactSummary
                audioInspectionSection
                evidenceSection
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
                transcriptionViewModel.reset()
                evidenceCopyStatus = nil
                Task {
                    await viewModel.start()
                    audioInspectionViewModel.load(artifact: viewModel.completedArtifact)
                }
            } label: {
                Label("Start", systemImage: "record.circle")
            }
            .disabled(!canReplaceArtifact)
            .keyboardShortcut("r", modifiers: [.command])

            Button {
                Task {
                    await viewModel.stop()
                    audioInspectionViewModel.load(artifact: viewModel.completedArtifact)
                }
            } label: {
                Label("Stop", systemImage: "stop.circle")
            }
            .disabled(!viewModel.canStop)
            .keyboardShortcut(".", modifiers: [.command])

            Button {
                openArtifactFolder()
            } label: {
                Label("Load Folder", systemImage: "folder")
            }
            .disabled(!canReplaceArtifact)
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
                loadedTranscriptPath("Transcript JSON", viewModel.loadedArtifactInspection?.transcriptJSONURL)
                loadedTranscriptPath("Transcript MD", viewModel.loadedArtifactInspection?.transcriptMarkdownURL)
                captureDiagnostics(artifact.captureDiagnostics)
                artifactWarnings(viewModel.loadedArtifactInspection?.warnings ?? [])
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
                        evidenceCopyStatus = nil
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

    @ViewBuilder
    private var audioInspectionSection: some View {
        if viewModel.completedArtifact != nil {
            AudioInspectionView(viewModel: audioInspectionViewModel)
        }
    }

    @ViewBuilder
    private var evidenceSection: some View {
        if let artifact = viewModel.completedArtifact {
            HStack(spacing: 12) {
                Button {
                    copyEvidence(for: artifact)
                } label: {
                    Label("Copy Evidence", systemImage: "doc.on.doc")
                }

                if let evidenceCopyStatus {
                    Text(evidenceCopyStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func transcriptionStatus(for artifact: RecordingArtifact) -> String {
        transcriptionViewModel.unavailableReason(for: artifact) ?? transcriptionViewModel.statusText
    }

    private func openArtifactFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Load"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        transcriptionViewModel.reset()
        evidenceCopyStatus = nil
        viewModel.loadArtifactFolder(url)
        audioInspectionViewModel.load(artifact: viewModel.completedArtifact)
    }

    private func copyEvidence(for artifact: RecordingArtifact) {
        let summary = evidenceSummaryBuilder.build(
            artifact: artifact,
            audioRows: audioInspectionViewModel.rows,
            loadResult: viewModel.loadedArtifactInspection,
            transcriptionArtifact: transcriptionViewModel.completedArtifact
        )
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(summary, forType: .string)
        evidenceCopyStatus = "Copied"
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

    @ViewBuilder
    private func loadedTranscriptPath(_ label: String, _ url: URL?) -> some View {
        if viewModel.loadedArtifactInspection != nil {
            artifactPath(label, url)
        }
    }

    @ViewBuilder
    private func captureDiagnostics(_ diagnostics: RecordingCaptureDiagnostics) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Diagnostics")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("System samples \(diagnostics.systemSampleCount), written \(diagnostics.systemWrittenSampleCount), failures \(diagnostics.systemAppendFailureCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            if let error = diagnostics.lastSystemAppendError {
                Text("System error: \(error)")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .textSelection(.enabled)
            }
            if let mix = diagnostics.mix {
                Text("Mix \(mix.exportStatus ?? "unknown"), inputs \(mix.inputFileCount), inserted \(mix.insertedTrackCount), skipped \(mix.skippedInputCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                if let error = mix.lastInputError {
                    Text("Mix input error: \(error)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .textSelection(.enabled)
                }
                if let error = mix.exportError {
                    Text("Mix error: \(error)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func artifactWarnings(_ warnings: [RecordingArtifactLoadWarning]) -> some View {
        if !warnings.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(warnings.map(\.warningText), id: \.self) { warning in
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding(.top, 4)
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

    private var canReplaceArtifact: Bool {
        viewModel.canStart && transcriptionViewModel.canTranscribe
    }
}

#Preview {
    CaptureProofView()
}

private extension RecordingArtifactLoadWarning {
    var warningText: String {
        errorDescription ?? "Artifact warning"
    }
}
