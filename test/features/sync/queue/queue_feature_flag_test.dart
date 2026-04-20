import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/queue/queue_feature_flag.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late MockSettingsDb settingsDb;

  setUp(() {
    settingsDb = MockSettingsDb();
    when(
      () => settingsDb.saveSettingsItem(any(), any()),
    ).thenAnswer((_) async => 1);
  });

  test('missing key defaults to false', () async {
    when(
      () => settingsDb.itemByKey(useInboundEventQueueKey),
    ).thenAnswer((_) async => null);
    final enabled = await readUseInboundEventQueueFlag(settingsDb);
    expect(enabled, isFalse);
  });

  test('"true" stored string enables the flag', () async {
    when(
      () => settingsDb.itemByKey(useInboundEventQueueKey),
    ).thenAnswer((_) async => 'true');
    final enabled = await readUseInboundEventQueueFlag(settingsDb);
    expect(enabled, isTrue);
  });

  test('arbitrary stored value reads as false', () async {
    when(
      () => settingsDb.itemByKey(useInboundEventQueueKey),
    ).thenAnswer((_) async => 'maybe');
    final enabled = await readUseInboundEventQueueFlag(settingsDb);
    expect(enabled, isFalse);
  });

  test('writeUseInboundEventQueueFlag persists the value', () async {
    await writeUseInboundEventQueueFlag(settingsDb, enabled: true);
    verify(
      () => settingsDb.saveSettingsItem(useInboundEventQueueKey, 'true'),
    ).called(1);
  });
}
