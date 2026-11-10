part of 'day_timeline.dart';

/// Lets a host show a [DayTimeline]'s lane-format and arrange controls
/// somewhere other than the timeline's own toolbar — the Day page puts them
/// at the end of its briefing strip, so the Day tab carries no chrome the
/// other tabs lack.
///
/// The timeline attaches itself while it is mounted and reports what the
/// controls show: whether both lanes are side by side, whether arrange mode
/// is on, and whether this timeline can arrange at all. Listeners hear of
/// every change — including a timeline's first report and its detaching —
/// after the frame that caused it. The toggles do nothing while no timeline
/// is attached.
class DayTimelineController extends ChangeNotifier {
  _DayTimelineState? _timeline;

  /// Whether the attached timeline has reported since attaching: its first
  /// report is news even when the values match the defaults, because the
  /// controls appear with it.
  bool _reported = false;
  bool _disposed = false;
  bool _showingBoth = false;
  bool _arrangeMode = false;
  bool _canArrange = false;

  /// Whether a timeline is attached.
  bool get isAttached => _timeline != null;

  /// Whether the planned and recorded lanes are side by side, rather than
  /// pages to swipe between.
  bool get showingBoth => _showingBoth;

  /// Whether the timeline's blocks are showing their move and resize
  /// handles.
  bool get arrangeMode => _arrangeMode;

  /// Whether the timeline can arrange at all — only a host that persists
  /// moves offers it.
  bool get canArrange => _canArrange;

  /// Switches between side-by-side lanes and swipeable pages.
  void toggleComparisonMode() => _timeline?._toggleComparisonMode();

  /// Turns arrange mode on or off.
  void toggleArrangeMode() => _timeline?._toggleArrangeMode();

  void _attach(_DayTimelineState timeline) {
    assert(
      _timeline == null || identical(_timeline, timeline),
      'A DayTimelineController drives one timeline at a time.',
    );
    _timeline = timeline;
  }

  void _detach(_DayTimelineState timeline) {
    if (!identical(_timeline, timeline)) return;
    _timeline = null;
    _reported = false;
    // Detaching happens while the tree is being torn down or rebuilt, where
    // listeners must not be told synchronously; they hear after the frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _report({
    required bool showingBoth,
    required bool arrangeMode,
    required bool canArrange,
  }) {
    if (_reported &&
        showingBoth == _showingBoth &&
        arrangeMode == _arrangeMode &&
        canArrange == _canArrange) {
      return;
    }
    _reported = true;
    _showingBoth = showingBoth;
    _arrangeMode = arrangeMode;
    _canArrange = canArrange;
    notifyListeners();
  }
}

/// A [DayTimeline]'s lane-format and arrange buttons, driven through its
/// [controller], for a host that shows them outside the timeline. Renders
/// nothing until a timeline has attached.
class DayTimelineControls extends StatelessWidget {
  const DayTimelineControls({required this.controller, super.key});

  final DayTimelineController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.isAttached) return const SizedBox.shrink();
        return _TimelineControlButtons(
          showingBoth: controller.showingBoth,
          arrangeMode: controller.arrangeMode,
          onToggleMode: controller.toggleComparisonMode,
          onToggleArrange: controller.canArrange
              ? controller.toggleArrangeMode
              : null,
        );
      },
    );
  }
}

/// The lane-format toggle and, when the timeline can arrange, the arrange
/// toggle — the same two buttons wherever they are shown.
class _TimelineControlButtons extends StatelessWidget {
  const _TimelineControlButtons({
    required this.showingBoth,
    required this.arrangeMode,
    required this.onToggleMode,
    required this.onToggleArrange,
  });

  final bool showingBoth;
  final bool arrangeMode;
  final VoidCallback onToggleMode;
  final VoidCallback? onToggleArrange;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: showingBoth
              ? messages.dailyOsNextTimelineShowPaged
              : messages.dailyOsNextTimelineShowBoth,
          child: IconButton(
            key: const Key('daily_os_timeline_mode_toggle'),
            onPressed: onToggleMode,
            icon: Icon(
              showingBoth ? LottiIcons.viewCarousel : LottiIcons.viewColumns,
            ),
          ),
        ),
        if (onToggleArrange != null)
          Tooltip(
            message: messages.dailyOsNextTimelineArrange,
            child: IconButton(
              key: const Key('daily_os_timeline_arrange_toggle'),
              isSelected: arrangeMode,
              onPressed: onToggleArrange,
              selectedIcon: const Icon(LottiIcons.drag),
              icon: const Icon(LottiIcons.drag),
            ),
          ),
      ],
    );
  }
}
