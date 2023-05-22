import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/settings/sliver_box_adapter_page.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/widgets/settings/config_flag_card.dart';

class FlagsPage extends StatelessWidget {
  const FlagsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return StreamBuilder<Set<ConfigFlag>>(
      stream: getIt<JournalDb>().watchConfigFlags(),
      builder: (
        BuildContext context,
        AsyncSnapshot<Set<ConfigFlag>> snapshot,
      ) {
        final items = snapshot.data?.toList() ?? [];

        const displayedItems = {
          privateFlag,
          enableNotificationsFlag,
          showBrightSchemeFlag,
          recordLocationFlag,
          enableSyncFlag,
          enableTaskManagement,
          allowInvalidCertFlag,
        };

        final filteredItems =
            items.where((flag) => displayedItems.contains(flag.name));

        return SliverBoxAdapterPage(
          title: localizations.settingsFlagsTitle,
          showBackButton: true,
          child: Column(
            children: [
              ...filteredItems.mapIndexed(
                (index, flag) => ConfigFlagCard(
                  item: flag,
                  index: index,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
