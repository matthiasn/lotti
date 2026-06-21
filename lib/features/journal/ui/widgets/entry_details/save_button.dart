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

    // No unsaved changes → render nothing and reserve NO space. (Keeping the
    // button mounted at zero opacity/size left a wide empty band around the
    // editor.)
    if (!unsaved) return const SizedBox.shrink();

    // Ease the button in (fade + a small upward slide) so it doesn't pop in at
    // full size. TweenAnimationBuilder runs its tween once on mount, so the
    // reveal animates even though the host only builds the button when it is
    // actually needed — no persistent mount, no reserved layout space.
    return TweenAnimationBuilder<double>(
      key: ValueKey('save-button-$entryId'),
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 6 * (1 - t)),
          child: child,
        ),
      ),
      child: DesignSystemButton(
        label: context.messages.saveLabel,
        onPressed: () {
          ref.read(provider.notifier).save();
          FocusManager.instance.primaryFocus?.unfocus();
        },
        variant: DesignSystemButtonVariant.dangerTertiary,
        size: DesignSystemButtonSize.large,
      ),
    );
  }
}
