import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/settings_v2/ui/mobile/settings_mobile_shell.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    bool showBack = false,
    VoidCallback? onBack,
    List<Widget>? actions,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        SettingsMobileShell(
          title: 'Settings',
          showBack: showBack,
          onBack: onBack,
          actions: actions,
          child: const Text('body-content'),
        ),
      ),
    );
  }

  testWidgets('renders the title and body', (tester) async {
    await pump(tester);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('body-content'), findsOneWidget);
  });

  testWidgets('shows no back affordance by default', (tester) async {
    await pump(tester);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
  });

  testWidgets('shows a back button and invokes onBack when tapped', (
    tester,
  ) async {
    var backs = 0;
    await pump(tester, showBack: true, onBack: () => backs++);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pump();
    expect(backs, 1);
  });

  testWidgets('renders trailing actions', (tester) async {
    await pump(
      tester,
      actions: const [Icon(Icons.search_rounded)],
    );
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
  });
}
