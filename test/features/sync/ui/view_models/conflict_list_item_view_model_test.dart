import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/ui/view_models/conflict_list_item_view_model.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConflictListItemViewModel', () {
    testWidgets('formats resolved conflicts with localized labels',
        (tester) async {
      late ConflictListItemViewModel viewModel;
      late BuildContext capturedContext;

      final conflict = Conflict(
        id: 'resolved-id',
        createdAt: DateTime(2024, 3, 3, 10, 30),
        updatedAt: DateTime(2024, 3, 3, 10, 30),
        serialized: jsonEncode(testWorkoutRunning.toJson()),
        schemaVersion: 1,
        status: ConflictStatus.resolved.index,
      );

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Builder(
            builder: (context) {
              capturedContext = context;
              viewModel = ConflictListItemViewModel.fromConflict(
                context: context,
                conflict: conflict,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await tester.pump();

      expect(viewModel.statusLabel, 'Resolved');
      expect(
        viewModel.statusColor,
        Theme.of(capturedContext).colorScheme.primary,
      );
      expect(
        viewModel.entityLabel,
        capturedContext.messages.entryTypeLabelWorkoutEntry,
      );
      expect(
        viewModel.semanticsLabel,
        contains('Resolved'),
      );
    });

    testWidgets('falls back to original casing when title case is null',
        (tester) async {
      late ConflictListItemViewModel viewModel;

      final conflict = Conflict(
        id: 'unresolved-id',
        createdAt: DateTime(2024, 4, 4),
        updatedAt: DateTime(2024, 4, 4),
        serialized: jsonEncode(testTextEntry.toJson()),
        schemaVersion: 1,
        status: ConflictStatus.unresolved.index,
      );

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Builder(
            builder: (context) {
              viewModel = ConflictListItemViewModel.fromConflict(
                context: context,
                conflict: conflict,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await tester.pump();

      expect(viewModel.statusLabel, isNotEmpty);
      expect(viewModel.timestampLabel, isNotEmpty);
      expect(viewModel.vectorClockLabel, isNotEmpty);
    });
  });
}
