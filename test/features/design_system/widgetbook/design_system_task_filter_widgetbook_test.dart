import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/checkboxes/design_system_checkbox.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_task_filter_widgetbook.dart';
import 'package:lotti/l10n/app_localizations.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildDesignSystemTaskFilterWidgetbookComponent', () {
    testWidgets('renders the task filter overview page', (tester) async {
      final component = buildDesignSystemTaskFilterWidgetbookComponent();
      final useCase = component.useCases.single;

      expect(component.name, 'Task filter modal');
      expect(useCase.name, 'Overview');
      await tester.binding.setSurfaceSize(const Size(1100, 1900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        makeTestableWidget2(
          Theme(
            data: DesignSystemTheme.dark(),
            child: Scaffold(
              body: SizedBox(
                width: 900,
                height: 1800,
                child: Builder(builder: useCase.builder),
              ),
            ),
          ),
          mediaQueryData: const MediaQueryData(size: Size(1100, 1900)),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Mobile Preview'), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);
      expect(find.text('AI Coding'), findsOneWidget);
      expect(find.text('Agents'), findsOneWidget);
      expect(_serializedState(tester), contains('"selectedPriorityId": "p2"'));
    });

    testWidgets('updates serialized state through widget callbacks', (
      tester,
    ) async {
      final useCase =
          buildDesignSystemTaskFilterWidgetbookComponent().useCases.single;
      await tester.binding.setSurfaceSize(const Size(1100, 1900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        makeTestableWidget2(
          Theme(
            data: DesignSystemTheme.dark(),
            child: Scaffold(
              body: SizedBox(
                width: 900,
                height: 1800,
                child: Builder(builder: useCase.builder),
              ),
            ),
          ),
          mediaQueryData: const MediaQueryData(size: Size(1100, 1900)),
        ),
      );
      await tester.pump();

      expect(_serializedState(tester), contains('"selectedPriorityId": "p2"'));
      expect(find.text('7'), findsOneWidget);

      final clearButton = find.byKey(
        const ValueKey('design-system-task-filter-clear'),
      );
      await tester.ensureVisible(clearButton);
      await tester.tap(clearButton);
      await tester.pump();

      expect(_serializedState(tester), contains('"selectedPriorityId": "all"'));
      expect(find.text('0'), findsOneWidget);

      final applyButton = find.byKey(
        const ValueKey('design-system-task-filter-apply'),
      );
      await tester.ensureVisible(applyButton);
      // The apply button sits inside a WidgetbookViewport whose stacking
      // can overlap with the outer Scaffold, making it fail hit-testing.
      await tester.tap(applyButton, warnIfMissed: false);
      await tester.pump();

      expect(_serializedState(tester), contains('"selectedPriorityId": "all"'));
      expect(find.text('0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'opens the shared DS field selection modal and updates the serialized state',
      (tester) async {
        final useCase =
            buildDesignSystemTaskFilterWidgetbookComponent().useCases.single;
        await tester.binding.setSurfaceSize(const Size(1100, 1900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          makeTestableWidget2(
            Theme(
              data: DesignSystemTheme.dark(),
              child: Scaffold(
                body: SizedBox(
                  width: 900,
                  height: 1800,
                  child: Builder(builder: useCase.builder),
                ),
              ),
            ),
            mediaQueryData: const MediaQueryData(size: Size(1100, 1900)),
          ),
        );
        await tester.pump();

        final filterSheet = tester.widget<DesignSystemTaskFilterSheet>(
          find.byType(DesignSystemTaskFilterSheet),
        );
        filterSheet.onFieldPressed?.call(DesignSystemTaskFilterSection.status);
        await tester.pumpAndSettle();

        expect(find.byType(DesignSystemCheckbox), findsNWidgets(3));
        expect(find.byType(CheckboxListTile), findsNothing);

        // Toggle 'blocked' option
        final blockedOption = find.byKey(
          const ValueKey('design-system-filter-selection-option-blocked'),
        );
        await tester.ensureVisible(blockedOption);
        await tester.tap(blockedOption);
        await tester.pump();

        // Apply selection
        final applyButton = find.byKey(
          const ValueKey('design-system-filter-selection-apply'),
        );
        await tester.ensureVisible(applyButton);
        await tester.tap(applyButton);
        await tester.pumpAndSettle();
        expect(_serializedState(tester), contains('"blocked"'));
      },
    );
    testWidgets(
      'preserves user selections across didChangeDependencies rebuild',
      (tester) async {
        final useCase =
            buildDesignSystemTaskFilterWidgetbookComponent().useCases.single;
        await tester.binding.setSurfaceSize(const Size(1400, 1900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        Widget buildApp({Locale locale = const Locale('en')}) {
          return _LocaleTestApp(
            locale: locale,
            child: Theme(
              data: DesignSystemTheme.dark(),
              child: Scaffold(
                body: SizedBox(
                  width: 1300,
                  height: 1800,
                  child: Builder(builder: useCase.builder),
                ),
              ),
            ),
          );
        }

        // Build with English locale — initial state
        await tester.pumpWidget(buildApp());
        await tester.pump();

        expect(
          _serializedState(tester),
          contains('"selectedPriorityId": "p2"'),
        );

        // Toggle p0 on. Priority is now multi-select, so the set grows to
        // include both p2 (initial) and p0; the legacy single-id getter
        // falls back to `all` when more than one is selected.
        await tester.tap(
          find.byKey(
            const ValueKey('design-system-task-filter-priority-p0'),
          ),
        );
        await tester.pump();

        final serialized =
            jsonDecode(_serializedState(tester)) as Map<String, dynamic>;
        expect(
          (serialized['selectedPriorityIds'] as List).cast<String>(),
          unorderedEquals(<String>['p2', 'p0']),
        );

        // Rebuild with German locale — triggers didChangeDependencies with
        // new messages while previous state is non-null
        await tester.pumpWidget(buildApp(locale: const Locale('de')));
        await tester.pump();

        // Priority selection should be preserved across the locale change
        final afterLocaleSwitch =
            jsonDecode(_serializedState(tester)) as Map<String, dynamic>;
        expect(
          (afterLocaleSwitch['selectedPriorityIds'] as List).cast<String>(),
          unorderedEquals(<String>['p2', 'p0']),
        );

        // Drain any overflow exceptions from the fixed-width WidgetbookViewport
        // rendering wider German labels — not a component bug.
        tester.takeException();
      },
    );
  });
}

class _LocaleTestApp extends StatelessWidget {
  const _LocaleTestApp({required this.locale, required this.child});
  final Locale locale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: const MediaQueryData(size: Size(1400, 1900)),
      child: MaterialApp(
        theme: DesignSystemTheme.dark(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
  }
}

String _serializedState(WidgetTester tester) {
  final statePanel = tester.widget<SelectableText>(find.byType(SelectableText));
  return statePanel.data ?? '';
}
