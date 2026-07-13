import AVFoundation
import Flutter

/// Native WAV/M4A audio converter using Apple's AVFoundation framework.
///
/// Registered as a Flutter platform channel handler for
/// `com.matthiasn.lotti/audio_converter`.
///
/// NOTE: Keep in sync with `macos/Runner/AudioConverter.swift` — the two
/// files differ only in the Flutter import and messenger accessor.
class AudioConverter {
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.matthiasn.lotti/audio_converter",
            binaryMessenger: registrar.messenger()
        )

        channel.setMethodCallHandler { (call, result) in
            switch call.method {
            case "convertWavToM4a":
                guard let args = call.arguments as? [String: String],
                      let inputPath = args["inputPath"],
                      let outputPath = args["outputPath"]
                else {
                    result(FlutterError(
                        code: "INVALID_ARGUMENTS",
                        message: "Missing inputPath or outputPath",
                        details: nil
                    ))
                    return
                }
                convertWavToM4a(inputPath: inputPath, outputPath: outputPath, result: result)
            case "convertM4aToWav":
                guard let args = call.arguments as? [String: String],
                      let inputPath = args["inputPath"],
                      let outputPath = args["outputPath"]
                else {
                    result(FlutterError(
                        code: "INVALID_ARGUMENTS",
                        message: "Missing inputPath or outputPath",
                        details: nil
                    ))
                    return
                }
                convertM4aToWav(inputPath: inputPath, outputPath: outputPath, result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private static func convertWavToM4a(
        inputPath: String,
        outputPath: String,
        result: @escaping FlutterResult
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let inputUrl = URL(fileURLWithPath: inputPath)
                let outputUrl = URL(fileURLWithPath: outputPath)

                // Read source WAV
                let inputFile = try AVAudioFile(forReading: inputUrl)
                let inputFormat = inputFile.processingFormat
                let rawLength = inputFile.length

                guard rawLength > 0, rawLength <= Int64(UInt32.max) else {
                    DispatchQueue.main.async {
                        result(FlutterError(
                            code: "EMPTY_FILE",
                            message: rawLength <= 0
                                ? "Input WAV file is empty"
                                : "Input WAV file too large (\(rawLength) frames)",
                            details: nil
                        ))
                    }
                    return
                }

                let frameCount = AVAudioFrameCount(rawLength)

                let outputSettings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: inputFormat.sampleRate,
                    AVNumberOfChannelsKey: inputFormat.channelCount,
                    AVEncoderBitRateKey: 128000
                ]

                let outputFile = try AVAudioFile(
                    forWriting: outputUrl,
                    settings: outputSettings,
                    commonFormat: .pcmFormatFloat32,
                    interleaved: false
                )

                // Read all PCM data
                guard let buffer = AVAudioPCMBuffer(
                    pcmFormat: inputFormat,
                    frameCapacity: frameCount
                ) else {
                    try? FileManager.default.removeItem(at: outputUrl)
                    DispatchQueue.main.async {
                        result(FlutterError(
                            code: "BUFFER_ERROR",
                            message: "Could not create audio buffer",
                            details: nil
                        ))
                    }
                    return
                }

                try inputFile.read(into: buffer)

                // Write as M4A (AVAudioFile handles the AAC encoding)
                try outputFile.write(from: buffer)

                DispatchQueue.main.async {
                    result(true)
                }
            } catch {
                let outputUrl = URL(fileURLWithPath: outputPath)
                try? FileManager.default.removeItem(at: outputUrl)
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "CONVERSION_ERROR",
                        message: "Failed to convert WAV to M4A: \(error.localizedDescription)",
                        details: "\(error)"
                    ))
                }
            }
        }
    }

    private static func convertM4aToWav(
        inputPath: String,
        outputPath: String,
        result: @escaping FlutterResult
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let outputUrl = URL(fileURLWithPath: outputPath)
            do {
                let inputFile = try AVAudioFile(
                    forReading: URL(fileURLWithPath: inputPath)
                )
                let inputFormat = inputFile.processingFormat
                guard inputFile.length > 0 else {
                    throw NSError(
                        domain: "AudioConverter",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Input M4A file is empty"]
                    )
                }

                let outputSettings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVSampleRateKey: inputFormat.sampleRate,
                    AVNumberOfChannelsKey: inputFormat.channelCount,
                    AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsFloatKey: false,
                    AVLinearPCMIsBigEndianKey: false,
                    AVLinearPCMIsNonInterleaved: false
                ]
                let outputFile = try AVAudioFile(
                    forWriting: outputUrl,
                    settings: outputSettings,
                    commonFormat: .pcmFormatFloat32,
                    interleaved: false
                )
                guard let buffer = AVAudioPCMBuffer(
                    pcmFormat: inputFormat,
                    frameCapacity: 4096
                ) else {
                    throw NSError(
                        domain: "AudioConverter",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "Could not create audio buffer"]
                    )
                }

                while true {
                    try inputFile.read(into: buffer)
                    if buffer.frameLength == 0 { break }
                    try outputFile.write(from: buffer)
                }

                DispatchQueue.main.async { result(true) }
            } catch {
                try? FileManager.default.removeItem(at: outputUrl)
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "CONVERSION_ERROR",
                        message: "Failed to convert M4A to WAV: \(error.localizedDescription)",
                        details: "\(error)"
                    ))
                }
            }
        }
    }
}
