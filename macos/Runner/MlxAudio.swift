import AVFoundation
import Darwin
import Foundation
import FlutterMacOS

#if arch(arm64) && canImport(MLX)
@preconcurrency import MLX
#endif
#if arch(arm64) && canImport(HuggingFace)
import HuggingFace
#endif
#if arch(arm64) && canImport(MLXAudioCore)
import MLXAudioCore
#endif
#if arch(arm64) && canImport(MLXAudioSTT)
import MLXAudioSTT
#endif
#if arch(arm64) && canImport(MLXAudioTTS)
import MLXAudioTTS
#endif
#if arch(arm64) && canImport(MLXAudioVAD)
import MLXAudioVAD
#endif

private enum MlxAudioBridgeError: LocalizedError {
    case unsupportedModel(String)
    case modelNotInstalled(String)
    case inferenceBusy(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedModel(let repo):
            return "Unsupported MLX Audio STT model: \(repo)"
        case .modelNotInstalled(let repo):
            return "MLX Audio model is not installed yet: \(repo)"
        case .inferenceBusy(let message):
            return message
        }
    }
}

private actor MlxAudioAsyncSemaphore {
    private struct Waiter {
        let id: UUID
        let continuation: CheckedContinuation<Void, Error>
    }

    private var availablePermits: Int
    private var waiters: [Waiter] = []

    init(value: Int) {
        availablePermits = value
    }

    func wait() async throws {
        if availablePermits > 0 {
            availablePermits -= 1
            return
        }

        let id = UUID()
        try await withTaskCancellationHandler {
            // Xcode 26 SDK can no longer infer T from the closure body that
            // stores the continuation in `waiters`. Pin the result type
            // explicitly so the call resolves without an inference failure.
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, Error>) in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else {
                    waiters.append(Waiter(id: id, continuation: continuation))
                }
            }
        } onCancel: {
            Task { await self.cancelWaiter(id: id) }
        }
    }

    private func cancelWaiter(id: UUID) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else {
            return
        }
        let waiter = waiters.remove(at: index)
        waiter.continuation.resume(throwing: CancellationError())
    }

    func signal() {
        guard !waiters.isEmpty else {
            availablePermits += 1
            return
        }

        waiters.removeFirst().continuation.resume()
    }
}

private final class MlxAudioEventStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    var onListen: (() -> Void)?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        onListen?()
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    func emit(_ payload: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(payload)
        }
    }
}

private final class MlxAudioStreamingDownloader: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private static let delegateQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.matthiasn.lotti.mlx_audio.download_delegate"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    private let destination: URL
    private let temporaryURL: URL
    private let onProgress: @Sendable (Int64) -> Void
    private var continuation: CheckedContinuation<Void, Error>?
    private var fileHandle: FileHandle?
    private var session: URLSession?
    private var receivedBytes: Int64 = 0
    private var lastEmittedBytes: Int64 = 0
    private var lastEmitTime = Date.distantPast
    private var completed = false
    private var pendingError: Error?

    static func download(
        from url: URL,
        to destination: URL,
        temporaryURL: URL,
        onProgress: @escaping @Sendable (Int64) -> Void
    ) async throws {
        let downloader = MlxAudioStreamingDownloader(
            destination: destination,
            temporaryURL: temporaryURL,
            onProgress: onProgress
        )
        try await downloader.start(url: url)
    }

    private init(
        destination: URL,
        temporaryURL: URL,
        onProgress: @escaping @Sendable (Int64) -> Void
    ) {
        self.destination = destination
        self.temporaryURL = temporaryURL
        self.onProgress = onProgress
    }

    private func start(url: URL) async throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? fileManager.removeItem(at: temporaryURL)
        _ = fileManager.createFile(atPath: temporaryURL.path, contents: nil)
        fileHandle = try FileHandle(forWritingTo: temporaryURL)

        do {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                var request = URLRequest(url: url)
                request.setValue("lotti/mlx-audio", forHTTPHeaderField: "User-Agent")
                let session = URLSession(
                    configuration: .default,
                    delegate: self,
                    delegateQueue: Self.delegateQueue
                )
                self.session = session
                session.dataTask(with: request).resume()
            }
            try fileHandle?.close()
            fileHandle = nil
            try? fileManager.removeItem(at: destination)
            try fileManager.moveItem(at: temporaryURL, to: destination)
        } catch {
            session?.invalidateAndCancel()
            session = nil
            try? fileHandle?.close()
            fileHandle = nil
            try? fileManager.removeItem(at: temporaryURL)
            throw error
        }

        session?.finishTasksAndInvalidate()
        session = nil
    }

    func urlSession(
        _: URLSession,
        dataTask _: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let httpResponse = response as? HTTPURLResponse,
              (200 ..< 300).contains(httpResponse.statusCode)
        else {
            pendingError = URLError(.badServerResponse)
            completionHandler(.cancel)
            return
        }
        completionHandler(.allow)
    }

    func urlSession(
        _: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        do {
            try fileHandle?.write(contentsOf: data)
            receivedBytes += Int64(data.count)
            emitProgressIfNeeded()
        } catch {
            pendingError = error
            dataTask.cancel()
        }
    }

    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if pendingError == nil, error == nil {
            onProgress(receivedBytes)
        }
        complete(with: pendingError ?? error)
    }

    private func emitProgressIfNeeded() {
        let now = Date()
        guard receivedBytes - lastEmittedBytes >= 8_000_000 ||
              now.timeIntervalSince(lastEmitTime) >= 0.5
        else {
            return
        }
        lastEmittedBytes = receivedBytes
        lastEmitTime = now
        onProgress(receivedBytes)
    }

    private func complete(with error: Error?) {
        guard !completed else { return }
        completed = true
        if let error {
            continuation?.resume(throwing: error)
        } else {
            continuation?.resume()
        }
        continuation = nil
    }
}

