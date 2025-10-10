import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/state/purge_controller.dart';
import 'package:lotti/features/sync/ui/purge_modal.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';

import '../../../widget_test_utils.dart';

class _TestPurgeController extends PurgeController {
  _TestPurgeController(this.initialState);

  final PurgeState initialState;
  final Completer<void> _operationCompleter = Completer<void>();

  bool purgeCalled = false;

  @override
  PurgeState build() => initialState;

  @override
  Future<void> purgeDeleted() async {
    purgeCalled = true;
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

  _TestPurgeController? controller;

  tearDown(() {
    controller?.completeOperation();
  });

  Future<void> pumpModal(WidgetTester tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => PurgeModal.show(context),
            child: const Text('Open purge modal'),
          ),
        ),
        overrides: [
          purgeControllerProvider.overrideWith(() {
            controller = _TestPurgeController(const PurgeState());
            return controller!;
          }),
        ],
      ),
    );

    await tester.tap(find.text('Open purge modal'));
    await tester.pumpAndSettle();

    final confirmButtonFinder = find.byType(LottiPrimaryButton);
    expect(confirmButtonFinder, findsOneWidget);
    final confirmButton =
        tester.widget<LottiPrimaryButton>(confirmButtonFinder);
    confirmButton.onPressed?.call();
    await tester.pump();
  }

  testWidgets('shows purge progress while running', (tester) async {
    await pumpModal(tester);

    expect(controller!.purgeCalled, isTrue);

    controller!.state = const PurgeState(
      progress: 0.58,
      isPurging: true,
    );
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('58%'), findsOneWidget);

    controller!.completeOperation();
    await tester.pump();
  });

  testWidgets('renders completion icon when purge finishes', (tester) async {
    await pumpModal(tester);

    controller!.state = const PurgeState(
      progress: 1,
    );
    await tester.pump();

    expect(find.byIcon(Icons.delete_forever_outlined), findsOneWidget);
    expect(find.text('100%'), findsNothing); // success state hides percentage

    controller!.completeOperation();
    await tester.pump();
  });
}
