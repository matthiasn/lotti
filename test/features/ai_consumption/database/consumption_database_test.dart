import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_consumption/database/consumption_database.dart';
import 'package:lotti/features/ai_consumption/repository/consumption_repository.dart';
import 'package:lotti/features/sync/vector_clock.dart';

import '../test_utils.dart';

void main() {
  late ConsumptionDatabase db;
  late ConsumptionRepository repo;

  setUp(() {
    db = ConsumptionDatabase(inMemoryDatabase: true);
    repo = ConsumptionRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('countAllConsumptionEvents reflects inserted rows', () async {
    expect(await db.countAllConsumptionEvents(), 0);
    await repo.upsertEvent(makeConsumptionEvent(id: 'a'));
    await repo.upsertEvent(makeConsumptionEvent(id: 'b'));
    expect(await db.countAllConsumptionEvents(), 2);
  });

  test(
    'streamConsumptionEventsWithVectorClock yields ids and parsed clocks',
    () async {
      await repo.upsertEvent(
        makeConsumptionEvent(id: 'a', vectorClock: const VectorClock({'h': 1})),
      );
      await repo.upsertEvent(makeConsumptionEvent(id: 'b'));

      final all = await db
          .streamConsumptionEventsWithVectorClock(batchSize: 10)
          .expand((batch) => batch)
          .toList();

      expect(all.map((r) => r.id).toList()..sort(), ['a', 'b']);
      expect(all.firstWhere((r) => r.id == 'a').vectorClock, {'h': 1});
      expect(all.firstWhere((r) => r.id == 'b').vectorClock, isNull);
    },
  );

  test('streamConsumptionEventsWithVectorClock pages by batchSize', () async {
    for (var i = 0; i < 5; i++) {
      await repo.upsertEvent(makeConsumptionEvent(id: 'e$i'));
    }
    final batches = await db
        .streamConsumptionEventsWithVectorClock(batchSize: 2)
        .toList();
    expect(batches.map((b) => b.length).toList(), [2, 2, 1]);
  });
}
