import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';

/// Live count of *unresolved* sync conflicts.
///
/// This is the proactive-surfacing signal: a badge on the conflicts entry and
/// the in-context "needs review" affordances watch it, so a freshly detected
/// conflict shows up without the user hunting through settings. Backed by the
/// JournalDb conflict stream, so it updates as conflicts are detected and
/// resolved.
// ignore: specify_nonobvious_property_types
final unresolvedConflictCountProvider = StreamProvider.autoDispose<int>((ref) {
  return getIt<JournalDb>()
      .watchConflicts(ConflictStatus.unresolved)
      .map((conflicts) => conflicts.length);
});
