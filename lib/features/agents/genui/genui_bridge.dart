import 'package:a2ui_core/a2ui_core.dart';
import 'package:lotti/features/agents/genui/evolution_catalog.dart';
import 'package:openai_dart/openai_dart.dart';

/// Bridges Lotti's OpenAI tool-calling layer to the A2UI message protocol.
///
/// When the LLM calls the `render_surface` tool, this bridge builds the A2UI
/// `createSurface` message and feeds it to the [EvolutionSurfaces]. The model
/// never writes A2UI itself.
class GenUiBridge {
  GenUiBridge({required this.processor});

  final EvolutionSurfaces processor;

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

  /// The widget types the evolution catalog — the one every surface here is
  /// created with — can draw.
  static final Set<String> _drawableTypes = {
    for (final item in buildEvolutionCatalog().components.values) item.name,
  };

  /// Process a `render_surface` tool call.
  ///
  /// Creates the surface with its root component in one v1.0 `createSurface`
  /// message — checked as a whole, so a surface that fails creates nothing —
  /// and returns the surface ID. A surface the model did not name gets an id
  /// of its own, so two such surfaces never collide; one it names again is
  /// updated in place, and keeps what it showed when the update fails.
  ///
  /// Throws a [GenUiBridgeException] — nothing is drawn — for a `rootType`
  /// the evolution catalog does not have, `data` that is not an object, or
  /// properties the type's schema refuses: a surface is never drawn as a
  /// type the model did not ask for.
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

    // A2UI components are flat JSON: the id and type sit beside the
    // widget's own properties. The fixed keys come last so a stray `id` or
    // `component` in the LLM's data cannot rename the root.
    // A null property is one not given: the app's own proposal surfaces
    // pass null for what a proposal leaves out, which a schema would refuse.
    final component = <String, dynamic>{
      for (final MapEntry(:key, :value) in data.entries) key: ?value,
      'id': 'root',
      'component': rootType,
    };
    const version = '1.0';
    final existed = processor.model.getSurface(surfaceId) != null;
    try {
      processor.processMessages([
        // A surface she names again is updated in place: the update is
        // checked before it is applied, so one that fails leaves the card
        // already on screen as it was.
        if (existed)
          {
            'version': version,
            'updateComponents': {
              'surfaceId': surfaceId,
              'components': [component],
            },
          }
        else
          {
            'version': version,
            'createSurface': {
              'surfaceId': surfaceId,
              'catalogId': evolutionCatalogId,
              'components': [component],
            },
          },
      ]);
    } on A2uiError catch (e) {
      throw GenUiBridgeException(e.message);
    }

    // An updated surface is already in the chat, where it redraws itself:
    // only a new one is announced.
    if (!existed) _pendingSurfaceIds.add(surfaceId);
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
