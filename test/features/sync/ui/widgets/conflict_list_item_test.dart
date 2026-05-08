import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/sync/ui/widgets/conflicts/conflict_list_item.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/l10n/app_localizations_en.dart';

import '../../../../widget_test_utils.dart';

const _wideSurface = Size(800, 600);
const _compactSurface = Size(400, 800);

Future<void> _pump(
  WidgetTester tester, {
  required Conflict conflict,
  required Size surface,
  VoidCallback? onTap,
}) async {
  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: surface.width,
          child: ConflictListItem(conflict: conflict, onTap: onTap),
        ),
      ),
    ),
  );
  await tester.pump();
}

Conflict _buildConflict({
  required ConflictStatus status,
  String id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
  JournalEntity? entity,
}) {
  final createdAt = DateTime(2024, 3, 15, 12, 30, 45);
  final meta = Metadata(
    id: id,
    createdAt: createdAt,
    updatedAt: createdAt,
    dateFrom: createdAt,
    dateTo: createdAt.add(const Duration(minutes: 5)),
    vectorClock: const VectorClock(<String, int>{'device': 2, 'server': 7}),
  );
  final resolvedEntity =
      entity ??
      JournalEntry(
        meta: meta,
        entryText: const EntryText(plainText: 'Sample entry'),
      );
  return Conflict(
    id: id,
    createdAt: createdAt,
    updatedAt: createdAt,
    serialized: jsonEncode(resolvedEntity.toJson()),
    schemaVersion: 1,
    status: status.index,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l10n = AppLocalizationsEn();

  group('ConflictListItem (wide layout)', () {
    testWidgets('renders status, entity type, timestamp, and short id', (
      tester,
    ) async {
      final conflict = _buildConflict(status: ConflictStatus.unresolved);
      await _pump(tester, conflict: conflict, surface: _wideSurface);

      // Status badge label.
      expect(find.text('Unresolved'), findsOneWidget);
      // Entity-type badge label (localized via en).
      expect(find.text(l10n.entryTypeLabelJournalEntry), findsOneWidget);
      // Mono short id (8-char prefix of UUID).
      expect(find.text('a1b2c3d4'), findsOneWidget);
      // No "Entity:" or "ID:" prefixes from the legacy design.
      expect(find.textContaining('Entity:'), findsNothing);
      expect(find.textContaining('ID:'), findsNothing);
    });

    testWidgets('hides the vector clock from the row', (tester) async {
      final conflict = _buildConflict(status: ConflictStatus.unresolved);
      await _pump(tester, conflict: conflict, surface: _wideSurface);

      // Old design surfaced VectorClock.toString() like "{device: 2, server: 7}".
      expect(find.textContaining('device:'), findsNothing);
      expect(find.textContaining('server:'), findsNothing);
    });

    testWidgets('mono id has a tooltip revealing the full id', (tester) async {
      final conflict = _buildConflict(status: ConflictStatus.unresolved);
      await _pump(tester, conflict: conflict, surface: _wideSurface);

      final tooltipMessage = l10n.conflictListItemTooltipFullId(conflict.id);
      expect(find.byTooltip(tooltipMessage), findsOneWidget);
    });

    testWidgets('semantics label includes status, entity, and full id', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final conflict = _buildConflict(status: ConflictStatus.unresolved);
      await _pump(tester, conflict: conflict, surface: _wideSurface);

      final node = tester.getSemantics(find.byType(ConflictListItem));
      final label = node.getSemanticsData().label;
      expect(label, contains('Unresolved'));
      expect(label, contains(l10n.entryTypeLabelJournalEntry));
      expect(label, contains(conflict.id));
      handle.dispose();
    });

    testWidgets('tap fires the onTap callback', (tester) async {
      var taps = 0;
      final conflict = _buildConflict(status: ConflictStatus.unresolved);
      await _pump(
        tester,
        conflict: conflict,
        surface: _wideSurface,
        onTap: () => taps++,
      );

      await tester.tap(find.byType(ConflictListItem));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('long ids do not overflow and only the prefix is shown', (
      tester,
    ) async {
      final conflict = _buildConflict(
        status: ConflictStatus.unresolved,
        id: 'aaaaaaaa-bbbbbbbb-cccccccc-dddddddd-eeeeeeee-ffffffff',
      );
      await _pump(tester, conflict: conflict, surface: _wideSurface);

      expect(tester.takeException(), isNull);
      expect(find.text('aaaaaaaa'), findsOneWidget);
      // The full id never appears as visible text (only inside the tooltip).
      expect(find.text(conflict.id), findsNothing);
    });
  });

  group('ConflictListItem (status tone)', () {
    testWidgets('status badge maps to success/danger by status', (
      tester,
    ) async {
      final variants = <(ConflictStatus, String, DesignSystemBadgeTone)>[
        (ConflictStatus.unresolved, 'Unresolved', DesignSystemBadgeTone.danger),
        (ConflictStatus.resolved, 'Resolved', DesignSystemBadgeTone.success),
      ];

      for (final (status, expectedLabel, expectedTone) in variants) {
        final conflict = _buildConflict(status: status);
        await _pump(tester, conflict: conflict, surface: _wideSurface);

        final badges = tester
            .widgetList<DesignSystemBadge>(find.byType(DesignSystemBadge))
            .toList();

        expect(
          badges,
          isNotEmpty,
          reason: 'expected at least one badge for $status',
        );
        final statusBadge = badges.first;
        expect(statusBadge.tone, expectedTone, reason: 'tone for $status');

        // The status label is rendered as the first badge's text.
        expect(find.text(expectedLabel), findsOneWidget);
      }
    });
  });

  group('ConflictListItem (compact layout)', () {
    testWidgets('mono id sits above status badge in compact width', (
      tester,
    ) async {
      final conflict = _buildConflict(status: ConflictStatus.unresolved);
      await _pump(tester, conflict: conflict, surface: _compactSurface);

      final monoFinder = find.text('a1b2c3d4');
      final statusFinder = find.text('Unresolved');

      expect(monoFinder, findsOneWidget);
      expect(statusFinder, findsOneWidget);

      final monoY = tester.getCenter(monoFinder).dy;
      final statusY = tester.getCenter(statusFinder).dy;
      // In compact mode, mono id is in the title row (above) and the status
      // pill is in the second row (below).
      expect(monoY, lessThan(statusY));
    });
  });
}
