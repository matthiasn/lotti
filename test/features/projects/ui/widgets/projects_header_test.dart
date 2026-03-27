import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/projects/ui/widgets/projects_header.dart';
import 'package:lotti/themes/theme.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Widget pumpHeader({
    String title = 'Projects',
    bool centerTitle = false,
    Widget? titleTrailing,
    Widget? searchTrailing,
  }) {
    return makeTestableWidgetWithScaffold(
      ProjectsHeader(
        title: title,
        centerTitle: centerTitle,
        titleTrailing: titleTrailing,
        searchTrailing: searchTrailing,
      ),
      theme: withOverrides(ThemeData.dark(useMaterial3: true)),
    );
  }

  group('ProjectsHeader', () {
    testWidgets('renders title text and search field', (tester) async {
      await tester.pumpWidget(pumpHeader());
      await tester.pump();

      expect(find.text('Projects'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets(
      'renders centered heading1 text when centerTitle is true '
      'and titleTrailing is null',
      (tester) async {
        await tester.pumpWidget(
          pumpHeader(title: 'Centered Title', centerTitle: true),
        );
        await tester.pump();

        expect(find.text('Centered Title'), findsOneWidget);
        expect(find.byType(Center), findsWidgets);

        // The title should be inside a Center widget, not inside a Row
        final centerFinder = find.ancestor(
          of: find.text('Centered Title'),
          matching: find.byType(Center),
        );
        expect(centerFinder, findsWidgets);
      },
    );

    testWidgets('renders searchTrailing widget when provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        pumpHeader(
          searchTrailing: const Icon(
            Icons.tune_rounded,
            key: Key('search-trailing'),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('search-trailing')), findsOneWidget);
    });
  });
}
