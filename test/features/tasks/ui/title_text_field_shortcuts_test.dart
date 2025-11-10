import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/ui/title_text_field.dart';
import 'package:lotti/l10n/app_localizations.dart';

void main() {
  testWidgets('TitleTextField saves on Ctrl+S and keeps focus', (tester) async {
    final focusNode = FocusNode();
    final saved = <String?>[];

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: TitleTextField(
              focusNode: focusNode,
              keepFocusOnSave: true,
              clearOnSave: true,
              onSave: saved.add,
            ),
          ),
        ),
      ),
    );

    // Focus the field and enter text
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(focusNode.hasFocus, isTrue);
    await tester.enterText(find.byType(TextField), 'foo');

    // Send Ctrl+S (platform-agnostic path)
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();

    expect(saved.length, 1);
    expect(focusNode.hasFocus, isTrue,
        reason: 'Focus should be retained after save');
  });
}
