import 'dart:convert';

import 'package:drift/drift.dart';

/// One stored payload's id and vector clock, as the sync sequence log
/// population reads them.
typedef VectorClockRecord = ({String id, Map<String, int>? vectorClock});

/// Pages through [table] in id order, yielding each row's id and the vector
/// clock that [clockSql] selects as JSON text. A clock that is absent or does
/// not parse comes back null, and the population skips that row.
///
/// The stable order keeps LIMIT/OFFSET pages from skipping or repeating rows.
Stream<List<VectorClockRecord>> streamTableVectorClocks(
  GeneratedDatabase db, {
  required String table,
  required String clockSql,
  int batchSize = 1000,
}) async* {
  var offset = 0;
  while (true) {
    final rows = await db
        .customSelect(
          'SELECT id, $clockSql AS vector_clock FROM $table '
          'ORDER BY id LIMIT ? OFFSET ?',
          variables: [Variable.withInt(batchSize), Variable.withInt(offset)],
        )
        .get();
    if (rows.isEmpty) return;
    yield [
      for (final row in rows)
        (
          id: row.read<String>('id'),
          vectorClock: _decodeVectorClock(
            row.readNullable<String>('vector_clock'),
          ),
        ),
    ];
    offset += batchSize;
  }
}

/// The number of rows in [table].
Future<int> countTableRows(GeneratedDatabase db, String table) async {
  final row = await db
      .customSelect('SELECT COUNT(*) AS row_count FROM $table')
      .getSingle();
  return row.read<int>('row_count');
}

Map<String, int>? _decodeVectorClock(String? encoded) {
  if (encoded == null) return null;
  try {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic>) return null;
    return decoded.map(
      (host, counter) => MapEntry(host, (counter as num).toInt()),
    );
  } on Object {
    return null;
  }
}
