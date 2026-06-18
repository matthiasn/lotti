import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/knowledge_graph_poc/domain/graph_models.dart';
import 'package:lotti/features/knowledge_graph_poc/ui/graph_style.dart';

/// Full-height "dossier" preview of the focused graph node, docked to the right
/// edge of the explorer. A frosted, category-lit surface anchors it over the
/// starfield; a cover hero, a headline title, a one-liner lede, the scrollable
/// TL;DR, a "linked" breakdown, and the node's age fill the column.
///
/// Content cross-fades when the focus node changes (keyed on [GraphNode.id]).
class NodeInspectorPanel extends StatelessWidget {
  const NodeInspectorPanel({
    required this.node,
    required this.createdLabel,
    required this.neighborCounts,
    required this.categoryNames,
    required this.style,
    required this.tokens,
    super.key,
  });

  final GraphNode node;

  /// Pre-formatted relative age (e.g. "2 days ago"); see [relativeAge].
  final String createdLabel;

  /// Direct-neighbor count per node type — drives the "linked" breakdown, which
  /// names what the graph can't label at a glance.
  final Map<GraphNodeType, int> neighborCounts;
  final Map<String, String> categoryNames;
  final GraphStyle style;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    final cat = style.categoryColor(node.categoryId);
    final radius = BorderRadius.circular(tokens.radii.l);
    return DecoratedBox(
      // Soft category-keyed glow so the rail reads as lit by the same light as
      // the graph rather than pasted on top of the starfield.
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          // Biased left because the rail is docked to the right edge — the
          // visible (left) side gets the stronger halo into the starfield.
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
                      createdLabel: createdLabel,
                      neighborCounts: neighborCounts,
                      categoryLabel:
                          categoryNames[node.categoryId] ?? node.categoryId,
                      style: style,
                      tokens: tokens,
                      cat: cat,
                    ),
                  ),
                ),
                // Inboard accent edge — a crisp rule plus an outward glow that
                // ties the panel to the focused node's hue.
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InspectorContent extends StatelessWidget {
  const _InspectorContent({
    required this.node,
    required this.createdLabel,
    required this.neighborCounts,
    required this.categoryLabel,
    required this.style,
    required this.tokens,
    required this.cat,
    super.key,
  });

  final GraphNode node;
  final String createdLabel;
  final Map<GraphNodeType, int> neighborCounts;
  final String categoryLabel;
  final GraphStyle style;
  final DsTokens tokens;
  final Color cat;

  @override
  Widget build(BuildContext context) {
    final summary = node.tldr != null && node.tldr!.trim().isNotEmpty
        ? splitTldr(node.tldr!)
        : (lede: tldrFallback(node, categoryLabel), body: '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Hero(
          node: node,
          categoryLabel: categoryLabel,
          style: style,
          tokens: tokens,
          cat: cat,
        ),
        Expanded(
          child: _Body(
            lede: summary.lede,
            body: summary.body,
            neighborCounts: neighborCounts,
            cat: cat,
            style: style,
            tokens: tokens,
          ),
        ),
        _Footer(createdLabel: createdLabel, cat: cat, tokens: tokens),
      ],
    );
  }
}

