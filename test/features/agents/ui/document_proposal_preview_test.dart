import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/document_proposal_preview.dart';

import '../../../widget_test_utils.dart';

void main() {
  const revision = {
    'documentId': 'brief',
    'title': 'Habitat brief',
    'baseVersionId': 'brief-v2',
    'markdown': '# Feeding\n\nFeed the penguins at noon.',
    'changeSummary': 'Moves feeding to noon.',
  };
  const newDocument = {
    'newTitle': 'Follow-up email',
    'markdown': 'Hi team,',
    'changeSummary': '',
  };

  Future<void> pumpButton(
    WidgetTester tester, {
    String toolName = 'propose_document_version',
    Map<String, dynamic> args = revision,
    Future<void> Function()? onConfirm,
    Future<void> Function()? onReject,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        DocumentProposalReadButton(
          toolName: toolName,
          args: args,
          onConfirm: onConfirm,
          onReject: onReject,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openPreview(WidgetTester tester) async {
    await tester.tap(find.byKey(DocumentProposalPreviewKeys.read));
    await tester.pumpAndSettle();
  }

  group('documentProposalTitle', () {
    test('names a new document by its new title', () {
      expect(documentProposalTitle(newDocument), 'Follow-up email');
    });

    test('names a revision by the title it revises', () {
      expect(documentProposalTitle(revision), 'Habitat brief');
    });

    test('is null without either', () {
      expect(documentProposalTitle(const {'newTitle': '  '}), isNull);
    });
  });

  testWidgets('shows nothing for another change', (tester) async {
    await pumpButton(tester, toolName: 'set_task_title');
    expect(find.byKey(DocumentProposalPreviewKeys.read), findsNothing);
  });

  testWidgets('shows nothing for a proposal without text', (tester) async {
    await pumpButton(
      tester,
      args: const {'newTitle': 'Brief', 'markdown': ' '},
    );
    expect(find.byKey(DocumentProposalPreviewKeys.read), findsNothing);
  });

  testWidgets('opens the proposed version: what it is, why, and its text', (
    tester,
  ) async {
    await pumpButton(tester);
    await openPreview(tester);

    expect(find.text('Habitat brief'), findsOneWidget);
    expect(find.text('Proposed new version'), findsOneWidget);
    expect(find.text('Moves feeding to noon.'), findsOneWidget);
    expect(find.textContaining('Feed the penguins at noon.'), findsOneWidget);
    // Nothing to decide from a read-only preview.
    expect(find.byKey(DocumentProposalPreviewKeys.confirm), findsNothing);
    expect(find.byKey(DocumentProposalPreviewKeys.reject), findsNothing);
  });

  testWidgets('a new document says so, and skips an empty summary', (
    tester,
  ) async {
    await pumpButton(tester, args: newDocument);
    await openPreview(tester);

    expect(find.text('Follow-up email'), findsOneWidget);
    expect(find.text('Proposed new document'), findsOneWidget);
    expect(find.textContaining('Hi team,'), findsOneWidget);
  });

  for (final confirm in [true, false]) {
    testWidgets(
      '${confirm ? 'Confirm' : 'Reject'} closes the sheet, then gives the '
      'verdict',
      (tester) async {
        final verdicts = <String>[];
        await pumpButton(
          tester,
          onConfirm: () async => verdicts.add('confirm'),
          onReject: () async => verdicts.add('reject'),
        );
        await openPreview(tester);

        await tester.tap(
          find.byKey(
            confirm
                ? DocumentProposalPreviewKeys.confirm
                : DocumentProposalPreviewKeys.reject,
          ),
        );
        await tester.pumpAndSettle();

        expect(verdicts, [if (confirm) 'confirm' else 'reject']);
        expect(find.text('Proposed new version'), findsNothing);
      },
    );
  }
}
