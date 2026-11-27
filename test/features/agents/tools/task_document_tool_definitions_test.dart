import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';

void main() {
  AgentToolDefinition toolNamed(String name) =>
      AgentToolRegistry.taskAgentTools.singleWhere((t) => t.name == name);

  group('read_document', () {
    final tool = toolNamed(TaskAgentToolNames.readDocument);

    test('takes exactly a document id, and is read-only', () {
      expect(tool.parameters['required'], ['documentId']);
      expect((tool.parameters['properties'] as Map).keys, ['documentId']);
      expect(tool.parameters['additionalProperties'], isFalse);
      expect(tool.description, startsWith('Read-only.'));
      expect(
        AgentToolRegistry.deferredTools,
        isNot(contains(TaskAgentToolNames.readDocument)),
      );
    });
  });

  group('write_document_version', () {
    final tool = toolNamed(TaskAgentToolNames.writeDocumentVersion);

    test(
      'requires the whole text and its summary; the document or a new title '
      'is the handler’s check, never a schema guess',
      () {
        expect(tool.parameters['required'], ['markdown', 'changeSummary']);
        expect((tool.parameters['properties'] as Map).keys, [
          'documentId',
          'newTitle',
          'markdown',
          'changeSummary',
        ]);
        expect(tool.parameters['additionalProperties'], isFalse);
      },
    );

    test(
      'writes at once, and says so: only when the user asked, never because '
      'new material arrived',
      () {
        expect(
          AgentToolRegistry.deferredTools,
          isNot(contains(TaskAgentToolNames.writeDocumentVersion)),
        );
        expect(tool.description, contains('Only when the user asked'));
        expect(tool.description, contains('never because new material'));
        expect(tool.description, contains('with no confirmation'));
        expect(tool.description, contains('stay in its history'));
      },
    );
  });
}
