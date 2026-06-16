import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

export 'package:lotti/features/projects/ui/widgets/expandable_report_section.dart';
export 'package:lotti/features/projects/ui/widgets/shared_tag_widgets.dart';

/// Bordered card that lays out a [header] above an item list, inserting a
/// divider after the header and between each item built by [itemBuilder].
///
/// The non-sliver counterpart of `ProjectTasksSliverPanel`; used where the
/// panel fits in a regular `Column` rather than a `CustomScrollView`.
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
