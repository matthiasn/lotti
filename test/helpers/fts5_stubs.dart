import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/search_hit.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';
import 'fallbacks.dart';

/// Stubs every write of [fts] to succeed, and [Fts5Db.matchIds] and
/// [Fts5Db.matchHits] to answer [matches] for the query they are asked — no
/// ids unless given. A hit is a match in a task's own text, with no snippet.
void stubFts5Db(
  MockFts5Db fts, {
  List<String> Function(String query)? matches,
}) {
  registerFts5Fallbacks();
  List<String> idsFor(Invocation invocation) =>
      matches?.call(invocation.positionalArguments.first as String) ??
      const <String>[];
  when(() => fts.indexEntities(any())).thenAnswer((_) async {});
  when(() => fts.indexByIds(any(), any())).thenAnswer((_) async {});
  when(() => fts.reindexMeasurements(any(), any())).thenAnswer((_) async {});
  when(() => anyMatchIds(fts)).thenAnswer((invocation) async => idsFor(invocation));
  // Every hit on the first page, none after it.
  when(() => anyMatchHits(fts)).thenAnswer(
    (invocation) async => invocation.namedArguments[#offset] == 0
        ? [for (final id in idsFor(invocation)) taskHit(id)]
        : const <SearchHit>[],
  );
}

/// A hit in task [id]'s own text, with [snippet].
SearchHit taskHit(String id, {String snippet = ''}) =>
    SearchHit(entityId: id, type: 'Task', snippet: snippet);

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

/// The [Fts5Db.matchHits] twin of [anyMatchIds].
Future<List<SearchHit>> anyMatchHits(Fts5Db fts, [String? query]) =>
    fts.matchHits(
      query ?? any(),
      anyTerm: any(named: 'anyTerm'),
      prefixLastWord: any(named: 'prefixLastWord'),
      types: any(named: 'types'),
      categoryIds: any(named: 'categoryIds'),
      includePrivate: any(named: 'includePrivate'),
      limit: any(named: 'limit'),
      offset: any(named: 'offset'),
    );
