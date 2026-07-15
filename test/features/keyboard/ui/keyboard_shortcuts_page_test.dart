import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/keyboard/ui/keyboard_shortcuts_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../widget_test_utils.dart';

void main() {
  testWidgets('persistent page documents and filters shortcuts', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const KeyboardShortcutsPage(),
        mediaQueryData: const MediaQueryData(size: Size(1000, 800)),
      ),
    );
    final messages = tester
        .element(find.byType(KeyboardShortcutsPage))
        .messages;

    expect(find.text(messages.keyboardShortcutsTitle), findsWidgets);
    expect(find.text(messages.keyboardShortcutsSubtitle), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'rename');
    await tester.pump();
    expect(find.text(messages.keyboardCommandRename), findsOneWidget);
    expect(find.text(messages.fileMenuNewTask), findsNothing);
  });
}
