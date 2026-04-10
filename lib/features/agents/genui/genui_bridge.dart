import 'package:genui/genui.dart';
import 'package:lotti/features/agents/genui/evolution_catalog.dart';
import 'package:openai_dart/openai_dart.dart';

/// Bridges Lotti's OpenAI tool-calling layer to GenUI's A2UI message protocol.
///
/// When the LLM calls the `render_surface` tool, this bridge constructs the
/// necessary [Component], [UpdateComponents], and [CreateSurface] messages and
/// feeds them to the [SurfaceController].
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

  /// Process a `render_surface` tool call.
  ///
  /// Constructs the genui [Component], sends [UpdateComponents] and
  /// [CreateSurface] to the processor, and returns the surface ID.
  String handleToolCall(Map<String, dynamic> args) {
    final surfaceIdValue = args['surfaceId'];
    final surfaceId = surfaceIdValue is String && surfaceIdValue.isNotEmpty
        ? surfaceIdValue
        : 'surface-unknown';

    const supportedRootTypes = {
      'EvolutionProposal',
      'SoulProposal',
      'EvolutionNoteConfirmation',
      'MetricsSummary',
      'VersionComparison',
      'FeedbackClassification',
      'FeedbackCategoryBreakdown',
      'SessionProgress',
      'CategoryRatings',
      'BinaryChoicePrompt',
      'ABComparison',
      'HighPriorityFeedback',
    };
    final rootTypeValue = args['rootType'];
    final rootType =
        rootTypeValue is String && supportedRootTypes.contains(rootTypeValue)
        ? rootTypeValue
        : 'EvolutionProposal';
    final rawData = args['data'];
    final data = rawData is Map<String, dynamic>
        ? rawData
        : <String, dynamic>{};

    const rootId = 'root';

    final component = Component(
      id: rootId,
      type: rootType,
      properties: data,
    );

    processor
      ..handleMessage(
        CreateSurface(
          surfaceId: surfaceId,
          catalogId: evolutionCatalogId,
        ),
      )
      ..handleMessage(
        UpdateComponents(
          surfaceId: surfaceId,
          components: [component],
        ),
      );

    _pendingSurfaceIds.add(surfaceId);
    return surfaceId;
  }
}
