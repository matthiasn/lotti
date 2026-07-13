import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_showcase_mobile_detail_header.dart';
import 'package:lotti/features/design_system/components/scrollbars/design_system_scrollbar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_models.dart';
import 'package:lotti/features/projects/ui/widgets/health_panel.dart';
import 'package:lotti/features/projects/ui/widgets/project_tasks_panel.dart';
import 'package:lotti/features/projects/ui/widgets/shared_widgets.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_status_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/color.dart';

/// The scrollable body of the read-first project detail surface (used on
/// mobile and in the desktop right pane).
///
/// Lays out, top to bottom: a header (title + status pill + category/target-date
/// meta tags that double as edit affordances when their `on*Tap` callbacks are
/// supplied), the [HealthPanel], the agent [ExpandableReportSection] (with
/// refresh / cancel-scheduled-wake controls and a live countdown), and the
/// [ProjectTasksSliverPanel]. The optional `on*Tap` callbacks let the host page
/// open pickers and trigger immediate saves; with them omitted it renders as a
/// pure read-only showcase. [currentTime] feeds the report's relative "updated
/// X ago" label.
class ProjectMobileDetailContent extends StatefulWidget {
  const ProjectMobileDetailContent({
    required this.record,
    required this.currentTime,
    this.onBack,
    this.onCategoryTap,
    this.onTargetDateTap,
    this.onStatusTap,
    this.onRefreshReport,
    this.onCancelScheduledReportWake,
    this.isRefreshingReport = false,
    this.onTaskTap,
    super.key,
  });

  final ProjectRecord record;
  final DateTime currentTime;
  final VoidCallback? onBack;
  final VoidCallback? onCategoryTap;
  final VoidCallback? onTargetDateTap;
  final VoidCallback? onStatusTap;
  final VoidCallback? onRefreshReport;
  final VoidCallback? onCancelScheduledReportWake;
  final bool isRefreshingReport;
  final ValueChanged<TaskSummary>? onTaskTap;

  @override
  State<ProjectMobileDetailContent> createState() =>
      _ProjectMobileDetailContentState();
}

/// Minimum content width at which the detail pane splits into a left
/// state-rail (health + AI next-steps) beside the task list, instead of a
/// single phone column stretched across a wide pane.
const _kDetailWideBreakpoint = 720.0;

/// Width of the desktop left state-rail (health + AI "what next") — the
/// primary "what's going on / what next" column, so it isn't out-massed by the
/// task backlog.
const _kDetailRailWidth = 440.0;

/// Max width for the desktop task column so two-zone rows keep a readable
/// measure instead of splaying title and status to opposite edges of a wide
/// pane.
const _kDetailTaskColumnMaxWidth = 640.0;

