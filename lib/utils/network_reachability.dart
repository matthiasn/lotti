import 'package:connectivity_plus/connectivity_plus.dart';

/// Whether a connectivity report carries a link that can reach a server:
/// any link other than none or Bluetooth.
///
/// `other` counts. It is what the platform reports for a link it cannot name —
/// WireGuard, Tailscale's `tun`, and similar VPN interfaces among them — and
/// treating it as offline would leave such a device waiting for a network it
/// already has.
bool reachesNetwork(List<ConnectivityResult> results) => results.any(
  (result) =>
      result != ConnectivityResult.none &&
      result != ConnectivityResult.bluetooth,
);
