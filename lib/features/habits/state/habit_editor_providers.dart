import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';

/// The workout types actually present in the journal — imported strings are
/// not normalised, so the picker offers what exists rather than a fixed list.
final FutureProvider<List<String>> workoutTypesProvider =
    FutureProvider.autoDispose<List<String>>(
      (ref) => getIt<JournalDb>().getWorkoutTypes(),
    );
