import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';

/// Journal's entry controller behind `skillEntityProvider`: the entry as the
/// controller currently holds it.
JournalEntity? skillEntityFromJournal(Ref ref, String entityId) =>
    ref.watch(entryControllerProvider(entityId)).value?.entry;
