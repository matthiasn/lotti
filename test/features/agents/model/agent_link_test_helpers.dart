
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_link.dart';

final hGeneratedAgentLinkBase = DateTime(2026, 5, 21, 10);

class GeneratedAgentLinkSelectionSpec {
  const GeneratedAgentLinkSelectionSpec({
    required this.createdMinuteOffset,
    required this.idSeed,
  });

  final int createdMinuteOffset;
  final int idSeed;

  String idAt(int index) => 'generated-link-$idSeed-$index';

  DateTime get createdAt =>
      hGeneratedAgentLinkBase.add(Duration(minutes: createdMinuteOffset));

  AgentLink toLink(int index) => AgentLink.agentTask(
    id: idAt(index),
    fromId: 'generated-agent-$index',
    toId: 'generated-task',
    createdAt: createdAt,
    updatedAt: createdAt,
    vectorClock: null,
  );

  @override
  String toString() {
    return 'GeneratedAgentLinkSelectionSpec('
        'createdMinuteOffset: $createdMinuteOffset, idSeed: $idSeed)';
  }
}

class GeneratedAgentLinkSelectionScenario {
  const GeneratedAgentLinkSelectionScenario({required this.links});

  final List<GeneratedAgentLinkSelectionSpec> links;

  List<AgentLink> get agentLinks =>
      links.indexed.map((entry) => entry.$2.toLink(entry.$1)).toList();

  List<String> get expectedOrderedIds {
    final indexed = links.indexed.toList()
      ..sort((a, b) {
        final byCreatedAt = b.$2.createdAt.compareTo(a.$2.createdAt);
        if (byCreatedAt != 0) return byCreatedAt;
        return b.$2.idAt(b.$1).compareTo(a.$2.idAt(a.$1));
      });
    return indexed.map((entry) => entry.$2.idAt(entry.$1)).toList();
  }

  @override
  String toString() {
    return 'GeneratedAgentLinkSelectionScenario(links: $links)';
  }
}

extension AnyGeneratedAgentLinkSelectionScenario on glados.Any {
  glados.Generator<GeneratedAgentLinkSelectionSpec> get agentLinkSpec =>
      glados.CombinableAny(this).combine2(
        glados.IntAnys(this).intInRange(-5, 5),
        glados.IntAnys(this).intInRange(0, 10000),
        (
          int createdMinuteOffset,
          int idSeed,
        ) => GeneratedAgentLinkSelectionSpec(
          createdMinuteOffset: createdMinuteOffset,
          idSeed: idSeed,
        ),
      );

  glados.Generator<GeneratedAgentLinkSelectionScenario>
  get agentLinkSelectionScenario => glados.ListAnys(this)
      .listWithLengthInRange(0, 12, agentLinkSpec)
      .map(
        (links) => GeneratedAgentLinkSelectionScenario(links: links),
      );
}
