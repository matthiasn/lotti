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
                    let pipe = try? await WhisperKit()
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
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}

