import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_workout_types.dart';

/// The workout activities present in the journal, canonicalised, de-duplicated
/// and sorted: rows imported in the plugin era say `RUNNING` while older and
/// newer rows say `running`, and one activity must appear in the picker once.
/// Canonicalising here loses nothing — the signal reader matches a chosen
/// activity across every stored spelling (`workoutTypeSpellings`).
final FutureProvider<List<String>> workoutTypesProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
      final stored = await getIt<JournalDb>().getWorkoutTypes();
      return stored
          .map(canonicalWorkoutType)
          .where((type) => type.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
    });
