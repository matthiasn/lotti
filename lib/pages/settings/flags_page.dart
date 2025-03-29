import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/pages/settings/sliver_box_adapter_page.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/widgets/settings/config_flag_card.dart';

class FlagsPage extends StatelessWidget {
  const FlagsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Set<ConfigFlag>>(
      stream: getIt<JournalDb>().watchConfigFlags(),
      builder: (
        BuildContext context,
        AsyncSnapshot<Set<ConfigFlag>> snapshot,
      ) {
        final items = snapshot.data?.toList() ?? [];

        const displayedItems = {
          enableHabitsPageFlag,
          enableDashboardsPageFlag,
          enableCalendarPageFlag,
          privateFlag,
          attemptEmbedding,
          enableNotificationsFlag,
          autoTranscribeFlag,
          recordLocationFlag,
          allowInvalidCertFlag,
          enableTooltipFlag,
          enableLoggingFlag,
          enableMatrixFlag,
          resendAttachments,
          useCloudInferenceFlag,
          enableAutoTaskTldrFlag,
        };

        final filteredItems =
            items.where((flag) => displayedItems.contains(flag.name));

        return SliverBoxAdapterPage(
          title: context.messages.settingsFlagsTitle,
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
