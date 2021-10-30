import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:wisely/classes/journal_entities.dart';
import 'package:wisely/utils/audio_utils.dart';

part 'journal_entities_cubit.g.dart';

@JsonSerializable()
class JournalEntitiesState {
  Map<String, JournalEntity> journalEntitiesMap = <String, JournalEntity>{};

  JournalEntitiesState();

  JournalEntitiesState.save(
      JournalEntitiesState state, JournalEntity journalEntity) {
    Map<String, JournalEntity> newJournalEntitiesMap =
        Map.from(state.journalEntitiesMap);
    newJournalEntitiesMap[journalEntity.id] = journalEntity;
    newJournalEntitiesMap
        .addEntries([MapEntry(journalEntity.id, journalEntity)]);
    journalEntitiesMap = newJournalEntitiesMap;
  }

  JournalEntitiesState.delete(
      JournalEntitiesState state, JournalEntity journalEntity) {
    Map<String, JournalEntity> newJournalEntitiesMap =
        Map.from(state.journalEntitiesMap);
    newJournalEntitiesMap.remove(journalEntity.id);
    journalEntitiesMap = newJournalEntitiesMap;
  }

  factory JournalEntitiesState.fromJson(Map<String, dynamic> json) =>
      _$JournalEntitiesStateFromJson(json);

  Map<String, dynamic> toJson() => _$JournalEntitiesStateToJson(this);

  @override
  String toString() {
    return 'AudioNotesCubitState ${journalEntitiesMap.values} entries';
  }
}

class JournalEntitiesCubit extends HydratedCubit<JournalEntitiesState> {
  JournalEntitiesCubit() : super(JournalEntitiesState());

  void save(JournalEntity journalEntity) {
    JournalEntitiesState next = JournalEntitiesState.save(state, journalEntity);
    emit(next);
  }

  void delete(JournalEntity journalEntity) {
    JournalEntitiesState next =
        JournalEntitiesState.delete(state, journalEntity);
    journalEntity.map(
      audioNote: (AudioNote audioNote) {
        AudioUtils.moveToTrash(audioNote);
      },
      journalImage: (JournalImage value) {},
      journalEntry: (JournalEntry value) {},
    );
    emit(next);
  }

  @override
  JournalEntitiesState fromJson(Map<String, dynamic> json) =>
      JournalEntitiesState.fromJson(json);

  @override
  Map<String, dynamic> toJson(JournalEntitiesState state) => state.toJson();
}
