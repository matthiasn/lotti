import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/consts.dart';

class ConfigFlagCard extends StatelessWidget {
  ConfigFlagCard({
    required this.item,
    required this.index,
    super.key,
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
        case enableNotificationsFlag:
          return localizations.configFlagEnableNotifications;
        default:
          return item.description;
      }
    }

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.only(
          left: 24,
          top: 4,
          bottom: 8,
          right: 24,
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                softWrap: true,
                getLocalizedDescription(item),
                style: settingsCardTextStyle(),
              ),
            ),
            const SizedBox(width: 8),
            CupertinoSwitch(
              value: item.status,
              activeColor: styleConfig().private,
              onChanged: (bool status) {
                _db.upsertConfigFlag(item.copyWith(status: status));
              },
            ),
          ],
        ),
      ),
    );
  }
}
