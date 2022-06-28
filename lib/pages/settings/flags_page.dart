import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/theme/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';

class FlagsPage extends StatefulWidget {
  const FlagsPage({super.key});

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
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: TitleAppBar(title: localizations.settingsFlagsTitle),
      backgroundColor: getIt<ThemeService>().colors.bodyBgColor,
      body: StreamBuilder<List<ConfigFlag>>(
        stream: stream,
        builder: (
          BuildContext context,
          AsyncSnapshot<List<ConfigFlag>> snapshot,
        ) {
          final items = snapshot.data ?? [];
          debugPrint('$items');

          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(8),
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
        case 'private':
          return localizations.configFlagPrivate;
        case 'notify_exceptions':
          return localizations.configFlagNotifyExceptions;
        case 'hide_for_screenshot':
          return localizations.configFlagHideForScreenshot;
        case 'enable_notifications':
          return localizations.configFlagEnableNotifications;
        case 'listen_to_global_screenshot_hotkey':
          return localizations.configFlagGlobalScreenshotHotkey;
        default:
          return item.description;
      }
    }

    return Card(
      color: getIt<ThemeService>().colors.entryCardColor,
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
                style: settingsCardTitleStyle,
              ),
              CupertinoSwitch(
                value: item.status,
                activeColor: getIt<ThemeService>().colors.private,
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
