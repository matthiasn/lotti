import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_entry_action_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

/// Floating action button that opens the create-entry menu ([CreateEntryModal]).
///
/// `linkedFromId` and `categoryId` are forwarded to the modal so anything
/// created from a task/entry detail page is linked to and categorized like its
/// host; both are null on the standalone journal list.
class FloatingAddActionButton extends ConsumerWidget {
  const FloatingAddActionButton({
    this.linkedFromId,
    this.categoryId,
    super.key,
  });

  final String? linkedFromId;
  final String? categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DesignSystemBottomNavigationFabPadding(
      child: DesignSystemFloatingActionButton(
        semanticLabel: context.messages.createEntryLabel,
        onPressed: () => CreateEntryModal.show(
          context: context,
          linkedFromId: linkedFromId,
          categoryId: categoryId,
        ),
      ),
    );
  }
}
