import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ratings/state/rating_prompt_controller.dart';
import 'package:lotti/features/ratings/ui/session_rating_modal.dart';

/// Listens to [RatingPromptController] and shows the rating modal
/// when a time entry ID becomes available.
///
/// Place this widget high in the widget tree (e.g., in the app scaffold)
/// so it can show the modal regardless of the current navigation state.
class RatingPromptListener extends ConsumerWidget {
  const RatingPromptListener({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<String?>(ratingPromptControllerProvider, (previous, next) {
      if (next != null && previous == null) {
        SessionRatingModal.show(context, next);
      }
    });

    return child;
  }
}
