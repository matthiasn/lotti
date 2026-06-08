import 'package:genui/genui.dart';
import 'package:lotti/features/agents/genui/evolution_catalog.dart';
import 'package:lotti/features/agents/genui/genui_bridge.dart';
import 'package:lotti/features/agents/workflow/evolution_strategy.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';

/// Shared GenUI bench: catalog-backed bridge + strategy + initialized
/// conversation manager — previously duplicated by three groups' setUps.
({GenUiBridge bridge, EvolutionStrategy strategy, ConversationManager manager})
buildGenUiBench({
  required String conversationId,
  EvolutionStrategy Function(GenUiBridge bridge)? strategyBuilder,
}) {
  final catalog = buildEvolutionCatalog();
  final processor = SurfaceController(catalogs: [catalog]);
  final bridge = GenUiBridge(processor: processor);
  final strategy =
      strategyBuilder?.call(bridge) ?? EvolutionStrategy(genUiBridge: bridge);
  final manager = ConversationManager(conversationId: conversationId)
    ..initialize(systemMessage: 'You are an evolution agent.');
  return (bridge: bridge, strategy: strategy, manager: manager);
}
