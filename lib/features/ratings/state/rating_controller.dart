import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/rating_data.dart';
import 'package:lotti/features/ratings/repository/rating_repository.dart';

/// Async controller exposing the current rating for a single target entry.
///
/// Keyed by (targetId, catalogId). The initial state loads any existing
/// [RatingEntry] from the repository; submitRating persists changes and
/// pushes the result back into state so watchers (e.g. the rate button and
/// summary) update immediately without re-querying the database.
final AsyncNotifierProviderFamily<
  RatingController,
  JournalEntity?,
  ({String catalogId, String targetId})
>
_ratingControllerFamily = AsyncNotifierProvider.autoDispose
    .family<
      RatingController,
      JournalEntity?,
      ({String targetId, String catalogId})
    >(
      RatingController.new,
      name: 'ratingControllerProvider',
    );

AsyncNotifierProvider<RatingController, JournalEntity?>
ratingControllerProvider({
  required String targetId,
  String catalogId = 'session',
}) {
  return _ratingControllerFamily((targetId: targetId, catalogId: catalogId));
}

class RatingController extends AsyncNotifier<JournalEntity?> {
  RatingController([
    this._providerArgs = (targetId: '', catalogId: 'session'),
  ]);

  final ({String targetId, String catalogId}) _providerArgs;
  String get targetId => _providerArgs.targetId;
  String get catalogId => _providerArgs.catalogId;

  /// Loads the existing rating for ([targetId], [catalogId]), or `null` when
  /// the target has not been rated with this catalog yet.
  @override
  Future<JournalEntity?> build() async {
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
