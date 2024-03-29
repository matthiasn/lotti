import UIKit
import Flutter
import WhisperKit


@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
        }
        
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        
        let transcriptionChannel = FlutterMethodChannel(
            name: "lotti/transcribe",
            binaryMessenger: controller.binaryMessenger)

        
        transcriptionChannel.setMethodCallHandler { (call, result) in
            switch call.method {
            case "transcribe":
                guard let args = call.arguments as? [String: Any] else { return }
                let audioFilePath = args["audioFilePath"] as! String
                
                Task {
                    let model = "small"
                    let pipe = try? await WhisperKit(model: model, verbose: true, prewarm: true)

                    let transcription = try? await pipe!.transcribe(
                        audioPath: audioFilePath,
                        decodeOptions: DecodingOptions(
                            task: DecodingTask.transcribe,
                            usePrefillPrompt: false
                        ))
                    
                    let text = transcription?.text
                    let language = transcription?.language

                    let data = [language, model, text]
                    result(data)
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}

