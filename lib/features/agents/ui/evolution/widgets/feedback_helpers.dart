import 'package:flutter/material.dart';
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

/// Returns the color associated with a [FeedbackCategory].
Color feedbackCategoryColor(FeedbackCategory category) {
  return switch (category) {
    FeedbackCategory.accuracy => const Color(0xFF1CB0F6),
    FeedbackCategory.communication => const Color(0xFF00BCD4),
    FeedbackCategory.prioritization => const Color(0xFF6B4CE5),
    FeedbackCategory.tooling => const Color(0xFFFF9600),
    FeedbackCategory.timeliness => const Color(0xFFFFD93D),
    FeedbackCategory.general => const Color(0xFFC0C0C0),
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
    FeedbackSentiment.negative => const Color(0xFFFF4B4B),
    FeedbackSentiment.positive => const Color(0xFF58CC02),
    FeedbackSentiment.neutral => const Color(0xFFFF9600),
  };
}
