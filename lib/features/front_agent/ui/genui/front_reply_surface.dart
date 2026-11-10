import 'package:a2ui_core/a2ui_core.dart'
    show CreateSurfaceMessage, UpdateComponentsMessage;
import 'package:collection/collection.dart';
import 'package:genui/genui.dart';
import 'package:lotti/features/front_agent/ui/genui/front_reply_catalog.dart';
import 'package:material_ui/material_ui.dart';

/// One reply of hers as a GenUI surface: [components] (see
/// `frontReplyComponents`) on a `SurfaceController` of
/// [frontReplyCatalog], drawn by GenUI's [Surface].
///
/// The surface is created once, under [surfaceId] (her reply's id), and
/// updated when its components change — a reply re-read after sync, a card
/// no longer shown twice — so it is never rebuilt from nothing. Draw it
/// inside a [FrontReplyScope].
class FrontReplySurface extends StatefulWidget {
  const FrontReplySurface({
    required this.surfaceId,
    required this.components,
    super.key,
  });

  final String surfaceId;
  final List<Map<String, Object?>> components;

  @override
  State<FrontReplySurface> createState() => _FrontReplySurfaceState();
}

class _FrontReplySurfaceState extends State<FrontReplySurface> {
  static const _equality = DeepCollectionEquality();

  final _controller = SurfaceController(catalogs: [frontReplyCatalog]);

  @override
  void initState() {
    super.initState();
    _controller.handleMessage(
      CreateSurfaceMessage(
        surfaceId: widget.surfaceId,
        catalogId: frontReplyCatalogId,
      ),
    );
    _update();
  }

  @override
  void didUpdateWidget(FrontReplySurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(
      oldWidget.surfaceId == widget.surfaceId,
      'A reply surface is keyed by its reply',
    );
    if (!_equality.equals(oldWidget.components, widget.components)) _update();
  }

  void _update() => _controller.handleMessage(
    UpdateComponentsMessage(
      surfaceId: widget.surfaceId,
      components: [
        for (final component in widget.components) {...component},
      ],
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Surface(surfaceContext: _controller.contextFor(widget.surfaceId));
}
