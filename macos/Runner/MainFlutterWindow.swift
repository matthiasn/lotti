import Cocoa
import FlutterMacOS
import IOKit

class MainFlutterWindow: NSWindow {
    override func awakeFromNib() {
        let flutterViewController = FlutterViewController.init()
        let windowFrame = self.frame
        self.contentViewController = flutterViewController
        self.setFrame(windowFrame, display: true)
        
        let registrar = flutterViewController.registrar(forPlugin: "AudioConverter")
        AudioConverter.register(with: registrar)
        let fileActionsRegistrar = flutterViewController.registrar(forPlugin: "FileActions")
        FileActions.register(with: fileActionsRegistrar)
        let mlxAudioRegistrar = flutterViewController.registrar(forPlugin: "MlxAudio")
        MlxAudio.register(with: mlxAudioRegistrar)
        RegisterGeneratedPlugins(registry: flutterViewController)

        super.awakeFromNib()
    }
}
