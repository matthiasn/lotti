import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface.dart';

class ChatModalPage extends ConsumerWidget {
  const ChatModalPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, state) {
        // Get the selected category ID if only one is selected
        final selectedCategoryIds = state.selectedCategoryIds;
        final categoryId =
            selectedCategoryIds.length == 1 ? selectedCategoryIds.first : null;

        Widget innerContent;
        if (categoryId == null) {
          innerContent = Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.category_outlined,
                  size: 64,
                  color: Theme.of(context).disabledColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'Please select a single category',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'The AI assistant needs a specific category context to help you with tasks',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).disabledColor,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        } else {
          innerContent = ChatInterface(categoryId: categoryId);
        }

        final panel = Material(
          elevation: 12,
          shadowColor: Colors.black.withValues(alpha: 0.5),
          color: theme.colorScheme.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant,
              width: 1.2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 880,
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ),
                child: innerContent,
              ),
            ),
          ),
        );

        // Provide the bottom sheet with finite height; center the panel.
        final sheetHeight = MediaQuery.of(context).size.height * 0.85;
        return SizedBox(
          height: sheetHeight,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: panel,
            ),
          ),
        );
      },
    );
  }
}
