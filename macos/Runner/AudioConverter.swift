import AVFoundation
import FlutterMacOS

/// Native WAV-to-M4A audio converter using Apple's AVFoundation framework.
///
/// Registered as a Flutter platform channel handler for
/// `com.matthiasn.lotti/audio_converter`.
///
/// NOTE: Keep in sync with `ios/Runner/AudioConverter.swift` — the two
/// files differ only in the Flutter import and messenger accessor.
class AudioConverter {
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.matthiasn.lotti/audio_converter",
            binaryMessenger: registrar.messenger
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
                let frameCount = AVAudioFrameCount(inputFile.length)

                guard frameCount > 0 else {
                    DispatchQueue.main.async {
                        result(FlutterError(
                            code: "EMPTY_FILE",
                            message: "Input WAV file is empty",
                            details: nil
                        ))
                    }
                    return
                }

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
}
