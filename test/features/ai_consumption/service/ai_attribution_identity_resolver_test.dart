import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_identity_resolver.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_preferences_keys.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uuid/uuid.dart';

import '../../../mocks/mocks.dart';

void main() {
  late MockSettingsDb settingsDb;
  late MockVectorClockService vectorClockService;
  late AiAttributionIdentityResolver resolver;

  setUp(() {
    settingsDb = MockSettingsDb();
    vectorClockService = MockVectorClockService();
    when(() => settingsDb.itemByKey(any())).thenAnswer((_) async => null);
    when(
      () => settingsDb.saveSettingsItem(any(), any()),
    ).thenAnswer((_) async => 1);
    resolver = AiAttributionIdentityResolver(
      settingsDb,
      vectorClockService,
      uuid: _FixedUuid(),
    );
  });

  test('captures the trimmed owner name and stable human principal', () async {
    when(
      () => settingsDb.itemByKey(dailyOsUserNameSettingsKey),
    ).thenAnswer((_) async => '  Ada  ');

    final actor = await resolver.humanInitiator();

    expect(actor.type, AiActorType.human);
    expect(actor.id, 'local:offline-user');
    expect(actor.humanPrincipalId, 'local:offline-user');
    expect(actor.displayName, 'Ada');
  });

  test(
    'uses the Matrix user id when a signed-in identity is available',
    () async {
      when(
        () => settingsDb.itemByKey(dailyOsUserNameSettingsKey),
      ).thenAnswer((_) async => 'Ada');
      final matrixResolver = AiAttributionIdentityResolver(
        settingsDb,
        vectorClockService,
        matrixUserId: () => '@ada:example.org',
        uuid: _FixedUuid(),
      );

      final actor = await matrixResolver.humanInitiator();

      expect(actor.id, 'matrix:@ada:example.org');
      expect(actor.humanPrincipalId, 'matrix:@ada:example.org');
      verifyNever(() => settingsDb.saveSettingsItem(any(), any()));
    },
  );

  test('reuses the persisted offline principal', () async {
    when(() => settingsDb.itemByKey(any())).thenAnswer((invocation) async {
      final key = invocation.positionalArguments.single as String;
      return key == dailyOsUserNameSettingsKey ? 'Ada' : 'local:persisted';
    });

    final actor = await resolver.humanInitiator();

    expect(actor.id, 'local:persisted');
    verifyNever(() => settingsDb.saveSettingsItem(any(), any()));
  });

  test('keeps an unknown owner display name empty', () async {
    when(
      () => settingsDb.itemByKey(dailyOsUserNameSettingsKey),
    ).thenAnswer((_) async => null);

    expect((await resolver.humanInitiator()).displayName, isEmpty);
  });

  test('captures the host id and falls back when none exists', () async {
    when(vectorClockService.getHost).thenAnswer((_) async => 'host-a');
    final known = await resolver.executor();
    expect(known.hostId, 'host-a');
    expect(known.displayName, isNotEmpty);

    when(vectorClockService.getHost).thenAnswer((_) async => null);
    expect((await resolver.executor()).hostId, 'unknown-host');
  });
}

class _FixedUuid implements Uuid {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #v4) return 'offline-user';
    return super.noSuchMethod(invocation);
  }
}
