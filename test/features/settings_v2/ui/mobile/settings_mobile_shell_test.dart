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
    // Elapse the BackWidget's 1s flutter_animate fade-in so no timer is
    // left pending when the back button is shown.
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('renders the title and body', (tester) async {
    await pump(tester);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('body-content'), findsOneWidget);
  });

  testWidgets('shows no back affordance by default', (tester) async {
    await pump(tester);
    expect(find.byIcon(Icons.chevron_left), findsNothing);
  });

  testWidgets('shows a back button and invokes onBack when tapped', (
    tester,
  ) async {
    var backs = 0;
    await pump(tester, showBack: true, onBack: () => backs++);
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    await tester.tap(find.byIcon(Icons.chevron_left));
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
