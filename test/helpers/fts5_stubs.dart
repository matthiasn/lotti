import 'package:lotti/database/fts5_db.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';
import 'fallbacks.dart';

/// Stubs every write of [fts] to succeed, and [Fts5Db.matchIds] to answer
/// [matches] for the query it is asked — no ids unless given.
void stubFts5Db(
  MockFts5Db fts, {
  List<String> Function(String query)? matches,
}) {
  registerFts5Fallbacks();
  when(() => fts.indexEntities(any())).thenAnswer((_) async {});
  when(() => fts.indexByIds(any(), any())).thenAnswer((_) async {});
  when(() => fts.reindexMeasurements(any(), any())).thenAnswer((_) async {});
  when(() => anyMatchIds(fts)).thenAnswer(
    (invocation) async =>
        matches?.call(invocation.positionalArguments.first as String) ??
        const <String>[],
  );
}

/// A [Fts5Db.matchIds] call with any filters, for `when` and `verify`;
/// [query] narrows it to that query. Mocktail matches named arguments only
/// when the stub names them, so every caller goes through this one shape.
Future<List<String>> anyMatchIds(Fts5Db fts, [String? query]) => fts.matchIds(
  query ?? any(),
  anyTerm: any(named: 'anyTerm'),
  prefixLastWord: any(named: 'prefixLastWord'),
  types: any(named: 'types'),
  categoryIds: any(named: 'categoryIds'),
  includePrivate: any(named: 'includePrivate'),
  limit: any(named: 'limit'),
);
