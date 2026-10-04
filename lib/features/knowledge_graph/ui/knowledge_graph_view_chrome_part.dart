part of 'knowledge_graph_view.dart';

/// Defers the nested detail navigator until after the graph's layout callback.
///
/// [KnowledgeGraphView] builds its responsive workspace from a [LayoutBuilder].
/// [EntryDetailSidebar] activates a nested [Navigator] route through Flutter's
/// overlay portal. Activating that subtree while the layout builder is inside
/// `performLayout` can reattach one of the task page's own layout builders and
/// trip Flutter's render-object mutation guard. The first frame reserves the
/// panel slot; the post-frame rebuild activates the navigator in the normal
/// build phase.
class _DeferredEntryDetailSidebar extends StatefulWidget {
  const _DeferredEntryDetailSidebar({
    required this.entryId,
    required this.onClose,
    required this.tokens,
    super.key,
  });

  final String entryId;
  final VoidCallback onClose;
  final DsTokens tokens;

  @override
  State<_DeferredEntryDetailSidebar> createState() =>
      _DeferredEntryDetailSidebarState();
}

class _DeferredEntryDetailSidebarState
    extends State<_DeferredEntryDetailSidebar> {
  bool _active = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _active = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_active) return const SizedBox.expand();
    return EntryDetailSidebar(
      entryId: widget.entryId,
      onClose: widget.onClose,
      tokens: widget.tokens,
    );
  }
}

class _TitleCard extends StatelessWidget {
  const _TitleCard({
    required this.focus,
    required this.total,
    required this.explorable,
    required this.tokens,
  });

  final GraphNode focus;
  final int total;
  final bool explorable;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step4,
        vertical: tokens.spacing.step3,
      ),
      decoration: BoxDecoration(
        color: tokens.colors.background.level02.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(tokens.radii.m),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            focus.label,
            style: tokens.typography.styles.subtitle.subtitle1.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step1),
          Text(
            explorable
                ? context.messages.knowledgeGraphWalkHint(total)
                : context.messages.knowledgeGraphNodeCount(total),
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendBar extends StatelessWidget {
  const _LegendBar({
    required this.scenario,
    required this.style,
    required this.categoryNames,
    required this.tokens,
    super.key,
  });

  final GraphScenario scenario;
  final GraphStyle style;
  final Map<String, String> categoryNames;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    final relations = relStylesIn(scenario);
    final categories = scenario.nodes.map((n) => n.categoryId).toSet().toList()
      ..sort(
        (a, b) => categoryOrder.indexOf(a).compareTo(categoryOrder.indexOf(b)),
      );
    final channelColor = tokens.colors.text.mediumEmphasis;
    final freshHsl = HSLColor.fromColor(style.focusRing);
    final agedDot = freshHsl
        .withLightness((freshHsl.lightness * 0.42).clamp(0.0, 1.0))
        .withSaturation((freshHsl.saturation * 0.7).clamp(0.0, 1.0))
        .toColor();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step4,
        vertical: tokens.spacing.step3,
      ),
      decoration: BoxDecoration(
        color: tokens.colors.background.level02.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(tokens.radii.m),
      ),
      child: Wrap(
        spacing: tokens.spacing.step5,
        runSpacing: tokens.spacing.step3,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final rel in relations)
            _LegendItem(
              label: relStyleLabel(context.messages, rel),
              tokens: tokens,
              swatch: SizedBox(
                width: 24,
                height: 10,
                child: CustomPaint(
                  painter: _EdgeSwatchPainter(visual: style.edgeVisual(rel)),
                ),
              ),
            ),
          for (final cat in categories)
            _LegendItem(
              label: graphCategoryLabel(context.messages, categoryNames, cat),
              tokens: tokens,
              swatch: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: style.categoryColor(cat),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          _LegendItem(
            label: context.messages.knowledgeGraphMoreLinks,
            tokens: tokens,
            swatch: _DotsSwatch(dots: [(7, channelColor), (13, channelColor)]),
          ),
          _LegendItem(
            label: context.messages.knowledgeGraphRecentToOlder,
            tokens: tokens,
            swatch: _DotsSwatch(dots: [(11, style.focusRing), (11, agedDot)]),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.label,
    required this.swatch,
    required this.tokens,
  });

  final String label;
  final Widget swatch;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        swatch,
        SizedBox(width: tokens.spacing.step2),
        Text(
          label,
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
      ],
    );
  }
}

/// A row of circles of given (diameter, color) — keys the size and brightness
/// encodings in the legend.
class _DotsSwatch extends StatelessWidget {
  const _DotsSwatch({required this.dots});

  final List<(double, Color)> dots;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (diameter, color) in dots)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Container(
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
      ],
    );
  }
}

/// Back + recenter controls for the walk (only shown in explorable worlds).
class _Controls extends StatelessWidget {
  const _Controls({
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
    required this.onRecenter,
    required this.tokens,
  });

  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onRecenter;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CircleButton(
          icon: LottiIcons.back,
          tooltip: context.messages.knowledgeGraphBack,
          enabled: canGoBack,
          onTap: onBack,
          tokens: tokens,
        ),
        SizedBox(width: tokens.spacing.step2),
        _CircleButton(
          icon: LottiIcons.forward,
          tooltip: context.messages.knowledgeGraphForward,
          enabled: canGoForward,
          onTap: onForward,
          tokens: tokens,
        ),
        SizedBox(width: tokens.spacing.step2),
        _CircleButton(
          icon: LottiIcons.focus,
          tooltip: context.messages.knowledgeGraphRecenter,
          enabled: true,
          onTap: onRecenter,
          tokens: tokens,
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
    required this.tokens,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: tokens.colors.background.level02.withValues(alpha: 0.86),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.step3),
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

class _EdgeSwatchPainter extends CustomPainter {
  _EdgeSwatchPainter({required this.visual});

  final EdgeVisual visual;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final paint = Paint()
      ..color = visual.color
      ..strokeWidth = visual.width
      ..strokeCap = StrokeCap.round;
    final dash = visual.dash;
    if (dash != null) {
      var x = 0.0;
      while (x < size.width) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + dash[0], size.width), y),
          paint,
        );
        x += dash[0] + dash[1];
      }
    } else {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_EdgeSwatchPainter old) => old.visual != visual;
}
