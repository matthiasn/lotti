// No direct blur usage; keep imports minimal
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/ui/ai_response_summary.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_widget.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/entry_detail_footer.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/habit_summary.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/entry_detail_header.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/health_summary.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/measurement_summary.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/survey_summary.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/workout_summary.dart';
import 'package:lotti/features/journal/ui/widgets/entry_image_widget.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/modern_journal_card.dart';
import 'package:lotti/features/journal/ui/widgets/tags/tags_list_widget.dart';
import 'package:lotti/features/speech/ui/widgets/audio_player.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_item_wrapper.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_wrapper.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/index.dart';
import 'package:lotti/widgets/events/event_form.dart';

class EntryDetailsWidget extends ConsumerWidget {
  const EntryDetailsWidget({
    required this.itemId,
    required this.showAiEntry,
    super.key,
    this.showTaskDetails = false,
    this.parentTags,
    this.linkedFrom,
    this.link,
    this.isHighlighted = false,
    this.isActiveTimer = false,
  });

  final String itemId;
  final bool showTaskDetails;
  final bool showAiEntry;
  final bool isHighlighted;
  final bool isActiveTimer;

  final JournalEntity? linkedFrom;
  final EntryLink? link;
  final Set<String>? parentTags;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final provider = entryControllerProvider(id: itemId);
    final entryState = ref.watch(provider).value;

    final item = entryState?.entry;
    if (item == null ||
        item.meta.deletedAt != null ||
        (item is AiResponseEntry && !showAiEntry)) {
      return const SizedBox.shrink();
    }

    final isTask = item is Task;
    final isAudio = item is JournalAudio;

    if (isTask && !showTaskDetails) {
      return Padding(
        padding: const EdgeInsets.only(
          left: AppTheme.spacingXSmall,
          right: AppTheme.spacingXSmall,
          bottom: AppTheme.spacingXSmall,
        ),
        child: ModernJournalCard(
          item: item,
          showLinkedDuration: true,
          removeHorizontalMargin: true,
        ),
      );
    }

    const cardMargin = EdgeInsets.only(
      left: AppTheme.spacingXSmall,
      right: AppTheme.spacingXSmall,
      bottom: AppTheme.spacingMedium,
    );

