import 'package:flutter/material.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/ui/agent_palette.dart';
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

/// Returns the color associated with a [FeedbackCategory].
Color feedbackCategoryColor(FeedbackCategory category) {
  return switch (category) {
    FeedbackCategory.accuracy => AgentPalette.blue,
    FeedbackCategory.communication => AgentPalette.cyan,
    FeedbackCategory.prioritization => AgentPalette.purple,
    FeedbackCategory.tooling => AgentPalette.orange,
    FeedbackCategory.timeliness => AgentPalette.yellow,
    FeedbackCategory.general => AgentPalette.silver,
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
    FeedbackSentiment.negative => AgentPalette.red,
    FeedbackSentiment.positive => AgentPalette.green,
    FeedbackSentiment.neutral => AgentPalette.orange,
  };
}
