import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/events/ui/model/event_view_data.dart';
import 'package:lotti/features/events/ui/widgets/event_timeline.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/markdown/agent_markdown_view.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// What one of the event's photos was seen as: the newest analysis of it, in
/// the words the caption under the timeline band was cut from.
class EventPhotoAnalysis {
  const EventPhotoAnalysis({
    required this.photo,
    required this.analysis,
    this.oneLiner,
  });

  /// The photo, as the timeline shows it.
  final EventPhoto photo;

  /// The full analysis, as markdown.
  final String analysis;

  /// Its one-line caption, when the analysis published one.
  final String? oneLiner;
}

/// Opens [analysis] in a sheet over the event page. [onOpenEntry] closes the
/// sheet and opens the photo's own entry — where it can be re-analysed,
/// unlinked or annotated; without it the sheet only reads.
Future<void> showEventPhotoAnalysis({
  required BuildContext context,
  required EventPhotoAnalysis analysis,
  VoidCallback? onOpenEntry,
}) {
  return ModalUtils.showSinglePageModal<void>(
    context: context,
    title: context.messages.eventsPhotoAnalysisTitle,
    builder: (sheetContext) => EventPhotoAnalysisView(
      analysis: analysis,
      onOpenEntry: onOpenEntry == null
          ? null
          : () {
              Navigator.of(sheetContext).pop();
              onOpenEntry();
            },
    ),
  );
}

/// The sheet's body: the photo as its timeline band, the caption, the whole
/// analysis, and the way through to the photo's entry.
class EventPhotoAnalysisView extends StatelessWidget {
  const EventPhotoAnalysisView({
    required this.analysis,
    this.onOpenEntry,
    super.key,
  });

  final EventPhotoAnalysis analysis;
  final VoidCallback? onOpenEntry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final styles = tokens.typography.styles;
    final oneLiner = analysis.oneLiner?.trim();
    final open = onOpenEntry;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        EventTimelinePhotoBand(photo: analysis.photo),
        if (oneLiner != null && oneLiner.isNotEmpty) ...[
          SizedBox(height: tokens.spacing.step4),
          Text(
            oneLiner,
            style: styles.subtitle.subtitle1.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
        ],
        SizedBox(height: tokens.spacing.step4),
        SelectionArea(
          child: AgentMarkdownView(
            analysis.analysis,
            style: styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
        ),
        if (open != null) ...[
          SizedBox(height: tokens.spacing.step5),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: DesignSystemButton(
              label: context.messages.eventsPhotoAnalysisOpenEntry,
              variant: DesignSystemButtonVariant.secondary,
              onPressed: open,
            ),
          ),
        ],
      ],
    );
  }
}
