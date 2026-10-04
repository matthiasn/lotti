import 'package:flutter_rating/flutter_rating.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/events/ui/model/event_view_data.dart';
import 'package:lotti/features/events/ui/widgets/event_cover_image.dart';
import 'package:lotti/features/events/ui/widgets/event_overlay_pill.dart';
import 'package:lotti/features/events/ui/widgets/event_photo_gallery.dart';
import 'package:lotti/features/events/ui/widgets/event_status_picker.dart';
import 'package:lotti/features/events/ui/widgets/event_timeline_beat.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/index.dart';
import 'package:lotti/widgets/timeline/timeline_models.dart';
import 'package:lotti/widgets/timeline/timeline_view.dart';
import 'package:material_ui/material_ui.dart';

part 'event_detail_view_hero_content_part.dart';

/// The redesigned event detail surface: a photographic hero header carrying the
/// event's identity (cover, title, when/where, status, rating), followed by an
/// AI summary, a vertical timeline of linked entries, and the associated
/// prep/follow-up tasks. On wide screens the body splits into a main column
/// (summary + timeline) and a tasks rail; on phones it stacks.
///
/// Editing happens inline: the title is tap-to-rename, the category/status pills
/// and the rating open pickers, and each section can add linked entries — so the
/// page never bounces to a separate editor. The empty event still shows its
/// section scaffolding with "add" affordances rather than a blank void. All
/// mutations are surfaced as callbacks; with none wired the view is read-only.
class EventDetailView extends StatelessWidget {
  const EventDetailView({
    required this.data,
    this.onBack,
    this.onRenameTitle,
    this.onTapCategory,
    this.onTapStatus,
    this.onTapDateTime,
    this.onSetRating,
    this.onAddCover,
    this.onChangeCover,
    this.onSetCover,
    this.onDelete,
    this.onRegenerateSummary,
    this.onAddToTimeline,
    this.onAddTask,
    this.onOpenTimelineEntry,
    this.onOpenTask,
    this.aiSummaryCard,
    super.key,
  });

  final EventDetailData data;
  final VoidCallback? onBack;

  /// Inline rename — receives the new (trimmed-by-caller) title.
  final ValueChanged<String>? onRenameTitle;

  /// Opens the category / status / date-time pickers. The rating is set
  /// directly.
  final VoidCallback? onTapCategory;
  final VoidCallback? onTapStatus;
  final VoidCallback? onTapDateTime;
  final ValueChanged<double>? onSetRating;

  /// Adds a cover photo (shown only while the event has no cover).
  final VoidCallback? onAddCover;

  /// Changes the cover photo through the picker: offered in the overflow menu
  /// once the event has a cover, and as a "Set cover" chip on the hero while
  /// that cover is only the automatic default ([EventCardData.coverChosen]
  /// false).
  final VoidCallback? onChangeCover;

  /// Makes the linked photo with this id the cover, from the photo gallery:
  /// the full-screen viewer's "Set cover" pill reports the photo in view,
  /// awaits the write and undoes its optimistic state unless it was stored.
  final Future<bool> Function(String id)? onSetCover;

  /// Deletes the event (offered in the overflow menu).
  final VoidCallback? onDelete;

  final VoidCallback? onRegenerateSummary;
  final VoidCallback? onAddToTimeline;
  final VoidCallback? onAddTask;

  /// Opens a timeline beat's source journal entry. When null, the rows render
  /// as static (and drop the trailing "open" chevron) so the affordance always
  /// matches the actual behavior.
  final ValueChanged<String>? onOpenTimelineEntry;

  /// Opens a linked task's detail page (receives the task id). When null (or a
  /// row has no id) the task rows render as static.
  final ValueChanged<String>? onOpenTask;

  /// Provider-backed AI summary card injected by the page (the event agent's
  /// living recap). When provided it replaces the passive [EventDetailData.summary]
  /// card; when null the view falls back to the passive summary.
  final Widget? aiSummaryCard;

  /// Content cap so the body doesn't sprawl on very wide screens.
  static const double _contentMaxWidth = 1080;

  /// At/above this body width the layout splits into two columns.
  static const double _twoColumnBreakpoint = 900;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Scaffold(
      backgroundColor: dsPageSurface(context),
      body: CustomScrollView(
        slivers: [
          _HeroSliver(
            card: data.card,
            whenLabel: data.whenLabel,
            onBack: onBack,
            onDelete: onDelete,
            onChangeCover: onChangeCover,
            onRenameTitle: onRenameTitle,
            onTapCategory: onTapCategory,
            onTapStatus: onTapStatus,
            onTapDateTime: onTapDateTime,
            onSetRating: onSetRating,
            onAddCover: onAddCover,
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    tokens.spacing.step4,
                    tokens.spacing.step4,
                    tokens.spacing.step4,
                    tokens.spacing.step10,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final twoColumn =
                          constraints.maxWidth >= _twoColumnBreakpoint;
                      return twoColumn
                          ? _twoColumnBody(context)
                          : _oneColumnBody(context);
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _oneColumnBody(BuildContext context) {
    final tokens = context.designTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._mainColumn(context),
        ..._tasksBlock(context),
        SizedBox(height: tokens.spacing.step2),
      ],
    );
  }

  Widget _twoColumnBody(BuildContext context) {
    final tokens = context.designTokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _mainColumn(context),
          ),
        ),
        SizedBox(width: tokens.spacing.step6),
        SizedBox(
          width: 320,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _tasksBlock(context),
          ),
        ),
      ],
    );
  }

  List<Widget> _mainColumn(BuildContext context) {
    return [
      // The date/time lives in the hero now (single source); the body opens
      // straight into the summary + sections. The page injects the agent-backed
      // recap card when events are enabled; otherwise the passive summary shows.
      if (aiSummaryCard != null)
        aiSummaryCard!
      else if (data.summary != null)
        _SummaryCard(summary: data.summary!, onRegenerate: onRegenerateSummary),
      // A flat, scannable photo wall (distinct from the narrative timeline).
      if (data.photos.isNotEmpty) ...[
        _SectionHeader(
          title: context.messages.eventsPhotosSection,
          count: data.photos.length,
          onAdd: onAddToTimeline,
        ),
        EventPhotoGrid(photos: data.photos, onSetCover: onSetCover),
      ],
      _SectionHeader(
        title: context.messages.eventsTimelineSection,
        count: data.timeline.length,
        onAdd: onAddToTimeline,
      ),
      if (data.timeline.isEmpty)
        _EmptyHint(
          label: context.messages.eventsTimelineEmpty,
          onTap: onAddToTimeline,
        )
      else
        TimelineView(
          groups: [
            TimelineGroup(
              beats: [
                for (final entry in data.timeline)
                  eventTimelineBeat(context, entry),
              ],
            ),
          ],
          onOpenBeat: onOpenTimelineEntry,
        ),
    ];
  }

  List<Widget> _tasksBlock(BuildContext context) {
    return [
      _SectionHeader(
        title: context.messages.eventsTasksSection,
        count: data.tasks.length,
        onAdd: onAddTask,
      ),
      if (data.tasks.isEmpty)
        _EmptyHint(
          label: context.messages.eventsTasksEmpty,
          onTap: onAddTask,
        )
      else
        for (final task in data.tasks) _TaskRow(task: task, onOpen: onOpenTask),
    ];
  }
}
