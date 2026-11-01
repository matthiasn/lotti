import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_detail_linked.dart';
import 'package:lotti/features/projects/ui/widgets/project_timeline_section.dart';

import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  final project = makeTestProject(id: 'project-1', title: 'Nest survey');

  Future<void> pump(WidgetTester tester, {required bool linked}) =>
      tester.pumpWidget(
        makeTestableWidget(
          ProjectTimelineSection(project: project),
          overrides: [
            hasNonTaskLinkedEntriesProvider(
              'project-1',
            ).overrideWith((ref) => linked),
            // The list's own rendering is LinkedEntriesWidget's to test.
            sortedLinkedEntriesProvider(
              'project-1',
            ).overrideWith((ref) => const []),
          ],
        ),
      );

  testWidgets('with only tasks linked, the project has no timeline at all', (
    tester,
  ) async {
    await pump(tester, linked: false);

    expect(find.text('Timeline'), findsNothing);
    expect(find.byType(LinkedEntriesWidget), findsNothing);
  });

  testWidgets('what is linked straight to the project shows under a '
      'Timeline heading, the tasks left to their own panel', (tester) async {
    await pump(tester, linked: true);

    expect(find.bySemanticsLabel('Timeline'), findsOne);
    final list = tester.widget<LinkedEntriesWidget>(
      find.byType(LinkedEntriesWidget),
    );
    expect(list.item, same(project));
    expect(list.hideTaskEntries, isTrue);
  });
}
