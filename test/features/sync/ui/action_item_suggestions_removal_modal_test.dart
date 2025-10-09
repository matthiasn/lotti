import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/state/action_item_suggestions_controller.dart';
import 'package:lotti/features/sync/ui/action_item_suggestions_removal_modal.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';

import '../../../widget_test_utils.dart';

class _TestActionItemSuggestionsController
    extends ActionItemSuggestionsController {
  _TestActionItemSuggestionsController(this.initialState);

  final ActionItemSuggestionsState initialState;
  final Completer<void> _operationCompleter = Completer<void>();

  bool removeCalled = false;

  @override
  ActionItemSuggestionsState build() => initialState;

  @override
  Future<void> removeActionItemSuggestions() async {
    removeCalled = true;
    return _operationCompleter.future;
  }

  void completeOperation() {
    if (!_operationCompleter.isCompleted) {
      _operationCompleter.complete();
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  _TestActionItemSuggestionsController? controller;

  tearDown(() {
    controller?.completeOperation();
  });

  Future<void> pumpModal(WidgetTester tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => ActionItemSuggestionsRemovalModal.show(context),
            child: const Text('Open modal'),
          ),
        ),
        overrides: [
          actionItemSuggestionsControllerProvider.overrideWith(() {
            controller = _TestActionItemSuggestionsController(
                const ActionItemSuggestionsState());
            return controller!;
          }),
        ],
      ),
    );

    await tester.tap(find.text('Open modal'));
    await tester.pumpAndSettle();

    final confirmButtonFinder = find.byType(LottiPrimaryButton);
    expect(confirmButtonFinder, findsOneWidget);
    final confirmButton =
        tester.widget<LottiPrimaryButton>(confirmButtonFinder);
    confirmButton.onPressed?.call();
    await tester.pump();
  }

  testWidgets('shows progress while removal is in progress', (tester) async {
    await pumpModal(tester);

    expect(controller!.removeCalled, isTrue);

    controller!.state = const ActionItemSuggestionsState(
      progress: 0.42,
      isRemoving: true,
    );
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('42%'), findsOneWidget);

    controller!.completeOperation();
    await tester.pump();
  });

  testWidgets('renders success state when progress completes', (tester) async {
    await pumpModal(tester);

    controller!.state = const ActionItemSuggestionsState(
      progress: 1,
    );
    await tester.pump();

    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);

    controller!.completeOperation();
    await tester.pump();
  });

  testWidgets('renders error message when removal fails', (tester) async {
    await pumpModal(tester);

    controller!.state = const ActionItemSuggestionsState(
      error: 'Failed to remove suggestions',
    );
    await tester.pump();

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.text('Failed to remove suggestions'), findsOneWidget);

    controller!.completeOperation();
    await tester.pump();
  });
}
