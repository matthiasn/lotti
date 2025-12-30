import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai_chat/ui/pages/chat_modal_page.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';

class AiChatIcon extends ConsumerWidget {
  const AiChatIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showTasks = ref.watch(journalPageScopeProvider);
    // Get the parent container to share with the modal
    final container = ProviderScope.containerOf(context);

    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: IconButton(
        onPressed: () {
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            barrierColor: Colors.black.withValues(alpha: 0.8),
            builder: (BuildContext modalContext) {
              // Use UncontrolledProviderScope to share the parent container
              // with overrides for the modal-specific scope value
              return UncontrolledProviderScope(
                container: container,
                child: ProviderScope(
                  overrides: [
                    journalPageScopeProvider.overrideWithValue(showTasks),
                  ],
                  child: Material(
                    color: Theme.of(modalContext).colorScheme.surface,
                    child: const ChatModalPage(),
                  ),
                ),
              );
            },
          );
        },
        icon: const Icon(
          Icons.psychology_outlined,
          semanticLabel: 'AI Chat Assistant',
        ),
        tooltip: 'AI Chat Assistant',
      ),
    );
  }
}
