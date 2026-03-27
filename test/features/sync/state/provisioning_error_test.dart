import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/state/provisioning_error.dart';

void main() {
  group('ProvisioningError', () {
    test('has expected values', () {
      expect(
        ProvisioningError.values,
        [
          ProvisioningError.loginFailed,
          ProvisioningError.configurationError,
        ],
      );
    });

    test('loginFailed has correct name', () {
      expect(ProvisioningError.loginFailed.name, 'loginFailed');
    });

    test('configurationError has correct name', () {
      expect(ProvisioningError.configurationError.name, 'configurationError');
    });
  });
}
