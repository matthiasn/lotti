import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/projects/ui/widgets/project_status_chip.dart';
import 'package:lotti/utils/file_utils.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('ProjectStatusChip', () {
    final now = DateTime(2024, 3, 15);

    ProjectStatus makeStatus(
      ProjectStatus Function({
        required String id,
        required DateTime createdAt,
        required int utcOffset,
      })
      factory,
    ) {
      return factory(
        id: uuid.v1(),
        createdAt: now,
        utcOffset: 0,
      );
    }

    testWidgets('renders Open status with correct label and icon', (
      tester,
    ) async {
      final status = makeStatus(ProjectStatus.open);
      await tester.pumpWidget(
        makeTestableWidget(ProjectStatusChip(status: status)),
      );
      await tester.pump();

      expect(find.text('Open'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    });

    testWidgets('renders Active status with correct label and icon', (
      tester,
    ) async {
      final status = makeStatus(ProjectStatus.active);
      await tester.pumpWidget(
        makeTestableWidget(ProjectStatusChip(status: status)),
      );
      await tester.pump();

      expect(find.text('Active'), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
    });

    testWidgets('renders On Hold status with correct label and icon', (
      tester,
    ) async {
      final status = ProjectStatus.onHold(
        id: uuid.v1(),
        createdAt: now,
        utcOffset: 0,
        reason: 'blocked',
      );
      await tester.pumpWidget(
        makeTestableWidget(ProjectStatusChip(status: status)),
      );
      await tester.pump();

      expect(find.text('On Hold'), findsOneWidget);
      expect(find.byIcon(Icons.pause_circle_outline), findsOneWidget);
    });

    testWidgets('renders Completed status with correct label and icon', (
      tester,
    ) async {
      final status = makeStatus(ProjectStatus.completed);
      await tester.pumpWidget(
        makeTestableWidget(ProjectStatusChip(status: status)),
      );
      await tester.pump();

      expect(find.text('Completed'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('renders Archived status with correct label and icon', (
      tester,
    ) async {
      final status = makeStatus(ProjectStatus.archived);
      await tester.pumpWidget(
        makeTestableWidget(ProjectStatusChip(status: status)),
      );
      await tester.pump();

      expect(find.text('Archived'), findsOneWidget);
      expect(find.byIcon(Icons.archive_outlined), findsOneWidget);
    });
  });
}
