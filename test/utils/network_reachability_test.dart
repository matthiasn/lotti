import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/utils/network_reachability.dart';

void main() {
  group('reachesNetwork', () {
    test('any link but none or Bluetooth reaches the network', () {
      expect(reachesNetwork(const [ConnectivityResult.wifi]), isTrue);
      expect(
        reachesNetwork(const [
          ConnectivityResult.bluetooth,
          ConnectivityResult.mobile,
        ]),
        isTrue,
      );
      expect(reachesNetwork(const [ConnectivityResult.none]), isFalse);
      expect(reachesNetwork(const [ConnectivityResult.bluetooth]), isFalse);
      expect(reachesNetwork(const []), isFalse);
    });

    test('an unnamed link such as a WireGuard or tun interface counts', () {
      expect(reachesNetwork(const [ConnectivityResult.other]), isTrue);
      expect(reachesNetwork(const [ConnectivityResult.vpn]), isTrue);
    });
  });
}
