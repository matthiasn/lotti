import Cocoa
import FlutterMacOS


import IOKit

class MainFlutterWindow: NSWindow {
    override func awakeFromNib() {
        let flutterViewController = FlutterViewController.init()
        let windowFrame = self.frame
        self.contentViewController = flutterViewController
        self.setFrame(windowFrame, display: true)
        let whisperKitRunner = WhisperKitRunner(flutterViewController: flutterViewController)
        
        RegisterGeneratedPlugins(registry: flutterViewController)
        
        super.awakeFromNib()
    }
}
