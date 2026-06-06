import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/error_banner.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  Future<void> pumpBanner(
    WidgetTester tester, {
    required VoidCallback onRetry,
    required VoidCallback onDismiss,
    String error = 'Something went wrong',
  }) {
    return tester.pumpWidget(
      makeTestableWidget(
        ErrorBanner(
          error: error,
          onRetry: onRetry,
          onDismiss: onDismiss,
        ),
      ),
    );
  }

  group('ErrorBanner', () {
    testWidgets('displays the error text in an error-styled container', (
      tester,
    ) async {
      await pumpBanner(
        tester,
        error: 'Network unreachable',
        onRetry: () {},
        onDismiss: () {},
      );

      expect(find.text('Network unreachable'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(ErrorBanner),
          matching: find.byType(Container),
        ),
      );
      final theme = Theme.of(tester.element(find.byType(ErrorBanner)));
      expect(
        (container.decoration! as BoxDecoration).color,
        theme.colorScheme.errorContainer,
      );
    });

    testWidgets('Retry button triggers onRetry only', (tester) async {
      var retries = 0;
      var dismissals = 0;
      await pumpBanner(
        tester,
        onRetry: () => retries++,
        onDismiss: () => dismissals++,
      );

      await tester.tap(find.text('Retry'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(retries, 1);
      expect(dismissals, 0);
    });

    testWidgets('Close button triggers onDismiss only', (tester) async {
      var retries = 0;
      var dismissals = 0;
      await pumpBanner(
        tester,
        onRetry: () => retries++,
        onDismiss: () => dismissals++,
      );

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump(const Duration(milliseconds: 300));

      expect(dismissals, 1);
      expect(retries, 0);
    });
  });
}
