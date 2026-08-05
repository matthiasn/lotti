import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:lotti/logic/health_data_types.dart';
import 'package:lotti/logic/health_permission_gate.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';

void main() {
  late MockHealthService health;
  late HealthPermissionGate gate;

  setUp(() {
    health = MockHealthService();
    gate = HealthPermissionGate(health);
  });

  /// HealthKit: read authorization is never disclosed, so `hasPermissions`
  /// answers `null` and `requestAuthorization` reports only that a sheet was
  /// shown.
  void stubAppleHealth({bool sheetShown = true}) {
    when(() => health.hasPermissions(any())).thenAnswer((_) async => null);
    when(
      () => health.requestAuthorization(any()),
    ).thenAnswer((_) async => sheetShown);
  }

  /// Health Connect: `hasPermissions` is definitive.
  void stubHealthConnect({
    required bool grantedBefore,
    bool? grantedAfter,
    bool sheetShown = true,
  }) {
    var call = 0;
    when(() => health.hasPermissions(any())).thenAnswer(
      (_) async =>
          ++call == 1 ? grantedBefore : (grantedAfter ?? grantedBefore),
    );
    when(
      () => health.requestAuthorization(any()),
    ).thenAnswer((_) async => sheetShown);
  }

  group('nothing to ask for', () {
    test('an empty request is granted without touching the platform', () async {
      expect(
        await gate.ensure(const [], userInitiated: true),
        HealthAuthorization.granted,
      );

      verifyNever(() => health.hasPermissions(any()));
      verifyNever(() => health.requestAuthorization(any()));
    });
  });

  group('access already confirmed', () {
    test('raises no sheet at all when the platform says yes', () async {
      stubHealthConnect(grantedBefore: true);

      expect(
        await gate.ensure(bpTypes, userInitiated: true),
        HealthAuthorization.granted,
      );

      // The whole point: a confirmed permission must not put a modal in front
      // of the user, not even one they asked for.
      verifyNever(() => health.requestAuthorization(any()));
    });

    test('records the family so a later ask stays quiet too', () async {
      stubHealthConnect(grantedBefore: true);

      await gate.ensure([
        HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
      ], userInitiated: false);

      expect(gate.requestedTypes, containsAll(bpTypes));
    });
  });

  group('the family, not the type', () {
    test('asking for one blood-pressure series authorizes both', () async {
      stubAppleHealth();

      await gate.ensure([
        HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
      ], userInitiated: false);

      verify(() => health.requestAuthorization(bpTypes)).called(1);
      verify(() => health.hasPermissions(bpTypes)).called(1);
    });

    test(
      'the second blood-pressure series does not raise a second sheet',
      () async {
        stubAppleHealth();

        // Exactly what a dashboard does: the BP card mounts one controller per
        // series, so two independent background imports start within a second
        // of each other. This used to be two authorization sheets, back to
        // back, for one switch in the user's mind.
        await gate.ensure([
          HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
        ], userInitiated: false);
        await gate.ensure([
          HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
        ], userInitiated: false);

        verify(() => health.requestAuthorization(any())).called(1);
      },
    );

    test('a different family is still asked for on its own', () async {
      stubAppleHealth();

      await gate.ensure(bpTypes, userInitiated: false);
      await gate.ensure([HealthDataType.WEIGHT], userInitiated: false);

      verify(() => health.requestAuthorization(bpTypes)).called(1);
      verify(
        () => health.requestAuthorization(bodyMeasurementTypes),
      ).called(1);
    });
  });

  group('ask once per session', () {
    test('a background repeat raises no second sheet', () async {
      stubAppleHealth();

      await gate.ensure(bpTypes, userInitiated: false);
      final second = await gate.ensure(bpTypes, userInitiated: false);

      // The reported bug: every visit to a dashboard re-raised a sheet the
      // user had already answered — and once the type is switched off in
      // Settings → Privacy & Security → Health, there is nothing in it to
      // answer.
      verify(() => health.requestAuthorization(any())).called(1);
      expect(second, HealthAuthorization.undisclosed);
    });

    test('a user-initiated repeat does ask again', () async {
      stubAppleHealth();

      await gate.ensure(bpTypes, userInitiated: false);
      final second = await gate.ensure(bpTypes, userInitiated: true);

      // A tap on the Health Import page means "ask me again", which is the one
      // moment re-raising the sheet is what the user wants.
      verify(() => health.requestAuthorization(any())).called(2);
      expect(second, HealthAuthorization.undisclosed);
    });

    test('a partially-asked family is still asked in full', () async {
      stubAppleHealth();

      await gate.ensure([HealthDataType.WEIGHT], userInitiated: false);
      // Sleep shares nothing with body measurements, so the memory must not
      // suppress it.
      await gate.ensure([HealthDataType.SLEEP_REM], userInitiated: false);

      verify(() => health.requestAuthorization(sleepTypes)).called(1);
    });

    test('the memory does not suppress a definitive re-check', () async {
      // Health Connect keeps answering, so a permission granted in system
      // settings mid-session is picked up without a sheet.
      when(() => health.hasPermissions(any())).thenAnswer((_) async => null);
      when(
        () => health.requestAuthorization(any()),
      ).thenAnswer((_) async => true);
      await gate.ensure(bpTypes, userInitiated: false);

      when(() => health.hasPermissions(any())).thenAnswer((_) async => true);
      expect(
        await gate.ensure(bpTypes, userInitiated: false),
        HealthAuthorization.granted,
      );
    });
  });

  group('Apple Health — read access is never disclosed', () {
    test('a shown sheet reports undisclosed, not granted', () async {
      stubAppleHealth();

      expect(
        await gate.ensure(bpTypes, userInitiated: true),
        HealthAuthorization.undisclosed,
      );
    });

    test(
      'spends no second round-trip re-checking what cannot be read',
      () async {
        stubAppleHealth();

        await gate.ensure(bpTypes, userInitiated: true);

        // Re-reading would only be told `null` again, at the cost of another
        // method-channel hop on a path a dashboard runs once per health card.
        verify(() => health.hasPermissions(any())).called(1);
      },
    );

    test('a sheet the platform refused to raise is a denial', () async {
      stubAppleHealth(sheetShown: false);

      expect(
        await gate.ensure(bpTypes, userInitiated: true),
        HealthAuthorization.denied,
      );
    });

    test('a null answer from the plugin is a denial, not a pass', () async {
      when(() => health.hasPermissions(any())).thenAnswer((_) async => null);
      when(
        () => health.requestAuthorization(any()),
      ).thenAnswer((_) async => null);

      expect(
        await gate.ensure(bpTypes, userInitiated: true),
        HealthAuthorization.denied,
      );
    });
  });

  group('Health Connect — read access is disclosed', () {
    test('a missing permission is re-requested, then confirmed', () async {
      stubHealthConnect(grantedBefore: false, grantedAfter: true);

      expect(
        await gate.ensure(bpTypes, userInitiated: false),
        HealthAuthorization.granted,
      );
      verify(() => health.requestAuthorization(bpTypes)).called(1);
    });

    test('a permission still missing after the ask is denied', () async {
      stubHealthConnect(grantedBefore: false);

      expect(
        await gate.ensure(bpTypes, userInitiated: true),
        HealthAuthorization.denied,
      );
      verify(() => health.hasPermissions(any())).called(2);
    });

    test('a null re-check after a definitive no is denied', () async {
      // Health Connect said no, then stopped answering. Treating the silence
      // as a pass would read every sample as importable and then import none.
      when(
        () => health.requestAuthorization(any()),
      ).thenAnswer((_) async => true);
      var call = 0;
      when(
        () => health.hasPermissions(any()),
      ).thenAnswer((_) async => ++call == 1 ? false : null);

      expect(
        await gate.ensure(bpTypes, userInitiated: true),
        HealthAuthorization.denied,
      );
    });

    test('a background repeat of a known-denied family does not ask', () async {
      stubHealthConnect(grantedBefore: false);

      await gate.ensure(bpTypes, userInitiated: true);
      final second = await gate.ensure(bpTypes, userInitiated: false);

      expect(second, HealthAuthorization.denied);
      // Health Connect's permission screen is as intrusive as HealthKit's
      // sheet; a chart the user is merely looking at must not summon it.
      verify(() => health.requestAuthorization(any())).called(1);
    });
  });

  group('requestedTypes', () {
    test('starts empty and is not writable from outside', () {
      expect(gate.requestedTypes, isEmpty);
      expect(
        () => gate.requestedTypes.add(HealthDataType.STEPS),
        throwsUnsupportedError,
      );
    });

    test('records the expanded family, not the requested type', () async {
      stubAppleHealth();

      await gate.ensure([HealthDataType.STEPS], userInitiated: false);

      expect(gate.requestedTypes, activityTypes.toSet());
    });

    test('is not recorded when the platform refused to ask', () async {
      // Recorded regardless: a refusal to raise the sheet is not a reason to
      // hammer the platform with it on every later import.
      stubAppleHealth(sheetShown: false);

      await gate.ensure([HealthDataType.STEPS], userInitiated: false);

      expect(gate.requestedTypes, activityTypes.toSet());
    });
  });
}
