import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/sync/ui/widgets/sync_list_scaffold.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/l10n/app_localizations_en.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/widgets/ui/empty_state_widget.dart';

import '../../../../widget_test_utils.dart';

// ---------------------------------------------------------------------------
// Shared test helpers
// ---------------------------------------------------------------------------

enum _TestFilter {
  pending,
  error,
}

class _TestItem {
  const _TestItem({
    required this.label,
    required this.hasError,
  });

  final String label;
  final bool hasError;
}

Map<_TestFilter, SyncFilterOption<_TestItem>> _buildFilters() {
  return {
    _TestFilter.pending: SyncFilterOption<_TestItem>(
      labelBuilder: (context) => context.messages.outboxMonitorLabelPending,
      predicate: (_) => true,
      icon: Icons.schedule_rounded,
    ),
    _TestFilter.error: SyncFilterOption<_TestItem>(
      labelBuilder: (context) => context.messages.outboxMonitorLabelError,
      predicate: (item) => item.hasError,
      icon: Icons.error_outline_rounded,
    ),
  };
}

String _formattedLabel({
  required AppLocalizations l10n,
  required String label,
}) {
  return toBeginningOfSentenceCase(label, l10n.localeName) ?? label;
}

/// Pumps a [SyncListScaffold] wrapped in the minimal [MaterialApp] shell.
///
/// Set [viewportWidth] to control the surface size for responsive tests.
/// Returns the [StreamController] so callers can push items.
Future<StreamController<List<_TestItem>>> _pumpScaffold(
  WidgetTester tester, {
  Map<_TestFilter, SyncFilterOption<_TestItem>>? filters,
  Widget? headerSliver,
  _TestFilter? initialFilter,
  double viewportWidth = 390,
  double viewportHeight = 844,
  bool useViewSize = false,
}) async {
  final controller = StreamController<List<_TestItem>>();

  if (useViewSize) {
    tester.view.physicalSize = Size(viewportWidth, viewportHeight);
    tester.view.devicePixelRatio = 1.0;
  }

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: useViewSize
          ? SyncListScaffold<_TestItem, _TestFilter>(
              title: 'Sync UI',
              stream: controller.stream,
              filters: filters ?? _buildFilters(),
              headerSliver: headerSliver,
              itemBuilder: (context, item) => ListTile(
                title: Text(item.label),
              ),
              emptyIcon: Icons.hourglass_empty,
              emptyTitleBuilder: (ctx) => 'Nothing here',
              emptyDescriptionBuilder: (_) => null,
              countSummaryBuilder: (ctx, label, count) =>
                  ctx.messages.syncListCountSummary(label, count),
              initialFilter: initialFilter ?? _TestFilter.pending,
              backButton: false,
            )
          : MediaQuery(
              data: MediaQueryData(
                size: Size(viewportWidth, viewportHeight),
                padding: const EdgeInsets.only(top: 47),
              ),
              child: SyncListScaffold<_TestItem, _TestFilter>(
                title: 'Sync UI',
                subtitle: 'Subtitle copy',
                stream: controller.stream,
                filters: filters ?? _buildFilters(),
                headerSliver: headerSliver,
                itemBuilder: (context, item) => ListTile(
                  title: Text(item.label),
                ),
                emptyIcon: Icons.hourglass_empty,
                emptyTitleBuilder: (ctx) => 'Nothing here',
                emptyDescriptionBuilder: (_) => null,
                countSummaryBuilder: (ctx, label, count) =>
                    ctx.messages.syncListCountSummary(label, count),
                initialFilter: initialFilter ?? _TestFilter.pending,
                backButton: false,
              ),
            ),
    ),
  );

  return controller;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => setUpTestGetIt(
        additionalSetup: () {
          getIt.registerSingleton<UserActivityService>(UserActivityService());
        },
      ));
  tearDown(tearDownTestGetIt);

  group('SyncListScaffold', () {
    testWidgets(
      'renders filters, summaries, loading, and empty states',
      (tester) async {
        final controller = await _pumpScaffold(tester);
        addTearDown(controller.close);
        final l10n = AppLocalizationsEn();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        final items = [
          const _TestItem(label: 'Pending item', hasError: false),
          const _TestItem(label: 'Error item', hasError: true),
        ];
        controller.add(items);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        final pendingSummary = l10n.syncListCountSummary(
          _formattedLabel(
            l10n: l10n,
            label: l10n.outboxMonitorLabelPending,
          ),
          items.length,
        );
        expect(find.text(pendingSummary), findsOneWidget);
        expect(
          find.text(
            _formattedLabel(
              l10n: l10n,
              label: l10n.outboxMonitorLabelPending,
            ),
          ),
          findsWidgets,
        );
        expect(
          find.text(
            _formattedLabel(
              l10n: l10n,
              label: l10n.outboxMonitorLabelError,
            ),
          ),
          findsWidgets,
        );
        expect(find.text('Pending item'), findsOneWidget);
        expect(find.text('Error item'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('syncFilter-error')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        final errorSummary = l10n.syncListCountSummary(
          _formattedLabel(
            l10n: l10n,
            label: l10n.outboxMonitorLabelError,
          ),
          1,
        );
        expect(find.text(errorSummary), findsOneWidget);
        expect(find.text('Error item'), findsOneWidget);
        expect(find.text('Pending item'), findsNothing);

        controller.add([
          const _TestItem(label: 'Final pending', hasError: false),
        ]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        final emptySummary = l10n.syncListCountSummary(
          _formattedLabel(
            l10n: l10n,
            label: l10n.outboxMonitorLabelError,
          ),
          0,
        );
        expect(find.text(emptySummary), findsOneWidget);
        expect(find.byType(EmptyStateWidget), findsOneWidget);
        expect(find.text('Nothing here'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'suppresses badge when configured and still shows positive counts',
      (tester) async {
        final controller = await _pumpScaffold(
          tester,
          filters: {
            _TestFilter.pending: SyncFilterOption<_TestItem>(
              labelBuilder: (context) =>
                  context.messages.outboxMonitorLabelPending,
              predicate: (_) => true,
              icon: Icons.schedule_rounded,
              selectedColor: syncPendingAccentColor,
              selectedForegroundColor: syncPendingForegroundColor,
              hideCountWhenZero: true,
              countAccentColor: syncPendingCountAccentColor,
              countAccentForegroundColor: syncPendingForegroundColor,
            ),
            _TestFilter.error: SyncFilterOption<_TestItem>(
              labelBuilder: (context) =>
                  context.messages.outboxMonitorLabelError,
              predicate: (item) => item.hasError,
              icon: Icons.error_outline_rounded,
              showCount: false,
            ),
          },
        );
        addTearDown(controller.close);

        controller.add(const <_TestItem>[]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        final pendingFilter = find.byKey(const ValueKey('syncFilter-pending'));
        expect(
          find.descendant(of: pendingFilter, matching: find.text('0')),
          findsNothing,
        );

        controller.add(const [
          _TestItem(label: 'Pending item', hasError: false),
          _TestItem(label: 'Errored item', hasError: true),
        ]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(
          find.descendant(of: pendingFilter, matching: find.text('2')),
          findsOneWidget,
        );

        final badgeFinder = find.descendant(
          of: pendingFilter,
          matching: find.byWidgetPredicate((widget) {
            if (widget is! Container) {
              return false;
            }
            final decoration = widget.decoration;
            return decoration is BoxDecoration &&
                decoration.borderRadius == BorderRadius.circular(999);
          }),
        );
        final badge = tester.widget<Container>(badgeFinder.first);
        final decoration = badge.decoration! as BoxDecoration;
        expect(
          decoration.color,
          equals(syncPendingAccentColor),
        );
        final border = decoration.border! as Border;
        expect(
          border.top.color,
          equals(
            syncPendingForegroundColor.withValues(alpha: 0.68),
          ),
        );
        expect(border.top.width, equals(1.3));
        final countText = tester.widget<Text>(
          find
              .descendant(
                of: badgeFinder,
                matching: find.text('2'),
              )
              .first,
        );
        expect(
          countText.style?.color,
          equals(syncPendingForegroundColor),
        );

        final errorFilter = find.byKey(const ValueKey('syncFilter-error'));
        expect(
          find.descendant(of: errorFilter, matching: find.text('1')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'renders headerSliver between header and list content',
      (tester) async {
        final controller = await _pumpScaffold(
          tester,
          headerSliver: const Text('Volume Chart Placeholder'),
        );
        addTearDown(controller.close);

        controller.add(const [
          _TestItem(label: 'Item A', hasError: false),
        ]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Volume Chart Placeholder'), findsOneWidget);
        expect(find.text('Item A'), findsOneWidget);
      },
    );

    testWidgets(
      'omits headerSliver when null',
      (tester) async {
        final controller = await _pumpScaffold(tester);
        addTearDown(controller.close);

        controller.add(const [
          _TestItem(label: 'Item B', hasError: false),
        ]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Volume Chart Placeholder'), findsNothing);
        expect(find.text('Item B'), findsOneWidget);
      },
    );

    testWidgets(
      'headerSliver visible during loading state',
      (tester) async {
        final controller = await _pumpScaffold(
          tester,
          headerSliver: const Text('Chart During Loading'),
        );
        addTearDown(controller.close);

        // Before any stream emission → loading indicator shown
        await tester.pump();

        expect(find.text('Chart During Loading'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgets(
      'headerSliver visible during empty state',
      (tester) async {
        final controller = await _pumpScaffold(
          tester,
          headerSliver: const Text('Chart During Empty'),
        );
        addTearDown(controller.close);

        controller.add(const <_TestItem>[]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Chart During Empty'), findsOneWidget);
        expect(find.byType(EmptyStateWidget), findsOneWidget);
      },
    );

    testWidgets(
      'didUpdateWidget resets filter when current selection removed',
      (tester) async {
        final controller = StreamController<List<_TestItem>>();
        addTearDown(controller.close);
        final l10n = AppLocalizationsEn();

        final filtersWithBoth = _buildFilters();

        // Initial pump with both filters, select error
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(390, 844),
                padding: EdgeInsets.only(top: 47),
              ),
              child: SyncListScaffold<_TestItem, _TestFilter>(
                title: 'Sync UI',
                stream: controller.stream,
                filters: filtersWithBoth,
                itemBuilder: (context, item) => ListTile(
                  title: Text(item.label),
                ),
                emptyIcon: Icons.hourglass_empty,
                emptyTitleBuilder: (ctx) => 'Nothing here',
                emptyDescriptionBuilder: (_) => null,
                countSummaryBuilder: (ctx, label, count) =>
                    ctx.messages.syncListCountSummary(label, count),
                initialFilter: _TestFilter.error,
                backButton: false,
              ),
            ),
          ),
        );

        controller.add(const [
          _TestItem(label: 'Item X', hasError: true),
        ]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Verify error filter is active
        final errorSummary = l10n.syncListCountSummary(
          _formattedLabel(l10n: l10n, label: l10n.outboxMonitorLabelError),
          1,
        );
        expect(find.text(errorSummary), findsOneWidget);

        // Rebuild with only the pending filter — error no longer exists
        final filtersOnlyPending = {
          _TestFilter.pending: SyncFilterOption<_TestItem>(
            labelBuilder: (context) =>
                context.messages.outboxMonitorLabelPending,
            predicate: (_) => true,
            icon: Icons.schedule_rounded,
          ),
        };

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(390, 844),
                padding: EdgeInsets.only(top: 47),
              ),
              child: SyncListScaffold<_TestItem, _TestFilter>(
                title: 'Sync UI',
                stream: controller.stream,
                filters: filtersOnlyPending,
                itemBuilder: (context, item) => ListTile(
                  title: Text(item.label),
                ),
                emptyIcon: Icons.hourglass_empty,
                emptyTitleBuilder: (ctx) => 'Nothing here',
                emptyDescriptionBuilder: (_) => null,
                countSummaryBuilder: (ctx, label, count) =>
                    ctx.messages.syncListCountSummary(label, count),
                backButton: false,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Should have fallen back to the first (pending) filter
        final pendingSummary = l10n.syncListCountSummary(
          _formattedLabel(l10n: l10n, label: l10n.outboxMonitorLabelPending),
          1,
        );
        expect(find.text(pendingSummary), findsOneWidget);
        expect(find.text('Item X'), findsOneWidget);
      },
    );

    group('responsive padding', () {
      testWidgets(
        'applies wider padding at 1200px viewport',
        (tester) async {
          const headerKey = Key('test-header-wide');
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final controller = await _pumpScaffold(
            tester,
            headerSliver: const SizedBox(
              key: headerKey,
              height: 50,
              child: Text('Chart'),
            ),
            viewportWidth: 1200,
            useViewSize: true,
          );
          addTearDown(controller.close);

          controller.add(const [
            _TestItem(label: 'Item C', hasError: false),
          ]);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));

          expect(find.text('Chart'), findsOneWidget);

          final headerWidget = tester.widget<Padding>(
            find
                .ancestor(
                  of: find.byKey(headerKey),
                  matching: find.byType(Padding),
                )
                .first,
          );
          final padding = headerWidget.padding as EdgeInsetsDirectional;
          expect(padding.start, greaterThanOrEqualTo(112));
          expect(padding.end, greaterThanOrEqualTo(112));
        },
      );

      testWidgets(
        'applies narrow padding at small viewport width',
        (tester) async {
          const headerKey = Key('test-header-narrow');
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final controller = await _pumpScaffold(
            tester,
            headerSliver: const SizedBox(
              key: headerKey,
              height: 50,
              child: Text('Chart'),
            ),
            viewportWidth: 350,
            useViewSize: true,
          );
          addTearDown(controller.close);

          controller.add(const [
            _TestItem(label: 'Item D', hasError: false),
          ]);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));

          expect(find.text('Chart'), findsOneWidget);

          final headerWidget = tester.widget<Padding>(
            find
                .ancestor(
                  of: find.byKey(headerKey),
                  matching: find.byType(Padding),
                )
                .first,
          );
          final padding = headerWidget.padding as EdgeInsetsDirectional;
          expect(padding.start, lessThan(20));
          expect(padding.end, lessThan(20));
        },
      );

      testWidgets(
        'at 992px breakpoint',
        (tester) async {
          const headerKey = Key('test-header-992');
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final controller = await _pumpScaffold(
            tester,
            headerSliver: const SizedBox(
              key: headerKey,
              height: 50,
              child: Text('Chart'),
            ),
            viewportWidth: 992,
            useViewSize: true,
          );
          addTearDown(controller.close);

          controller.add(const [
            _TestItem(label: 'Item E', hasError: false),
          ]);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));

          final headerWidget = tester.widget<Padding>(
            find
                .ancestor(
                  of: find.byKey(headerKey),
                  matching: find.byType(Padding),
                )
                .first,
          );
          final padding = headerWidget.padding as EdgeInsetsDirectional;
          expect(padding.start, greaterThanOrEqualTo(80));
          expect(padding.end, greaterThanOrEqualTo(80));
        },
      );

      testWidgets(
        'at 1800px breakpoint',
        (tester) async {
          const headerKey = Key('test-header-1800');
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final controller = await _pumpScaffold(
            tester,
            headerSliver: const SizedBox(
              key: headerKey,
              height: 50,
              child: Text('Chart'),
            ),
            viewportWidth: 1800,
            useViewSize: true,
          );
          addTearDown(controller.close);

          controller.add(const [
            _TestItem(label: 'Item F', hasError: false),
          ]);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));

          final headerWidget = tester.widget<Padding>(
            find
                .ancestor(
                  of: find.byKey(headerKey),
                  matching: find.byType(Padding),
                )
                .first,
          );
          final padding = headerWidget.padding as EdgeInsetsDirectional;
          expect(padding.start, greaterThanOrEqualTo(196));
          expect(padding.end, greaterThanOrEqualTo(196));
        },
      );
    });
  });
}
