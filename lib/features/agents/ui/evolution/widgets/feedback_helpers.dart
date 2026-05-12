import 'package:flutter/widgets.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Returns the localized label for a [FeedbackCategory].
String feedbackCategoryLabel(BuildContext context, FeedbackCategory category) {
  final messages = context.messages;
  return switch (category) {
    FeedbackCategory.accuracy => messages.agentFeedbackCategoryAccuracy,
    FeedbackCategory.communication =>
      messages.agentFeedbackCategoryCommunication,
    FeedbackCategory.prioritization =>
      messages.agentFeedbackCategoryPrioritization,
    FeedbackCategory.tooling => messages.agentFeedbackCategoryTooling,
    FeedbackCategory.timeliness => messages.agentFeedbackCategoryTimeliness,
    FeedbackCategory.general => messages.agentFeedbackCategoryGeneral,
  };
}
