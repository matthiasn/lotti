import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/app_bar/task_app_bar.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:lotti/widgets/create/add_actions.dart';
import 'package:lotti/widgets/journal/entry_detail_linked.dart';
import 'package:lotti/widgets/journal/entry_detail_linked_from.dart';
import 'package:lotti/widgets/journal/entry_details_widget.dart';

class EntryDetailPage extends StatelessWidget {
  const EntryDetailPage({
    required this.itemId,
    super.key,
    this.readOnly = false,
  });

  final String itemId;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<JournalEntity?>(
      stream: getIt<JournalDb>().watchEntityById(itemId),
      builder: (
        BuildContext context,
        AsyncSnapshot<JournalEntity?> snapshot,
      ) {
        final item = snapshot.data;
        if (item == null) {
          return const EmptyScaffoldWithTitle('');
        }

        return Scaffold(
          appBar: item is Task
              ? TaskAppBar(itemId: item.meta.id)
              : const TitleAppBar(title: '') as PreferredSizeWidget,
          backgroundColor: styleConfig().negspace,
          floatingActionButton: RadialAddActionButtons(
            linked: item,
            radius: isMobile ? 180 : 120,
            isMacOS: Platform.isMacOS,
            isIOS: Platform.isIOS,
            isAndroid: Platform.isAndroid,
          ),
          body: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.only(top: 8, bottom: 96),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                EntryDetailWidget(
                  itemId: itemId,
                  popOnDelete: true,
                  showTaskDetails: true,
                ),
                LinkedEntriesWidget(item: item),
                LinkedFromEntriesWidget(item: item),
              ],
            ),
          ),
        );
      },
    );
  }
}
