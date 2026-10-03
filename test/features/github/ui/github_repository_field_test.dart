import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/github/ui/github_repository_field.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

void main() {
  final field = find.byKey(const Key('github_repository_field'));

  Future<List<String?>> pump(
    WidgetTester tester, {
    String? repository,
  }) async {
    final reported = <String?>[];
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        GitHubRepositoryField(
          repository: repository,
          onChanged: reported.add,
        ),
      ),
    );
    return reported;
  }

  String fieldText(WidgetTester tester) => tester
      .widget<EditableText>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      )
      .controller
      .text;

  testWidgets('shows the stored repository', (tester) async {
    await pump(tester, repository: 'penguin/colony');
    expect(fieldText(tester), 'penguin/colony');
  });

  testWidgets(
    'reports a repository typed as a URL as owner/repo, and keeps the text '
    'as typed',
    (tester) async {
      final reported = await pump(tester);

      await tester.enterText(field, 'https://github.com/penguin/colony.git');
      await tester.pump();

      expect(reported, ['penguin/colony']);
      expect(fieldText(tester), 'https://github.com/penguin/colony.git');
    },
  );

  testWidgets(
    'flags what is not a repository and reports nothing, so the stored one '
    'stays',
    (tester) async {
      final reported = await pump(tester, repository: 'penguin/colony');

      await tester.enterText(field, 'penguin');
      await tester.pump();

      expect(reported, isEmpty);
      expect(
        find.text('Not a GitHub repository. Write owner/repo.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('clearing the field reports no repository', (tester) async {
    final reported = await pump(tester, repository: 'penguin/colony');

    await tester.enterText(field, '  ');
    await tester.pump();

    expect(reported, [null]);
  });

  testWidgets(
    'a repository changed elsewhere replaces the text, unless the typed text '
    'already reads as it',
    (tester) async {
      Widget host(String? repository) => makeTestableWidgetWithScaffold(
        GitHubRepositoryField(repository: repository, onChanged: (_) {}),
      );
      await tester.pumpWidget(host('penguin/colony'));

      await tester.pumpWidget(host('penguin/igloo'));
      expect(fieldText(tester), 'penguin/igloo');

      await tester.enterText(field, 'https://github.com/penguin/ice');
      await tester.pumpWidget(host('penguin/ice'));
      expect(fieldText(tester), 'https://github.com/penguin/ice');
    },
  );
}