/// Flutter bridge for embedded MLX Audio.
///
/// The app still ships on Intel macOS. Keep all SDK references behind the
/// compile-time MLX condition so x86 builds return `unsupported` instead of
/// requiring Apple Silicon-only libraries.
final class MlxAudio: NSObject {
    private static let methodChannelName = "com.matthiasn.lotti/mlx_audio"
    private static let eventChannelName = "com.matthiasn.lotti/mlx_audio/events"
    private static let realtimeEventChannelName = "com.matthiasn.lotti/mlx_audio/realtime_events"
    private static let unsupportedMessage =
        "MLX Audio requires Apple Silicon and the MLX Audio Swift SDK."
    private static let diarizationModelId =
        "mlx-community/diar_streaming_sortformer_4spk-v2.1-fp16"

    private let downloadEvents = MlxAudioEventStreamHandler()
    private let realtimeEvents = MlxAudioEventStreamHandler()
    private let stateQueue = DispatchQueue(label: "com.matthiasn.lotti.mlx_audio.state")
    private var audioPlayer: AVAudioPlayer?
    private var latestDownloadPayloadByModel: [String: [String: Any]] = [:]
    private var lastLoggedDownloadPercentByModel: [String: Int] = [:]
    #if arch(arm64) && canImport(MLX) && canImport(MLXAudioCore) && canImport(MLXAudioSTT)
    private var realtimeSession: StreamingInferenceSession?
    private var realtimeEventTask: Task<Void, Never>?
    private var realtimeModelId: String?
    private var cachedSTTModelId: String?
    private var cachedSTTModel: (any STTGenerationModel)?
    private var cachedSTTModelLastUsedAt: Date?
    private var cachedSTTModelEvictionTask: Task<Void, Never>?
    private static let mlxInferenceGate = MlxAudioAsyncSemaphore(value: 1)
    private static let mlxMemoryConfigurationLock = NSLock()
    private static var didConfigureMlxMemory = false
    private static let cachedSTTModelTimeToLiveSeconds: TimeInterval = 120
    private static let mlxCacheLimitBytes = 512 * 1024 * 1024
    private static let mlxWiredLimitPolicy = WiredMaxPolicy(
        id: UUID(uuidString: "FD65E5A2-5748-4F8C-9B3C-36FB18F775B2")!
    )
    private static var mlxMemoryLimitBytes: Int {
        let gibibyte = UInt64(1024 * 1024 * 1024)
        let physicalBytes = ProcessInfo.processInfo.physicalMemory
        let appCeiling = UInt64(32) * gibibyte
        let systemCeiling = physicalBytes * 3 / 4
        let lowerBound = UInt64(8) * gibibyte
        let preferred = max(lowerBound, min(appCeiling, systemCeiling))
        return Int(min(preferred, systemCeiling))
    }
    #endif

    static func register(with registrar: FlutterPluginRegistrar) {
        let instance = MlxAudio()
        instance.downloadEvents.onListen = { [weak instance] in
            instance?.replayLatestDownloadProgress()
        }
        let methodChannel = FlutterMethodChannel(
            name: methodChannelName,
            binaryMessenger: registrar.messenger
        )
        let eventChannel = FlutterEventChannel(
            name: eventChannelName,
            binaryMessenger: registrar.messenger
        )
        let realtimeEventChannel = FlutterEventChannel(
            name: realtimeEventChannelName,
            binaryMessenger: registrar.messenger
        )

        methodChannel.setMethodCallHandler(instance.handle)
        eventChannel.setStreamHandler(instance.downloadEvents)
        realtimeEventChannel.setStreamHandler(instance.realtimeEvents)
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]

