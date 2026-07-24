import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/tasks/state/task_link_groups_controller.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/edit_link_type_modal.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockJournalRepository journalRepo;

  setUp(() {
    // _EditLinkTypeApplyFooter awaits a HapticFeedback call before popping —
    // under the test binding that never resolves without a mock handler (see
    // test/README.md's "Platform-channel calls in widgets" section).
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          return null;
        });
    journalRepo = MockJournalRepository();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  // DsSegmentedToggle renders an invisible width-reserving ghost copy of each
  // segment's label alongside the visible one — plain find.text matches two
  // Texts; the visible one is the Stack's last child.
  Finder visibleText(String label) => find.text(label).last;

  Finder saveButton() => find.widgetWithText(DesignSystemButton, 'Save');
  Finder closeButton() => find.byIcon(Icons.close_rounded);

  Future<void> openModal(
    WidgetTester tester, {
    EntryLinkType currentType = EntryLinkType.blocks,
    TaskLinkDirection currentDirection = TaskLinkDirection.incoming,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [journalRepositoryProvider.overrideWithValue(journalRepo)],
        child: WidgetTestBench(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                await EditLinkTypeModal.show(
                  context: context,
                  linkId: 'link-1',
                  currentType: currentType,
                  currentDirection: currentDirection,
                );
              },
              child: const Text('Open Modal'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Modal'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  void stubUpdateLinkType({required bool result}) {
    when(
      () => journalRepo.updateLinkType(
        linkId: any(named: 'linkId'),
        newType: any(named: 'newType'),
        swapDirection: any(named: 'swapDirection'),
      ),
    ).thenAnswer((_) async => result);
  }

  group('EditLinkTypeModal', () {
    testWidgets('opens pre-selected to the current type and phrasing', (
      tester,
    ) async {
      stubUpdateLinkType(result: true);

      await openModal(tester);

      expect(find.text('Edit relationship'), findsOneWidget);
      // incoming -> the anchor is blocked by the other task -> inverse
      // phrasing ("Is blocked by") is pre-selected.
      final toggle = tester.widget<DsSegmentedToggle<bool>>(
        find.byType(DsSegmentedToggle<bool>),
      );
      expect(toggle.selected, isTrue);
      expect(visibleText('Is blocked by'), findsOneWidget);
    });

    testWidgets(
      'an outgoing link pre-selects the primary phrasing (not inverse)',
      (tester) async {
        stubUpdateLinkType(result: true);

        await openModal(tester, currentDirection: TaskLinkDirection.outgoing);

        final toggle = tester.widget<DsSegmentedToggle<bool>>(
          find.byType(DsSegmentedToggle<bool>),
        );
        expect(toggle.selected, isFalse);
        expect(toggle.segments[0].label, 'Blocks');
        expect(toggle.segments[1].label, 'Is blocked by');
      },
    );

    testWidgets('Save persists the unchanged type/direction as an identity '
        'round-trip', (tester) async {
      stubUpdateLinkType(result: true);

      await openModal(
        tester,
        currentType: EntryLinkType.followsUp,
        currentDirection: TaskLinkDirection.outgoing,
      );

      await tester.tap(saveButton());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verify(
        () => journalRepo.updateLinkType(
          linkId: 'link-1',
          newType: EntryLinkType.followsUp,
          swapDirection: false,
        ),
      ).called(1);
      expect(find.text('Edit relationship'), findsNothing);
    });

    testWidgets(
      'selecting a new type before Save persists that type',
      (tester) async {
        stubUpdateLinkType(result: true);

        await openModal(
          tester,
          currentType: EntryLinkType.followsUp,
          currentDirection: TaskLinkDirection.outgoing,
        );

        await tester.tap(find.text('Duplicates'));
        await tester.pump();
        await tester.tap(saveButton());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        verify(
          () => journalRepo.updateLinkType(
            linkId: 'link-1',
            newType: EntryLinkType.duplicates,
            swapDirection: false,
          ),
        ).called(1);
      },
    );

    testWidgets(
      'toggling the inverse phrasing before Save requests a direction flip',
      (tester) async {
        stubUpdateLinkType(result: true);

        await openModal(tester, currentDirection: TaskLinkDirection.outgoing);

        // The toggle's own tap doesn't hit-test reliably under the Wolt
        // sticky-footer overlay in the test harness (its InkWell region and
        // the footer's glass surface overlap in the hit-test order) —
        // invoke the callback directly, same as this repo's established
        // pattern for other interaction tests.
        tester
            .widget<DsSegmentedToggle<bool>>(
              find.byType(DsSegmentedToggle<bool>),
            )
            .onChanged(true);
        await tester.pump();
        await tester.tap(saveButton());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        verify(
          () => journalRepo.updateLinkType(
            linkId: 'link-1',
            newType: EntryLinkType.blocks,
            swapDirection: true,
          ),
        ).called(1);
      },
    );

    testWidgets('the close button dismisses without persisting anything', (
      tester,
    ) async {
      await openModal(tester);

      await tester.tap(closeButton());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verifyNever(
        () => journalRepo.updateLinkType(
          linkId: any(named: 'linkId'),
          newType: any(named: 'newType'),
          swapDirection: any(named: 'swapDirection'),
        ),
      );
      expect(find.text('Edit relationship'), findsNothing);
    });

    testWidgets('shows a SnackBar and stays open when the save fails', (
      tester,
    ) async {
      stubUpdateLinkType(result: false);

      await openModal(tester);

      await tester.tap(saveButton());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The repository is confirmed called exactly once (below); the Wolt
      // sticky-footer host can transiently mount two SnackBar widget
      // instances for a single logical show (a benign rendering artifact),
      // so assert on content rather than widget count.
      verify(
        () => journalRepo.updateLinkType(
          linkId: any(named: 'linkId'),
          newType: any(named: 'newType'),
          swapDirection: any(named: 'swapDirection'),
        ),
      ).called(1);
      expect(
        find.text("Couldn't update the relationship. Please try again."),
        findsWidgets,
      );
      expect(find.text('Edit relationship'), findsOneWidget);
    });
  });
}