    final card = ModernBaseCard(
      key: isAudio ? Key('$itemId-${item.meta.vectorClock}') : Key(itemId),
      margin: cardMargin,
      padding:
          const EdgeInsets.symmetric(horizontal: AppTheme.cardPaddingCompact),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EntryDetailsContent(
            itemId,
            linkedFrom: linkedFrom,
            parentTags: parentTags,
            link: link,
          ),
        ],
      ),
    );

    // Timer highlight takes precedence (persistent, border-centric glow)
    if (isActiveTimer) {
      final color = context.colorScheme.error;
      return Stack(
        children: [
          card,
          Positioned.fill(
            child: IgnorePointer(
              child: Padding(
                padding: cardMargin,
                child: _PulsingBorder(
                  color: color,
                  radius: AppTheme.cardBorderRadius,
                  strokeWidth: 1,
                  glowSigma: 0,
                  duration: const Duration(milliseconds: 1200),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Scroll highlight (temporary, border-centric; color differs from timer)
    if (isHighlighted) {
      return Stack(
        children: [
          card,
          const Positioned.fill(
            child: IgnorePointer(
              child: Padding(
                padding: cardMargin,
                child: _PulsingBorder(
                  color: Colors.pink,
                  radius: AppTheme.cardBorderRadius,
                  strokeWidth: 1,
                  glowSigma: 0,
                  duration: Duration(milliseconds: 1200),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return card;
  }
}

class _GlowBorderPainter extends CustomPainter {
  _GlowBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.glowSigma,
    required this.devicePixelRatio,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double glowSigma;
  final double devicePixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    // Align to device pixels for crisp corners/edges
    final dpr = devicePixelRatio <= 0 ? 1.0 : devicePixelRatio;
    final alignedWidth = (size.width * dpr).round() / dpr;
    final alignedHeight = (size.height * dpr).round() / dpr;

    // Choose nearest whole-physical-pixel thickness to requested width (min 1px)
    final requestedPx = strokeWidth * dpr;
    final ringPx = requestedPx < 1 ? 1.0 : requestedPx.roundToDouble();
    final ringLogical = ringPx / dpr;

    final outer = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, alignedWidth, alignedHeight),
      Radius.circular(radius),
    );
    final inner = outer.deflate(ringLogical);

    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(outer)
      ..addRRect(inner);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _GlowBorderPainter oldDelegate) {
    return color != oldDelegate.color ||
        radius != oldDelegate.radius ||
        strokeWidth != oldDelegate.strokeWidth ||
        glowSigma != oldDelegate.glowSigma;
  }
}

class _PulsingBorder extends StatefulWidget {
  const _PulsingBorder({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.glowSigma,
    required this.duration,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double glowSigma;
  final Duration duration;

  @override
  State<_PulsingBorder> createState() => _PulsingBorderState();
}

class _PulsingBorderState extends State<_PulsingBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..repeat(reverse: true);

  // Larger amplitude for more pronounced pulse (no blur; opacity only)
  late final Animation<double> _opacity = Tween<double>(begin: 0.4, end: 1)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ??
        View.of(context).devicePixelRatio;
    return FadeTransition(
      opacity: _opacity,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _GlowBorderPainter(
            color: widget.color,
            radius: widget.radius,
            strokeWidth: widget.strokeWidth,
            glowSigma: 0, // sharp edges; no blur
            devicePixelRatio: dpr,
          ),
        ),
      ),
    );
  }
}

class EntryDetailsContent extends ConsumerWidget {
  const EntryDetailsContent(
    this.itemId, {
    this.linkedFrom,
    this.link,
    this.parentTags,
    super.key,
  });

  final String itemId;

  final JournalEntity? linkedFrom;
  final EntryLink? link;

  final Set<String>? parentTags;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final provider = entryControllerProvider(id: itemId);
    final entryState = ref.watch(provider).value;

    final item = entryState?.entry;
    if (item == null || item.meta.deletedAt != null) {
      return const SizedBox.shrink();
    }

    final shouldHideEditor = switch (item) {
      JournalEvent() ||
      QuantitativeEntry() ||
      WorkoutEntry() ||
      Checklist() ||
      ChecklistItem() ||
      AiResponseEntry() =>
        true,
      _ => false,
    };

    final detailSection = switch (item) {
      JournalAudio() => AudioPlayerWidget(item),
      WorkoutEntry() => WorkoutSummary(item),
      SurveyEntry() => SurveySummary(item),
      QuantitativeEntry() => HealthSummary(item),
      MeasurementEntry() => MeasurementSummary(item),
      JournalEvent() => EventForm(item),
      HabitCompletionEntry() => HabitSummary(
          item,
          paddingLeft: 10,
          paddingBottom: 5,
          showIcon: true,
          showText: false,
        ),
      AiResponseEntry() => AiResponseSummary(
          item,
          linkedFromId: linkedFrom?.id,
          fadeOut: true,
        ),
      Checklist() => ChecklistWrapper(
          entryId: item.meta.id,
          taskId: item.data.linkedTasks.first,
        ),
      ChecklistItem() => ChecklistItemWrapper(
          item.id,
          checklistId: '',
          taskId: '',
        ),
      _ => null,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EntryDetailHeader(
          entryId: itemId,
          inLinkedEntries: linkedFrom != null,
          linkedFromId: linkedFrom?.id,
          link: link,
        ),
        TagsListWidget(entryId: itemId, parentTags: parentTags),
        if (item is JournalImage) EntryImageWidget(item),
        if (!shouldHideEditor) EditorWidget(entryId: itemId),
        if (detailSection != null) detailSection,
        EntryDetailFooter(
          entryId: itemId,
          linkedFrom: linkedFrom,
          inLinkedEntries: linkedFrom != null,
        ),
      ],
    );
  }
}