        switch call.method {
        case "getModelStatus":
            guard let modelId = args["modelId"] as? String else {
                result(invalidArguments("Missing modelId"))
                return
            }
            result(modelStatus(modelId: modelId))

        case "installModel":
            guard let modelId = args["modelId"] as? String else {
                result(invalidArguments("Missing modelId"))
                return
            }
            installModel(modelId: modelId, result: result)

        case "transcribeFile":
            guard let modelId = args["modelId"] as? String,
                  let filePath = args["filePath"] as? String
            else {
                result(invalidArguments("Missing modelId or filePath"))
                return
            }
            transcribeFile(
                filePath: filePath,
                modelId: modelId,
                language: args["language"] as? String,
                speechDictionaryTerms: args["speechDictionaryTerms"] as? [String] ?? [],
                enableSpeakerDiarization: args["enableSpeakerDiarization"] as? Bool ?? false,
                result: result
            )

        case "transcribeBase64Audio":
            guard let modelId = args["modelId"] as? String,
                  let audioBase64 = args["audioBase64"] as? String
            else {
                result(invalidArguments("Missing modelId or audioBase64"))
                return
            }
            transcribeBase64Audio(
                audioBase64: audioBase64,
                modelId: modelId,
                language: args["language"] as? String,
                speechDictionaryTerms: args["speechDictionaryTerms"] as? [String] ?? [],
                enableSpeakerDiarization: args["enableSpeakerDiarization"] as? Bool ?? false,
                result: result
            )

        case "speakText":
            guard let modelId = args["modelId"] as? String,
                  let text = args["text"] as? String
            else {
                result(invalidArguments("Missing modelId or text"))
                return
            }
            speakText(
                text: text,
                modelId: modelId,
                language: args["language"] as? String,
                result: result
            )

        case "stopSpeaking":
            stopAudioPlayer()
            result(nil)

        case "startRealtimeTranscription":
            guard let modelId = args["modelId"] as? String else {
                result(invalidArguments("Missing modelId"))
                return
            }
            startRealtimeTranscription(
                modelId: modelId,
                language: args["language"] as? String,
                delayPreset: args["delayPreset"] as? String,
                result: result
            )

        case "appendRealtimePcm":
            guard let pcmData = args["pcm16"] as? FlutterStandardTypedData else {
                result(invalidArguments("Missing pcm16"))
                return
            }
            appendRealtimePcm(pcmData.data, result: result)

        case "stopRealtimeTranscription":
            stopRealtimeTranscription(result: result)

        case "cancelRealtimeTranscription":
            cancelRealtimeTranscription(result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func modelStatus(modelId: String) -> [String: Any] {
        #if arch(arm64) && canImport(MLXAudioCore) && canImport(HuggingFace)
        if let latest = latestDownloadPayload(modelId: modelId) {
            return latest
        }
        let modelDir = modelCacheDirectory(cache: HubCache.default, modelId: modelId)
        if isModelCached(modelId: modelId) {
            return [
                "modelId": modelId,
                "status": "installed",
            ]
        }
        let partialBytes = modelCacheBytes(in: modelDir)
        if partialBytes > 0 {
            return [
                "modelId": modelId,
                "status": "downloading",
                "completedUnitCount": partialBytes,
                "totalUnitCount": 0,
            ]
        }
        return [
            "modelId": modelId,
            "status": "notInstalled",
        ]
        #else
        return unsupportedStatus(modelId: modelId)
        #endif
    }

    private func installModel(modelId: String, result: @escaping FlutterResult) {
        #if arch(arm64) && canImport(MLXAudioCore) && canImport(HuggingFace)
        clearLoggedDownloadPercent(modelId: modelId)
        NSLog("[MLX Audio] starting model download model=\(modelId)")
        emitDownload([
            "modelId": modelId,
            "status": "downloading",
            "progress": 0.0,
            "completedUnitCount": 0,
            "totalUnitCount": 0,
        ])

        Task {
            do {
                guard let repoID = Repo.ID(rawValue: modelId) else {
                    throw MlxAudioBridgeError.unsupportedModel(modelId)
                }
                let cache = HubCache.default
                let client = HubClient(cache: cache)
                _ = try await self.downloadModelWithMeasuredProgress(
                    client: client,
                    cache: cache,
                    repoID: repoID,
                    modelId: modelId
                )
                self.emitDownload([
                    "modelId": modelId,
                    "status": "installed",
                    "progress": 1.0,
                ])
                self.clearLoggedDownloadPercent(modelId: modelId)
                NSLog("[MLX Audio] completed model download model=\(modelId)")
                result(nil)
            } catch {
                self.clearLoggedDownloadPercent(modelId: modelId)
                NSLog("[MLX Audio] model download failed model=\(modelId) error=\(error.localizedDescription)")
                self.emitDownload([
                    "modelId": modelId,
                    "status": "failed",
                    "message": error.localizedDescription,
                ])
                result(FlutterError(
                    code: "DOWNLOAD_FAILED",
                    message: error.localizedDescription,
                    details: "\(error)"
                ))
            }
        }
        #else
        NSLog("[MLX Audio] model download unsupported model=\(modelId)")
        emitDownload(unsupportedStatus(modelId: modelId))
        result(nil)
        #endif
    }

    private func transcribeFile(
        filePath: String,
        modelId: String,
        language: String?,
        speechDictionaryTerms: [String],
        enableSpeakerDiarization: Bool,
        result: @escaping FlutterResult
    ) {
        #if arch(arm64) && canImport(MLX) && canImport(MLXAudioCore) && canImport(MLXAudioSTT) && canImport(MLXAudioVAD)
        Task {
            do {
                let started = CFAbsoluteTimeGetCurrent()
                let inputURL = URL(fileURLWithPath: filePath)
                self.logResourceSnapshot(
                    stage: "transcribe.request",
                    modelId: modelId,
                    audioURL: inputURL
                )
                let output = try await withMlxInferenceResources(
                    stage: "transcribe",
                    modelId: modelId,
                    audioURL: inputURL
                ) {
                    try await self.transcribeAudioURL(
                        inputURL,
                        modelId: modelId,
                        language: language,
                        speechDictionaryTerms: speechDictionaryTerms
                    )
                }
                let diarizationStatus: String
                if enableSpeakerDiarization {
                    diarizationStatus = try await withMlxInferenceResources(
                        stage: "diarization",
                        modelId: Self.diarizationModelId,
                        audioURL: inputURL
                    ) {
                        try await self.diarizationStatusIfRequested(
                            audioURL: inputURL,
                            enableSpeakerDiarization: true
                        )
                    }
                } else {
                    diarizationStatus = "disabled"
                }
                var payload: [String: Any] = [
                    "text": output.text,
                    "processingTimeMs": Int((CFAbsoluteTimeGetCurrent() - started) * 1000),
                    "diarizationStatus": diarizationStatus,
                ]
                if let language = output.language {
                    payload["detectedLanguage"] = language
                }
                result(payload)
            } catch {
                result(FlutterError(
                    code: "TRANSCRIPTION_FAILED",
                    message: error.localizedDescription,
                    details: "\(error)"
                ))
            }
        }
        #else
        result(unsupportedError())
        #endif
    }

    private func transcribeBase64Audio(
        audioBase64: String,
        modelId: String,
        language: String?,
        speechDictionaryTerms: [String],
        enableSpeakerDiarization: Bool,
        result: @escaping FlutterResult
    ) {
        guard let data = Data(base64Encoded: audioBase64) else {
            result(invalidArguments("audioBase64 is not valid base64"))
            return
        }

        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mlx-audio-\(UUID().uuidString).m4a")

        do {
            try data.write(to: temporaryURL)
        } catch {
            result(FlutterError(
                code: "AUDIO_WRITE_FAILED",
                message: error.localizedDescription,
                details: "\(error)"
            ))
            return
        }

        transcribeFile(
            filePath: temporaryURL.path,
            modelId: modelId,
            language: language,
            speechDictionaryTerms: speechDictionaryTerms,
            enableSpeakerDiarization: enableSpeakerDiarization,
            result: { flutterResult in
                try? FileManager.default.removeItem(at: temporaryURL)
                result(flutterResult)
            }
        )
    }

    private func speakText(
        text: String,
        modelId: String,
        language: String?,
        result: @escaping FlutterResult
    ) {
        #if arch(arm64) && canImport(MLX) && canImport(MLXAudioCore) && canImport(MLXAudioSTT) && canImport(MLXAudioTTS)
        Task {
            do {
                try await withMlxInferenceResources(stage: "tts", modelId: modelId) {
                    let model = try await TTS.loadModel(modelRepo: modelId)
                    let audio = try await model.generate(
                        text: text,
                        voice: nil,
                        refAudio: nil,
                        refText: nil,
                        language: language ?? "English"
                    )
                    let outputURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent("mlx-audio-tts-\(UUID().uuidString).wav")
                    try AudioUtils.writeWavFile(
                        samples: audio.asArray(Float.self),
                        sampleRate: Double(model.sampleRate),
                        fileURL: outputURL
                    )
                    defer {
                        try? FileManager.default.removeItem(at: outputURL)
                    }
                    let wavData = try Data(contentsOf: outputURL)
                    try playAudio(data: wavData)
                }
                result(nil)
            } catch {
                result(FlutterError(
                    code: "TTS_FAILED",
                    message: error.localizedDescription,
                    details: "\(error)"
                ))
            }
        }
        #else
        result(unsupportedError())
        #endif
    }

    private func playAudio(data: Data) throws {
        let player = try AVAudioPlayer(data: data)
        player.prepareToPlay()
        stateQueue.sync {
            audioPlayer?.stop()
            audioPlayer = player
        }
        player.play()
    }

    private func stopAudioPlayer() {
        stateQueue.sync {
            audioPlayer?.stop()
            audioPlayer = nil
        }
    }

    private func startRealtimeTranscription(
        modelId: String,
        language: String?,
        delayPreset: String?,
        result: @escaping FlutterResult
    ) {
        #if arch(arm64) && canImport(MLX) && canImport(MLXAudioCore) && canImport(MLXAudioSTT) && canImport(HuggingFace)
        Task {
            do {
                self.logResourceSnapshot(stage: "realtime.start.request", modelId: modelId)
                let lower = modelId.lowercased()
                guard lower.contains("qwen3-asr") || lower.contains("qwen3_asr") else {
                    throw MlxAudioBridgeError.unsupportedModel(modelId)
                }

                self.cancelRealtimeSessionState()

                try await self.withMlxInferenceResources(
                    stage: "realtime.start",
                    modelId: modelId
                ) {
                    self.evictCachedSTTModel(reason: "realtime.start")
                    self.clearLoggedDownloadPercent(modelId: modelId)
                    try requireModelInstalled(modelId: modelId)
                    emitDownload([
                        "modelId": modelId,
                        "status": "installed",
                        "progress": 1.0,
                    ])
                    self.clearLoggedDownloadPercent(modelId: modelId)

                    self.logResourceSnapshot(stage: "realtime.loadModel.start", modelId: modelId)
                    let model = try await Qwen3ASRModel.fromPretrained(modelId)
                    self.logResourceSnapshot(stage: "realtime.loadModel.done", modelId: modelId)
                    let config = StreamingConfig(
                        delayPreset: streamingDelayPreset(from: delayPreset),
                        language: normalizeLanguage(language) ?? "English",
                        temperature: 0.0,
                        finalizeCompletedWindows: true
                    )
                    let session = StreamingInferenceSession(model: model, config: config)
                    let eventTask = Task { [weak self] in
                        for await event in session.events {
                            self?.emitRealtimeEvent(event)
                        }
                        self?.clearRealtimeSessionState()
                    }
                    self.setRealtimeSession(
                        session,
                        eventTask: eventTask,
                        modelId: modelId
                    )
                }

                NSLog("[MLX Audio] started realtime transcription model=\(modelId)")
                result(nil)
            } catch {
                self.clearLoggedDownloadPercent(modelId: modelId)
                emitDownload([
                    "modelId": modelId,
                    "status": "failed",
                    "message": error.localizedDescription,
                ])
                emitRealtime([
                    "type": "transcription.error",
                    "message": error.localizedDescription,
                ])
                result(FlutterError(
                    code: "REALTIME_START_FAILED",
                    message: error.localizedDescription,
                    details: "\(error)"
                ))
            }
        }
        #else
        emitRealtime([
            "type": "transcription.error",
            "message": Self.unsupportedMessage,
        ])
        result(unsupportedError())
        #endif
    }

    private func appendRealtimePcm(_ pcm16: Data, result: @escaping FlutterResult) {
        #if arch(arm64) && canImport(MLX) && canImport(MLXAudioCore) && canImport(MLXAudioSTT)
        guard let realtimeSession = currentRealtimeSession() else {
            result(FlutterError(
                code: "REALTIME_NOT_STARTED",
                message: "MLX realtime transcription has not been started.",
                details: nil
            ))
            return
        }

        realtimeSession.feedAudio(samples: pcm16LittleEndianToFloatSamples(pcm16))
        result(nil)
        #else
        result(unsupportedError())
        #endif
    }

    private func stopRealtimeTranscription(result: @escaping FlutterResult) {
        #if arch(arm64) && canImport(MLX) && canImport(MLXAudioCore) && canImport(MLXAudioSTT)
        currentRealtimeSession()?.stop()
        result(nil)
        #else
        result(unsupportedError())
        #endif
    }

    private func cancelRealtimeTranscription(result: @escaping FlutterResult) {
        #if arch(arm64) && canImport(MLX) && canImport(MLXAudioCore) && canImport(MLXAudioSTT)
        cancelRealtimeSessionState()
        result(nil)
        #else
        result(unsupportedError())
        #endif
    }

    private func emitDownload(_ payload: [String: Any]) {
        if let modelId = payload["modelId"] as? String {
            stateQueue.sync {
                latestDownloadPayloadByModel[modelId] = payload
            }
        }
        downloadEvents.emit(payload)
    }

    private func emitRealtime(_ payload: [String: Any]) {
        realtimeEvents.emit(payload)
    }

    private func replayLatestDownloadProgress() {
        let payloads = stateQueue.sync {
            Array(latestDownloadPayloadByModel.values)
        }
        for payload in payloads {
            downloadEvents.emit(payload)
        }
    }

    private func latestDownloadPayload(modelId: String) -> [String: Any]? {
        stateQueue.sync {
            latestDownloadPayloadByModel[modelId]
        }
    }

    private func clearLoggedDownloadPercent(modelId: String) {
        stateQueue.sync {
            lastLoggedDownloadPercentByModel[modelId] = nil
        }
    }

    private func shouldLogDownloadProgress(modelId: String, percent: Int) -> Bool {
        stateQueue.sync {
            let lastLoggedPercent = lastLoggedDownloadPercentByModel[modelId]
            guard lastLoggedPercent == nil ||
                  percent >= (lastLoggedPercent ?? 0) + 5 ||
                  (percent == 100 && lastLoggedPercent != 100)
            else {
                return false
            }
            lastLoggedDownloadPercentByModel[modelId] = percent
            return true
        }
    }

    #if arch(arm64) && canImport(MLX) && canImport(MLXAudioCore) && canImport(MLXAudioSTT)
    private func setRealtimeSession(
        _ session: StreamingInferenceSession,
        eventTask: Task<Void, Never>,
        modelId: String
    ) {
        stateQueue.sync {
            realtimeSession = session
            realtimeEventTask = eventTask
            realtimeModelId = modelId
        }
    }

    private func currentRealtimeSession() -> StreamingInferenceSession? {
        stateQueue.sync {
            realtimeSession
        }
    }

    private func clearRealtimeSessionState() {
        let modelId = stateQueue.sync {
            let modelId = realtimeModelId
            realtimeSession = nil
            realtimeEventTask = nil
            realtimeModelId = nil
            return modelId
        }

        if let modelId {
            drainMlxCache(stage: "realtime.session.cleared", modelId: modelId)
        }
    }

    private func cancelRealtimeSessionState() {
        let current = stateQueue.sync {
            let state = (
                session: realtimeSession,
                task: realtimeEventTask,
                modelId: realtimeModelId
            )
            realtimeSession = nil
            realtimeEventTask = nil
            realtimeModelId = nil
            return state
        }
        current.task?.cancel()
        current.session?.cancel()
        if let modelId = current.modelId {
            drainMlxCache(stage: "realtime.session.cancelled", modelId: modelId)
        }
    }
    #endif

    private func unsupportedStatus(modelId: String) -> [String: Any] {
        [
            "modelId": modelId,
            "status": "unsupported",
            "message": Self.unsupportedMessage,
        ]
    }

    private func invalidArguments(_ message: String) -> FlutterError {
        FlutterError(code: "INVALID_ARGUMENTS", message: message, details: nil)
    }

    private func unsupportedError() -> FlutterError {
        FlutterError(
            code: "UNSUPPORTED",
            message: Self.unsupportedMessage,
            details: nil
        )
    }

    private func logResourceSnapshot(
        stage: String,
        modelId: String,
        audioURL: URL? = nil
    ) {
        let audioBytes = audioURL.flatMap { url in
            (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
        } ?? 0
        let residentBytes = currentResidentMemoryBytes() ?? 0
        var mlxMemory = ""
        #if arch(arm64) && canImport(MLX)
        let snapshot = Memory.snapshot()
        mlxMemory = " mlxActiveBytes=\(snapshot.activeMemory) mlxCacheBytes=\(snapshot.cacheMemory) mlxPeakBytes=\(snapshot.peakMemory) mlxMemoryLimitBytes=\(Memory.memoryLimit) mlxCacheLimitBytes=\(Memory.cacheLimit)"
        #endif
        NSLog(
            "[MLX Audio] diagnostics stage=\(stage) model=\(modelId) residentBytes=\(residentBytes) physicalBytes=\(ProcessInfo.processInfo.physicalMemory) audioBytes=\(audioBytes)\(mlxMemory)"
        )
    }

    private func currentResidentMemoryBytes() -> UInt64? {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return UInt64(info.resident_size)
    }

    #if arch(arm64) && canImport(MLX) && canImport(MLXAudioCore) && canImport(MLXAudioSTT)
    private func configureMlxMemoryLimitsIfNeeded() {
        Self.mlxMemoryConfigurationLock.lock()
        defer { Self.mlxMemoryConfigurationLock.unlock() }

        guard !Self.didConfigureMlxMemory else { return }

        Memory.memoryLimit = Self.mlxMemoryLimitBytes
        Memory.cacheLimit = Self.mlxCacheLimitBytes
        Memory.clearCache()
        Memory.peakMemory = 0
        Self.didConfigureMlxMemory = true

        NSLog(
            "[MLX Audio] configured MLX memory limits memoryLimitBytes=\(Self.mlxMemoryLimitBytes) cacheLimitBytes=\(Self.mlxCacheLimitBytes)"
        )
    }

    private func withMlxInferenceResources<T>(
        stage: String,
        modelId: String,
        audioURL: URL? = nil,
        operation: () async throws -> T
    ) async throws -> T {
        configureMlxMemoryLimitsIfNeeded()
        try await Self.mlxInferenceGate.wait()
        Memory.peakMemory = 0
        logResourceSnapshot(stage: "\(stage).enter", modelId: modelId, audioURL: audioURL)

        let ticket = WiredMemoryTicket(
            size: Self.mlxMemoryLimitBytes,
            policy: Self.mlxWiredLimitPolicy,
            manager: .shared,
            kind: .active
        )

        do {
            let value = try await ticket.withWiredLimit {
                try await operation()
            }
            drainMlxCache(stage: "\(stage).done", modelId: modelId, audioURL: audioURL)
            await Self.mlxInferenceGate.signal()
            return value
        } catch {
            drainMlxCache(stage: "\(stage).failed", modelId: modelId, audioURL: audioURL)
            await Self.mlxInferenceGate.signal()
            throw error
        }
    }

    private func drainMlxCache(stage: String, modelId: String, audioURL: URL? = nil) {
        Stream.gpu.synchronize()
        Memory.clearCache()
        logResourceSnapshot(stage: stage, modelId: modelId, audioURL: audioURL)
    }

    private func cachedOrLoadSTTModel(repo: String) async throws -> any STTGenerationModel {
        let now = Date()
        if cachedSTTModelId == repo, let cachedSTTModel {
            cachedSTTModelLastUsedAt = now
            scheduleCachedSTTModelEviction(modelId: repo)
            NSLog("[MLX Audio] reused cached STT model model=\(repo)")
            return cachedSTTModel
        }

        evictCachedSTTModel(reason: "replace")
        let model = try await loadSTTModel(repo: repo)
        cachedSTTModelId = repo
        cachedSTTModel = model
        cachedSTTModelLastUsedAt = now
        scheduleCachedSTTModelEviction(modelId: repo)
        NSLog("[MLX Audio] cached STT model model=\(repo)")
        return model
    }

    private func scheduleCachedSTTModelEviction(modelId: String) {
        cachedSTTModelEvictionTask?.cancel()
        cachedSTTModelEvictionTask = Task { [weak self] in
            let nanoseconds = UInt64(Self.cachedSTTModelTimeToLiveSeconds * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            await self?.evictCachedSTTModelIfIdle(modelId: modelId)
        }
    }

    private func evictCachedSTTModelIfIdle(modelId: String) async {
        do {
            try await Self.mlxInferenceGate.wait()
        } catch {
            return
        }

        if cachedSTTModelId == modelId,
           let lastUsedAt = cachedSTTModelLastUsedAt,
           Date().timeIntervalSince(lastUsedAt) < Self.cachedSTTModelTimeToLiveSeconds
        {
            scheduleCachedSTTModelEviction(modelId: modelId)
            await Self.mlxInferenceGate.signal()
            return
        }

        evictCachedSTTModel(reason: "ttl", modelId: modelId)
        await Self.mlxInferenceGate.signal()
    }

    private func evictCachedSTTModel(reason: String, modelId: String? = nil) {
        if let modelId, cachedSTTModelId != modelId {
            return
        }

        guard cachedSTTModel != nil else {
            return
        }

        let evictedModelId = cachedSTTModelId ?? "unknown"
        cachedSTTModel = nil
        cachedSTTModelId = nil
        cachedSTTModelLastUsedAt = nil
        cachedSTTModelEvictionTask?.cancel()
        cachedSTTModelEvictionTask = nil

        drainMlxCache(stage: "stt.modelCache.evicted.\(reason)", modelId: evictedModelId)
        NSLog("[MLX Audio] evicted cached STT model model=\(evictedModelId) reason=\(reason)")
    }

    private func transcribeAudioURL(
        _ audioURL: URL,
        modelId: String,
        language: String?,
        speechDictionaryTerms: [String]
    ) async throws -> STTOutput {
        if currentRealtimeSession() != nil {
            throw MlxAudioBridgeError.inferenceBusy(
                "MLX realtime transcription is active. Stop realtime transcription before starting batch transcription."
            )
        }

        try requireModelInstalled(modelId: modelId)
        emitDownload([
            "modelId": modelId,
            "status": "installed",
            "progress": 1.0,
        ])
        logResourceSnapshot(stage: "stt.loadModel.start", modelId: modelId, audioURL: audioURL)
        let model = try await cachedOrLoadSTTModel(repo: modelId)
        logResourceSnapshot(stage: "stt.loadModel.done", modelId: modelId, audioURL: audioURL)
        let (inputSampleRate, inputAudio) = try autoreleasepool {
            try loadAudioArray(from: audioURL)
        }
        logResourceSnapshot(stage: "stt.audioLoaded", modelId: modelId, audioURL: audioURL)
        let audio = try autoreleasepool {
            try prepareAudioForSTT(
                inputAudio,
                inputSampleRate: inputSampleRate,
                targetSampleRate: 16000
            )
        }
        logResourceSnapshot(stage: "stt.audioPrepared", modelId: modelId, audioURL: audioURL)

        var params = model.defaultGenerationParameters
        params = STTGenerateParameters(
            maxTokens: params.maxTokens,
            temperature: 0.0,
            topP: params.topP,
            topK: params.topK,
            verbose: false,
            language: normalizeLanguage(language) ?? params.language,
            chunkDuration: max(2.4, min(params.chunkDuration, 30.0)),
            minChunkDuration: max(1.0, params.minChunkDuration)
        )

        let biasContext = buildBiasContext(speechDictionaryTerms) ?? ""
        logResourceSnapshot(stage: "stt.generate.start", modelId: modelId, audioURL: audioURL)
        if let qwenModel = model as? Qwen3ASRModel {
            let output = qwenModel.generate(
                audio: audio,
                maxTokens: params.maxTokens,
                temperature: params.temperature,
                context: biasContext,
                language: params.language,
                chunkDuration: params.chunkDuration,
                minChunkDuration: params.minChunkDuration,
                repetitionPenalty: params.repetitionPenalty,
                repetitionContextSize: params.repetitionContextSize
            )
            logResourceSnapshot(stage: "stt.generate.done", modelId: modelId, audioURL: audioURL)
            return output
        }

        let output = model.generate(audio: audio, generationParameters: params)
        logResourceSnapshot(stage: "stt.generate.done", modelId: modelId, audioURL: audioURL)
        return output
    }

    private func loadSTTModel(repo: String) async throws -> any STTGenerationModel {
        let lower = repo.lowercased()
        if lower.contains("glmasr") || lower.contains("glm-asr") {
            return try await GLMASRModel.fromPretrained(repo)
        }
        if lower.contains("qwen3-asr") || lower.contains("qwen3_asr") {
            return try await Qwen3ASRModel.fromPretrained(repo)
        }
        if lower.contains("voxtral") {
            return try await VoxtralRealtimeModel.fromPretrained(repo)
        }
        if lower.contains("cohere") {
            return try await CohereTranscribeModel.fromPretrained(repo)
        }
        if lower.contains("parakeet") {
            return try await ParakeetModel.fromPretrained(repo)
        }
        if lower.contains("firered") || lower.contains("fire-red") {
            return try await FireRedASR2Model.fromPretrained(repo)
        }
        if lower.contains("sensevoice") {
            return try await SenseVoiceModel.fromPretrained(repo)
        }
        throw MlxAudioBridgeError.unsupportedModel(repo)
    }

    private func prepareAudioForSTT(
        _ audio: MLXArray,
        inputSampleRate: Int,
        targetSampleRate: Int
    ) throws -> MLXArray {
        let mono = audio.ndim > 1 ? audio.mean(axis: -1) : audio
        guard inputSampleRate != targetSampleRate else { return mono }
        return try MLXAudioCore.resampleAudio(
            mono,
            from: inputSampleRate,
            to: targetSampleRate
        )
    }

    private func normalizeLanguage(_ language: String?) -> String? {
        guard let trimmed = language?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else {
            return nil
        }

        switch trimmed.lowercased() {
        case "en", "english":
            return "English"
        case "de", "german", "deutsch":
            return "German"
        default:
            return trimmed
        }
    }

    private func buildBiasContext(_ terms: [String]) -> String? {
        let normalized = terms
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !normalized.isEmpty else { return nil }
        return "Use these spellings for names, places, product names, and technical terms when acoustically plausible: "
            + normalized.joined(separator: ", ")
    }

    private func streamingDelayPreset(from value: String?) -> DelayPreset {
        switch value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "realtime":
            return .realtime
        case "agent":
            return .agent
        case "subtitle", nil, "":
            return .subtitle
        default:
            if let value, let ms = Int(value), ms > 0 {
                return .custom(ms: ms)
            }
            return .subtitle
        }
    }

    private func emitRealtimeEvent(_ event: TranscriptionEvent) {
        switch event {
        case .provisional(let text):
            emitRealtime([
                "type": "transcription.provisional",
                "text": text,
            ])
        case .confirmed(let text):
            emitRealtime([
                "type": "transcription.confirmed",
                "text": text,
            ])
        case .displayUpdate(let confirmedText, let provisionalText):
            emitRealtime([
                "type": "transcription.display",
                "confirmedText": confirmedText,
                "provisionalText": provisionalText,
            ])
        case .stats(let stats):
            emitRealtime([
                "type": "transcription.stats",
                "encodedWindowCount": stats.encodedWindowCount,
                "totalAudioSeconds": stats.totalAudioSeconds,
                "tokensPerSecond": stats.tokensPerSecond,
                "realTimeFactor": stats.realTimeFactor,
                "peakMemoryGB": stats.peakMemoryGB,
            ])
        case .ended(let fullText):
            emitRealtime([
                "type": "transcription.done",
                "text": fullText,
            ])
        }
    }

    private func pcm16LittleEndianToFloatSamples(_ data: Data) -> [Float] {
        let sampleCount = data.count / 2
        guard sampleCount > 0 else { return [] }

        return data.withUnsafeBytes { rawBuffer in
            guard let bytes = rawBuffer.bindMemory(to: UInt8.self).baseAddress else {
                return []
            }

            var samples: [Float] = []
            samples.reserveCapacity(sampleCount)
            for index in 0..<sampleCount {
                let low = UInt16(bytes[index * 2])
                let high = UInt16(bytes[index * 2 + 1]) << 8
                let signed = Int16(bitPattern: low | high)
                samples.append(max(-1.0, Float(signed) / 32768.0))
            }
            return samples
        }
    }
    #endif

    #if arch(arm64) && canImport(MLXAudioVAD) && canImport(MLXAudioCore)
    private func diarizationStatusIfRequested(
        audioURL: URL,
        enableSpeakerDiarization: Bool
    ) async throws -> String {
        guard enableSpeakerDiarization else { return "disabled" }
        guard isModelCached(modelId: Self.diarizationModelId) else {
            return "modelNotInstalled"
        }
        let (_, audio) = try loadAudioArray(from: audioURL, sampleRate: 16000)
        let model = try await SortformerModel.fromPretrained(Self.diarizationModelId)
        let output = try await model.generate(
            audio: audio,
            sampleRate: 16000,
            threshold: 0.5,
            minDuration: 0.25,
            mergeGap: 0.5,
            verbose: false
        )
        return "speakers:\(output.numSpeakers);segments:\(output.segments.count)"
    }
    #else
    private func diarizationStatusIfRequested(
        audioURL: URL,
        enableSpeakerDiarization: Bool
    ) async throws -> String {
        enableSpeakerDiarization ? "unsupported" : "disabled"
    }
    #endif

    #if arch(arm64) && canImport(MLXAudioCore) && canImport(HuggingFace)
    private func isModelCached(modelId: String) -> Bool {
        let modelDir = modelCacheDirectory(cache: HubCache.default, modelId: modelId)
        guard hasValidModelFile(in: modelDir, requiredExtension: "safetensors") else {
            return false
        }
        let configPath = modelDir.appendingPathComponent("config.json")
        guard let configData = try? Data(contentsOf: configPath),
              (try? JSONSerialization.jsonObject(with: configData)) != nil
        else {
            return false
        }
        return true
    }

    private func downloadModelWithMeasuredProgress(
        client: HubClient,
        cache: HubCache,
        repoID: Repo.ID,
        modelId: String
    ) async throws -> URL {
        let modelDir = modelCacheDirectory(cache: cache, modelId: modelId)
        try FileManager.default.createDirectory(
            at: modelDir,
            withIntermediateDirectories: true
        )

        let entries = try await client.listFiles(
            in: repoID,
            kind: .model,
            revision: "main",
            recursive: true
        )
        .filter { self.isModelDownloadEntry($0) }

        let totalUnitCount = max(
            entries.reduce(Int64(0)) { partial, entry in
                partial + modelDownloadWeight(for: entry)
            },
            1
        )

        if hasCompleteModelFiles(in: modelDir, entries: entries) {
            emitDownloadProgress(
                modelId: modelId,
                completedUnitCount: totalUnitCount,
                totalUnitCount: totalUnitCount
            )
            return modelDir
        }

        emitDownloadProgress(
            modelId: modelId,
            completedUnitCount: 0,
            totalUnitCount: totalUnitCount
        )

        var completedBeforeCurrentFile: Int64 = 0
        for entry in entries {
            let fileWeight = modelDownloadWeight(for: entry)
            let destination = modelDir.appendingPathComponent(entry.path)
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let existingSize = (try? destination.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            if FileManager.default.fileExists(atPath: destination.path),
               Int64(existingSize) >= fileWeight {
                completedBeforeCurrentFile += fileWeight
                emitDownloadProgress(
                    modelId: modelId,
                    completedUnitCount: min(completedBeforeCurrentFile, totalUnitCount),
                    totalUnitCount: totalUnitCount
                )
                continue
            }

            let completedBeforeFile = completedBeforeCurrentFile
            do {
                try await MlxAudioStreamingDownloader.download(
                    from: huggingFaceResolveURL(repoID: repoID, entryPath: entry.path),
                    to: destination,
                    temporaryURL: destination.appendingPathExtension("download")
                ) { [weak self] downloadedBytes in
                    self?.emitDownloadProgress(
                        modelId: modelId,
                        completedUnitCount: completedBeforeFile + min(
                            max(downloadedBytes, 0),
                            fileWeight
                        ),
                        totalUnitCount: totalUnitCount
                    )
                }
            } catch {
                throw error
            }

            completedBeforeCurrentFile += fileWeight
            emitDownloadProgress(
                modelId: modelId,
                completedUnitCount: min(completedBeforeCurrentFile, totalUnitCount),
                totalUnitCount: totalUnitCount
            )
        }

        guard hasCompleteModelFiles(in: modelDir, entries: entries) else {
            throw ModelUtilsError.incompleteDownload(repoID.description)
        }

        return modelDir
    }

    private func huggingFaceResolveURL(repoID: Repo.ID, entryPath: String) -> URL {
        var url = URL(string: "https://huggingface.co")!
        url.appendPathComponent(repoID.namespace)
        url.appendPathComponent(repoID.name)
        url.appendPathComponent("resolve")
        url.appendPathComponent("main")
        for component in entryPath.split(separator: "/") {
            url.appendPathComponent(String(component))
        }
        return url
    }

    private func modelCacheDirectory(cache: HubCache, modelId: String) -> URL {
        cache.cacheDirectory
            .appendingPathComponent("mlx-audio")
            .appendingPathComponent(modelId.replacingOccurrences(of: "/", with: "_"))
    }

    private func isModelDownloadEntry(_ entry: Git.TreeEntry) -> Bool {
        guard entry.type == .file else { return false }
        let path = entry.path.lowercased()
        return [
            ".safetensors",
            ".json",
            ".txt",
            ".wav",
            ".model",
            ".tiktoken",
        ].contains { path.hasSuffix($0) }
    }

    private func modelDownloadWeight(for entry: Git.TreeEntry) -> Int64 {
        max(Int64(entry.size ?? 1), 1)
    }

    private func hasValidModelFile(in modelDir: URL, requiredExtension: String) -> Bool {
        guard let files = FileManager.default.enumerator(
            at: modelDir,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else {
            return false
        }

        for case let file as URL in files {
            guard file.pathExtension == requiredExtension else { continue }
            let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            if size > 0 {
                return true
            }
        }
        return false
    }

    private func modelCacheBytes(in modelDir: URL) -> Int64 {
        guard let files = FileManager.default.enumerator(
            at: modelDir,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]
        ) else {
            return 0
        }

        var total = Int64(0)
        for case let file as URL in files {
            let values = try? file.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values?.isRegularFile == true else { continue }
            total += Int64(values?.fileSize ?? 0)
        }
        return total
    }

    private func hasCompleteModelFiles(in modelDir: URL, entries: [Git.TreeEntry]) -> Bool {
        guard hasValidModelFile(in: modelDir, requiredExtension: "safetensors") else {
            return false
        }

        for entry in entries {
            let file = modelDir.appendingPathComponent(entry.path)
            guard FileManager.default.fileExists(atPath: file.path) else {
                return false
            }

            let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            guard size > 0 else { return false }
            if let expectedSize = entry.size, Int64(size) < Int64(expectedSize) {
                return false
            }
        }

        return true
    }

    private func requireModelInstalled(modelId: String) throws {
        guard isModelCached(modelId: modelId) else {
            let modelDir = modelCacheDirectory(cache: HubCache.default, modelId: modelId)
            let partialBytes = modelCacheBytes(in: modelDir)
            if partialBytes > 0 {
                emitDownload([
                    "modelId": modelId,
                    "status": "downloading",
                    "completedUnitCount": partialBytes,
                    "totalUnitCount": 0,
                ])
            } else {
                emitDownload([
                    "modelId": modelId,
                    "status": "notInstalled",
                ])
            }
            throw MlxAudioBridgeError.modelNotInstalled(modelId)
        }
    }

    private func emitDownloadProgress(
        modelId: String,
        completedUnitCount: Int64,
        totalUnitCount: Int64
    ) {
        let total = max(totalUnitCount, 0)
        let completed = min(max(completedUnitCount, 0), total)
        let fraction = total > 0 ? Double(completed) / Double(total) : 0.0
        let clampedFraction = min(max(fraction, 0.0), 1.0)
        let percent = completed >= total && total > 0
            ? 100
            : Int((clampedFraction * 100.0).rounded(.down))
        if shouldLogDownloadProgress(modelId: modelId, percent: percent) {
            NSLog("[MLX Audio] download progress model=\(modelId) percent=\(percent) completed=\(completed) total=\(total)")
        }
        emitDownload([
            "modelId": modelId,
            "status": "downloading",
            "progress": clampedFraction,
            "completedUnitCount": completed,
            "totalUnitCount": total,
        ])
    }
    #endif
}
