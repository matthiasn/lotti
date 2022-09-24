import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/journal/entry_details_widget.dart';

class LinkedEntriesWidget extends StatefulWidget {
  const LinkedEntriesWidget({
    super.key,
    this.navigatorKey,
    required this.itemId,
  });

  final GlobalKey? navigatorKey;
  final String itemId;

  @override
  State<LinkedEntriesWidget> createState() => _LinkedEntriesWidgetState();
}

class _LinkedEntriesWidgetState extends State<LinkedEntriesWidget> {
  final JournalDb _db = getIt<JournalDb>();
  late Stream<List<String>> stream;

  @override
  void initState() {
    super.initState();
    stream = _db.watchLinkedEntityIds(widget.itemId);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return StreamBuilder<List<String>>(
      stream: stream,
      builder: (context, itemsSnapshot) {
        if (itemsSnapshot.data == null || itemsSnapshot.data!.isEmpty) {
          return Container();
        } else {
          final itemIds = itemsSnapshot.data!;

          return Column(
            children: [
              Text(
                localizations.journalLinkedEntriesLabel,
                style: TextStyle(
                  color: colorConfig().coal,
                  fontFamily: 'Oswald',
                ),
              ),
              ...List.generate(
                itemIds.length,
                (int index) {
                  final itemId = itemIds.elementAt(index);

                  Future<void> onDismissed(DismissDirection _) async {
                    await _db.removeLink(
                      fromId: widget.itemId,
                      toId: itemId,
                    );
                  }

                  Future<bool> confirmDismiss(DismissDirection _) async {
                    const unlinkKey = 'unlinkKey';
                    final result = await showModalActionSheet<String>(
                      context: context,
                      title: localizations.journalUnlinkQuestion,
                      actions: [
                        SheetAction(
                          icon: Icons.warning,
                          label: localizations.journalUnlinkConfirm,
                          key: unlinkKey,
                          isDestructiveAction: true,
                          isDefaultAction: true,
                        ),
                      ],
                    );

                    return result == unlinkKey;
                  }

                  return Dismissible(
                    key: ValueKey('Dismissible-$itemId'),
                    onDismissed: onDismissed,
                    confirmDismiss: confirmDismiss,
                    background: ColoredBox(
                      color: colorConfig().alarm,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              localizations.journalUnlinkText,
                              style: TextStyle(
                                color: colorConfig().iron,
                                fontFamily: 'Oswald',
                                fontWeight: FontWeight.w300,
                                fontSize: 24,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.link_off,
                              size: 32,
                              color: colorConfig().iron,
                            ),
                          ),
                        ],
                      ),
                    ),
                    child: EntryDetailWidget(
                      itemId: itemId,
                      popOnDelete: false,
                    ),
                  );
                },
              )
            ],
          );
        }
      },
    );
  }
}
