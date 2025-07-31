import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/journal/state/save_button_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/buttons/lotti_tertiary_button.dart';

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
      child: LottiTertiaryButton(
        onPressed: () {
          ref.read(provider.notifier).save();
          FocusManager.instance.primaryFocus?.unfocus();
        },
        label: context.messages.saveLabel,
      ),
    );
  }
}
