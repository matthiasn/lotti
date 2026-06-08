import 'package:flutter/material.dart';
import 'package:genui/genui.dart';

/// Builds a widget for a [CatalogItem] with the given [data], wrapped in
/// a [Builder] so it can be pumped inside a testable material app.
Widget buildCatalogWidget(CatalogItem item, Map<String, Object?> data) {
  return Builder(
    builder: (context) {
      final itemContext = CatalogItemContext(
        data: data,
        id: 'test-component',
        type: item.name,
        buildChild: (id, [dataContext]) => const SizedBox.shrink(),
        dispatchEvent: (_) {},
        buildContext: context,
        dataContext: DataContext(InMemoryDataModel(), DataPath.root),
        getComponent: (_) => null,
        getCatalogItem: (_) => null,
        surfaceId: 'test-surface',
        reportError: (_, _) {},
      );
      return item.widgetBuilder(itemContext);
    },
  );
}

/// Like [buildCatalogWidget] but captures dispatched events into [events].
Widget buildCatalogWidgetWithEvents(
  CatalogItem item,
  Map<String, Object?> data, {
  required List<UiEvent> events,
}) {
  return Builder(
    builder: (context) {
      final itemContext = CatalogItemContext(
        data: data,
        id: 'test-component',
        type: item.name,
        buildChild: (id, [dataContext]) => const SizedBox.shrink(),
        dispatchEvent: events.add,
        buildContext: context,
        dataContext: DataContext(InMemoryDataModel(), DataPath.root),
        getComponent: (_) => null,
        getCatalogItem: (_) => null,
        surfaceId: 'test-surface',
        reportError: (_, _) {},
      );
      return item.widgetBuilder(itemContext);
    },
  );
}
