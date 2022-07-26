import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/editor_state_service.dart';

class EntryCubit extends Cubit<EntryState> {
  EntryCubit({
    required this.entryId,
    required this.entry,
  }) : super(
          EntryState(
            entryId: entryId,
            dirty: false,
            entry: null,
          ),
        ) {
    debugPrint('EntryCubit $entryId');
  }

  String entryId;
  JournalEntity entry;

  final EditorStateService _editorStateService = getIt<EditorStateService>();

  Future<void> save() async {
    debugPrint('EntryCubit saving $entryId');
  }

  @override
  Future<void> close() async {
    debugPrint('EntryCubit closing $entryId');
    await super.close();
  }
}
