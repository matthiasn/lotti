import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/rating_data.dart';
import 'package:lotti/features/ratings/repository/rating_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'rating_controller.g.dart';

/// Async controller exposing the current rating for a single target entry.
///
/// Keyed by ([targetId], [catalogId]). The initial state loads any existing
/// [RatingEntry] from the repository; [submitRating] persists changes and
/// pushes the result back into state so watchers (e.g. the rate button and
/// summary) update immediately without re-querying the database.
@riverpod
class RatingController extends _$RatingController {
  /// Loads the existing rating for ([targetId], [catalogId]), or `null` when
  /// the target has not been rated with this catalog yet.
  @override
  Future<JournalEntity?> build({
    required String targetId,
    String catalogId = 'session',
  }) async {
    return ref
        .read(ratingRepositoryProvider)
        .getRatingForTargetEntry(
          targetId,
          catalogId: catalogId,
        );
  }

  /// Persists [dimensions] (and optional [note]) via the repository and
  /// updates state with the result. Returns the persisted [RatingEntry], or
  /// `null` when persistence fails (state is still set to the `null` result).
  Future<RatingEntry?> submitRating(
    List<RatingDimension> dimensions, {
    String? note,
  }) async {
    final result = await ref
        .read(ratingRepositoryProvider)
        .createOrUpdateRating(
          targetId: targetId,
          dimensions: dimensions,
          catalogId: catalogId,
          note: note,
        );
    state = AsyncData(result);
    return result;
  }
}
