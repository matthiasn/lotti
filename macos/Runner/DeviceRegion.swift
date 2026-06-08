import Cocoa
import FlutterMacOS

/// Exposes the macOS System-Settings *Region* to Flutter.
///
/// Flutter's locale APIs report the preferred *language* (often `en_US` for
/// GUI apps, regardless of the configured region), so the calendar reads the
/// region directly from `Locale.current` to decide the first day of the week.
class DeviceRegion {
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.matthiasn.lotti/device_region",
            binaryMessenger: registrar.messenger
        )

        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "getRegionCode":
                if #available(macOS 13.0, *) {
                    result(Locale.current.region?.identifier)
                } else {
                    result(Locale.current.regionCode)
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
}
