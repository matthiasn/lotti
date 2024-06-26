import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/app_bar/task_app_bar.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:lotti/widgets/create/add_actions.dart';
import 'package:lotti/widgets/journal/entry_detail_linked.dart';
import 'package:lotti/widgets/journal/entry_detail_linked_from.dart';
import 'package:lotti/widgets/journal/entry_details_widget.dart';

class EntryDetailPage extends ConsumerWidget {
  const EntryDetailPage({
    required this.itemId,
    super.key,
    this.readOnly = false,
  });

  final String itemId;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: itemId);
    final item = ref.watch(provider).value?.entry;

    if (item == null) {
      return const EmptyScaffoldWithTitle('');
    }

    return Scaffold(
      appBar: item is Task
          ? TaskAppBar(itemId: item.meta.id)
          : const TitleAppBar(title: '') as PreferredSizeWidget,
      floatingActionButton: RadialAddActionButtons(
        linked: item,
        radius: isMobile ? 180 : 120,
        isMacOS: Platform.isMacOS,
        isIOS: Platform.isIOS,
        isAndroid: Platform.isAndroid,
      ).animate().fadeIn(duration: const Duration(milliseconds: 500)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(
          top: 8,
          bottom: 200,
          left: 5,
          right: 5,
        ),
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
        ).animate().fadeIn(
              duration: const Duration(
                milliseconds: 100,
              ),
            ),
      ),
    );
  }
}
