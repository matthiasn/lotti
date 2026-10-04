import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

/// How many of a checklist's items are done, out of how many.
typedef JournalChecklistCounts = ({int completedCount, int totalCount});

/// A checklist's completion, for its journal card. Null until the
/// composition root wires the tasks feature's completion counts; journal does
/// not depend on tasks.
final FutureProviderFamily<JournalChecklistCounts?, String>
journalChecklistCountsProvider = FutureProvider.autoDispose
    .family<JournalChecklistCounts?, String>(
      (ref, checklistId) async => null,
      name: 'journalChecklistCountsProvider',
    );

/// The person a check-in is with, by name, for its journal card. Null until
/// the composition root wires the relationships feature's name lookup.
final FutureProviderFamily<String?, String> journalRelationshipNameProvider =
    FutureProvider.autoDispose.family<String?, String>(
      (ref, relationshipId) async => null,
      name: 'journalRelationshipNameProvider',
    );
