//
//  whisper.swift
//  Runner
//
//  Created by mn on 01.04.24.
//

import Foundation
import FlutterMacOS
import WhisperKit

public class WhisperKitRunner: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private let transcriptionChannel: FlutterMethodChannel

    init(flutterViewController: FlutterViewController) {
        transcriptionChannel = FlutterMethodChannel(
            name: "lotti/transcribe",
            binaryMessenger: flutterViewController.engine.binaryMessenger)
        super.init()

        transcriptionChannel.setMethodCallHandler { (call, result) in
            switch call.method {
            case "transcribe":
                guard let args = call.arguments as? [String: Any] else { return }
                let audioFilePath = args["audioFilePath"] as! String
                
                Task {
                    let model = "large-v3"
                    let pipe = try? await WhisperKit(model: model, verbose: true, prewarm: true)
                    
                    let transcription = try? await pipe!.transcribe(
                        audioPath: audioFilePath,
                        decodeOptions: DecodingOptions(
                            task: DecodingTask.transcribe,
                            usePrefillPrompt: false
                        ),
                        callback: { progress in
                            print("\n---")
                            print(progress)
                            print("\n")
                            print(progress.text)
                            print("\n")
                            return nil
                        }
                    )
                    
                    let text = transcription?.text
                    let language = transcription?.language
                    
                    let data = [language, model, text]
                    result(data)
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
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
