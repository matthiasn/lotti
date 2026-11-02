import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/events/ui/model/event_view_data.dart';
import 'package:lotti/features/events/ui/widgets/event_photo_analysis_sheet.dart';
import 'package:lotti/features/events/ui/widgets/event_timeline.dart';
import 'package:lotti/widgets/markdown/agent_markdown_view.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../test_utils/broken_image_provider.dart';
import '../../../../widget_test_utils.dart';

void main() {
  const analysis = EventPhotoAnalysis(
    photo: EventPhoto(BrokenImageProvider(), id: 'photo-1'),
    analysis:
        '## Scene\nThree penguins in flight suits beside a glowing launch '
        'pad.\n\n- A rocket on the gantry',
    oneLiner: 'Penguins in flight suits beside a glowing launch pad.',
  );

  group('EventPhotoAnalysisView', () {
    testWidgets('shows the photo, its caption and the whole analysis', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SingleChildScrollView(
            child: EventPhotoAnalysisView(analysis: analysis),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(EventTimelinePhotoBand), findsOneWidget);
      expect(
        find.text('Penguins in flight suits beside a glowing launch pad.'),
        findsOneWidget,
      );
      expect(
        tester.widget<AgentMarkdownView>(find.byType(AgentMarkdownView)).text,
        analysis.analysis,
      );
      // Read-only without a way through to the entry.
      expect(find.byType(DesignSystemButton), findsNothing);
    });

    testWidgets('an analysis without a caption leads with the analysis', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SingleChildScrollView(
            child: EventPhotoAnalysisView(
              analysis: EventPhotoAnalysis(
                photo: EventPhoto(BrokenImageProvider()),
                analysis: 'A rocket on the gantry.',
                oneLiner: '  ',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AgentMarkdownView), findsOneWidget);
      expect(find.text('  '), findsNothing);
    });
  });

  testWidgets('showEventPhotoAnalysis opens the sheet, and Open photo closes '
      "it on the way to the photo's entry", (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showEventPhotoAnalysis(
              context: context,
              analysis: analysis,
              onOpenEntry: () => opened++,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('What the photo shows'), findsOneWidget);
    expect(find.byType(EventPhotoAnalysisView), findsOneWidget);

    await tester.ensureVisible(find.text('Open photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open photo'));
    await tester.pumpAndSettle();

    expect(opened, 1);
    expect(find.byType(EventPhotoAnalysisView), findsNothing);
  });
}
