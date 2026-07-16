import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/category_color.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';

/// Live task fields needed by Daily OS plan surfaces.
class LiveTaskMetadata {
  /// Creates task metadata.
  const LiveTaskMetadata({
    this.title,
    this.coverArtId,
    this.coverArtCropX = 0.5,
    this.categoryId,
    this.categoryName,
    this.categoryColorHex,
    this.missing = false,
  });

  /// Live task title, if resolved and non-blank.
  final String? title;

  /// Live task cover-art id, if resolved and non-blank.
  final String? coverArtId;

  /// Cover-art crop origin.
  final double coverArtCropX;

  /// Current category assignment from the linked task.
  final String? categoryId;

  /// Current category name, when its definition resolves.
  final String? categoryName;

  /// Current category color, when its definition resolves.
  final String? categoryColorHex;

  /// True once the linked task provider resolved and found no task.
  final bool missing;

  /// Applies the live category fields over a persisted Daily OS snapshot.
  ///
  /// The snapshot supplies a safe visual fallback while a category is absent
  /// or has malformed legacy color data. A changed task assignment still
  /// projects its new id immediately, even before a matching definition is
  /// available locally.
  DayAgentCategory categoryOr(DayAgentCategory fallback) {
    final liveId = categoryId?.trim();
    if (liveId == null || liveId.isEmpty) return fallback;

    final liveName = categoryName?.trim();
    final normalizedColor =
        normalizeCategoryColorHex(categoryColorHex) ?? fallback.colorHex;
    return DayAgentCategory(
      id: liveId,
      name: liveName == null || liveName.isEmpty
          ? (fallback.id == liveId ? fallback.name : liveId)
          : liveName,
      colorHex: normalizedColor,
    );
  }
}

/// Keeps the Daily OS task projection current without constructing the much
/// heavier task-detail controller graph.
///
/// Task notifications cover title, cover art, and category reassignment.
/// Category notifications cover category name/color edits. Both paths refetch
/// the task and its current category directly from the database, avoiding a
/// cache-notification race and making updates visible on the next UI frame.
final FutureProviderFamily<LiveTaskMetadata, String> liveTaskMetadataProvider =
    FutureProvider.autoDispose.family<LiveTaskMetadata, String>((
      ref,
      taskId,
    ) async {
      final db = getIt<JournalDb>();
      final notifications = getIt<UpdateNotifications>();
      final sub = notifications.updateStream.listen((affectedIds) {
        if (affectedIds.contains(taskId) ||
            affectedIds.contains(categoriesNotification)) {
          ref.invalidateSelf();
        }
      });
      ref.onDispose(sub.cancel);

      final entity = await db.journalEntityById(taskId);
      if (entity is! Task) {
        return const LiveTaskMetadata(missing: true);
      }

      final liveTitle = entity.data.title.trim();
      final coverArtId = entity.data.coverArtId?.trim();
      final categoryId = entity.meta.categoryId?.trim();
      CategoryDefinition? category;
      if (categoryId != null && categoryId.isNotEmpty) {
        category = await db.getCategoryById(categoryId);
      }
      return LiveTaskMetadata(
        title: liveTitle.isEmpty ? null : liveTitle,
        coverArtId: coverArtId == null || coverArtId.isEmpty
            ? null
            : coverArtId,
        coverArtCropX: entity.data.coverArtCropX,
        categoryId: categoryId,
        categoryName: category?.name,
        categoryColorHex: category?.color,
      );
    });

/// Watches live task metadata for [rawTaskId].
///
/// Widget tests often render Daily OS cards without a registered journal DB, so
/// this helper preserves the existing no-op behavior when live task resolution
/// is unavailable.
LiveTaskMetadata watchLiveTaskMetadata(WidgetRef ref, String? rawTaskId) {
  final taskId = rawTaskId?.trim();
  if (taskId == null || taskId.isEmpty || !canResolveLiveTaskMetadata()) {
    return const LiveTaskMetadata();
  }

  final value = ref.watch(liveTaskMetadataProvider(taskId));
  return value.value ?? const LiveTaskMetadata();
}

/// Whether the getIt graph can resolve live task rows.
bool canResolveLiveTaskMetadata() {
  return getIt.isRegistered<JournalDb>() &&
      getIt.isRegistered<UpdateNotifications>();
}
