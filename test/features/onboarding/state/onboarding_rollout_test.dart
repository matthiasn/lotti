import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/onboarding/state/onboarding_rollout.dart';
import 'package:lotti/features/onboarding/state/onboarding_trigger_service.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  group('applyOnboardingRolloutFlags', () {
    late MockJournalDb journalDb;
    late MockSettingsDb settingsDb;
    late MockDomainLogger logger;

    setUp(() {
      journalDb = MockJournalDb();
      settingsDb = MockSettingsDb();
      logger = MockDomainLogger();
    });

    test('production lever is off', () {
      expect(onboardingRolloutEnabled, isFalse);
    });

    test('disabled lever performs no reads or writes', () async {
      await applyOnboardingRolloutFlags(
        journalDb: journalDb,
        settingsDb: settingsDb,
        logger: logger,
      );

      verifyZeroInteractions(journalDb);
      verifyZeroInteractions(settingsDb);
      verifyZeroInteractions(logger);
    });

    test(
      'armed lever force-enables the walkthrough row and records its marker',
      () async {
        when(
          () => settingsDb.itemByKey(onboardingRolloutFlagsAppliedKey),
        ).thenAnswer((_) async => null);
        when(() => journalDb.getConfigFlagByName(any())).thenAnswer((
          invocation,
        ) {
          final name = invocation.positionalArguments.single as String;
          return Future.value(
            ConfigFlag(
              name: name,
              description: 'Description for $name',
              status: false,
            ),
          );
        });
        when(
          () => journalDb.upsertConfigFlag(any()),
        ).thenAnswer((_) async => 1);
        when(
          () => settingsDb.saveSettingsItem(
            onboardingRolloutFlagsAppliedKey,
            'true',
          ),
        ).thenAnswer((_) async => 1);

        await applyOnboardingRolloutFlags(
          journalDb: journalDb,
          settingsDb: settingsDb,
          logger: logger,
          rolloutEnabled: true,
        );

        final written = verify(
          () => journalDb.upsertConfigFlag(captureAny()),
        ).captured.cast<ConfigFlag>();
        expect(written.map((flag) => flag.name), onboardingRolloutFlags);
        expect(written.every((flag) => flag.status), isTrue);
        verify(
          () => settingsDb.saveSettingsItem(
            onboardingRolloutFlagsAppliedKey,
            'true',
          ),
        ).called(1);
      },
    );

    test('armed lever honors the one-shot marker', () async {
      when(
        () => settingsDb.itemByKey(onboardingRolloutFlagsAppliedKey),
      ).thenAnswer((_) async => 'true');

      await applyOnboardingRolloutFlags(
        journalDb: journalDb,
        settingsDb: settingsDb,
        logger: logger,
        rolloutEnabled: true,
      );

      verifyNever(() => journalDb.getConfigFlagByName(any()));
      verifyNever(() => journalDb.upsertConfigFlag(any()));
    });

    for (final scenario in <(String, ConfigFlag?)>[
      ('absent', null),
      (
        'already-enabled',
        const ConfigFlag(
          name: dailyOsOnboardingEnabledFlag,
          description: 'Enable the Daily OS onboarding walkthrough?',
          status: true,
        ),
      ),
    ]) {
      test('armed lever skips an ${scenario.$1} row', () async {
        when(
          () => settingsDb.itemByKey(onboardingRolloutFlagsAppliedKey),
        ).thenAnswer((_) async => null);
        when(
          () => journalDb.getConfigFlagByName(dailyOsOnboardingEnabledFlag),
        ).thenAnswer((_) async => scenario.$2);
        when(
          () => settingsDb.saveSettingsItem(
            onboardingRolloutFlagsAppliedKey,
            'true',
          ),
        ).thenAnswer((_) async => 1);

        await applyOnboardingRolloutFlags(
          journalDb: journalDb,
          settingsDb: settingsDb,
          logger: logger,
          rolloutEnabled: true,
        );

        verifyNever(() => journalDb.upsertConfigFlag(any()));
        verify(
          () => settingsDb.saveSettingsItem(
            onboardingRolloutFlagsAppliedKey,
            'true',
          ),
        ).called(1);
      });
    }

    test('armed lever logs failures without burning the marker', () async {
      when(
        () => settingsDb.itemByKey(onboardingRolloutFlagsAppliedKey),
      ).thenThrow(Exception('settings unavailable'));

      await expectLater(
        applyOnboardingRolloutFlags(
          journalDb: journalDb,
          settingsDb: settingsDb,
          logger: logger,
          rolloutEnabled: true,
        ),
        completes,
      );

      verify(
        () => logger.error(
          LogDomain.onboarding,
          any(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'onboardingRolloutFlags',
        ),
      ).called(1);
      verifyNever(() => settingsDb.saveSettingsItem(any(), any()));
    });
  });

  group('applyOnboardingRolloutBackfill', () {
    late SettingsDb settingsDb;
    late MockDomainLogger logger;

    setUp(() {
      settingsDb = SettingsDb(inMemoryDatabase: true);
      logger = MockDomainLogger();
    });

    tearDown(() => settingsDb.close());

    test(
      'disabled lever does not inspect readiness or persist state',
      () async {
        var readinessReads = 0;
        var retireWrites = 0;

        await applyOnboardingRolloutBackfill(
          readProviderReady: () async {
            readinessReads++;
            return true;
          },
          retireWelcome: () async {
            retireWrites++;
          },
          settingsDb: settingsDb,
          logger: logger,
        );

        expect(readinessReads, 0);
        expect(retireWrites, 0);
        expect(
          await settingsDb.itemByKey(onboardingRolloutBackfillAppliedKey),
          isNull,
        );
      },
    );

    test(
      'armed lever retires a ready install and records its marker',
      () async {
        await applyOnboardingRolloutBackfill(
          readProviderReady: () async => true,
          retireWelcome: () => settingsDb.saveSettingsItem(
            onboardingWelcomeCompletedKey,
            'true',
          ),
          settingsDb: settingsDb,
          logger: logger,
          rolloutEnabled: true,
        );

        expect(
          await settingsDb.itemByKey(onboardingWelcomeCompletedKey),
          'true',
        );
        expect(
          await settingsDb.itemByKey(onboardingRolloutBackfillAppliedKey),
          'true',
        );
      },
    );

    test(
      'armed lever leaves an unconfigured install welcome-eligible',
      () async {
        var retireWrites = 0;

        await applyOnboardingRolloutBackfill(
          readProviderReady: () async => false,
          retireWelcome: () async {
            retireWrites++;
          },
          settingsDb: settingsDb,
          logger: logger,
          rolloutEnabled: true,
        );

        expect(retireWrites, 0);
        expect(
          await settingsDb.itemByKey(onboardingRolloutBackfillAppliedKey),
          'true',
        );
      },
    );

    test(
      'armed lever does not reclassify an install after its marker',
      () async {
        await settingsDb.saveSettingsItem(
          onboardingRolloutBackfillAppliedKey,
          'true',
        );
        var readinessReads = 0;

        await applyOnboardingRolloutBackfill(
          readProviderReady: () async {
            readinessReads++;
            return true;
          },
          retireWelcome: () async {},
          settingsDb: settingsDb,
          logger: logger,
          rolloutEnabled: true,
        );

        expect(readinessReads, 0);
      },
    );

    test('a failed retire logs and leaves the marker absent', () async {
      await expectLater(
        applyOnboardingRolloutBackfill(
          readProviderReady: () async => true,
          retireWelcome: () async => throw Exception('write failed'),
          settingsDb: settingsDb,
          logger: logger,
          rolloutEnabled: true,
        ),
        completes,
      );

      verify(
        () => logger.error(
          LogDomain.onboarding,
          any(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'onboardingRolloutBackfill',
        ),
      ).called(1);
      expect(
        await settingsDb.itemByKey(onboardingRolloutBackfillAppliedKey),
        isNull,
      );
    });
  });
}
