import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/speech/state/recording_return.dart';
import 'package:material_ui/material_ui.dart';

/// Lets a page come back to where it was scrolled when the recording strip
/// takes the user back to a take's origin.
///
/// It reports [controller]'s offset under [route] as the page scrolls, so a
/// take started here remembers it. When the strip's way back asks for this
/// route, the offset is restored once, clamped to what the page can scroll
/// to now: on the first frame of a page built anew, or at once for a page
/// that stayed mounted in its tab. The page's own scrolling is untouched
/// otherwise. A page without it lands at its top.
class RecordingOriginScrollAnchor extends ConsumerStatefulWidget {
  const RecordingOriginScrollAnchor({
    required this.route,
    required this.controller,
    required this.child,
    super.key,
  });

  /// The route the page stands at, as the navigation service reports it.
  final String route;

  /// The page's primary scroll controller.
  final ScrollController controller;

  final Widget child;

  @override
  ConsumerState<RecordingOriginScrollAnchor> createState() =>
      _RecordingOriginScrollAnchorState();
}

class _RecordingOriginScrollAnchorState
    extends ConsumerState<RecordingOriginScrollAnchor> {
  late RecordingOriginScroll _scroll;

  @override
  void initState() {
    super.initState();
    _scroll = ref.read(recordingOriginScrollProvider)..addListener(_restore);
    widget.controller.addListener(_report);
    WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
  }

  @override
  void didUpdateWidget(covariant RecordingOriginScrollAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_report);
      widget.controller.addListener(_report);
    }
    if (oldWidget.route != widget.route) _scroll.forget(oldWidget.route);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_report);
    _scroll
      ..removeListener(_restore)
      ..forget(widget.route);
    super.dispose();
  }

  void _report() {
    if (widget.controller.hasClients) {
      _scroll.report(widget.route, widget.controller.offset);
    }
  }

  void _restore() {
    if (!mounted || !widget.controller.hasClients) return;
    final offset = _scroll.takeRestore(widget.route);
    if (offset == null) return;
    final position = widget.controller.position;
    widget.controller.jumpTo(
      offset.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
