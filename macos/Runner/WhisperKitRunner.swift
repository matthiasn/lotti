import Foundation
import FlutterMacOS
import WhisperKit

public class WhisperKitRunner: NSObject, FlutterStreamHandler {
    let transcriptionChannelName = "lotti/transcribe"
    let transcriptionProgressChannelName = "lotti/transcribe-progress"
    let model = "large-v3"
    
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
                
                if (self.whisperKit == nil) {
                    if (self.eventSink != nil) {
                        self.eventSink!(["Initializing model...", ""])
                    }
                }


                Task {
                    if (self.whisperKit == nil) {
                        self.whisperKit = try? await WhisperKit(model: self.model,
                                                                verbose: true,
                                                                prewarm: true)
                    }
                    
                    let transcription = try? await self.whisperKit!.transcribe(
                        audioPath: audioFilePath,
                        decodeOptions: DecodingOptions(
                            task: DecodingTask.transcribe,
                            usePrefillPrompt: false,
                            detectLanguage: true
                        ),
                        callback: self.sendTranscriptionProgressEvent
                    )
                    
                    let text = transcription?.text
                    let language = transcription?.language
                    
                    let data = [language, self.model, text]
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
