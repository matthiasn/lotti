import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/pages/settings/sliver_box_adapter_page.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/widgets/settings/config_flag_card.dart';
import 'package:showcaseview/showcaseview.dart';

class FlagsPage extends StatefulWidget {
  const FlagsPage({super.key});

  @override
  State<FlagsPage> createState() => _FlagsPageState();
}

class _FlagsPageState extends State<FlagsPage> {
  final _privateFlagKey = GlobalKey();
  final _embeddingFlagKey = GlobalKey();
  final _autoTranscribeFlagKey = GlobalKey();
  final _enableMatrixFlagKey = GlobalKey();
  final _enableTooltipFlagKey = GlobalKey();
  final _recordLocationFlagKey = GlobalKey();
  final _resendAttachmentsFlagKey = GlobalKey();
  final _enableLoggingFlagKey = GlobalKey();
  final _useCloudInferenceFlagKey = GlobalKey();
  final _enableNotificationFlagKey = GlobalKey();
  final _enableAutoTaskTldrFlagKey = GlobalKey();

  final _enableHabitsPageFlagKey = GlobalKey();
  final _enableDashboardsPageFlagKey = GlobalKey();
  final _enableCalendarPageFlagKey = GlobalKey();

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
          enableTooltipFlag,
          enableLoggingFlag,
          enableMatrixFlag,
          resendAttachments,
          useCloudInferenceFlag,
          enableAutoTaskTldrFlag,
        };

        final filteredItems =
            items.where((flag) => displayedItems.contains(flag.name)).toList();

        return ShowCaseWidget(
          builder: (context) => SliverBoxAdapterShowcasePage(
            showcaseIcon: IconButton(
              onPressed: () {
                ShowCaseWidget.of(context).startShowCase([
                  _privateFlagKey,
                  _embeddingFlagKey,
                  _autoTranscribeFlagKey,
                  _enableMatrixFlagKey,
                  _enableTooltipFlagKey,
                  _recordLocationFlagKey,
                  _resendAttachmentsFlagKey,
                  _enableLoggingFlagKey,
                  _useCloudInferenceFlagKey,
                  _enableNotificationFlagKey,
                  _enableAutoTaskTldrFlagKey,
                  _enableHabitsPageFlagKey,
                  _enableDashboardsPageFlagKey,
                  _enableCalendarPageFlagKey,
                ]);
              },
              icon: const Icon(
                Icons.info_outline_rounded,
              ),
            ),
            title: context.messages.settingsFlagsTitle,
            showBackButton: true,
            child: Column(
              children: [
                ...filteredItems.mapIndexed(
                  (index, flag) => ConfigFlagCard(
                    item: flag,
                    index: index,
                    showcaseKey: _getShowcaseKeyForFlag(flag.name),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  GlobalKey? _getShowcaseKeyForFlag(String flagName) {
    switch (flagName) {
      case privateFlag:
        return _privateFlagKey;
      case attemptEmbedding:
        return _embeddingFlagKey;
      case autoTranscribeFlag:
        return _autoTranscribeFlagKey;
      case enableMatrixFlag:
        return _enableMatrixFlagKey;
      case enableTooltipFlag:
        return _enableTooltipFlagKey;
      case recordLocationFlag:
        return _recordLocationFlagKey;
      case resendAttachments:
        return _resendAttachmentsFlagKey;
      case enableLoggingFlag:
        return _enableLoggingFlagKey;
      case useCloudInferenceFlag:
        return _useCloudInferenceFlagKey;
      case enableNotificationsFlag:
        return _enableNotificationFlagKey;
      case enableAutoTaskTldrFlag:
        return _enableAutoTaskTldrFlagKey;
      case enableHabitsPageFlag:
        return _enableHabitsPageFlagKey;
      case enableDashboardsPageFlag:
        return _enableDashboardsPageFlagKey;
      case enableCalendarPageFlag:
        return _enableCalendarPageFlagKey;

      default:
        return null;
    }
  }
}
