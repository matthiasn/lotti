import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/create/add_actions.dart';
import 'package:lotti/widgets/journal/entry_detail_widget.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';

class EntryAppBarTitle extends StatefulWidget {
  final JournalEntity item;
  const EntryAppBarTitle({
    Key? key,
    required this.item,
  }) : super(key: key);

  @override
  _EntryAppBarTitleState createState() => _EntryAppBarTitleState();
}

class _EntryAppBarTitleState extends State<EntryAppBarTitle> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      df.format(widget.item.meta.dateFrom),
      style: TextStyle(
        color: AppColors.entryBgColor,
        fontFamily: 'Oswald',
      ),
    );
  }
}

class EntryDetailRoute extends StatelessWidget {
  const EntryDetailRoute({
    Key? key,
    required this.item,
  }) : super(key: key);

  final JournalEntity item;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bodyBgColor,
      appBar: AppBar(
        backgroundColor: AppColors.headerBgColor,
        foregroundColor: AppColors.appBarFgColor,
      ),
      body: Container(
        color: AppColors.bodyBgColor,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.only(top: 16.0, bottom: 64),
          reverse: true,
          child: EntryDetailWidget(
            item: item,
          ),
        ),
      ),
      floatingActionButton: RadialAddActionButtons(
        linked: item,
        radius: isMobile ? 180 : 120,
      ),
    );
  }
}
