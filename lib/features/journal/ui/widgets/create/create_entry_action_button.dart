import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_entry_action_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Floating action button that opens the create-entry menu ([CreateEntryModal])
/// for a standalone entry.
///
/// It floats on the logbook list; on a phone the shell docks the same action
/// on the mobile navigation launcher instead, and an entry's own page creates
/// *linked* entries from its sticky `EntryActionBar`, so this button never
/// creates a linked entry. `categoryId` is forwarded to the modal so an entry
/// created from a single-category feed lands in that category; it is null
/// whenever the feed spans none or several.
class FloatingAddActionButton extends ConsumerWidget {
  const FloatingAddActionButton({
    this.categoryId,
    super.key,
  });

  final String? categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // No launcher clearance: this button only floats on the desktop logbook,
    // where there is no mobile launcher to clear.
    return DesignSystemFloatingActionButton(
      semanticLabel: context.messages.createEntryLabel,
      onPressed: () => CreateEntryModal.show(
        context: context,
        linkedFromId: null,
        categoryId: categoryId,
      ),
    );
  }
}
