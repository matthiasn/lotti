import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/ui/report_content_parser.dart';
import 'package:lotti/features/agents/ui/wake_countdown_state.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/state/project_health_metrics.dart';
import 'package:lotti/features/projects/ui/widgets/project_health_indicator.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_status_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart' show numericBadgeFontFeatures;
import 'package:lotti/utils/markdown_link_utils.dart';

part 'shared_tag_widgets.dart';
part 'expandable_report_section.dart';

class ShowcasePanel extends StatelessWidget {
  const ShowcasePanel({
    required this.header,
    required this.itemCount,
    required this.itemBuilder,
    super.key,
  });

  final Widget header;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Container(
      decoration: BoxDecoration(
        color: ShowcasePalette.surface(context),
        borderRadius: BorderRadius.circular(tokens.radii.sectionCards),
        border: Border.all(color: ShowcasePalette.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.step5,
              tokens.spacing.step2,
              tokens.spacing.step5,
              tokens.spacing.step2,
            ),
            child: header,
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: ShowcasePalette.border(context),
          ),
          if (itemCount > 0) SizedBox(height: tokens.spacing.step2),
          for (var index = 0; index < itemCount; index++) ...[
            itemBuilder(context, index),
            if (index < itemCount - 1) ...[
              SizedBox(height: tokens.spacing.step2),
              Divider(
                height: 1,
                thickness: 1,
                color: ShowcasePalette.border(context),
              ),
              SizedBox(height: tokens.spacing.step2),
            ],
          ],
        ],
      ),
    );
  }
}

/// A centred "no results" message.
class NoResultsPane extends StatelessWidget {
  const NoResultsPane({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Center(
      child: Text(
        context.messages.projectShowcaseNoResults,
        style: tokens.typography.styles.body.bodyMedium.copyWith(
          color: ShowcasePalette.mediumText(context),
        ),
      ),
    );
  }
}

/// A titled text block with an optional trailing label (e.g. "Updated 2h ago").
class TextSection extends StatelessWidget {
  const TextSection({
    required this.title,
    required this.body,
    this.trailingLabel,
    super.key,
  });

  final String title;
  final String body;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 36,
          child: Row(
            children: [
              Text(
                title,
                style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                  color: ShowcasePalette.highText(context),
                ),
              ),
              const Spacer(),
              if (trailingLabel case final trailingLabel?)
                Text(
                  trailingLabel,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: ShowcasePalette.mediumText(context),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: tokens.typography.styles.body.bodyMedium.copyWith(
            color: ShowcasePalette.highText(context),
          ),
        ),
      ],
    );
  }
}
