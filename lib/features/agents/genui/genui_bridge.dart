import 'package:a2ui_core/a2ui_core.dart'
    show CreateSurfaceMessage, UpdateComponentsMessage;
import 'package:genui/genui.dart';
import 'package:lotti/features/agents/genui/evolution_catalog.dart';
import 'package:openai_dart/openai_dart.dart';

/// Bridges Lotti's OpenAI tool-calling layer to GenUI's A2UI message protocol.
///
/// When the LLM calls the `render_surface` tool, this bridge constructs the
/// necessary [CreateSurfaceMessage] and [UpdateComponentsMessage] messages
/// and feeds them to the [SurfaceController].
class GenUiBridge {
  GenUiBridge({required this.processor});

  final SurfaceController processor;

  /// Tool name constant.
  static const toolName = 'render_surface';

  /// Tracks surface IDs created during the current LLM turn.
  ///
  /// Drained by the chat state after each turn to add
  /// `EvolutionSurfaceMessage` entries.
  final List<String> _pendingSurfaceIds = [];

  /// Surface IDs created since last drain.
  List<String> drainPendingSurfaceIds() {
    final ids = List<String>.from(_pendingSurfaceIds);
    _pendingSurfaceIds.clear();
    return ids;
  }

  /// Whether [name] is the genui bridge tool.
  bool isGenUiTool(String name) => name == toolName;

  /// OpenAI-compatible tool definition for the `render_surface` tool.
  ChatCompletionTool get toolDefinition => const ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: toolName,
      description:
          'Render rich UI content inline in the chat. Available widget '
          'types: EvolutionProposal, EvolutionNoteConfirmation, '
          'MetricsSummary, VersionComparison, CategoryRatings, '
          'BinaryChoicePrompt, '
          'HighPriorityFeedback. Each surface needs a unique surfaceId '
          'and a root component type with its data.',
      parameters: {
        'type': 'object',
        'properties': {
          'surfaceId': {
            'type': 'string',
            'description': 'Unique identifier for this surface',
          },
          'rootType': {
            'type': 'string',
            'enum': [
              'EvolutionProposal',
              'EvolutionNoteConfirmation',
              'MetricsSummary',
              'VersionComparison',
              'CategoryRatings',
              'BinaryChoicePrompt',
              'ABComparison',
              'HighPriorityFeedback',
            ],
            'description': 'Widget type to render',
          },
          'data': {
            'type': 'object',
            'description':
                'Properties matching the widget schema for the chosen type',
          },
        },
        'required': ['surfaceId', 'rootType', 'data'],
        'additionalProperties': false,
      },
    ),
  );

  /// Surfaces created without an id of the model's own, for unique ids.
  int _unnamedSurfaces = 0;

  /// The widget types the controller's catalogs can draw.
  late final Set<String> _drawableTypes = {
    for (final catalog in processor.catalogs)
      for (final item in catalog.items) item.name,
  };

  /// Process a `render_surface` tool call.
  ///
  /// Sends a [CreateSurfaceMessage] followed by an [UpdateComponentsMessage]
  /// carrying the root component to the processor, and returns the surface
  /// ID. A surface the model did not name gets an id of its own, so two such
  /// surfaces never collide.
  ///
  /// Throws a [GenUiBridgeException] — nothing is drawn — for a `rootType`
  /// the catalogs do not have or `data` that is not an object: a surface is
  /// never drawn as a type the model did not ask for, or with properties it
  /// did not give.
  String handleToolCall(Map<String, dynamic> args) {
    final rootType = args['rootType'];
    if (rootType is! String || !_drawableTypes.contains(rootType)) {
      throw GenUiBridgeException(
        'rootType "$rootType" is not a widget type; use one of the rootType '
        'values render_surface lists.',
      );
    }
    final rawData = args['data'];
    if (rawData != null && rawData is! Map<String, dynamic>) {
      throw GenUiBridgeException(
        'data must be an object of the $rootType properties.',
      );
    }
    final data = rawData as Map<String, dynamic>? ?? <String, dynamic>{};
    final surfaceIdValue = args['surfaceId'];
    final surfaceId = surfaceIdValue is String && surfaceIdValue.isNotEmpty
        ? surfaceIdValue
        : 'surface-unnamed-${++_unnamedSurfaces}';

    const rootId = 'root';

    // A2UI components are flat JSON: the id and type sit beside the
    // widget's own properties. The fixed keys come last so a stray `id` or
    // `component` in the LLM's data cannot rename the root.
    final component = <String, dynamic>{
      ...data,
      'id': rootId,
      'component': rootType,
    };

    processor
      ..handleMessage(
        CreateSurfaceMessage(
          surfaceId: surfaceId,
          catalogId: evolutionCatalogId,
        ),
      )
      ..handleMessage(
        UpdateComponentsMessage(
          surfaceId: surfaceId,
          components: [component],
        ),
      );

    _pendingSurfaceIds.add(surfaceId);
    return surfaceId;
  }
}

/// A `render_surface` call the bridge did not draw, with the reason the
/// model is told.
class GenUiBridgeException implements Exception {
  const GenUiBridgeException(this.message);

  final String message;

  @override
  String toString() => message;
}
