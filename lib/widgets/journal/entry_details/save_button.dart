import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

class SaveButton extends ConsumerWidget {
  const SaveButton({
    required this.entryId,
    super.key,
  });

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: entryId);
    final state = ref.watch(provider).value;
    final unsaved = state?.map(
          dirty: (_) => true,
          saved: (_) => false,
        ) ??
        false;

    if (!unsaved) {
      return const SizedBox.shrink();
    }
    return TextButton(
      onPressed: () {
        ref.read(provider.notifier).save();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          context.messages.saveLabel,
          style: saveButtonStyle(Theme.of(context)),
        ),
      ),
    ).animate().fadeIn(duration: const Duration(milliseconds: 500));
  }
}
