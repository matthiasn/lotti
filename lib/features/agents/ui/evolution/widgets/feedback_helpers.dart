import 'package:flutter/material.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/gamey/colors.dart';

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

/// Returns the color associated with a [FeedbackCategory].
Color feedbackCategoryColor(FeedbackCategory category) {
  return switch (category) {
    FeedbackCategory.accuracy => GameyColors.primaryBlue,
    FeedbackCategory.communication => GameyColors.aiCyan,
    FeedbackCategory.prioritization => GameyColors.primaryPurple,
    FeedbackCategory.tooling => GameyColors.primaryOrange,
    FeedbackCategory.timeliness => GameyColors.taskYellow,
    FeedbackCategory.general => GameyColors.silverReward,
  };
}

/// Returns the icon associated with a [FeedbackCategory].
IconData feedbackCategoryIcon(FeedbackCategory category) {
  return switch (category) {
    FeedbackCategory.accuracy => Icons.verified_outlined,
    FeedbackCategory.communication => Icons.chat_outlined,
    FeedbackCategory.prioritization => Icons.sort_outlined,
    FeedbackCategory.tooling => Icons.build_outlined,
    FeedbackCategory.timeliness => Icons.schedule_outlined,
    FeedbackCategory.general => Icons.info_outlined,
  };
}

/// Returns the color associated with a [FeedbackSentiment].
Color feedbackSentimentColor(FeedbackSentiment sentiment) {
  return switch (sentiment) {
    FeedbackSentiment.negative => GameyColors.primaryRed,
    FeedbackSentiment.positive => GameyColors.primaryGreen,
    FeedbackSentiment.neutral => GameyColors.primaryOrange,
  };
}
