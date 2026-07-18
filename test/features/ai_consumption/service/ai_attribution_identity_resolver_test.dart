import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_identity_resolver.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_preferences_keys.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late MockSettingsDb settingsDb;
  late MockVectorClockService vectorClockService;
  late AiAttributionIdentityResolver resolver;

  setUp(() {
    settingsDb = MockSettingsDb();
    vectorClockService = MockVectorClockService();
    resolver = AiAttributionIdentityResolver(settingsDb, vectorClockService);
  });

  test('captures the trimmed owner name and stable human principal', () async {
    when(
      () => settingsDb.itemByKey(dailyOsUserNameSettingsKey),
    ).thenAnswer((_) async => '  Ada  ');

    final actor = await resolver.humanInitiator();

    expect(actor.type, AiActorType.human);
    expect(actor.id, 'human:owner');
    expect(actor.humanPrincipalId, 'human:owner');
    expect(actor.displayName, 'Ada');
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
