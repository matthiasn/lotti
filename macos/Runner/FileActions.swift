import Cocoa
import FlutterMacOS

/// Desktop file actions used by Flutter for media entry actions.
///
/// The macOS reveal path intentionally goes through NSWorkspace so Finder
/// selects the exact file rather than opening only its parent directory.
class FileActions {
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.matthiasn.lotti/file_actions",
            binaryMessenger: registrar.messenger
        )

        channel.setMethodCallHandler { call, result in
            guard let args = call.arguments as? [String: String],
                  let path = args["path"]
            else {
                result(FlutterError(
                    code: "INVALID_ARGUMENTS",
                    message: "Missing path",
                    details: nil
                ))
                return
            }

            switch call.method {
            case "revealInFileManager":
                revealInFinder(path: path, result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private static func revealInFinder(
        path: String,
        result: @escaping FlutterResult
    ) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
        result(true)
    }
}
