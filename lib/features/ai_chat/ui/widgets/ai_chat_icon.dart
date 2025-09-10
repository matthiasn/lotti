import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/features/ai_chat/ui/pages/chat_modal_page.dart';

class AiChatIcon extends StatelessWidget {
  const AiChatIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: IconButton(
        onPressed: () {
          // Capture the cubit before showing the modal
          final journalPageCubit = context.read<JournalPageCubit>();

          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            barrierColor: Colors.black.withValues(alpha: 0.8),
            builder: (BuildContext modalContext) {
              return MultiBlocProvider(
                providers: [
                  BlocProvider.value(
                    value: journalPageCubit,
                  ),
                ],
                child: Material(
                  color: Theme.of(modalContext).colorScheme.surface,
                  child: const ChatModalPage(),
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
