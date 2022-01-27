import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/create/add_actions.dart';
import 'package:lotti/widgets/journal/entry_detail_footer.dart';
import 'package:lotti/widgets/journal/entry_detail_widget.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:lotti/widgets/journal/tags_widget.dart';

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
    required this.index,
  }) : super(key: key);

  final int index;
  final JournalEntity item;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bodyBgColor,
      appBar: AppBar(
        toolbarHeight: 160,
        title: Column(
          children: [
            TagsWidget(item: item),
            EntryInfoRow(entityId: item.meta.id),
          ],
        ),
        backgroundColor: AppColors.bodyBgColor,
      ),
      body: Container(
        color: AppColors.bodyBgColor,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          reverse: true,
          child: EntryDetailWidget(
            item: item,
          ),
        ),
      ),
      floatingActionButton: RadialAddActionButtons(
        linked: item,
        radius: 120,
      ),
    );
  }
}
