import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/timezone.dart';
import 'package:uuid/uuid.dart';

/// Service responsible for creating and updating journal entry metadata.
///
/// This service handles:
/// - UUID generation (v1 for unique entries, v5 for deterministic deduplication)
/// - Vector clock management via [VectorClockService]
/// - Timezone and UTC offset handling
///
/// By extracting metadata operations into a dedicated service, we improve
/// testability and maintain single responsibility in `PersistenceLogic`.
class MetadataService {
  MetadataService({
    required VectorClockService vectorClockService,
  }) : _vectorClockService = vectorClockService;

  final VectorClockService _vectorClockService;
  final _uuid = const Uuid();

  /// Creates a [Metadata] object with either a random UUID v1 ID or a
  /// deterministic UUID v5 ID.
  ///
  /// If [uuidV5Input] is provided, it will be used as the basis for the UUID v5 ID.
  /// This is useful for deduplicating entries (e.g., health data imports).
  ///
  /// The [dateFrom] and [dateTo] parameters are optional and will default to
  /// the current date and time if not provided. They can differ when importing
  /// photos from the camera roll, for example.
  Future<Metadata> createMetadata({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? uuidV5Input,
    bool? private,
    List<String>? tagIds,
    List<String>? labelIds,
    String? categoryId,
    bool? starred,
    EntryFlag? flag,
  }) async {
    final now = DateTime.now();
    final vc = await _vectorClockService.getNextVectorClock();

    return Metadata(
      createdAt: now,
      updatedAt: now,
      dateFrom: dateFrom ?? now,
      dateTo: dateTo ?? now,
      id: generateId(uuidV5Input: uuidV5Input),
      vectorClock: vc,
      private: private,
      tagIds: tagIds,
      labelIds: labelIds,
      categoryId: categoryId,
      starred: starred,
      timezone: await getLocalTimezone(),
      utcOffset: now.timeZoneOffset.inMinutes,
      flag: flag,
    );
  }

  /// Generates an ID for a journal entry.
  ///
  /// If [uuidV5Input] is provided, returns a deterministic UUID v5 based on the
  /// input string. This prevents inserting the same external entity multiple times.
  ///
  /// If [uuidV5Input] is null, returns a random UUID v1.
  String generateId({String? uuidV5Input}) {
    if (uuidV5Input != null) {
      return _uuid.v5(Namespace.nil.value, uuidV5Input);
    }
    return _uuid.v1();
  }

  /// Updates existing [Metadata] with a new vector clock and optional field changes.
  ///
  /// Always increments the vector clock based on the previous clock.
  /// The `updatedAt` timestamp is set to the current time.
  ///
  /// Use [clearCategoryId] to explicitly clear the category (set to null).
  /// Use [clearLabelIds] to explicitly clear the labels (set to null).
  Future<Metadata> updateMetadata(
    Metadata metadata, {
    DateTime? dateFrom,
    DateTime? dateTo,
    String? categoryId,
    bool clearCategoryId = false,
    DateTime? deletedAt,
    List<String>? labelIds,
    bool clearLabelIds = false,
  }) async =>
      metadata.copyWith(
        updatedAt: DateTime.now(),
        vectorClock: await _vectorClockService.getNextVectorClock(
          previous: metadata.vectorClock,
        ),
        dateFrom: dateFrom ?? metadata.dateFrom,
        dateTo: dateTo ?? metadata.dateTo,
        categoryId: clearCategoryId ? null : categoryId ?? metadata.categoryId,
        deletedAt: deletedAt ?? metadata.deletedAt,
        labelIds: clearLabelIds ? null : labelIds ?? metadata.labelIds,
      );
}
