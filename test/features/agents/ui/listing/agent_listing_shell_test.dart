import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/listing/agent_list_data.dart';
import 'package:lotti/features/agents/ui/listing/agent_list_filter_state.dart';
import 'package:lotti/features/agents/ui/listing/agent_listing_shell.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../widget_test_utils.dart';

AgentListRowData _row({
  required String id,
  required String title,
  String? subtitle,
  Widget Function(BuildContext)? trailing,
  VoidCallback? onTap,
}) {
  return AgentListRowData(
    id: id,
    title: title,
    subtitle: subtitle,
    sortAt: DateTime(2026),
    searchKey: '$title $id ${subtitle ?? ''}'.toLowerCase(),
    trailing: trailing,
    onTap: onTap,
  );
}

AgentListGroupAxis _flatGroup() => AgentListGroupAxis(
  id: 'all',
  label: 'All',
  // Skip the group entirely when there are no rows so the shell's
  // empty-state branch fires (matches what real adapters do).
  buildGroups: (rows) => rows.isEmpty
      ? const []
      : [AgentListGroup(id: 'all', label: 'All', items: rows)],
);

AgentListSortAxis _byName() => AgentListSortAxis(
  id: 'name',
  label: 'Name',
  compare: (a, b) => a.title.compareTo(b.title),
);

void main() {
  setUp(() async {
    await setUpTestGetIt();
  });
  tearDown(() async {
    await tearDownTestGetIt();
  });

  Future<void> pumpShell(
    WidgetTester tester, {
    required AsyncValue<List<AgentListRowData>> rowsAsync,
    List<AgentListFilterAxis> filterAxes = const [],
    String empty = 'Nothing here',
    String placeholder = 'Search…',
    AgentListAxisMatcher matcher = _alwaysMatch,
    bool settle = true,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: AgentListingShell(
            rowsAsync: rowsAsync,
            filterAxes: filterAxes,
            groupAxes: [_flatGroup()],
            sortAxes: [_byName()],
            searchPlaceholder: placeholder,
            emptyMessage: empty,
            axisMatcher: matcher,
          ),
        ),
        mediaQueryData: const MediaQueryData(size: Size(1200, 900)),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // Avoid pumpAndSettle when a CircularProgressIndicator is on screen
      // — it animates indefinitely and the test would time out.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  group('AgentListingShell — async branches', () {
    testWidgets('loading shows a spinner', (tester) async {
      await pumpShell(
        tester,
        rowsAsync: const AsyncValue.loading(),
        settle: false,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('error shows the localized common error message', (
      tester,
    ) async {
      await pumpShell(
        tester,
        rowsAsync: AsyncValue.error('boom', StackTrace.current),
      );
      final ctx = tester.element(find.byType(AgentListingShell));
      expect(find.text(ctx.messages.commonError), findsOneWidget);
    });

    testWidgets('empty data shows the page-supplied empty message', (
      tester,
    ) async {
      await pumpShell(
        tester,
        rowsAsync: const AsyncValue.data(<AgentListRowData>[]),
        empty: 'Nothing yet',
      );
      expect(find.text('Nothing yet'), findsOneWidget);
    });
  });

  group('AgentListingShell — trailing slot', () {
    testWidgets(
      'each row renders its custom trailing builder instead of the chevron',
      (tester) async {
        await pumpShell(
          tester,
          rowsAsync: AsyncValue.data([
            _row(
              id: 'r1',
              title: 'Row 1',
              trailing: (_) => const Text('CUSTOM-TRAIL-1'),
            ),
            _row(
              id: 'r2',
              title: 'Row 2',
              trailing: (_) => const Text('CUSTOM-TRAIL-2'),
            ),
          ]),
        );
        expect(find.text('CUSTOM-TRAIL-1'), findsOneWidget);
        expect(find.text('CUSTOM-TRAIL-2'), findsOneWidget);
        // Default chevron shouldn't render when trailing is supplied.
        expect(find.byIcon(Icons.chevron_right), findsNothing);
      },
    );

    testWidgets(
      'actionable rows without a trailing builder fall back to the chevron',
      (tester) async {
        await pumpShell(
          tester,
          rowsAsync: AsyncValue.data([
            _row(id: 'r1', title: 'Row 1', onTap: () {}),
          ]),
        );
        expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      },
    );

    testWidgets(
      'non-actionable rows render no chevron and no custom trailing',
      (tester) async {
        await pumpShell(
          tester,
          rowsAsync: AsyncValue.data([_row(id: 'r1', title: 'Row 1')]),
        );
        expect(find.byIcon(Icons.chevron_right), findsNothing);
      },
    );
  });

  group('AgentListingShell — search', () {
    testWidgets('typing narrows the visible row count', (tester) async {
      await pumpShell(
        tester,
        rowsAsync: AsyncValue.data([
          _row(id: 'a', title: 'Alpha'),
          _row(id: 'b', title: 'Bravo'),
        ]),
      );

      await tester.enterText(find.byType(TextField), 'alp');
      await tester.pumpAndSettle();

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Bravo'), findsNothing);
    });
  });
}

bool _alwaysMatch(String _, Set<String> _, AgentListRowData _) => true;
