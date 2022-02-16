import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/misc/app_bar_version.dart';

class FlagsPage extends StatefulWidget {
  const FlagsPage({Key? key}) : super(key: key);

  @override
  State<FlagsPage> createState() => _FlagsPageState();
}

class _FlagsPageState extends State<FlagsPage> {
  final JournalDb _db = getIt<JournalDb>();

  late final Stream<List<ConfigFlag>> stream = _db.watchConfigFlags();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConfigFlag>>(
      stream: stream,
      builder: (
        BuildContext context,
        AsyncSnapshot<List<ConfigFlag>> snapshot,
      ) {
        List<ConfigFlag> items = snapshot.data ?? [];
        debugPrint('$items');

        return Scaffold(
          appBar: const VersionAppBar(title: 'Flags'),
          backgroundColor: AppColors.bodyBgColor,
          body: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(8.0),
            children: List.generate(
              items.length,
              (int index) {
                return ConfigFlagCard(
                  item: items.elementAt(index),
                  index: index,
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class ConfigFlagCard extends StatelessWidget {
  final JournalDb _db = getIt<JournalDb>();

  final ConfigFlag item;
  final int index;

  ConfigFlagCard({
    Key? key,
    required this.item,
    required this.index,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.headerBgColor,
      elevation: 8.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: SingleChildScrollView(
        child: ListTile(
          contentPadding:
              const EdgeInsets.only(left: 16, top: 4, bottom: 8, right: 16),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.description,
                style: TextStyle(
                  color: AppColors.entryTextColor,
                  fontFamily: 'Oswald',
                  fontSize: 20.0,
                ),
              ),
              CupertinoSwitch(
                value: item.status,
                activeColor: AppColors.private,
                onChanged: (bool status) {
                  _db.upsertConfigFlag(item.copyWith(status: status));
                },
              ),
            ],
          ),
          enabled: true,
        ),
      ),
    );
  }
}
