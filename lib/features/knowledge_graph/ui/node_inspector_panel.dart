import 'dart:io';
import 'dart:ui';

import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/ui/widgets/entry_image_widget.dart';
import 'package:lotti/features/knowledge_graph/domain/graph_models.dart';
import 'package:lotti/features/knowledge_graph/ui/graph_style.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

part 'node_inspector_panel_node_inspector_panel_part.dart';

class _InspectorContentState extends State<_InspectorContent> {
  bool _summaryExpanded = false;
  final ScrollController _scroll = ScrollController();

  /// Whether content extends past the bottom edge. Drives both the bottom
  /// fade and the "more below" affordance: a permanently-on fade over a
  /// scrollable list read as a disabled section, so the linked entries below
  /// it were taken for the whole set.
  bool _hasMoreBelow = false;

  @override
  void initState() {
    super.initState();
    // Scrolling alone does not rebuild this widget, so the overflow state has
    // to follow the controller — a build-time check would leave the
    // affordance showing after the user reached the end.
    _scroll.addListener(_syncOverflow);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_syncOverflow)
      ..dispose();
    super.dispose();
  }

  /// Bottom padding held for the fade + overflow pill. It inflates the scroll
  /// extent on its own, so it must be discounted when asking whether real
  /// CONTENT continues below — otherwise a panel whose entries fit exactly
  /// would advertise "more below" and scroll to blank space.
  double _reservedStrip(BuildContext context) =>
      context.designTokens.spacing.sectionGap;

  void _syncOverflow() {
    if (!_scroll.hasClients || !mounted) return;
    final position = _scroll.position;
    // Content ends `reserved` above the scrollable's end; anything beyond the
    // viewport bottom after discounting it is genuine content.
    final contentBelow =
        position.maxScrollExtent - _reservedStrip(context) - position.pixels;
    final more = contentBelow > 1;
    if (more != _hasMoreBelow) {
      setState(() => _hasMoreBelow = more);
    }
  }

  void _scrollToEnd() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: kThemeAnimationDuration,
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final tokens = widget.tokens;
    final summary = resolveInspectorSummary(node);
    final media = inspectorMediaPaths(node);
    // Overflow depends on laid-out content, so re-check after each frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncOverflow());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          // Content DIMENSIONS change without a scroll event and without
          // rebuilding this widget — expanding the SUMMARY animates the
          // extent over several frames via AnimatedSize. A controller
          // listener only sees offset activity, so the metrics notification
          // is what keeps the affordance honest across that animation.
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (_) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _syncOverflow(),
              );
              return false;
            },
            child: Stack(
              children: [
                SingleChildScrollView(
                  controller: _scroll,
                  // The bottom strip belongs to the fade + overflow pill, so
                  // reserve it unconditionally: content scrolls clear of them
                  // instead of being covered, and the reserve never changes as
                  // the affordance appears or disappears.
                  padding: EdgeInsets.fromLTRB(
                    tokens.spacing.cardPadding,
                    tokens.spacing.cardPadding,
                    tokens.spacing.cardPadding,
                    tokens.spacing.cardPadding + tokens.spacing.sectionGap,
                  ),
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
                        style: tokens.typography.styles.heading.heading2
                            .copyWith(
                              color: tokens.colors.text.highEmphasis,
                            ),
                      ),
                      // One-liner deck — the assigned agent's tagline (or the
                      // first line of a summary), sat right under the title.
                      if (summary.deck != null) ...[
                        SizedBox(height: tokens.spacing.step3),
                        Text(
                          summary.deck!,
                          style: tokens.typography.styles.body.bodyLarge
                              .copyWith(
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
                            label:
                                context.messages.knowledgeGraphSummarySection,
                            child: InkWell(
                              onTap: () => setState(
                                () => _summaryExpanded = !_summaryExpanded,
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(tokens.spacing.step4),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          LottiIcons.aiSpark,
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
                                            LottiIcons.expand,
                                            size: IconSizes.s,
                                            color: tokens
                                                .colors
                                                .text
                                                .mediumEmphasis,
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
                // Bottom fade — shown only while content actually continues
                // below, dissolving the next row into the surface instead of
                // cutting it. At the end of the list it disappears, so the fade
                // never reads as a permanently dimmed (disabled) section.
                if (_hasMoreBelow)
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
                              tokens.colors.background.level01.withValues(
                                alpha: 0,
                              ),
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
        ),
        // Explicit "there is more" control: the count in the LINKED eyebrow
        // promised entries the panel appeared not to have. It sits in its own
        // row rather than floating over the list, so it never covers the entry
        // it is pointing past.
        if (_hasMoreBelow)
          Padding(
            padding: EdgeInsets.only(top: tokens.spacing.step1),
            child: Center(
              child: _MoreBelowButton(
                label: context.messages.knowledgeGraphMoreBelow,
                cat: widget.cat,
                tokens: tokens,
                onTap: _scrollToEnd,
              ),
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
