import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';

class FlagsPage extends StatefulWidget {
  const FlagsPage({super.key});

  @override
  State<FlagsPage> createState() => _FlagsPageState();
}

class _FlagsPageState extends State<FlagsPage> {
  final JournalDb _db = getIt<JournalDb>();

  late final Stream<Set<ConfigFlag>> stream = _db.watchConfigFlags();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: TitleAppBar(title: localizations.settingsFlagsTitle),
      backgroundColor: colorConfig().bodyBgColor,
      body: StreamBuilder<Set<ConfigFlag>>(
        stream: stream,
        builder: (
          BuildContext context,
          AsyncSnapshot<Set<ConfigFlag>> snapshot,
        ) {
          final items = snapshot.data?.toList() ?? [];
          debugPrint('$items');

          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            children: List.generate(
              items.length,
              (int index) {
                return ConfigFlagCard(
                  item: items.elementAt(index),
                  index: index,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class ConfigFlagCard extends StatelessWidget {
  ConfigFlagCard({
    super.key,
    required this.item,
    required this.index,
  });

  final JournalDb _db = getIt<JournalDb>();
  final ConfigFlag item;
  final int index;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    String getLocalizedDescription(ConfigFlag flag) {
      switch (flag.name) {
        case privateFlag:
          return localizations.configFlagPrivate;
        case notifyExceptionsFlag:
          return localizations.configFlagNotifyExceptions;
        case hideForScreenshotFlag:
          return localizations.configFlagHideForScreenshot;
        case enableNotificationsFlag:
          return localizations.configFlagEnableNotifications;
        case listenToScreenshotHotkeyFlag:
          return localizations.configFlagGlobalScreenshotHotkey;
        default:
          return item.description;
      }
    }

    return Card(
      color: colorConfig().headerBgColor,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        child: ListTile(
          contentPadding:
              const EdgeInsets.only(left: 16, top: 4, bottom: 8, right: 16),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                getLocalizedDescription(item),
                style: TextStyle(
                  color: colorConfig().entryTextColor,
                  fontFamily: 'Oswald',
                  fontSize: 20,
                ),
              ),
              CupertinoSwitch(
                value: item.status,
                activeColor: colorConfig().private,
                onChanged: (bool status) {
                  _db.upsertConfigFlag(item.copyWith(status: status));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
