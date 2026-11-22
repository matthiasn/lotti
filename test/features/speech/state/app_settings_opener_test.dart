import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/speech/state/app_settings_opener.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;

void main() {
  test("unless overridden, Open settings is the platform's own", () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Read, never called: calling it would need the platform channel.
    expect(
      container.read(appSettingsOpenerProvider),
      same(permissions.openAppSettings),
    );
  });
}
