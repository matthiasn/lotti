import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/knowledge_graph/domain/graph_models.dart';
import 'package:lotti/features/knowledge_graph/ui/graph_style.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Full-height "dossier" preview of the focused graph node, docked to the right
/// edge of the explorer. A frosted, category-lit surface anchors it over the
/// starfield; a cover banner heads it, then the full title, the AI summary (if
/// any), and a tappable timeline of the node's linked entries fill the column.
///
/// Tapping a timeline row walks the graph to that node (via [onNeighborTap]),
/// so the panel doubles as a navigator. Content cross-fades when the focus
/// node changes (keyed on [GraphNode.id]).
class NodeInspectorPanel extends StatelessWidget {
  const NodeInspectorPanel({
    required this.node,
    required this.neighbors,
    required this.now,
    required this.createdLabel,
    required this.categoryNames,
    required this.style,
    required this.tokens,
    this.onNeighborTap,
    this.canGoBack = false,
    this.onBack,
    this.onRecenter,
    this.onOpen,
    super.key,
  });

  final GraphNode node;

  /// Direct neighbors of [node] (its linked entries), most-recent first —
  /// rendered as the tappable timeline.
  final List<GraphNode> neighbors;

  /// Deterministic "now" used to label each neighbor's relative age.
  final DateTime now;

  /// Pre-formatted relative age of [node] itself (e.g. "2 days ago").
  final String createdLabel;
  final Map<String, String> categoryNames;
  final GraphStyle style;
  final DsTokens tokens;

  /// Called with a neighbor's id when its timeline row is tapped.
  final void Function(String id)? onNeighborTap;

  /// Whether a "back" step is available (the walk history is non-empty).
  final bool canGoBack;

  /// Pops one step of the walk history (back to the previously focused node).
  final VoidCallback? onBack;

  /// Re-frames the camera on the current focus node.
  final VoidCallback? onRecenter;

  /// Opens the focused node's full details in a side panel.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final cat = style.categoryColor(node.categoryId);
    final radius = BorderRadius.circular(tokens.radii.l);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: cat.withValues(alpha: 0.16),
            blurRadius: 48,
            spreadRadius: -8,
            offset: const Offset(-12, 0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.colors.background.level01.withValues(alpha: 0.82),
              borderRadius: radius,
              border: Border.all(color: cat.withValues(alpha: 0.22)),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOut,
                    child: _InspectorContent(
                      key: ValueKey(node.id),
                      node: node,
                      neighbors: neighbors,
                      now: now,
                      createdLabel: createdLabel,
                      categoryLabel:
                          categoryNames[node.categoryId] ?? node.categoryId,
                      style: style,
                      tokens: tokens,
                      cat: cat,
                      onNeighborTap: onNeighborTap,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: tokens.spacing.step5,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            cat.withValues(alpha: 0.28),
                            cat.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 2,
                  child: IgnorePointer(
                    child: ColoredBox(color: cat.withValues(alpha: 0.9)),
                  ),
                ),
                // Walk navigation — overlaid on the hero, stable across the
                // content cross-fade so the controls don't flicker on each step.
                if (onBack != null || onRecenter != null)
                  Positioned(
                    top: tokens.spacing.step3,
                    left: tokens.spacing.step3 + 2,
                    child: Row(
                      children: [
                        if (onBack != null)
                          _NavButton(
                            icon: Icons.arrow_back_rounded,
                            tooltip: context.messages.knowledgeGraphBack,
                            onTap: canGoBack ? onBack : null,
                            tokens: tokens,
                          ),
                        if (onRecenter != null) ...[
                          SizedBox(width: tokens.spacing.step2),
                          _NavButton(
                            icon: Icons.center_focus_strong_rounded,
                            tooltip: context.messages.knowledgeGraphRecenter,
                            onTap: onRecenter,
                            tokens: tokens,
                          ),
                        ],
                      ],
                    ),
                  ),
                // Open the focused entry's full details in the side panel.
                if (onOpen != null)
                  Positioned(
                    top: tokens.spacing.step3,
                    right: tokens.spacing.step3,
                    child: _NavButton(
                      icon: Icons.open_in_full_rounded,
                      tooltip: context.messages.knowledgeGraphOpenDetails,
                      onTap: onOpen,
                      tokens: tokens,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small circular glass control for the panel's walk navigation. Disabled
/// (dimmed, non-interactive) when [onTap] is null.
class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.tokens,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: tokens.colors.background.level02.withValues(alpha: 0.7),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.step2),
            child: Icon(
              icon,
              size: 18,
              color: enabled
                  ? tokens.colors.text.highEmphasis
                  : tokens.colors.text.lowEmphasis,
            ),
          ),
        ),
      ),
    );
  }
}

