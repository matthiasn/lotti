part of 'agent_chat_view.dart';

/// Collapses a long agent reply to a bounded height with a bottom fade and a
/// Show more / Show less toggle.
///
/// The clamp is HEIGHT-based, not line-based: `GptMarkdown` renders block
/// elements (lists, headings, quotes) as `WidgetSpan`s that each count as a
/// single "line" of the outer `Text.rich`, so a `maxLines` clamp never bites
/// on markdown-heavy replies and the former toggle looked inert. Measuring
/// the laid-out height keeps the toggle honest: it appears exactly when the
/// content overflows the collapsed viewport.
class _CollapsibleAgentMarkdown extends StatefulWidget {
  const _CollapsibleAgentMarkdown({
    required this.cacheKey,
    required this.measuredHeights,
    required this.text,
    required this.style,
    required this.fadeColor,
    this.onLinkTap,
  });

  /// Identifies this reply in [measuredHeights] — the message id, stable
  /// across the item's disposal and rebuild.
  final String cacheKey;

  /// List-owned measurements that outlive this item; see
  /// [_AgentChatViewState._measuredHeights].
  final Map<String, double> measuredHeights;

  final String text;
  final TextStyle style;
  final void Function(String url, String title)? onLinkTap;

  /// The bubble surface color the bottom fade dissolves into.
  final Color fadeColor;

  @override
  State<_CollapsibleAgentMarkdown> createState() =>
      _CollapsibleAgentMarkdownState();
}

class _CollapsibleAgentMarkdownState extends State<_CollapsibleAgentMarkdown> {
  static const _collapsedLines = 8;

  bool _expanded = false;
  double? _contentHeight;

  @override
  void initState() {
    super.initState();
    // A rebuilt item starts from the height the list already knows, so its
    // first frame is the collapsed one. A stale value (the pane was resized
    // while this reply was off screen) is corrected by the next measurement
    // — one settling rebuild, never a repeating one.
    _contentHeight = widget.measuredHeights[widget.cacheKey];
  }

  double get _collapsedHeight {
    final fontSize = widget.style.fontSize ?? 14;
    return fontSize * (widget.style.height ?? 1.4) * _collapsedLines;
  }

  void _handleHeight(double height) {
    widget.measuredHeights[widget.cacheKey] = height;
    if (_contentHeight == height) return;
    // Reported during layout — defer the rebuild to the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _contentHeight != height) {
        setState(() => _contentHeight = height);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final collapsedHeight = _collapsedHeight;
    final overflows = (_contentHeight ?? 0) > collapsedHeight + 1;
    final collapsed = overflows && !_expanded;
    // The child stays laid out at full height inside the OverflowBox while
    // collapsed, so the measurement keeps tracking content changes.
    final content = _MeasureHeight(
      onHeight: _handleHeight,
      child: AgentMarkdownView(
        widget.text,
        style: widget.style,
        onLinkTap: widget.onLinkTap,
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!collapsed)
          content
        else
          ClipRect(
            key: const ValueKey('agent-reply-collapse'),
            child: Stack(
              children: [
                SizedBox(
                  height: collapsedHeight,
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    maxHeight: double.infinity,
                    child: content,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: tokens.spacing.step6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          widget.fadeColor.withValues(alpha: 0),
                          widget.fadeColor,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (overflows) ...[
          SizedBox(height: tokens.spacing.step1),
          MergeSemantics(
            child: Semantics(
              expanded: _expanded,
              child: DesignSystemButton(
                label: _expanded
                    ? context.messages.aiResponseShowLess
                    : context.messages.aiResponseShowMore,
                onPressed: () => setState(() => _expanded = !_expanded),
                variant: DesignSystemButtonVariant.tertiary,
                size: DesignSystemButtonSize.dense,
                trailingIcon: _expanded
                    ? LottiIcons.collapse
                    : LottiIcons.expand,
                alignsLabelToLeadingEdge: true,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MeasureHeight extends SingleChildRenderObjectWidget {
  const _MeasureHeight({required this.onHeight, super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureHeight(onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasureHeight renderObject,
  ) {
    renderObject.onHeight = onHeight;
  }
}

class _RenderMeasureHeight extends RenderProxyBox {
  _RenderMeasureHeight(this.onHeight);

  ValueChanged<double> onHeight;
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    if (_reported != size.height) {
      _reported = size.height;
      onHeight(size.height);
    }
  }
}
