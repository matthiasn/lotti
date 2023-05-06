import Cocoa
import FlutterMacOS

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
                let modelPath = args["modelPath"] as! String
                guard let transcript = transcribe(audioFilePath: audioFilePath, modelPath: modelPath) else {
                    result(
                        FlutterError(
                            code: "FAIL",
                            message: "Transcription failure.",
                            details: nil))
                    return
                }
                result(transcript)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        RegisterGeneratedPlugins(registry: flutterViewController)
        
        super.awakeFromNib()
    }
}
