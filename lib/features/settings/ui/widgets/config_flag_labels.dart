import 'package:flutter/widgets.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/theme/icon_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';

/// Resolves a [ConfigFlag] into a localized (title, subtitle) pair.
///
/// Lives here rather than on a page so the search filter, the Config Flags
/// list and the Sections list all read the same labels — a flag that moves
/// between those surfaces keeps its wording without a second edit.
typedef FlagLabelResolver =
    ({String title, String subtitle}) Function(ConfigFlag flag);

/// The presentation catalog for config flags: one glyph, one localized title
/// and one localized description per flag name.
///
/// Every surface that renders a toggle for a stored [ConfigFlag] goes through
/// here. The raw `ConfigFlag.description` written by `initConfigFlags` is an
/// English developer string and must never reach a user — it survives only as
/// the fallback for a flag this catalog has no entry for, which in practice
/// means a flag no surface lists.
abstract final class ConfigFlagLabels {
  static IconData iconFor(String flagName) {
    switch (flagName) {
      case privateFlag:
        return LottiIcons.lock;
      case enableNotificationsFlag:
        return LottiIcons.notificationActive;
      case recordLocationFlag:
        return LottiIcons.map;
      case enableTooltipFlag:
        return LottiIcons.info;
      case enableAiStreamingFlag:
        return LottiIcons.bolt;
      case enableAiSummaryTtsFlag:
        return LottiIcons.volume;
      case enableQueryChatFlag:
        return LottiIcons.chat;
      case enableLoggingFlag:
        return LottiIcons.bug;
      case enableMatrixFlag:
        return LottiIcons.sync;
      case resendAttachments:
        return LottiIcons.refresh;
      case enableHabitsPageFlag:
        return LottiIcons.repeat;
      case enableDashboardsPageFlag:
        return LottiIcons.dashboard;
      case enableUnifiedGoalsFlag:
        return LottiIcons.focus;
      case enableDailyOsPageFlag:
        return LottiIcons.today;
      case enableEventsFlag:
        return LottiIcons.calendar;
      case enableRelationshipsFlag:
        return LottiIcons.people;
      case enableSessionRatingsFlag:
        return LottiIcons.star;
      case enableProjectsFlag:
        return LottiIcons.folder;
      case enableEmbeddingsFlag:
        return LottiIcons.hub;
      case enableVectorSearchFlag:
        return LottiIcons.search;
      case enableWhatsNewFlag:
        return LottiIcons.verified;
      case dailyOsOnboardingEnabledFlag:
        return LottiIcons.tip;
      case enableForkHealingFlag:
        return LottiIcons.merge;
      default:
        return LottiIcons.settings;
    }
  }

  static String titleFor(BuildContext context, ConfigFlag flag) {
    switch (flag.name) {
      case privateFlag:
        return context.messages.configFlagPrivate;
      case enableNotificationsFlag:
        return context.messages.configFlagEnableNotifications;
      case recordLocationFlag:
        return context.messages.configFlagRecordLocation;
      case enableTooltipFlag:
        return context.messages.configFlagEnableTooltip;
      case enableAiStreamingFlag:
        return context.messages.configFlagEnableAiStreaming;
      case enableAiSummaryTtsFlag:
        return context.messages.configFlagEnableAiSummaryTts;
      case enableQueryChatFlag:
        return context.messages.configFlagEnableQueryChat;
      case enableLoggingFlag:
        return context.messages.configFlagEnableLogging;
      case enableMatrixFlag:
        return context.messages.configFlagEnableMatrix;
      case resendAttachments:
        return context.messages.configFlagResendAttachments;
      case enableHabitsPageFlag:
        return context.messages.configFlagEnableHabitsPage;
      case enableDashboardsPageFlag:
        return context.messages.configFlagEnableDashboardsPage;
      case enableUnifiedGoalsFlag:
        return context.messages.configFlagEnableUnifiedGoals;
      case enableDailyOsPageFlag:
        return context.messages.configFlagEnableDailyOs;
      case enableEventsFlag:
        return context.messages.configFlagEnableEvents;
      case enableRelationshipsFlag:
        return context.messages.configFlagEnableRelationships;
      case enableSessionRatingsFlag:
        return context.messages.configFlagEnableSessionRatings;
      case enableProjectsFlag:
        return context.messages.configFlagEnableProjects;
      case enableEmbeddingsFlag:
        return context.messages.configFlagEnableEmbeddings;
      case enableVectorSearchFlag:
        return context.messages.configFlagEnableVectorSearch;
      case enableWhatsNewFlag:
        return context.messages.configFlagEnableWhatsNew;
      case dailyOsOnboardingEnabledFlag:
        return context.messages.configFlagDailyOsOnboardingEnabled;
      case enableForkHealingFlag:
        return context.messages.configFlagEnableForkHealing;
      default:
        return flag.name;
    }
  }

  static String subtitleFor(BuildContext context, ConfigFlag flag) {
    switch (flag.name) {
      case privateFlag:
        return context.messages.configFlagPrivateDescription;
      case enableNotificationsFlag:
        return context.messages.configFlagEnableNotificationsDescription;
      case recordLocationFlag:
        return context.messages.configFlagRecordLocationDescription;
      case enableTooltipFlag:
        return context.messages.configFlagEnableTooltipDescription;
      case enableAiStreamingFlag:
        return context.messages.configFlagEnableAiStreamingDescription;
      case enableAiSummaryTtsFlag:
        return context.messages.configFlagEnableAiSummaryTtsDescription;
      case enableQueryChatFlag:
        return context.messages.configFlagEnableQueryChatDescription;
      case enableLoggingFlag:
        return context.messages.configFlagEnableLoggingDescription;
      case enableMatrixFlag:
        return context.messages.configFlagEnableMatrixDescription;
      case resendAttachments:
        return context.messages.configFlagResendAttachmentsDescription;
      case enableHabitsPageFlag:
        return context.messages.configFlagEnableHabitsPageDescription;
      case enableDashboardsPageFlag:
        return context.messages.configFlagEnableDashboardsPageDescription;
      case enableUnifiedGoalsFlag:
        return context.messages.configFlagEnableUnifiedGoalsDescription;
      case enableDailyOsPageFlag:
        return context.messages.configFlagEnableDailyOsDescription;
      case enableEventsFlag:
        return context.messages.configFlagEnableEventsDescription;
      case enableRelationshipsFlag:
        return context.messages.configFlagEnableRelationshipsDescription;
      case enableSessionRatingsFlag:
        return context.messages.configFlagEnableSessionRatingsDescription;
      case enableProjectsFlag:
        return context.messages.configFlagEnableProjectsDescription;
      case enableEmbeddingsFlag:
        return context.messages.configFlagAttemptEmbeddingDescription;
      case enableVectorSearchFlag:
        return context.messages.configFlagEnableVectorSearchDescription;
      case enableWhatsNewFlag:
        return context.messages.configFlagEnableWhatsNewDescription;
      case dailyOsOnboardingEnabledFlag:
        return context.messages.configFlagDailyOsOnboardingEnabledDescription;
      case enableForkHealingFlag:
        return context.messages.configFlagEnableForkHealingDescription;
      default:
        return flag.description;
    }
  }

  /// The resolver [FlagLabelResolver] callers pass to the search filter and
  /// the row builders — one closure over the active locale's catalog.
  static FlagLabelResolver resolverFor(BuildContext context) =>
      (flag) => (
        title: titleFor(context, flag),
        subtitle: subtitleFor(context, flag),
      );
}
