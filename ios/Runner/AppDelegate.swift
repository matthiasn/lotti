import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
        }
        
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController

        AudioConverter.register(with: self.registrar(forPlugin: "AudioConverter")!)
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}

