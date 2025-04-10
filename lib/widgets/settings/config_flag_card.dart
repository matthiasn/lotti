import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/manual/widget/showcase_text_style.dart';
import 'package:lotti/features/manual/widget/showcase_with_widget.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/consts.dart';

class ConfigFlagCard extends StatelessWidget {
  ConfigFlagCard({
    required this.item,
    required this.index,
    GlobalKey? showcaseKey,
    super.key,
  }) : _showcaseKey = showcaseKey;

  final JournalDb _db = getIt<JournalDb>();
  final ConfigFlag item;
  final int index;
  final GlobalKey? _showcaseKey;

  GlobalKey? get showcaseKey => _showcaseKey;

  @override
  Widget build(BuildContext context) {
    String getLocalizedDescription(ConfigFlag flag) {
      switch (flag.name) {
        case privateFlag:
          return context.messages.configFlagPrivate;
        case enableNotificationsFlag:
          return context.messages.configFlagEnableNotifications;
        default:
          return item.description;
      }
    }

    final card = Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                softWrap: true,
                getLocalizedDescription(item),
                style: context.textTheme.bodyLarge,
              ),
            ),
            const SizedBox(width: 10),
            CupertinoSwitch(
              value: item.status,
              activeTrackColor: context.colorScheme.error,
              onChanged: (bool status) {
                _db.upsertConfigFlag(item.copyWith(status: status));
              },
            ),
          ],
        ),
      ),
    );

    if (_showcaseKey != null) {
      return ShowcaseWithWidget(
        showcaseKey: _showcaseKey!,
        description: ShowcaseTextStyle(
          descriptionText: _getShowcaseDescription(context),
        ),
        startNav: item.name == privateFlag,
        endNav: item.name == enableCalendarPageFlag,
        isTooltipTop: item.name == enableCalendarPageFlag ||
            item.name == enableDashboardsPageFlag ||
            item.name == enableHabitsPageFlag,
        child: card,
      );
    }

    return card;
  }

  String _getShowcaseDescription(BuildContext context) {
    switch (item.name) {
      case privateFlag:
        return context.messages.configFlagPrivateDescription;
      case attemptEmbedding:
        return context.messages.configFlagAttemptEmbeddingDescription;
      case autoTranscribeFlag:
        return context.messages.configFlagAutoTranscribeDescription;
      case enableMatrixFlag:
        return context.messages.configFlagEnableMatrixDescription;
      case enableTooltipFlag:
        return context.messages.configFlagEnableTooltipDescription;
      case recordLocationFlag:
        return context.messages.configFlagRecordLocationDescription;
      case resendAttachments:
        return context.messages.configFlagResendAttachmentsDescription;
      case enableLoggingFlag:
        return context.messages.configFlagEnableLoggingDescription;
      case useCloudInferenceFlag:
        return context.messages.configFlagUseCloudInferenceDescription;
      case enableNotificationsFlag:
        return context.messages.configFlagEnableNotificationsDescription;
      case enableAutoTaskTldrFlag:
        return context.messages.configFlagEnableAutoTaskTldrDescription;
      case enableHabitsPageFlag:
        return context.messages.configFlagEnableHabitsPageDescription;
      case enableDashboardsPageFlag:
        return context.messages.configFlagEnableDashboardsPageDescription;
      case enableCalendarPageFlag:
        return context.messages.configFlagEnableCalendarPageDescription;
      default:
        return item.description;
    }
  }
}
