import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/tasks/state/task_live_data_provider.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';

/// Live task fields needed by Daily OS plan surfaces.
class LiveTaskMetadata {
  /// Creates task metadata.
  const LiveTaskMetadata({
    this.title,
    this.coverArtId,
    this.coverArtCropX = 0.5,
    this.missing = false,
  });

  /// Live task title, if resolved and non-blank.
  final String? title;

  /// Live task cover-art id, if resolved and non-blank.
  final String? coverArtId;

  /// Cover-art crop origin.
  final double coverArtCropX;

  /// True once the linked task provider resolved and found no task.
  final bool missing;
}

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

  final value = ref.watch(taskLiveDataProvider(taskId));
  final task = value.value;
  final liveTitle = task?.data.title.trim();
  final coverArtId = task?.data.coverArtId?.trim();
  return LiveTaskMetadata(
    title: liveTitle == null || liveTitle.isEmpty ? null : liveTitle,
    coverArtId: coverArtId == null || coverArtId.isEmpty ? null : coverArtId,
    coverArtCropX: task?.data.coverArtCropX ?? 0.5,
    missing: value.hasValue && task == null,
  );
}

/// Whether the getIt graph can resolve live task rows.
bool canResolveLiveTaskMetadata() {
  return getIt.isRegistered<JournalDb>() &&
      getIt.isRegistered<UpdateNotifications>();
}
