import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

Future<void> _pumpToast(
  WidgetTester tester, {
  required DesignSystemToastTone tone,
  String title = 'Title',
  String? description = 'Notification details',
  ToastAction? action,
  VoidCallback? onDismiss,
  String? dismissSemanticsLabel,
  Duration? countdownDuration,
  double initialCountdownProgress = 1.0,
  double width = 320,
  MediaQueryData? mediaQueryData,
}) {
  return tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      SizedBox(
        width: width,
        child: DesignSystemToast(
          tone: tone,
          title: title,
          description: description,
          action: action,
          onDismiss: onDismiss,
          dismissSemanticsLabel: dismissSemanticsLabel,
          countdownDuration: countdownDuration,
          initialCountdownProgress: initialCountdownProgress,
        ),
      ),
      theme: DesignSystemTheme.light(),
      mediaQueryData: mediaQueryData,
    ),
  );
}

Color _toastBorderColor(WidgetTester tester) {
  final decorated = tester
      .widgetList<DecoratedBox>(find.byType(DecoratedBox))
      .firstWhere(
        (widget) {
          final decoration = widget.decoration;
          return decoration is BoxDecoration && decoration.border != null;
        },
      );
  return ((decorated.decoration as BoxDecoration).border! as Border).top.color;
}

void main() {
  group('DesignSystemToast', () {
    testWidgets('top-aligns leading icon, title, and dismiss action', (
      tester,
    ) async {
      await _pumpToast(
        tester,
        tone: DesignSystemToastTone.success,
        title: 'Success',
        onDismiss: () {},
      );

      final leadingIconTop = tester
          .getTopLeft(find.byIcon(Icons.check_circle_rounded))
          .dy;
      final titleTop = tester.getTopLeft(find.text('Success')).dy;
      final dismissIconTop = tester
          .getTopLeft(find.byIcon(Icons.close_rounded))
          .dy;

      expect(
        leadingIconTop,
        titleTop,
        reason: 'leading icon must share its top edge with the title',
      );
      expect(
        dismissIconTop,
        titleTop,
        reason: 'dismiss action must be top-aligned with the title',
      );
    });

    testWidgets('invokes onDismiss when the dismiss action is tapped', (
      tester,
    ) async {
      var dismissed = false;

      await _pumpToast(
        tester,
        tone: DesignSystemToastTone.success,
        onDismiss: () => dismissed = true,
      );

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      expect(dismissed, isTrue);
    });

    testWidgets('hides the dismiss icon when onDismiss is null', (
      tester,
    ) async {
      await _pumpToast(tester, tone: DesignSystemToastTone.warning);

      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    final toneCases = <(DesignSystemToastTone, IconData, Color)>[
      (
        DesignSystemToastTone.success,
        Icons.check_circle_rounded,
        dsTokensLight.colors.alert.success.defaultColor,
      ),
      (
        DesignSystemToastTone.warning,
        Icons.warning_rounded,
        dsTokensLight.colors.alert.warning.defaultColor,
      ),
      (
        DesignSystemToastTone.error,
        Icons.error_rounded,
        dsTokensLight.colors.alert.error.defaultColor,
      ),
    ];

    for (final (tone, icon, tokenColor) in toneCases) {
      testWidgets('tone $tone renders styling and border from tokens', (
        tester,
      ) async {
        await _pumpToast(tester, tone: tone);

        expect(find.byIcon(icon), findsOneWidget);

        final title = tester.widget<Text>(find.text('Title'));
        final description = tester.widget<Text>(
          find.text('Notification details'),
        );

        expect(title.style?.fontSize, dsTokensLight.typography.size.subtitle2);
        expect(title.style?.color, dsTokensLight.colors.text.highEmphasis);
        expect(
          description.style?.fontSize,
          dsTokensLight.typography.size.caption,
        );
        expect(
          description.style?.color,
          dsTokensLight.colors.text.mediumEmphasis,
        );

        expect(_toastBorderColor(tester), tokenColor);
      });
    }

    testWidgets('title + description are announced as a live region', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();

      await _pumpToast(
        tester,
        tone: DesignSystemToastTone.success,
        title: 'Saved',
        description: 'Your changes are live',
      );

      final toastSemantics = tester.getSemantics(
        find.byType(DesignSystemToast),
      );
      expect(toastSemantics.label, contains('Saved'));
      expect(toastSemantics.label, contains('Your changes are live'));

      semantics.dispose();
    });

    testWidgets('respects custom dismissSemanticsLabel', (tester) async {
      final semantics = tester.ensureSemantics();

      await _pumpToast(
        tester,
        tone: DesignSystemToastTone.error,
        onDismiss: () {},
        dismissSemanticsLabel: 'Close error toast',
      );

      final dismissSemantics = tester.getSemantics(
        find.byIcon(Icons.close_rounded),
      );
      expect(dismissSemantics.label, contains('Close error toast'));

      semantics.dispose();
    });

    testWidgets('keeps the 56px minimum height at default text scale', (
      tester,
    ) async {
      await _pumpToast(tester, tone: DesignSystemToastTone.success);

      final toastSize = tester.getSize(find.byType(DesignSystemToast));
      expect(toastSize.height, 56);
    });

    testWidgets('grows beyond 56px when system text scale increases', (
      tester,
    ) async {
      await _pumpToast(
        tester,
        tone: DesignSystemToastTone.success,
        mediaQueryData: const MediaQueryData(
          size: Size(390, 844),
          textScaler: TextScaler.linear(2.5),
        ),
      );

      final toastSize = tester.getSize(find.byType(DesignSystemToast));
      expect(
        toastSize.height,
        greaterThan(56),
        reason: 'minHeight must let content expand under accessibility scaling',
      );
    });

    testWidgets('matches Figma inner padding and content spacing', (
      tester,
    ) async {
      await _pumpToast(
        tester,
        tone: DesignSystemToastTone.success,
        onDismiss: () {},
      );

      // The leading icon sits after the stripe and the inner frame padding.
      final stripeWidth = dsTokensLight.spacing.step3;
      final innerPadding = dsTokensLight.spacing.step3;
      final toastLeft = tester.getTopLeft(find.byType(DesignSystemToast)).dx;
      final iconLeft = tester
          .getTopLeft(find.byIcon(Icons.check_circle_rounded))
          .dx;
      expect(
        iconLeft - toastLeft,
        stripeWidth + innerPadding,
        reason: 'icon offset = stripe width + inner frame padding',
      );

      // Title and description are separated by spacing.step2.
      final titleBottom = tester.getBottomLeft(find.text('Title')).dy;
      final descTop = tester.getTopLeft(find.text('Notification details')).dy;
      expect(
        descTop - titleBottom,
        dsTokensLight.spacing.step2,
        reason: 'title → description gap is spacing.step2',
      );
    });

    group('title-only variant', () {
      testWidgets('omits the description row when description is null', (
        tester,
      ) async {
        await _pumpToast(
          tester,
          tone: DesignSystemToastTone.success,
          title: 'Saved',
          description: null,
        );

        expect(find.text('Saved'), findsOneWidget);
        expect(find.text('Notification details'), findsNothing);
      });

      testWidgets(
        'treats an empty-or-whitespace description as absent',
        (tester) async {
          final semantics = tester.ensureSemantics();

          await _pumpToast(
            tester,
            tone: DesignSystemToastTone.success,
            title: 'Saved',
            // Whitespace-only description must behave like null: no second
            // line, and the semantics label must not end with a stray `. `.
            description: '   ',
          );

          // No blank second-line Text is rendered — the toast keeps its
          // minimum 56px height and single-line layout.
          final toastSize = tester.getSize(find.byType(DesignSystemToast));
          expect(toastSize.height, 56);

          final toastSemantics = tester.getSemantics(
            find.byType(DesignSystemToast),
          );
          expect(toastSemantics.label, contains('Saved'));
          // No stray ". " fragment from a blank description.
          expect(toastSemantics.label, isNot(contains('. ')));

          semantics.dispose();
        },
      );

      testWidgets(
        'centers icon, title, and dismiss vertically in the 56px box',
        (tester) async {
          await _pumpToast(
            tester,
            tone: DesignSystemToastTone.success,
            title: 'Saved',
            description: null,
            onDismiss: () {},
          );

          final toastCenter = tester
              .getCenter(find.byType(DesignSystemToast))
              .dy;
          final iconCenter = tester
              .getCenter(find.byIcon(Icons.check_circle_rounded))
              .dy;
          final titleCenter = tester.getCenter(find.text('Saved')).dy;
          final dismissCenter = tester
              .getCenter(find.byIcon(Icons.close_rounded))
              .dy;

          // Allow sub-pixel rounding tolerance; the three elements must sit
          // on the same vertical axis in the single-line case.
          expect((iconCenter - titleCenter).abs(), lessThan(1));
          expect((dismissCenter - titleCenter).abs(), lessThan(1));
          // And that axis is the vertical center of the toast box.
          expect((titleCenter - toastCenter).abs(), lessThan(1));
        },
      );

      testWidgets('announces title only in the semantics label', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();

        await _pumpToast(
          tester,
          tone: DesignSystemToastTone.success,
          title: 'Saved',
          description: null,
        );

        final toastSemantics = tester.getSemantics(
          find.byType(DesignSystemToast),
        );
        expect(toastSemantics.label, contains('Saved'));
        expect(toastSemantics.label, isNot(contains('null')));
        expect(toastSemantics.label, isNot(contains('. ')));

        semantics.dispose();
      });

      testWidgets('still honors the 56px minimum height', (tester) async {
        await _pumpToast(
          tester,
          tone: DesignSystemToastTone.success,
          description: null,
        );

        final toastSize = tester.getSize(find.byType(DesignSystemToast));
        expect(toastSize.height, 56);
      });
    });

    group('action button', () {
      testWidgets('renders the action label and invokes onPressed on tap', (
        tester,
      ) async {
        var taps = 0;
        await _pumpToast(
          tester,
          tone: DesignSystemToastTone.warning,
          title: 'Item deleted',
          description: null,
          action: ToastAction(
            label: 'UNDO',
            onPressed: () => taps++,
          ),
        );

        expect(find.text('UNDO'), findsOneWidget);
        await tester.tap(find.text('UNDO'));
        await tester.pump();
        expect(taps, 1);
      });

      testWidgets('action and dismiss can coexist in the trailing slot', (
        tester,
      ) async {
        await _pumpToast(
          tester,
          tone: DesignSystemToastTone.success,
          action: ToastAction(label: 'UNDO', onPressed: () {}),
          onDismiss: () {},
        );

        expect(find.text('UNDO'), findsOneWidget);
        expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      });

      testWidgets('action label inherits the tone border color', (
        tester,
      ) async {
        await _pumpToast(
          tester,
          tone: DesignSystemToastTone.error,
          description: null,
          action: ToastAction(label: 'RETRY', onPressed: () {}),
        );

        final actionText = tester.widget<Text>(find.text('RETRY'));
        expect(
          actionText.style?.color,
          dsTokensLight.colors.alert.error.defaultColor,
          reason:
              'action label uses the tone border color so the CTA reads '
              'as part of the toast tone, not as a generic link',
        );
      });

      testWidgets('semanticsLabel override is honored', (tester) async {
        final semantics = tester.ensureSemantics();
        await _pumpToast(
          tester,
          tone: DesignSystemToastTone.warning,
          description: null,
          action: ToastAction(
            label: 'UNDO',
            semanticsLabel: 'Undo deletion of checklist item',
            onPressed: () {},
          ),
        );

        final actionSemantics = tester.getSemantics(find.text('UNDO'));
        expect(
          actionSemantics.label,
          contains('Undo deletion of checklist item'),
        );

        semantics.dispose();
      });
    });

    group('countdown bar', () {
      testWidgets('renders a LinearProgressIndicator when countdown is set', (
        tester,
      ) async {
        await _pumpToast(
          tester,
          tone: DesignSystemToastTone.warning,
          description: null,
          countdownDuration: const Duration(seconds: 5),
        );

        expect(find.byType(LinearProgressIndicator), findsOneWidget);
      });

      testWidgets('omits the LinearProgressIndicator when countdown is null', (
        tester,
      ) async {
        await _pumpToast(
          tester,
          tone: DesignSystemToastTone.success,
          description: null,
        );

        expect(find.byType(LinearProgressIndicator), findsNothing);
      });

      testWidgets('drains from initial progress toward zero', (tester) async {
        await _pumpToast(
          tester,
          tone: DesignSystemToastTone.warning,
          description: null,
          countdownDuration: const Duration(seconds: 4),
        );

        final initial = tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value!;
        await tester.pump(const Duration(seconds: 2));
        final mid = tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value!;
        expect(
          mid,
          lessThan(initial),
          reason: 'progress must shrink as the countdown drains',
        );

        // Cleanup: advance past the duration so the controller settles.
        await tester.pump(const Duration(seconds: 3));
      });

      testWidgets('respects initialCountdownProgress < 1.0', (tester) async {
        await _pumpToast(
          tester,
          tone: DesignSystemToastTone.warning,
          description: null,
          countdownDuration: const Duration(seconds: 10),
          initialCountdownProgress: 0.4,
        );

        final progress = tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value!;
        expect(progress, closeTo(0.4, 0.05));

        await tester.pump(const Duration(seconds: 11));
      });

      testWidgets('uses the tone color for the progress fill', (tester) async {
        await _pumpToast(
          tester,
          tone: DesignSystemToastTone.error,
          description: null,
          countdownDuration: const Duration(seconds: 3),
        );

        final indicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        expect(
          indicator.valueColor?.value,
          dsTokensLight.colors.alert.error.defaultColor,
        );

        await tester.pump(const Duration(seconds: 4));
      });
    });
  });
}
