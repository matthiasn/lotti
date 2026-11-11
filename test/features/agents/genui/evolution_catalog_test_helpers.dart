import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/genui/evolution_catalog.dart';
import 'package:lotti/features/agents/genui/evolution_catalog_helpers.dart';
import 'package:material_ui/material_ui.dart';

/// The node a component under test is built for: only its id is read.
class _TestNode extends Fake implements ComponentNode<ComponentImplementation> {
  @override
  String get componentId => 'test-component';
}

/// Builds the widget of the catalog component [item] from [data], on a real
/// (empty) surface so its actions can be sent.
///
/// The builder is called directly, so [data] is not checked against the
/// component's schema: these tests cover what a builder does with whatever
/// it is given.
Widget buildCatalogWidget(
  ComponentImplementation item,
  Map<String, Object?> data,
) => buildCatalogWidgetWithEvents(item, data, events: []);

/// Like [buildCatalogWidget] but captures the actions the widget sends into
/// [events], as they arrive from the surface named [surfaceId].
Widget buildCatalogWidgetWithEvents(
  ComponentImplementation item,
  Map<String, Object?> data, {
  required List<A2uiRendererAction> events,
  String surfaceId = 'test-surface',
}) {
  final processor = EvolutionSurfaces(catalogs: [buildEvolutionCatalog()])
    ..processMessages([
      {
        'version': '1.0',
        'createSurface': {
          'surfaceId': surfaceId,
          'catalogId': evolutionCatalogId,
        },
      },
    ]);
  addTearDown(processor.dispose);
  final surface = processor.model.getSurface(surfaceId)!;
  surface.onAction.subscribe(events.add);
  return EvolutionSurfaceScope(
    surface: surface,
    child: Builder(
      builder: (context) => item.builder(
        context,
        _TestNode(),
        ComponentProps(data),
        (_) => const SizedBox.shrink(),
      ),
    ),
  );
}
