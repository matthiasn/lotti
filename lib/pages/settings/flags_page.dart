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
  final GlobalKey<State<StatefulWidget>> _privateFlagKey = GlobalKey();
  final GlobalKey<State<StatefulWidget>> _enableMatrixFlagKey = GlobalKey();
  final GlobalKey<State<StatefulWidget>> _enableTooltipFlagKey = GlobalKey();
  final GlobalKey<State<StatefulWidget>> _recordLocationFlagKey = GlobalKey();
  final GlobalKey<State<StatefulWidget>> _resendAttachmentsFlagKey =
      GlobalKey();
  final GlobalKey<State<StatefulWidget>> _enableLoggingFlagKey = GlobalKey();
  final GlobalKey<State<StatefulWidget>> _enableNotificationFlagKey =
      GlobalKey();

  final GlobalKey<State<StatefulWidget>> _enableHabitsPageFlagKey = GlobalKey();
  final GlobalKey<State<StatefulWidget>> _enableDashboardsPageFlagKey =
      GlobalKey();
  final GlobalKey<State<StatefulWidget>> _enableCalendarPageFlagKey =
      GlobalKey();

  static const List<String> displayedItems = [
    privateFlag,
    enableNotificationsFlag,
    recordLocationFlag,
    enableTooltipFlag,
    enableLoggingFlag,
    enableMatrixFlag,
    resendAttachments,
    enableHabitsPageFlag,
    enableDashboardsPageFlag,
    enableCalendarPageFlag,
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Set<ConfigFlag>>(
      stream: getIt<JournalDb>().watchConfigFlags(),
      builder: (
        BuildContext context,
        AsyncSnapshot<Set<ConfigFlag>> snapshot,
      ) {
        final flagLookup = <String, ConfigFlag>{
          for (final ConfigFlag flag in snapshot.data ?? {}) flag.name: flag,
        };

        final orderedFlags =
            displayedItems.map((name) => flagLookup[name]).nonNulls.toList();

        return SliverBoxAdapterShowcasePage(
          showcaseIcon: IconButton(
            onPressed: () {
              ShowCaseWidget.of(context).startShowCase([
                _privateFlagKey,
                _enableNotificationFlagKey,
                _recordLocationFlagKey,
                _enableTooltipFlagKey,
                _enableLoggingFlagKey,
                _enableMatrixFlagKey,
                _resendAttachmentsFlagKey,
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
          child: SingleChildScrollView(
            child: Column(
              children: [
                ...orderedFlags.mapIndexed(
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
      case enableNotificationsFlag:
        return _enableNotificationFlagKey;
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
