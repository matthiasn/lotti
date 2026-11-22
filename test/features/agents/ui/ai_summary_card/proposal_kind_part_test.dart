import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/proposal_kind_part.dart';

void main() {
  test('a proposed new document is an addition, a new version an update', () {
    expect(
      resolveKind(TaskAgentToolNames.proposeDocumentVersion, const {
        'newTitle': 'Meeting summary',
      }),
      ProposalKind.add,
    );
    expect(
      resolveKind(TaskAgentToolNames.proposeDocumentVersion, const {
        'documentId': 'doc-1',
        'title': 'Launch brief',
      }),
      ProposalKind.update,
    );
  });
}
