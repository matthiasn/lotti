import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/logging_service.dart';

import '../mocks/mocks.dart';
import 'test_get_it.dart';

void main() {
  group('ensureThemingServicesRegistered', () {
    // CI bundles a shard's files into one isolate: a fallback left behind
    // made a later file's own registration of the same type throw.
    group('leaves nothing behind once its test ends', () {
      test('registers the fallbacks it needs', () {
        ensureThemingServicesRegistered();

        expect(getIt.isRegistered<UpdateNotifications>(), isTrue);
        expect(getIt.isRegistered<SettingsDb>(), isTrue);
        expect(getIt.isRegistered<LoggingService>(), isTrue);
        expect(getIt.isRegistered<DomainLogger>(), isTrue);
      });

      tearDownAll(() {
        expect(getIt.isRegistered<UpdateNotifications>(), isFalse);
        expect(getIt.isRegistered<SettingsDb>(), isFalse);
        expect(getIt.isRegistered<LoggingService>(), isFalse);
        expect(getIt.isRegistered<DomainLogger>(), isFalse);
      });
    });

    group('keeps what the test registered itself', () {
      final own = MockUpdateNotifications();

      test('a registration made before the call survives its teardown', () {
        getIt.registerSingleton<UpdateNotifications>(own);
        addTearDown(() => getIt.unregister<UpdateNotifications>());

        ensureThemingServicesRegistered();

        expect(getIt<UpdateNotifications>(), same(own));
      });
    });

    test('a reset before teardown does not make the teardown throw', () async {
      ensureThemingServicesRegistered();

      await getIt.reset();

      expect(getIt.isRegistered<UpdateNotifications>(), isFalse);
    });
  });
}
