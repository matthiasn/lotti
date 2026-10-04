import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/journal_entities.dart';

/// The entity the AI skills menu is opened on: null while it loads, or when
/// there is none.
///
/// Null until the composition root wires journal's entry controller
/// (`skillEntityFromJournal`); the AI feature does not depend on journal.
final ProviderFamily<JournalEntity?, String> skillEntityProvider = Provider
    .autoDispose
    .family<JournalEntity?, String>(
      (ref, entityId) => null,
      name: 'skillEntityProvider',
    );
