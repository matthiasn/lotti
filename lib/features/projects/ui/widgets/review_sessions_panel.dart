import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_models.dart';
import 'package:lotti/features/projects/ui/widgets/shared_widgets.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// A panel listing review sessions for a project.
class ReviewSessionsPanel extends StatelessWidget {
  const ReviewSessionsPanel({required this.record, super.key});

  final ProjectRecord record;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Container(
      decoration: BoxDecoration(
        color: ShowcasePalette.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ShowcasePalette.border(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          context.messages.projectShowcaseOneOnOneReviewsTab,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tokens.typography.styles.subtitle.subtitle2
                              .copyWith(
                                color: ShowcasePalette.highText(context),
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CountDotBadge(count: record.reviewSessions.length),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  context.messages.projectShowcaseSessionsCount(
                    record.reviewSessions.length,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: ShowcasePalette.mediumText(context),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: ShowcasePalette.border(context),
          ),
          for (
            var index = 0;
            index < record.reviewSessions.length;
            index++
          ) ...[
            ReviewSessionBlock(session: record.reviewSessions[index]),
            if (index < record.reviewSessions.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                color: ShowcasePalette.border(context),
              ),
          ],
        ],
      ),
    );
  }
}

/// A single review session block with summary, stars, and optional expanded
/// metrics.
class ReviewSessionBlock extends StatelessWidget {
  const ReviewSessionBlock({required this.session, super.key});

  final ReviewSession session;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  session.summaryLabel,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: ShowcasePalette.mediumText(context),
                    fontSize: 13,
                  ),
                ),
              ),
              _StarsRow(rating: session.rating, size: 16),
            ],
          ),
        ),
        if (session.expanded)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(8, 0, 8, 0),
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
            color: ShowcasePalette.expandedSurface(context),
            child: Column(
              children: [
                for (final metric in session.metrics)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ReviewMetricRow(metric: metric),
                  ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: ShowcasePalette.border(context),
                ),
                if (session.note case final note?)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      note,
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: ShowcasePalette.mediumText(context),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ReviewMetricRow extends StatelessWidget {
  const _ReviewMetricRow({required this.metric});

  final ReviewMetric metric;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Row(
      children: [
        Expanded(
          child: Text(
            switch (metric.type) {
              ReviewMetricType.communication =>
                context.messages.agentFeedbackCategoryCommunication,
              ReviewMetricType.usefulness =>
                context.messages.projectShowcaseUsefulness,
              ReviewMetricType.accuracy =>
                context.messages.agentFeedbackCategoryAccuracy,
            },
            style: tokens.typography.styles.others.caption.copyWith(
              color: ShowcasePalette.mediumText(context),
            ),
          ),
        ),
        _StarsRow(rating: metric.rating, size: 14),
      ],
    );
  }
}

class _StarsRow extends StatelessWidget {
  const _StarsRow({
    required this.rating,
    required this.size,
  });

  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (index) => Icon(
          index < rating ? Icons.star_rounded : Icons.star_border_rounded,
          size: size,
          color: ShowcasePalette.amber(context),
        ),
      ),
    );
  }
}
