import 'package:flutter/material.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_entry_action_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class FloatingAddActionButton extends StatelessWidget {
  const FloatingAddActionButton({
    this.linkedFromId,
    this.categoryId,
    super.key,
  });

  final String? linkedFromId;
  final String? categoryId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(5),
      child: FloatingActionButton(
        onPressed: () => CreateEntryModal.show(
          context: context,
          linkedFromId: linkedFromId,
          categoryId: categoryId,
        ),
        child: Icon(
          Icons.add_rounded,
          semanticLabel: context.messages.createEntryLabel,
        ),
      ),
    );
  }
}