/// Cover hero: the node's real cover art (or an image entry's photo) under a
/// bottom scrim with the kicker + title overlaid; a category-gradient + glyph
/// watermark when there is no image.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.node,
    required this.categoryLabel,
    required this.style,
    required this.tokens,
    required this.cat,
  });

  final GraphNode node;
  final String categoryLabel;
  final GraphStyle style;
  final DsTokens tokens;
  final Color cat;

  @override
  Widget build(BuildContext context) {
    final coverPath = node.coverImagePath ?? node.imagePath;
    final scrimEnd = tokens.colors.background.level01;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (coverPath != null)
            Image.file(
              File(coverPath),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _gradientHero(),
            )
          else
            _gradientHero(),
          // Top scrim — softens the hard top edge against the rounded corner so
          // the cover/kicker isn't cramped against the panel's top.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.3],
                colors: [
                  scrimEnd.withValues(alpha: 0.45),
                  scrimEnd.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          // Bottom scrim so the overlaid title reads over any cover, fading
          // fully to the body colour so the hero and body read as one surface.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.25, 1],
                colors: [
                  scrimEnd.withValues(alpha: 0),
                  scrimEnd.withValues(alpha: 0.96),
                ],
              ),
            ),
          ),
          Positioned(
            left: tokens.spacing.cardPadding,
            right: tokens.spacing.cardPadding,
            bottom: tokens.spacing.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _Kicker(
                  node: node,
                  label: '${typeLabel(node.type)} · $categoryLabel',
                  cat: cat,
                  tokens: tokens,
                ),
                SizedBox(height: tokens.spacing.step3),
                Text(
                  node.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.typography.styles.heading.heading2.copyWith(
                    color: tokens.colors.text.highEmphasis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gradientHero() {
    final hsl = HSLColor.fromColor(cat);
    final dark = hsl
        .withLightness((hsl.lightness * 0.4).clamp(0.0, 1.0))
        .toColor();
    return ClipRect(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [cat, dark],
          ),
        ),
        child: OverflowBox(
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          alignment: Alignment.topRight,
          child: Padding(
            padding: EdgeInsets.only(
              top: tokens.spacing.step4,
              right: tokens.spacing.step4,
            ),
            child: Icon(
              glyphForType(node.type),
              size: 132,
              color: style.glyphColor.withValues(alpha: 0.18),
            ),
          ),
        ),
      ),
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
        // Emissive chip: a faint hue fill + a brighter hue hairline that echoes
        // the panel's lit edges, with near-white text that stays legible over
        // any cover.
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

class _Body extends StatelessWidget {
  const _Body({
    required this.lede,
    required this.body,
    required this.neighborCounts,
    required this.cat,
    required this.style,
    required this.tokens,
  });

  final String lede;
  final String body;
  final Map<GraphNodeType, int> neighborCounts;
  final Color cat;
  final GraphStyle style;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    final linked = neighborCounts.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return DecoratedBox(
      // Feather the hero's category hue a little way into the body so the two
      // regions read as one continuous surface, not stacked tiles.
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, 0.22],
          colors: [cat.withValues(alpha: 0.1), cat.withValues(alpha: 0)],
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(tokens.spacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (lede.isNotEmpty)
              Text(
                lede,
                style: tokens.typography.styles.body.bodyLarge.copyWith(
                  color: tokens.colors.text.highEmphasis,
                ),
              ),
            if (body.isNotEmpty) ...[
              SizedBox(height: tokens.spacing.sectionGap),
              _SectionLabel(label: 'SUMMARY', cat: cat, tokens: tokens),
              SizedBox(height: tokens.spacing.step3),
              Text(
                body,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                  height: 1.5,
                ),
              ),
            ],
            // Named-neighbour breakdown — sits under the content so it fills the
            // column on thin summaries instead of stranding a void above the
            // footer, and tells the reader what the graph can't label at a
            // glance.
            if (linked.isNotEmpty) ...[
              SizedBox(height: tokens.spacing.sectionGap),
              _SectionLabel(label: 'LINKED', cat: cat, tokens: tokens),
              SizedBox(height: tokens.spacing.step3),
              Wrap(
                spacing: tokens.spacing.step2,
                runSpacing: tokens.spacing.step2,
                children: [
                  for (final e in linked)
                    _LinkChip(
                      type: e.key,
                      count: e.value,
                      // Colour each chip with the graph's own relation hue for
                      // that neighbour type, so the breakdown reads as the same
                      // system as the edges/legend on the canvas.
                      color: style
                          .edgeVisual(relStyleForNeighborType(e.key))
                          .color,
                      tokens: tokens,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Category-tinted section eyebrow + hairline divider, shared by the body's
/// SUMMARY and LINKED sections.
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
          // Hue-tinted so the category light carries to the very bottom of the
          // column instead of dead-ending in a neutral grey footer.
          Divider(color: cat.withValues(alpha: 0.12), height: 1),
          SizedBox(height: tokens.spacing.step4),
          Row(
            children: [
              // Category-hued so the panel's accent terminates on content, not
              // on the divider line above.
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

class _LinkChip extends StatelessWidget {
  const _LinkChip({
    required this.type,
    required this.count,
    required this.color,
    required this.tokens,
  });

  final GraphNodeType type;
  final int count;
  final Color color;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step3,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: tokens.colors.background.level02.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(tokens.radii.smallChips),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(glyphForType(type), size: 12, color: color),
          SizedBox(width: tokens.spacing.step2),
          Text(
            '$count  ${typeLabel(type)}',
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Relative-age label for the footer (pure; unit-tested).
String relativeAge(Duration d) {
  if (d.inHours < 24) return 'today';
  final days = d.inDays;
  if (days == 1) return 'yesterday';
  if (days < 14) return '$days days ago';
  if (days < 60) return '${(days / 7).round()} weeks ago';
  return '${(days / 30).round()} months ago';
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
/// given node type, so the inspector's "linked" chips reuse the graph's edge
/// palette (pure; unit-tested). Mirrors the relation a focus task has to each
/// neighbour kind: project→containment, AI→provenance, rating→evaluation,
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
  }
}

/// A short, type-specific descriptor for nodes that have no real summary — used
/// as the lede so the panel is never bare (pure; unit-tested).
String tldrFallback(GraphNode node, String categoryLabel) {
  switch (node.type) {
    case GraphNodeType.task:
      return 'A $categoryLabel task in your graph.';
    case GraphNodeType.project:
      return 'A $categoryLabel project — walk in to explore its tasks.';
    case GraphNodeType.aiResponse:
      return 'An AI-generated summary derived from the linked task.';
    case GraphNodeType.rating:
      return 'A rating of the linked task.';
    case GraphNodeType.checklist:
      return 'A checklist — its items branch off from here.';
    case GraphNodeType.checklistItem:
      return 'One item on a checklist.';
    case GraphNodeType.audioEntry:
      return 'A voice note captured against this task.';
    case GraphNodeType.imageEntry:
      return 'An image attached to this task.';
    case GraphNodeType.textEntry:
      return 'A text log entry on this task.';
  }
}
