import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/gradient_themes.dart';

void main() {
  // GradientThemes is a thin delegation layer over ModernGradientThemes
  // (lib/themes/colors.dart). The behavior worth pinning is that each wrapper
  // forwards to the matching ModernGradientThemes builder for the active
  // brightness, so the assertions compare the wrapper output to the delegate
  // output captured from the same BuildContext.
  Future<void> pumpAndCompare(
    WidgetTester tester, {
    required Brightness brightness,
    required void Function(BuildContext context) verify,
  }) async {
    late BuildContext capturedContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    verify(capturedContext);
  }

  for (final brightness in Brightness.values) {
    group('GradientThemes (${brightness.name})', () {
      testWidgets('cardGradient delegates to ModernGradientThemes', (
        tester,
      ) async {
        await pumpAndCompare(
          tester,
          brightness: brightness,
          verify: (context) {
            expect(
              GradientThemes.cardGradient(context),
              equals(ModernGradientThemes.cardGradient(context)),
            );
          },
        );
      });

      testWidgets('primaryGradient delegates to ModernGradientThemes', (
        tester,
      ) async {
        await pumpAndCompare(
          tester,
          brightness: brightness,
          verify: (context) {
            expect(
              GradientThemes.primaryGradient(context),
              equals(ModernGradientThemes.primaryGradient(context)),
            );
          },
        );
      });

      testWidgets('accentGradient delegates to ModernGradientThemes', (
        tester,
      ) async {
        await pumpAndCompare(
          tester,
          brightness: brightness,
          verify: (context) {
            expect(
              GradientThemes.accentGradient(context),
              equals(ModernGradientThemes.accentGradient(context)),
            );
          },
        );
      });

      testWidgets('backgroundGradient delegates to ModernGradientThemes', (
        tester,
      ) async {
        await pumpAndCompare(
          tester,
          brightness: brightness,
          verify: (context) {
            expect(
              GradientThemes.backgroundGradient(context),
              equals(ModernGradientThemes.backgroundGradient(context)),
            );
          },
        );
      });
    });
  }
}
