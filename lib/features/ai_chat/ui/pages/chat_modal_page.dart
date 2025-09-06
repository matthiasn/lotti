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
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, state) {
        // Get the selected category ID if only one is selected
        final selectedCategoryIds = state.selectedCategoryIds;
        final categoryId =
            selectedCategoryIds.length == 1 ? selectedCategoryIds.first : null;

        if (categoryId == null) {
          return Center(
            child: Padding(
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
            ),
          );
        }

        // Wrap in a SizedBox to provide bounded constraints
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: ChatInterface(categoryId: categoryId),
        );
      },
    );
  }
}
