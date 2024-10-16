import Foundation
import Flutter
import WhisperKit

public class WhisperKitRunner: NSObject, FlutterStreamHandler {
    let transcriptionChannelName = "lotti/transcribe"
    let transcriptionProgressChannelName = "lotti/transcribe-progress"
    
    private var eventSink: FlutterEventSink?
    private let transcriptionChannel: FlutterMethodChannel
    private let transcriptionProgressChannel: FlutterEventChannel
    
    private var whisperKit: WhisperKit?
    
    init(binaryMessenger: FlutterBinaryMessenger) {
        transcriptionChannel = FlutterMethodChannel(
            name: transcriptionChannelName,
            binaryMessenger: binaryMessenger)
        
        transcriptionProgressChannel = FlutterEventChannel(name: transcriptionProgressChannelName,
                                                           binaryMessenger: binaryMessenger)
        
        super.init()
        
        transcriptionChannel.setMethodCallHandler { (call, result) in
            switch call.method {
            case "transcribe":
                guard let args = call.arguments as? [String: Any] else { return }
                let audioFilePath = args["audioFilePath"] as! String
                let model = args["model"] as! String
                let language = args["language"] as! String
                let detectLanguage = language.isEmpty
                
                Task {
                    if (self.whisperKit == nil || self.whisperKit?.modelVariant.description != model) {
                        if (self.eventSink != nil) {
                            self.eventSink!(["Initializing model...", ""])
                        }
                        self.whisperKit = try? await WhisperKit(model: model,
                                                                verbose: true,
                                                                prewarm: true)
                    }
                    
                    let transcription = try? await self.whisperKit!.transcribe(
                        audioPath: audioFilePath,
                        decodeOptions: DecodingOptions(
                            task: DecodingTask.transcribe,
                            language: detectLanguage ? nil : language,
                            usePrefillPrompt: !detectLanguage,
                            detectLanguage: detectLanguage
                        ),
                        callback: self.sendTranscriptionProgressEvent
                    )
                    
                    let text : String? = transcription?.first?.text
                    let detectedLanguage = transcription?.first?.language
                    let data = [detectedLanguage, self.whisperKit?.modelVariant.description, text]
                    result(data)
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        transcriptionProgressChannel.setStreamHandler(self)
    }
    
    private func sendTranscriptionProgressEvent(progress: TranscriptionProgress) -> Bool? {
        guard let eventSink = eventSink else {
            return nil
        }
        
        eventSink([progress.text,
                   progress.timings.pipelineStart.formatted()])
        return nil
    }
    
    public func onListen(withArguments arguments: Any?,
                         eventSink: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = eventSink
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}
