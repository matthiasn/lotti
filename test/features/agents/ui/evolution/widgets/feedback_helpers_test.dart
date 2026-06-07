import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/feedback_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  group('feedbackCategoryLabel', () {
    testWidgets('maps every category to its localized label', (tester) async {
      await tester.pumpWidget(makeTestableWidgetWithScaffold(const SizedBox()));
      final context = tester.element(find.byType(SizedBox));
      final messages = context.messages;

      // Resolve expectations from the live ARB bundle so the asserts track
      // copy changes instead of inlining English strings.
      final expectedByCategory = {
        FeedbackCategory.accuracy: messages.agentFeedbackCategoryAccuracy,
        FeedbackCategory.communication:
            messages.agentFeedbackCategoryCommunication,
        FeedbackCategory.prioritization:
            messages.agentFeedbackCategoryPrioritization,
        FeedbackCategory.tooling: messages.agentFeedbackCategoryTooling,
        FeedbackCategory.timeliness: messages.agentFeedbackCategoryTimeliness,
        FeedbackCategory.general: messages.agentFeedbackCategoryGeneral,
      };

      // The switch is exhaustive — every enum value must resolve, and the
      // labels must be distinct user-visible strings.
      expect(expectedByCategory.keys, containsAll(FeedbackCategory.values));
      for (final category in FeedbackCategory.values) {
        final label = feedbackCategoryLabel(context, category);
        expect(label, expectedByCategory[category], reason: '$category');
        expect(label, isNotEmpty, reason: '$category');
      }
      expect(
        FeedbackCategory.values
            .map((c) => feedbackCategoryLabel(context, c))
            .toSet(),
        hasLength(FeedbackCategory.values.length),
        reason: 'labels must be distinct',
      );
    });
  });
}
