import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/state/conflict_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';

void main() {
  late TestGetItMocks mocks;

  setUp(() async {
    mocks = await setUpTestGetIt();
  });

  tearDown(tearDownTestGetIt);

  Future<int> readCount(List<Conflict> conflicts) async {
    when(
      () => mocks.journalDb.watchConflicts(ConflictStatus.unresolved),
    ).thenAnswer((_) => Stream.value(conflicts));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // Keep the autoDispose provider alive while we await the first value.
    container.listen(unresolvedConflictCountProvider, (_, __) {});
    return container.read(unresolvedConflictCountProvider.future);
  }

  test('emits the number of unresolved conflicts', () async {
    expect(await readCount([unresolvedConflict, unresolvedConflict]), 2);
  });

  test('emits zero when there are no unresolved conflicts', () async {
    expect(await readCount(const <Conflict>[]), 0);
  });
}
