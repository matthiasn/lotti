import 'package:flutter/foundation.dart';
import 'package:lotti/features/knowledge_graph/domain/graph_projection.dart';
import 'package:lotti/features/knowledge_graph/ui/graph_visual_spec.dart';

enum GraphViewMode { graph, connections }

@immutable
class GraphViewportState {
  const GraphViewportState({
    required this.focusId,
    required this.selectedId,
    this.backHistory = const [],
    this.forwardHistory = const [],
    this.density = GraphDensity.balanced,
    this.filters = const GraphProjectionFilters(),
    this.mode = GraphViewMode.graph,
    this.expandedAggregateIds = const {},
  });

  final String focusId;
  final String selectedId;
  final List<String> backHistory;
  final List<String> forwardHistory;
  final GraphDensity density;
  final GraphProjectionFilters filters;
  final GraphViewMode mode;
  final Set<String> expandedAggregateIds;

  bool get canGoBack => backHistory.isNotEmpty;
  bool get canGoForward => forwardHistory.isNotEmpty;

  GraphViewportState copyWith({
    String? focusId,
    String? selectedId,
    List<String>? backHistory,
    List<String>? forwardHistory,
    GraphDensity? density,
    GraphProjectionFilters? filters,
    GraphViewMode? mode,
    Set<String>? expandedAggregateIds,
  }) => GraphViewportState(
    focusId: focusId ?? this.focusId,
    selectedId: selectedId ?? this.selectedId,
    backHistory: backHistory ?? this.backHistory,
    forwardHistory: forwardHistory ?? this.forwardHistory,
    density: density ?? this.density,
    filters: filters ?? this.filters,
    mode: mode ?? this.mode,
    expandedAggregateIds: expandedAggregateIds ?? this.expandedAggregateIds,
  );
}

/// Session-scoped source of truth shared by the graph and Connections view.
class GraphViewportController extends ValueNotifier<GraphViewportState> {
  GraphViewportController({required String initialFocusId})
    : super(
        GraphViewportState(
          focusId: initialFocusId,
          selectedId: initialFocusId,
        ),
      );

  void walkTo(String id) {
    if (id == value.focusId) {
      selectNode(id);
      return;
    }
    value = value.copyWith(
      focusId: id,
      selectedId: id,
      backHistory: [...value.backHistory, value.focusId],
      forwardHistory: const [],
      expandedAggregateIds: const {},
    );
  }

  /// Re-seeds the local workspace from search or the minimap.
  void jumpTo(String id) {
    value = value.copyWith(
      focusId: id,
      selectedId: id,
      backHistory: const [],
      forwardHistory: const [],
      expandedAggregateIds: const {},
    );
  }

  void selectNode(String id) {
    if (id == value.selectedId) return;
    value = value.copyWith(selectedId: id);
  }

  void goBack() {
    if (!value.canGoBack) return;
    final previous = value.backHistory.last;
    value = value.copyWith(
      focusId: previous,
      selectedId: previous,
      backHistory: value.backHistory.sublist(
        0,
        value.backHistory.length - 1,
      ),
      forwardHistory: [value.focusId, ...value.forwardHistory],
      expandedAggregateIds: const {},
    );
  }

  void goForward() {
    if (!value.canGoForward) return;
    final next = value.forwardHistory.first;
    value = value.copyWith(
      focusId: next,
      selectedId: next,
      backHistory: [...value.backHistory, value.focusId],
      forwardHistory: value.forwardHistory.sublist(1),
      expandedAggregateIds: const {},
    );
  }

  void setDensity(GraphDensity density) {
    if (density == value.density) return;
    value = value.copyWith(density: density);
  }

  void setFilters(GraphProjectionFilters filters) {
    value = value.copyWith(filters: filters, expandedAggregateIds: const {});
  }

  void setMode(GraphViewMode mode) {
    if (mode == value.mode) return;
    value = value.copyWith(mode: mode);
  }

  void toggleAggregate(String id) {
    final expanded = {...value.expandedAggregateIds};
    if (!expanded.add(id)) expanded.remove(id);
    value = value.copyWith(expandedAggregateIds: expanded);
  }
}
