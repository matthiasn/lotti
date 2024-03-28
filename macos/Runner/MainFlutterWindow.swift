import Cocoa
import FlutterMacOS
import WhisperKit


import IOKit

class MainFlutterWindow: NSWindow {
    override func awakeFromNib() {
        let flutterViewController = FlutterViewController.init()
        let windowFrame = self.frame
        self.contentViewController = flutterViewController
        self.setFrame(windowFrame, display: true)
        
        let transcriptionChannel = FlutterMethodChannel(
            name: "lotti/transcribe",
            binaryMessenger: flutterViewController.engine.binaryMessenger)
        
        transcriptionChannel.setMethodCallHandler { (call, result) in
            switch call.method {
            case "transcribe":
                guard let args = call.arguments as? [String: Any] else { return }
                let audioFilePath = args["audioFilePath"] as! String
                Task {
                    let pipe = try? await WhisperKit(model: "large-v3")
                    let transcription = try? await pipe!.transcribe(audioPath: audioFilePath)?.text
                    result(transcription)
                }
            case "detectLanguage":
                guard let args = call.arguments as? [String: Any] else { return }
                Task {
                    let lang =  await detectLanguage( args: args)
                    result(lang)
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        RegisterGeneratedPlugins(registry: flutterViewController)
        
        super.awakeFromNib()
    }
}