class _ProjectMobileDetailContentState
    extends State<ProjectMobileDetailContent> {
  late final ScrollController _scrollController = ScrollController();
  late final ScrollController _railScrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    _railScrollController.dispose();
    super.dispose();
  }

  Color get _categoryColor => colorFromCssHex(
    widget.record.category?.color ?? defaultCategoryColorHex,
  );

  Widget _healthPanel() =>
      HealthPanel(record: widget.record, categoryColor: _categoryColor);

  Widget _aiReportCard() => _AiReportCard(
    record: widget.record,
    currentTime: widget.currentTime,
    onRefresh: widget.onRefreshReport,
    onCancelScheduledWake: widget.onCancelScheduledReportWake,
    isRefreshing: widget.isRefreshingReport,
  );

  Widget _header() => _ProjectMobileHeader(
    record: widget.record,
    categoryColor: _categoryColor,
    onCategoryTap: widget.onCategoryTap,
    onTargetDateTap: widget.onTargetDateTap,
    onStatusTap: widget.onStatusTap,
  );

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return ColoredBox(
      color: ShowcasePalette.page(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.step5,
              tokens.spacing.step4,
              tokens.spacing.step5,
              0,
            ),
            child: DesignSystemShowcaseMobileDetailHeader(
              foregroundColor: ShowcasePalette.highText(context),
              onBack: widget.onBack,
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) =>
                  constraints.maxWidth >= _kDetailWideBreakpoint
                  ? _buildWide(context, tokens)
                  : _buildNarrow(context, tokens),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNarrow(BuildContext context, DsTokens tokens) {
    return DesignSystemScrollbar(
      controller: _scrollController,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.step5,
              tokens.spacing.step3,
              tokens.spacing.step5,
              tokens.spacing.step6,
            ),
            sliver: SliverMainAxisGroup(
              slivers: [
                SliverToBoxAdapter(child: _header()),
                SliverToBoxAdapter(
                  child: SizedBox(height: tokens.spacing.step5),
                ),
                SliverToBoxAdapter(child: _healthPanel()),
                SliverToBoxAdapter(
                  child: SizedBox(height: tokens.spacing.step5),
                ),
                SliverToBoxAdapter(child: _aiReportCard()),
                SliverToBoxAdapter(
                  child: SizedBox(height: tokens.spacing.step6),
                ),
                ProjectTasksSliverPanel(
                  record: widget.record,
                  categoryColor: _categoryColor,
                  onTaskTap: widget.onTaskTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWide(BuildContext context, DsTokens tokens) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step5,
        tokens.spacing.step3,
        tokens.spacing.step5,
        tokens.spacing.step6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          SizedBox(height: tokens.spacing.step5),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left "vital signs" rail: health hero + AI next-steps.
                SizedBox(
                  width: _kDetailRailWidth,
                  child: DesignSystemScrollbar(
                    controller: _railScrollController,
                    child: SingleChildScrollView(
                      controller: _railScrollController,
                      child: Column(
                        children: [
                          _healthPanel(),
                          SizedBox(height: tokens.spacing.step5),
                          _aiReportCard(),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: tokens.spacing.step6),
                // Right column: the task triage list as a standing home.
                // Centred in its Expanded so leftover width becomes a balanced
                // gutter on both sides rather than a one-sided empty band.
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: _kDetailTaskColumnMaxWidth,
                      ),
                      child: DesignSystemScrollbar(
                        controller: _scrollController,
                        child: CustomScrollView(
                          controller: _scrollController,
                          slivers: [
                            ProjectTasksSliverPanel(
                              record: widget.record,
                              categoryColor: _categoryColor,
                              onTaskTap: widget.onTaskTap,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Wraps the agent [ExpandableReportSection] in a first-class, category-tinted
/// card and surfaces the project's AI recommendations as a "what next" list —
/// the page's most useful content, previously floating as bare grey prose.
class _AiReportCard extends StatelessWidget {
  const _AiReportCard({
    required this.record,
    required this.currentTime,
    this.onRefresh,
    this.onCancelScheduledWake,
    this.isRefreshing = false,
  });

  final ProjectRecord record;
  final DateTime currentTime;
  final VoidCallback? onRefresh;
  final VoidCallback? onCancelScheduledWake;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final recommendations = record.recommendations
        .where((r) => r.trim().isNotEmpty)
        .toList(growable: false);

    // The AI report is the AGENT zone: a teal left-edge rail + faint teal wash +
    // a sparkle title mark it as machine-authored, mirroring the Health card's
    // category rail so UGC-vs-agent reads structurally, not just by glyph.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ShowcasePalette.agentCardSurface(context),
        borderRadius: BorderRadius.circular(tokens.radii.sectionCards),
        border: Border.all(color: ShowcasePalette.border(context)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tokens.radii.sectionCards),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.all(tokens.spacing.step5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The actionable "what next" leads the agent card — above the report
                  // prose — so the page's stated purpose is the first thing read.
                  if (recommendations.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: tokens.typography.lineHeight.subtitle1,
                          color: ShowcasePalette.teal(context),
                        ),
                        SizedBox(width: tokens.spacing.step2),
                        Text(
                          context.messages.projectRecommendationsTitle,
                          style: tokens.typography.styles.subtitle.subtitle1
                              .copyWith(
                                color: ShowcasePalette.highText(context),
                              ),
                        ),
                      ],
                    ),
                    SizedBox(height: tokens.spacing.step3),
                    for (final recommendation in recommendations)
                      Padding(
                        padding: EdgeInsets.only(bottom: tokens.spacing.step3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(
                                top: tokens.spacing.step1,
                              ),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                size: tokens.typography.lineHeight.bodySmall,
                                color: ShowcasePalette.teal(context),
                              ),
                            ),
                            SizedBox(width: tokens.spacing.step2),
                            Expanded(
                              child: Text(
                                recommendation,
                                style: tokens.typography.styles.body.bodySmall
                                    .copyWith(
                                      color: ShowcasePalette.highText(context),
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(height: tokens.spacing.step2),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: ShowcasePalette.border(context),
                    ),
                    SizedBox(height: tokens.spacing.step3),
                  ],
                  ExpandableReportSection(
                    title: context.messages.projectShowcaseAiReportTitle,
                    leadingIcon: Icons.auto_awesome,
                    body:
                        record.aiSummary.isEmpty && record.reportContent.isEmpty
                        ? context.messages.agentReportNone
                        : record.aiSummary,
                    fullContent: record.reportContent,
                    trailingLabel: showcaseUpdatedLabel(
                      context,
                      updatedAt: record.reportUpdatedAt,
                      currentTime: currentTime,
                    ),
                    nextWakeAt: record.reportNextWakeAt,
                    onRefresh: onRefresh,
                    onCancelScheduledWake: onCancelScheduledWake,
                    isRefreshing: isRefreshing,
                  ),
                ],
              ),
            ),
            PositionedDirectional(
              start: 0,
              top: 0,
              bottom: 0,
              child: SizedBox(
                width: tokens.spacing.step1 + tokens.spacing.step1,
                child: ColoredBox(color: ShowcasePalette.teal(context)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectMobileHeader extends StatelessWidget {
  const _ProjectMobileHeader({
    required this.record,
    required this.categoryColor,
    this.onCategoryTap,
    this.onTargetDateTap,
    this.onStatusTap,
  });

  final ProjectRecord record;
  final Color categoryColor;
  final VoidCallback? onCategoryTap;
  final VoidCallback? onTargetDateTap;
  final VoidCallback? onStatusTap;

  /// The project title with a leading category-coloured bar bound to it, so the
  /// project's identity reads as a banner on the title rather than a floating
  /// stripe at the page edge.
  Widget _titleWithAccent(BuildContext context, TextStyle titleStyle) {
    final tokens = context.designTokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: tokens.spacing.step1 + tokens.spacing.step1,
          height: tokens.typography.lineHeight.heading2,
          decoration: BoxDecoration(
            color: categoryColor,
            borderRadius: BorderRadius.circular(tokens.radii.xs),
          ),
        ),
        SizedBox(width: tokens.spacing.step3),
        Expanded(child: Text(record.project.data.title, style: titleStyle)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final category = record.category;
    final titleStyle = tokens.typography.styles.heading.heading2.copyWith(
      color: ShowcasePalette.highText(context),
    );
    final statusPill = ProjectStatusPill(
      status: record.project.data.status,
      large: true,
      onTap: onStatusTap,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final statusOnNextLine = _shouldWrapStatusPill(
          context,
          maxWidth: constraints.maxWidth,
          title: record.project.data.title,
          status: record.project.data.status,
          titleStyle: titleStyle,
          tokens: tokens,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!statusOnNextLine)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _titleWithAccent(context, titleStyle)),
                  SizedBox(width: tokens.spacing.step4),
                  statusPill,
                ],
              )
            else ...[
              _titleWithAccent(context, titleStyle),
              SizedBox(height: tokens.spacing.step3),
              Align(
                alignment: Alignment.centerRight,
                child: statusPill,
              ),
            ],
            SizedBox(height: tokens.spacing.step3),
            Wrap(
              spacing: tokens.spacing.step3,
              runSpacing: tokens.spacing.step3,
              children: [
                // DS-aligned metadata pills (same `DsPill` grammar as the task
                // detail header): a category dot + name, and a date pill.
                if (category != null)
                  DsPill(
                    variant: DsPillVariant.filled,
                    bordered: true,
                    leading: _CategoryDot(color: categoryColor),
                    label: category.name,
                    labelColor: ShowcasePalette.highText(context),
                    onTap: onCategoryTap,
                  )
                else if (onCategoryTap != null)
                  DsPill(
                    variant: DsPillVariant.muted,
                    leading: Icon(
                      Icons.label_outline,
                      size: tokens.typography.lineHeight.caption,
                      color: ShowcasePalette.lowText(context),
                    ),
                    label: context.messages.habitCategoryLabel,
                    onTap: onCategoryTap,
                  ),
                if (record.project.data.targetDate case final targetDate?)
                  DsPill(
                    variant: DsPillVariant.filled,
                    bordered: true,
                    leading: Icon(
                      Icons.calendar_today_outlined,
                      size: tokens.typography.lineHeight.caption,
                      color: ShowcasePalette.mediumText(context),
                    ),
                    label: DateFormat.yMMMd(
                      Localizations.localeOf(context).toString(),
                    ).format(targetDate),
                    labelColor: ShowcasePalette.highText(context),
                    onTap: onTargetDateTap,
                  )
                else if (onTargetDateTap != null)
                  DsPill(
                    variant: DsPillVariant.muted,
                    leading: Icon(
                      Icons.calendar_today_outlined,
                      size: tokens.typography.lineHeight.caption,
                      color: ShowcasePalette.lowText(context),
                    ),
                    label: context.messages.projectTargetDateLabel,
                    onTap: onTargetDateTap,
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// A small category-coloured dot used as the leading mark on the category
/// [DsPill], mirroring the task detail header's category treatment (the colour
/// appears as a dot, not a full pill fill).
class _CategoryDot extends StatelessWidget {
  const _CategoryDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final size = tokens.spacing.step3 + tokens.spacing.step1;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(tokens.radii.xs),
      ),
    );
  }
}

bool _shouldWrapStatusPill(
  BuildContext context, {
  required double maxWidth,
  required String title,
  required ProjectStatus status,
  required TextStyle titleStyle,
  required DsTokens tokens,
}) {
  final textDirection = Directionality.of(context);
  final textScaler = MediaQuery.textScalerOf(context);
  final titlePainter = TextPainter(
    text: TextSpan(text: title, style: titleStyle),
    textDirection: textDirection,
    maxLines: 1,
    textScaler: textScaler,
  )..layout();

  final statusPainter = TextPainter(
    text: TextSpan(
      text: showcaseProjectStatusLabel(context, status),
      style: tokens.typography.styles.subtitle.subtitle2.copyWith(height: 1),
    ),
    textDirection: textDirection,
    maxLines: 1,
    textScaler: textScaler,
  )..layout();

  final statusWidth =
      tokens.spacing.step3 +
      tokens.typography.lineHeight.caption +
      tokens.spacing.step1 +
      statusPainter.width +
      tokens.spacing.step1 +
      tokens.typography.lineHeight.caption +
      tokens.spacing.step3;

  return titlePainter.width + tokens.spacing.step4 + statusWidth > maxWidth;
}
