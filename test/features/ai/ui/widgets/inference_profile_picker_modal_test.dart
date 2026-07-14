import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/widgets/inference_profile_picker_modal.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';

import '../../../../test_helper.dart';

AiConfigInferenceProfile _profile({
  required String id,
  required String name,
  String? description,
  bool desktopOnly = false,
}) => AiConfigInferenceProfile(
  id: id,
  name: name,
  description: description,
  createdAt: DateTime(2024, 3, 15),
  thinkingModelId: 'internal-$id',
  desktopOnly: desktopOnly,
);

void main() {
  testWidgets(
    'renders descriptions, selected semantics, and desktop-only context',
    (tester) async {
      final selected = _profile(
        id: 'private',
        name: 'Private profile',
        description: 'No data retention',
        desktopOnly: true,
      );
      final other = _profile(id: 'fast', name: 'Fast profile');

      await tester.pumpWidget(
        WidgetTestBench(
          child: InferenceProfilePickerList(
            profiles: [selected, other],
            selectedProfileId: selected.id,
            onSelected: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Private profile'), findsOneWidget);
      expect(find.text('No data retention'), findsOneWidget);
      expect(find.text('Selected'), findsOneWidget);
      expect(find.byTooltip('Desktop Only'), findsOneWidget);
      expect(find.text('internal-private'), findsNothing);

      final selectedRow = tester.widget<DesignSystemSelectionRow>(
        find.byKey(const ValueKey('private')),
      );
      expect(selectedRow.selected, isTrue);
      expect(selectedRow.semanticLabel, contains('Desktop Only'));
      expect(find.byType(Divider), findsNothing);
    },
  );

  testWidgets('returns the selected id and dismisses the modal', (
    tester,
  ) async {
    String? result;
    final profiles = [
      _profile(id: 'private', name: 'Private profile'),
      _profile(id: 'fast', name: 'Fast profile'),
    ];

    await tester.pumpWidget(
      WidgetTestBench(
        child: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await InferenceProfilePickerModal.show(
                context: context,
                profiles: profiles,
                selectedProfileId: profiles.first.id,
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Choose an inference profile'), findsOneWidget);

    await tester.tap(find.text('Fast profile'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(result, 'fast');
    expect(find.text('Choose an inference profile'), findsNothing);
  });

  testWidgets('empty input returns null without opening a modal', (
    tester,
  ) async {
    String? result = 'pending';
    await tester.pumpWidget(
      WidgetTestBench(
        child: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await InferenceProfilePickerModal.show(
                context: context,
                profiles: const [],
                selectedProfileId: null,
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pump();

    expect(result, isNull);
    expect(find.text('Choose an inference profile'), findsNothing);
  });
}
