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

    // One parameterized body per status variant.
    ProjectStatus statusFor(String label) => switch (label) {
      'Open' => makeStatus(ProjectStatus.open),
      'Active' => makeStatus(ProjectStatus.active),
      'On Hold' => ProjectStatus.onHold(
        id: uuid.v1(),
        createdAt: now,
        utcOffset: 0,
        reason: 'blocked',
      ),
      'Completed' => makeStatus(ProjectStatus.completed),
      _ => makeStatus(ProjectStatus.archived),
    };

    for (final (label, icon) in [
      ('Open', Icons.radio_button_unchecked),
      ('Active', Icons.play_circle_outline),
      ('On Hold', Icons.pause_circle_outline),
      ('Completed', Icons.check_circle_outline),
      ('Archived', Icons.archive_outlined),
    ]) {
      testWidgets('renders $label status with its label and icon', (
        tester,
      ) async {
        await tester.pumpWidget(
          makeTestableWidget(ProjectStatusChip(status: statusFor(label))),
        );
        await tester.pump();

        expect(find.text(label), findsOneWidget);
        expect(find.byIcon(icon), findsOneWidget);
      });
    }
  });
}
