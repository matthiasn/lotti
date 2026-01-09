import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/features/whats_new/model/whats_new_content.dart';

part 'whats_new_state.freezed.dart';

/// UI state for the What's New feature.
@freezed
abstract class WhatsNewState with _$WhatsNewState {
  const factory WhatsNewState({
    /// List of unseen release content, ordered by date descending (newest first).
    @Default([]) List<WhatsNewContent> unseenContent,
  }) = _WhatsNewState;

  const WhatsNewState._();

  /// Whether there is any unseen release content.
  bool get hasUnseenRelease => unseenContent.isNotEmpty;
}
