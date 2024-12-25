import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details_widget.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modal_action_sheet.dart';
import 'package:lotti/widgets/modal/modal_sheet_action.dart';

class LinkedEntriesWidget extends StatefulWidget {
  const LinkedEntriesWidget({
    required this.item,
    super.key,
  });

  final JournalEntity item;

  @override
  State<LinkedEntriesWidget> createState() => _LinkedEntriesWidgetState();
}

class _LinkedEntriesWidgetState extends State<LinkedEntriesWidget> {
  bool _includeHidden = false;

  @override
  Widget build(BuildContext context) {
    final db = getIt<JournalDb>();

    return StreamBuilder<List<String>>(
      stream: db.watchLinkedEntityIds(
        widget.item.meta.id,
        includedHidden: _includeHidden,
      ),
      builder: (context, itemsSnapshot) {
        if (itemsSnapshot.data == null || itemsSnapshot.data!.isEmpty) {
          return Container();
        } else {
          final itemIds = itemsSnapshot.data!;

          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    context.messages.journalLinkedEntriesLabel,
                    style: TextStyle(
                      color: context.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(width: 40),
                  Text(
                    // TODO: l10n
                    'hidden:',
                    style: TextStyle(
                      color: context.colorScheme.outline,
                    ),
                  ),
                  // TODO: move to filter bottom sheet, use controller
                  Checkbox(
                    value: _includeHidden,
                    onChanged: (value) {
                      setState(() {
                        _includeHidden = value ?? false;
                      });
                    },
                  ),
                ],
              ),
              ...List.generate(
                itemIds.length,
                (int index) {
                  final itemId = itemIds.elementAt(index);

                  Future<void> unlink() async {
                    const unlinkKey = 'unlinkKey';
                    final result = await showModalActionSheet<String>(
                      context: context,
                      title: context.messages.journalUnlinkQuestion,
                      actions: [
                        ModalSheetAction(
                          icon: Icons.warning,
                          label: context.messages.journalUnlinkConfirm,
                          key: unlinkKey,
                          isDestructiveAction: true,
                          isDefaultAction: true,
                        ),
                      ],
                    );

                    if (result == unlinkKey) {
                      await db.removeLink(
                        fromId: widget.item.meta.id,
                        toId: itemId,
                      );
                    }
                  }

                  return EntryDetailWidget(
                    key: Key('$itemId-$itemId'),
                    itemId: itemId,
                    popOnDelete: false,
                    unlinkFn: unlink,
                    parentTags: widget.item.meta.tagIds?.toSet(),
                    linkedFrom: widget.item,
                  );
                },
              ),
            ],
          );
        }
      },
    );
  }
}