class _InspectorContent extends StatefulWidget {
  const _InspectorContent({
    required this.node,
    required this.neighbors,
    required this.now,
    required this.createdLabel,
    required this.categoryLabel,
    required this.style,
    required this.tokens,
    required this.cat,
    required this.onNeighborTap,
    super.key,
  });

  final GraphNode node;
  final List<GraphNode> neighbors;
  final DateTime now;
  final String createdLabel;
  final String categoryLabel;
  final GraphStyle style;
  final DsTokens tokens;
  final Color cat;
  final void Function(String id)? onNeighborTap;

  @override
  State<_InspectorContent> createState() => _InspectorContentState();
}

class _InspectorContentState extends State<_InspectorContent> {
  bool _summaryExpanded = false;

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final tokens = widget.tokens;
    final summary = resolveInspectorSummary(node);
    final media = inspectorMediaPaths(node);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: EdgeInsets.all(tokens.spacing.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Reserve only the compact navigation row; entries with no
                    // media no longer pay for an empty decorative hero.
                    SizedBox(
                      height: TapTargets.minimum + tokens.spacing.step2,
                    ),
                    _Kicker(
                      node: node,
                      label:
                          '${typeLabel(context.messages, node.type)} · ${widget.categoryLabel}',
                      cat: widget.cat,
                      tokens: tokens,
                    ),
                    SizedBox(height: tokens.spacing.step4),
                    // Full title — never truncated; this is the node's identity.
                    Text(
                      node.label,
                      style: tokens.typography.styles.heading.heading2.copyWith(
                        color: tokens.colors.text.highEmphasis,
                      ),
                    ),
                    // One-liner deck — the assigned agent's tagline (or the
                    // first line of a summary), sat right under the title.
                    if (summary.deck != null) ...[
                      SizedBox(height: tokens.spacing.step3),
                      Text(
                        summary.deck!,
                        style: tokens.typography.styles.body.bodyLarge.copyWith(
                          color: tokens.colors.text.highEmphasis,
                        ),
                      ),
                    ],
                    if (media.isNotEmpty) ...[
                      SizedBox(height: tokens.spacing.sectionGap),
                      _MediaCarousel(
                        paths: media,
                        coverPath: node.coverImagePath,
                        coverCropX: node.coverImageCropX,
                        tokens: tokens,
                        cat: widget.cat,
                      ),
                    ],
                    if (summary.body != null) ...[
                      SizedBox(height: tokens.spacing.sectionGap),
                      DesignSystemSectionCard(
                        padding: EdgeInsets.zero,
                        child: Semantics(
                          button: true,
                          expanded: _summaryExpanded,
                          label: context.messages.knowledgeGraphSummarySection,
                          child: InkWell(
                            onTap: () => setState(
                              () => _summaryExpanded = !_summaryExpanded,
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(tokens.spacing.step4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.auto_awesome_rounded,
                                        size: IconSizes.s,
                                        color: widget.cat,
                                      ),
                                      SizedBox(width: tokens.spacing.step2),
                                      Expanded(
                                        child: Text(
                                          context
                                              .messages
                                              .knowledgeGraphSummarySection,
                                          style: tokens
                                              .typography
                                              .styles
                                              .others
                                              .overline
                                              .copyWith(color: widget.cat),
                                        ),
                                      ),
                                      AnimatedRotation(
                                        turns: _summaryExpanded ? 0.5 : 0,
                                        duration: kThemeAnimationDuration,
                                        child: Icon(
                                          Icons.expand_more_rounded,
                                          size: IconSizes.s,
                                          color:
                                              tokens.colors.text.mediumEmphasis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  AnimatedSize(
                                    duration: kThemeAnimationDuration,
                                    alignment: Alignment.topCenter,
                                    child: _summaryExpanded
                                        ? Padding(
                                            padding: EdgeInsets.only(
                                              top: tokens.spacing.step3,
                                            ),
                                            child: Text(
                                              summary.body!,
                                              style: tokens
                                                  .typography
                                                  .styles
                                                  .body
                                                  .bodySmall
                                                  .copyWith(
                                                    color: tokens
                                                        .colors
                                                        .text
                                                        .mediumEmphasis,
                                                    height: 1.5,
                                                  ),
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (widget.neighbors.isNotEmpty) ...[
                      SizedBox(height: tokens.spacing.sectionGap),
                      _SectionLabel(
                        label: context.messages.knowledgeGraphLinkedSection(
                          widget.neighbors.length,
                        ),
                        cat: widget.cat,
                        tokens: tokens,
                      ),
                      SizedBox(height: tokens.spacing.step2),
                      for (final n in widget.neighbors)
                        _TimelineItem(
                          node: n,
                          ageLabel: relativeAge(
                            context.messages,
                            widget.now.difference(n.createdAt),
                          ),
                          color: widget.style
                              .edgeVisual(relStyleForNeighborType(n.type))
                              .color,
                          tokens: tokens,
                          onTap: widget.onNeighborTap == null
                              ? null
                              : () => widget.onNeighborTap!(n.id),
                        ),
                    ],
                  ],
                ),
              ),
              // Bottom fade — signals "more below" when the timeline scrolls,
              // dissolving the last row into the surface rather than cutting it.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: tokens.spacing.sectionGap,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          tokens.colors.background.level01.withValues(alpha: 0),
                          tokens.colors.background.level01.withValues(
                            alpha: 0.82,
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
        _Footer(
          createdLabel: widget.createdLabel,
          cat: widget.cat,
          tokens: tokens,
        ),
      ],
    );
  }
}

/// Ordered inspector media: cover art first, followed by linked task images.
/// Duplicate paths are removed while preserving the source order.
List<String> inspectorMediaPaths(GraphNode node) {
  final seen = <String>{};
  return [
    if (node.coverImagePath != null) node.coverImagePath!,
    ...node.mediaPaths,
    if (node.imagePath != null) node.imagePath!,
  ].where(seen.add).toList(growable: false);
}

class _MediaCarousel extends StatelessWidget {
  const _MediaCarousel({
    required this.paths,
    required this.coverPath,
    required this.coverCropX,
    required this.tokens,
    required this.cat,
  });

  final List<String> paths;
  final String? coverPath;
  final double coverCropX;
  final DsTokens tokens;
  final Color cat;

  @override
  Widget build(BuildContext context) {
    final height = tokens.spacing.step13;
    final width = height + tokens.spacing.step10;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(
          label: context.messages.knowledgeGraphPhotosSection(paths.length),
          cat: cat,
          tokens: tokens,
        ),
        SizedBox(height: tokens.spacing.step3),
        SizedBox(
          height: height,
          child: ListView.separated(
            key: const ValueKey('knowledge-graph-media-carousel'),
            scrollDirection: Axis.horizontal,
            itemCount: paths.length,
            separatorBuilder: (_, _) => SizedBox(width: tokens.spacing.step3),
            itemBuilder: (context, index) {
              final path = paths[index];
              final isCover = path == coverPath;
              final alignment = isCover
                  ? Alignment((coverCropX.clamp(0, 1) * 2) - 1, 0)
                  : Alignment.center;
              return Container(
                width: width,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: tokens.colors.background.level02,
                  borderRadius: BorderRadius.circular(tokens.radii.l),
                  border: Border.all(color: tokens.colors.decorative.level01),
                ),
                child: Image.file(
                  File(path),
                  key: ValueKey('knowledge-graph-media-$path'),
                  fit: BoxFit.cover,
                  alignment: alignment,
                  errorBuilder: (_, _, _) => ColoredBox(
                    color: tokens.colors.background.level02,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: tokens.colors.text.lowEmphasis,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Kicker extends StatelessWidget {
  const _Kicker({
    required this.node,
    required this.label,
    required this.cat,
    required this.tokens,
  });

  final GraphNode node;
  final String label;
  final Color cat;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step3,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: cat.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(tokens.radii.smallChips),
        border: Border.all(color: cat.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            glyphForType(node.type),
            size: 13,
            color: tokens.colors.text.highEmphasis,
          ),
          SizedBox(width: tokens.spacing.step2),
          Flexible(
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tokens.typography.styles.others.overline.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One linked entry in the timeline: a relation-coloured glyph, the entry's
/// snippet, and its relative age. Tapping walks the graph to that node.
class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.node,
    required this.ageLabel,
    required this.color,
    required this.tokens,
    required this.onTap,
  });

  final GraphNode node;
  final String ageLabel;
  final Color color;
  final DsTokens tokens;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radii.smallChips),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: tokens.spacing.step2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Relation-colour swatch — a tinted chip behind the glyph so the
            // relation class reads at a glance, not just the icon shape.
            Container(
              padding: EdgeInsets.all(tokens.spacing.step1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(tokens.radii.smallChips),
              ),
              child: Icon(glyphForType(node.type), size: 16, color: color),
            ),
            SizedBox(width: tokens.spacing.step3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    node.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: tokens.colors.text.highEmphasis,
                    ),
                  ),
                  Text(
                    '${typeLabel(context.messages, node.type)} · $ageLabel',
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Category-tinted section eyebrow + hairline divider.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.label,
    required this.cat,
    required this.tokens,
  });

  final String label;
  final Color cat;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: tokens.typography.styles.others.overline.copyWith(color: cat),
        ),
        SizedBox(height: tokens.spacing.step2),
        Divider(color: cat.withValues(alpha: 0.25), height: 1),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.createdLabel,
    required this.cat,
    required this.tokens,
  });

  final String createdLabel;
  final Color cat;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(tokens.spacing.cardPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: cat.withValues(alpha: 0.12), height: 1),
          SizedBox(height: tokens.spacing.step4),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 14, color: cat),
              SizedBox(width: tokens.spacing.step2),
              Text(
                createdLabel,
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Resolves a node's inspector summary into a one-liner `deck` + a longer
/// `body` (pure; unit-tested). Prefers the assigned agent's `oneLiner`/`tldr`
/// (task nodes); otherwise splits a single summary blob (e.g. an AI-response
/// node's text) into a lede + body. Either field may be null.
({String? deck, String? body}) resolveInspectorSummary(GraphNode node) {
  final oneLiner = node.oneLiner?.trim();
  final tldr = node.tldr?.trim();
  if (oneLiner != null && oneLiner.isNotEmpty) {
    final hasBody = tldr != null && tldr.isNotEmpty;
    return (deck: oneLiner, body: hasBody ? previewFromMarkdown(tldr) : null);
  }
  if (tldr != null && tldr.isNotEmpty) {
    final s = splitTldr(tldr);
    return (
      deck: s.lede.isEmpty ? null : s.lede,
      body: s.body.isEmpty ? null : s.body,
    );
  }
  return (deck: null, body: null);
}

/// Relative-age label for the footer/timeline (pure; unit-tested).
String relativeAge(AppLocalizations messages, Duration d) {
  if (d.inHours < 24) return messages.knowledgeGraphAgeToday;
  final days = d.inDays;
  if (days == 1) return messages.knowledgeGraphAgeYesterday;
  if (days < 14) return messages.knowledgeGraphAgeDaysAgo(days);
  if (days < 60) {
    return messages.knowledgeGraphAgeWeeksAgo((days / 7).round());
  }
  return messages.knowledgeGraphAgeMonthsAgo((days / 30).round());
}

/// Flattens a markdown summary into a compact plain-text preview: drops heading
/// markers and emphasis/quote punctuation, normalizes list bullets to "• ", and
/// collapses blank lines (pure; unit-tested).
String previewFromMarkdown(String md) {
  final cleaned = md
      .replaceAll(RegExp(r'^\s*#{1,6}\s*', multiLine: true), '')
      .replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '• ')
      // Underscores join words when stripped bare (snake_case identifiers,
      // `_emphasis_`), so turn them into spaces rather than deleting them.
      .replaceAll('_', ' ')
      .replaceAll(RegExp('[*`>]'), '')
      .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
      .replaceAll(RegExp(r'\n{2,}'), '\n')
      .trim();
  return cleaned.isEmpty ? md.trim() : cleaned;
}

/// Splits a markdown-ish TL;DR into a one-liner lede + the remaining body
/// (pure; unit-tested). The lede is the first line, or — when the first line is
/// long / there is no newline — the first sentence; any leading bullet marker
/// is stripped from it. Body is the remainder (empty for a one-line summary).
({String lede, String body}) splitTldr(String md) {
  final cleaned = previewFromMarkdown(md);
  if (cleaned.isEmpty) return (lede: '', body: '');

  String lede;
  String body;
  final nl = cleaned.indexOf('\n');
  if (nl >= 0 && nl <= 160) {
    lede = cleaned.substring(0, nl).trim();
    body = cleaned.substring(nl + 1).trim();
  } else {
    final sentence = RegExp(r'[.!?](\s|$)').firstMatch(cleaned);
    if (sentence != null && sentence.end <= 200) {
      lede = cleaned.substring(0, sentence.end).trim();
      body = cleaned.substring(sentence.end).trim();
    } else {
      lede = cleaned;
      body = '';
    }
  }
  lede = lede.replaceFirst(RegExp(r'^•\s*'), '');
  return (lede: lede, body: body);
}

/// The graph relation class whose colour best represents a neighbour of the
/// given node type, so the timeline glyphs reuse the graph's edge palette
/// (pure; unit-tested). project→containment, AI→provenance, rating→evaluation,
/// checklist(item)→checklist, task→linkedTask, entries→note.
RelStyle relStyleForNeighborType(GraphNodeType type) {
  switch (type) {
    case GraphNodeType.project:
      return RelStyle.containment;
    case GraphNodeType.aiResponse:
      return RelStyle.provenance;
    case GraphNodeType.rating:
      return RelStyle.evaluation;
    case GraphNodeType.checklist:
    case GraphNodeType.checklistItem:
      return RelStyle.checklist;
    case GraphNodeType.task:
      return RelStyle.linkedTask;
    case GraphNodeType.textEntry:
    case GraphNodeType.audioEntry:
    case GraphNodeType.imageEntry:
      return RelStyle.note;
    case GraphNodeType.mediaCollection:
      return RelStyle.note;
    case GraphNodeType.aggregate:
      return RelStyle.linkedTask;
  }
}
