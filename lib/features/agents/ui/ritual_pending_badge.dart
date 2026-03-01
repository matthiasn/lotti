import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/state/ritual_review_providers.dart';
import 'package:lotti/themes/gamey/colors.dart';
import 'package:lotti/themes/theme.dart';

/// Badge wrapper that shows the pending ritual count on its child widget.
///
/// Hidden (passthrough) when count is 0.
class RitualPendingBadge extends ConsumerWidget {
  const RitualPendingBadge({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(
      templatesPendingReviewProvider
          .select((async) => async.value?.length ?? 0),
    );

    return Badge(
      label: Text('$count', style: badgeStyle),
      isLabelVisible: count != 0,
      backgroundColor: GameyColors.primaryPurple,
      child: child,
    );
  }
}
