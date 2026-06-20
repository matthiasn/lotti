import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/journal/state/save_button_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Save action for an entry, shown in the app bar and the linked-entry footer.
///
/// Watches [SaveButtonController] (which reflects the entry's dirty state) and
/// fades itself in only when there are unsaved changes; pressing it saves the
/// entry through the controller and drops keyboard focus.
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

    // Reveal with a combined grow + fade so the button eases into the layout
    // rather than popping in at full size (the previous fade never played in
    // the footer, which mounted the button fresh only once it was needed). Both
    // hosts — the app bar and the linked-entry footer — keep it mounted, so the
    // transition animates; when there are no unsaved changes it collapses to
    // zero size and reserves no space.
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      alignment: Alignment.centerRight,
      child: AnimatedOpacity(
        curve: Curves.easeInOutQuint,
        opacity: unsaved ? 1 : 0,
        duration: const Duration(milliseconds: 300),
        child: unsaved
            ? DesignSystemButton(
                label: context.messages.saveLabel,
                onPressed: () {
                  ref.read(provider.notifier).save();
                  FocusManager.instance.primaryFocus?.unfocus();
                },
                variant: DesignSystemButtonVariant.dangerTertiary,
                size: DesignSystemButtonSize.large,
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
