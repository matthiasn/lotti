import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/state/action_item_suggestions.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/animation/ai_running_animation.dart';
import 'package:lotti/themes/theme.dart';

class ActionItemSuggestionsView extends ConsumerWidget {
  const ActionItemSuggestionsView({
    required this.id,
    super.key,
  });

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      actionItemSuggestionsControllerProvider(id: id),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 240),
      child: Stack(
        children: [
          SingleChildScrollView(
            reverse: true,
            child: Padding(
              padding: const EdgeInsets.only(
                top: 10,
                bottom: 55,
                left: 20,
                right: 20,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 600),
                child: Text(
                  state,
                  style: monospaceTextStyleSmall.copyWith(
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: AiRunningAnimationWrapper(
              entryId: id,
              height: 50,
              responseTypes: const {actionItemSuggestions},
            ),
          ),
        ],
      ),
    );
  }
}
