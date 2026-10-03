import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/github/ui/github_repository_field.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

void main() {
  final field = find.byKey(const Key('github_repository_field'));

  late List<bool> validity;

  Future<List<String?>> pump(
    WidgetTester tester, {
    String? repository,
  }) async {
    final reported = <String?>[];
    validity = [];
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        GitHubRepositoryField(
          repository: repository,
          onChanged: reported.add,
          onValidityChanged: validity.add,
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
      expect(validity, [true]);
      expect(fieldText(tester), 'https://github.com/penguin/colony.git');
    },
  );

  testWidgets(
    'flags what is not a repository and reports nothing, so the stored one '
    'stays, but tells the form the text is invalid',
    (tester) async {
      final reported = await pump(tester, repository: 'penguin/colony');

      await tester.enterText(field, 'penguin');
      await tester.pump();

      expect(reported, isEmpty);
      expect(validity, [false]);
      expect(
        find.text('Not a GitHub repository. Write owner/repo.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('clearing the field reports no repository', (tester) async {
    final reported = await pump(tester, repository: 'penguin/colony');

    await tester.enterText(field, 'penguin');
    await tester.enterText(field, '  ');
    await tester.pump();

    expect(reported, [null]);
    expect(validity, [false, true]);
  });

  testWidgets(
    'a repository changed elsewhere replaces the text, unless the typed text '
    'already reads as it',
    (tester) async {
      Widget host(String? repository) => makeTestableWidgetWithScaffold(
        GitHubRepositoryField(
          repository: repository,
          onChanged: (_) {},
          onValidityChanged: (_) {},
        ),
      );
      await tester.pumpWidget(host('penguin/colony'));

      await tester.pumpWidget(host('penguin/igloo'));
      expect(fieldText(tester), 'penguin/igloo');

      await tester.enterText(field, 'https://github.com/penguin/ice');
      await tester.pumpWidget(host('penguin/ice'));
      expect(fieldText(tester), 'https://github.com/penguin/ice');
    },
  );

  testWidgets(
    'invalid text replaced by a repository changed elsewhere is valid again, '
    'reported after the frame rather than during the parent build',
    (tester) async {
      final reports = <bool>[];
      Widget host(String? repository) => makeTestableWidgetWithScaffold(
        GitHubRepositoryField(
          repository: repository,
          onChanged: (_) {},
          onValidityChanged: reports.add,
        ),
      );
      await tester.pumpWidget(host('penguin/colony'));
      await tester.enterText(field, 'penguin');
      await tester.pump();
      expect(reports, [false]);

      await tester.pumpWidget(host('penguin/igloo'));
      expect(fieldText(tester), 'penguin/igloo');
      expect(
        find.text('Not a GitHub repository. Write owner/repo.'),
        findsNothing,
      );
      expect(reports, [false, true]);

      // A further external change, with the text valid, reports nothing.
      await tester.pumpWidget(host('penguin/ice'));
      expect(reports, [false, true]);
    },
  );

  testWidgets(
    'a field removed while invalid reports valid, so the form is not left '
    'unable to save with nothing on screen saying why',
    (tester) async {
      final reports = <bool>[];
      Widget host({required bool shown}) => makeTestableWidgetWithScaffold(
        shown
            ? GitHubRepositoryField(
                repository: null,
                onChanged: (_) {},
                onValidityChanged: reports.add,
              )
            : const SizedBox.shrink(),
      );
      await tester.pumpWidget(host(shown: true));
      await tester.enterText(field, 'penguin');
      await tester.pump();

      await tester.pumpWidget(host(shown: false));
      await tester.pump();

      expect(reports, [false, true]);
    },
  );

  testWidgets('a field removed while valid reports nothing more', (
    tester,
  ) async {
    final reports = <bool>[];
    Widget host({required bool shown}) => makeTestableWidgetWithScaffold(
      shown
          ? GitHubRepositoryField(
              repository: null,
              onChanged: (_) {},
              onValidityChanged: reports.add,
            )
          : const SizedBox.shrink(),
    );
    await tester.pumpWidget(host(shown: true));
    await tester.enterText(field, 'penguin/colony');
    await tester.pump();

    await tester.pumpWidget(host(shown: false));
    await tester.pump();

    expect(reports, [true]);
  });
}
