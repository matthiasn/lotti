import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_entry_action_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/gamey/gamey_fab.dart';

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
    return Padding(
      padding: const EdgeInsets.all(5),
      child: GameyFab(
        onPressed: () => CreateEntryModal.show(
          context: context,
          linkedFromId: linkedFromId,
          categoryId: categoryId,
        ),
        semanticLabel: context.messages.createEntryLabel,
        child: Icon(
          Icons.add_rounded,
          semanticLabel: context.messages.createEntryLabel,
        ),
      ),
    );
  }
}
