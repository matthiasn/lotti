import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:collection/collection.dart';
import 'package:lotti/features/front_agent/model/front_reply_surface.dart';
import 'package:lotti/features/front_agent/ui/a2ui/front_reply_catalog.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:material_ui/material_ui.dart';

/// The A2UI surfaces of one conversation's replies: one message processor
/// of [frontReplyCatalog] for the whole thread, fed each reply's stored
/// surface.
///
/// [surfaces] are the replies to draw, by reply id. A reply new to the
/// thread is created, one whose stored surface changed (re-read after sync)
/// is replaced, and one that left the thread is deleted. A surface the
/// processor refuses — a stored shape it cannot draw — is logged and left
/// out, so the reply falls back to her words.
///
/// A tapped quick reply comes back through the processor's actions as
/// [onQuickReply], with the reply's own words.
class FrontReplySurfaces extends StatefulWidget {
  const FrontReplySurfaces({
    required this.surfaces,
    required this.logger,
    required this.onQuickReply,
    required this.child,
    super.key,
  });

  final Map<String, FrontReplySurface> surfaces;

  /// Receives a stored surface the processor refused.
  final DomainLogger logger;
  final ValueChanged<String> onQuickReply;
  final Widget child;

  /// The live surface reply [replyId] is drawn on, or null when it has none.
  static SurfaceModel<ComponentImplementation>? surfaceOf(
    BuildContext context,
    String replyId,
  ) => context
      .dependOnInheritedWidgetOfExactType<_FrontReplySurfacesScope>()
      ?.live[replyId];

  @override
  State<FrontReplySurfaces> createState() => _FrontReplySurfacesState();
}

class _FrontReplySurfacesState extends State<FrontReplySurfaces> {
  static const _equality = DeepCollectionEquality();

  final _processor = MessageProcessor<ComponentImplementation>(
    catalogs: [frontReplyCatalog],
  );

  /// What each reply's live surface was created from.
  final _fed = <String, FrontReplySurface>{};
  Map<String, SurfaceModel<ComponentImplementation>> _live = const {};

  @override
  void initState() {
    super.initState();
    _processor.model.onAction.subscribe((action) {
      final text = action.context['text'];
      if (action.name == frontQuickReplyAction &&
          text is String &&
          text.trim().isNotEmpty) {
        widget.onQuickReply(text.trim());
      }
    });
    _sync();
  }

  @override
  void didUpdateWidget(FrontReplySurfaces oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  /// Brings the processor's surfaces in line with [FrontReplySurfaces.surfaces].
  void _sync() {
    for (final id in _fed.keys.toList()) {
      final wanted = widget.surfaces[id];
      if (wanted != null &&
          _equality.equals(wanted.message, _fed[id]!.message)) {
        continue;
      }
      _process({
        'version': frontReplyProtocolVersion,
        'deleteSurface': {'surfaceId': _fed.remove(id)!.surfaceId},
      });
    }
    for (final MapEntry(key: id, value: surface) in widget.surfaces.entries) {
      if (_fed.containsKey(id) || surface.wordsOnly) continue;
      if (_process(surface.message)) _fed[id] = surface;
    }
    _live = {
      for (final MapEntry(key: id, value: surface) in _fed.entries)
        id: ?_processor.model.getSurface(surface.surfaceId),
    };
  }

  /// Applies one A2UI message; false when the processor refuses it.
  bool _process(Map<String, Object?> message) {
    try {
      _processor.processMessages([message]);
      return true;
    } on A2uiError catch (error, stackTrace) {
      // The message is her reply — model-written text — so only the error's
      // code is logged.
      widget.logger.error(
        LogDomain.agentWorkflow,
        error.code,
        stackTrace: stackTrace,
        subDomain: 'FrontReplySurfaces',
        message: 'A reply surface could not be drawn',
        errorType: error.runtimeType,
      );
      return false;
    }
  }

  @override
  void dispose() {
    _processor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _FrontReplySurfacesScope(live: _live, child: widget.child);
}

class _FrontReplySurfacesScope extends InheritedWidget {
  const _FrontReplySurfacesScope({required this.live, required super.child});

  final Map<String, SurfaceModel<ComponentImplementation>> live;

  @override
  bool updateShouldNotify(_FrontReplySurfacesScope oldWidget) =>
      !identical(live, oldWidget.live);
}
