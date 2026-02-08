import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/rating_data.dart';
import 'package:lotti/features/ratings/repository/rating_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'rating_controller.g.dart';

@riverpod
class RatingController extends _$RatingController {
  @override
  Future<JournalEntity?> build({required String timeEntryId}) async {
    return ref
        .read(ratingRepositoryProvider)
        .getRatingForTimeEntry(timeEntryId);
  }

  /// Returns the persisted [RatingEntry], or `null` when persistence fails.
  Future<RatingEntry?> submitRating(
    List<RatingDimension> dimensions, {
    String? note,
  }) async {
    final result =
        await ref.read(ratingRepositoryProvider).createOrUpdateRating(
              timeEntryId: timeEntryId,
              dimensions: dimensions,
              note: note,
            );
    state = AsyncData(result);
    return result;
  }
}
