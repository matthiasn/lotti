import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/app_bar/task_app_bar.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:lotti/widgets/create/add_actions.dart';
import 'package:lotti/widgets/journal/entry_detail_linked.dart';
import 'package:lotti/widgets/journal/entry_detail_linked_from.dart';
import 'package:lotti/widgets/journal/entry_details_widget.dart';
import 'package:path_provider/path_provider.dart';

class EntryDetailPage extends StatefulWidget {
  const EntryDetailPage({
    super.key,
    required this.itemId,
    this.readOnly = false,
  });

  final String itemId;
  final bool readOnly;

  @override
  State<EntryDetailPage> createState() => _EntryDetailPageState();
}

class _EntryDetailPageState extends State<EntryDetailPage> {
  final JournalDb _db = getIt<JournalDb>();
  bool showDetails = false;

  late final Stream<JournalEntity?> _stream =
      _db.watchEntityById(widget.itemId);

  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();

  Directory? docDir;
  double editorHeight = (Platform.isIOS || Platform.isAndroid) ? 160 : 240;
  double imageTextEditorHeight =
      (Platform.isIOS || Platform.isAndroid) ? 160 : 240;

  @override
  void initState() {
    super.initState();

    getApplicationDocumentsDirectory().then((value) {
      setState(() {
        docDir = value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return StreamBuilder<JournalEntity?>(
      stream: _stream,
      builder: (
        BuildContext context,
        AsyncSnapshot<JournalEntity?> snapshot,
      ) {
        final item = snapshot.data;
        if (item == null) {
          return EmptyScaffoldWithTitle(localizations.entryNotFound);
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
                  itemId: widget.itemId,
                  popOnDelete: true,
                  showTaskDetails: true,
                ),
                LinkedEntriesWidget(itemId: widget.itemId),
                LinkedFromEntriesWidget(item: item),
              ],
            ),
          ),
        );
      },
    );
  }
}
