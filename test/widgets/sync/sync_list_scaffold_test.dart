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
import 'package:lotti/widgets/ui/empty_state_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await getIt.reset();
    getIt.registerSingleton<UserActivityService>(UserActivityService());
  });

  tearDown(() async {
    await getIt.reset();
  });

  group('SyncListScaffold', () {
    testWidgets(
      'renders filters, summaries, loading, and empty states',
      (tester) async {
        final controller = StreamController<List<_TestItem>>();
        addTearDown(controller.close);
        final l10n = AppLocalizationsEn();

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SyncListScaffold<_TestItem, _TestFilter>(
              title: 'Sync UI',
              stream: controller.stream,
              filters: _buildFilters(),
              itemBuilder: (context, item) => ListTile(
                title: Text(item.label),
              ),
              emptyIcon: Icons.hourglass_empty,
              emptyTitleBuilder: (ctx) => 'Nothing here',
              emptyDescriptionBuilder: (_) => null,
              countSummaryBuilder: (ctx, label, count) =>
                  ctx.messages.syncListCountSummary(label, count),
              initialFilter: _TestFilter.pending,
              backButton: false,
            ),
          ),
        );

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
        await tester.pumpAndSettle();

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
  });
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
