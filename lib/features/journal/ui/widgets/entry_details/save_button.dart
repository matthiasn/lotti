import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/journal/state/save_button_controller.dart';
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
    final provider = saveButtonControllerProvider(id: entryId);
    final unsaved = ref.watch(provider).value ?? false;

    return AnimatedOpacity(
      curve: Curves.easeInOutQuint,
      opacity: unsaved ? 1 : 0,
      duration: const Duration(milliseconds: 500),
      child: TextButton(
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
      ),
    );
  }
}
