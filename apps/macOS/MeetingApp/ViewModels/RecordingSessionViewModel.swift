import Foundation

@MainActor
final class RecordingSessionViewModel: ObservableObject {
    @Published private(set) var state: RecordingSessionState = .idle
    @Published private(set) var activity: AudioCaptureActivity = .idle
    @Published private(set) var lastStartLatency: TimeInterval?
    @Published private(set) var loadedArtifactInspection: RecordingArtifactLoadResult?

    private let permissionService: CapturePermissionChecking
    private let recorderFactory: @MainActor () -> MeetingAudioRecording
    private let artifactLoader: RecordingArtifactLoading
    private var recorder: MeetingAudioRecording?
    private var activityTask: Task<Void, Never>?
    private let clock: () -> Date

    init(
        permissionService: CapturePermissionChecking = CapturePermissionService(),
        recorderFactory: @escaping @MainActor () -> MeetingAudioRecording = { MeetingAudioRecorder() },
        artifactLoader: RecordingArtifactLoading = RecordingArtifactLoader(),
        clock: @escaping () -> Date = Date.init
    ) {
        self.permissionService = permissionService
        self.recorderFactory = recorderFactory
        self.artifactLoader = artifactLoader
        self.clock = clock
    }

    var canStart: Bool {
        state.canStart
    }

    var canStop: Bool {
        state.canStop
    }

    var completedArtifact: RecordingArtifact? {
        if case let .completed(artifact) = state {
            return artifact
        }
        return nil
    }

    var statusText: String {
        switch state {
        case .idle:
            return "Ready"
        case .checkingPermissions:
            return "Checking permissions"
        case .ready:
            return "Ready"
        case .recording:
            return "Recording"
        case .stopping:
            return "Stopping"
        case .completed:
            return "Completed"
        case let .failed(reason):
            return reason.errorDescription ?? "Recording failed"
        }
    }

    func start() async {
        guard state.canStart else {
            return
        }

        let requestedAt = clock()
        state = .checkingPermissions
        loadedArtifactInspection = nil

        let permissions = await permissionService.checkPermissions()
        guard permissions.microphone == .authorized else {
            state = .failed(.microphonePermissionDenied)
            return
        }
        guard permissions.screenRecording == .authorized else {
            state = .failed(.screenRecordingPermissionDenied)
            return
        }

        state = .ready
        let recorder = recorderFactory()
        self.recorder = recorder
        observeActivity(from: recorder)

        do {
            let artifact = try await recorder.start()
            lastStartLatency = clock().timeIntervalSince(requestedAt)
            state = .recording(RecordingSessionSnapshot(
                sessionId: artifact.sessionId,
                startedAt: artifact.startedAt,
                artifact: artifact
            ))
        } catch {
            state = .failed(.recorderFailed(error.localizedDescription))
            self.recorder = nil
        }
    }

    func loadArtifactFolder(_ directoryURL: URL) {
        guard state.canStart else {
            return
        }

        do {
            let result = try artifactLoader.load(from: directoryURL)
            loadedArtifactInspection = result
            state = .completed(result.artifact)
            activity = .idle
            lastStartLatency = nil
        } catch {
            state = .failed(.artifactLoadFailed(error.localizedDescription))
            loadedArtifactInspection = nil
        }
    }

    func stop() async {
        guard case .recording = state, let recorder else {
            return
        }

        state = .stopping
        do {
            let artifact = try await recorder.stop()
            state = .completed(artifact)
            loadedArtifactInspection = nil
        } catch {
            state = .failed(.recorderFailed(error.localizedDescription))
        }
        activityTask?.cancel()
        activityTask = nil
        self.recorder = nil
    }

    private func observeActivity(from recorder: MeetingAudioRecording) {
        activityTask?.cancel()
        activityTask = Task { [weak self] in
            for await activity in recorder.activityStream {
                await MainActor.run {
                    self?.activity = activity
                }
            }
        }
    }
}
