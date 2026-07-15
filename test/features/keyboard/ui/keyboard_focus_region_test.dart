import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/ui/app_command_host.dart';
import 'package:lotti/features/keyboard/ui/keyboard_focus_region.dart';

import '../../../widget_test_utils.dart';

void main() {
  testWidgets('F6 cycles focus regions and Shift+F6 reverses', (tester) async {
    final first = FocusNode(debugLabel: 'first');
    final second = FocusNode(debugLabel: 'second');
    addTearDown(first.dispose);
    addTearDown(second.dispose);

    await tester.pumpWidget(
      _testApp(
        AppCommandHost(
          platform: TargetPlatform.windows,
          handlers: const <AppCommandId, AppCommandHandler>{},
          child: _TwoFocusRegions(first: first, second: second),
        ),
      ),
    );

    first.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.f6);
    await tester.pump();
    expect(second.hasFocus, isTrue);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.f6);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(first.hasFocus, isTrue);
  });

  for (final reverse in [false, true]) {
    testWidgets(
      '${reverse ? 'reverse' : 'forward'} traversal skips empty regions',
      (tester) async {
        final controller = KeyboardFocusRegionController();
        final target = FocusNode();
        addTearDown(controller.dispose);
        addTearDown(target.dispose);
        final focusable = KeyboardFocusRegion(
          debugLabel: 'focusable',
          child: TextButton(
            focusNode: target,
            onPressed: () {},
            child: const Text('Target'),
          ),
        );
        const empty = KeyboardFocusRegion(
          debugLabel: 'empty',
          child: SizedBox.shrink(),
        );

        await tester.pumpWidget(
          _testApp(
            KeyboardFocusRegionRegistry(
              controller: controller,
              child: Column(
                children: reverse ? [focusable, empty] : [empty, focusable],
              ),
            ),
          ),
        );

        expect(controller.focusNext(reverse: reverse), isTrue);
        await tester.pump();
        expect(target.hasFocus, isTrue);
      },
    );
  }

  testWidgets('reverse traversal starts at the last region without focus', (
    tester,
  ) async {
    final controller = KeyboardFocusRegionController();
    final first = FocusNode();
    final second = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(first.dispose);
    addTearDown(second.dispose);

    await tester.pumpWidget(
      _testApp(
        KeyboardFocusRegionRegistry(
          controller: controller,
          child: _TwoFocusRegions(first: first, second: second),
        ),
      ),
    );

    expect(controller.focusNext(reverse: true), isTrue);
    await tester.pump();
    expect(second.hasFocus, isTrue);
  });

  testWidgets('restores the previously focused child in a region', (
    tester,
  ) async {
    final controller = KeyboardFocusRegionController();
    final remembered = FocusNode();
    final outside = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(remembered.dispose);
    addTearDown(outside.dispose);

    await tester.pumpWidget(
      _testApp(
        KeyboardFocusRegionRegistry(
          controller: controller,
          child: Column(
            children: [
              KeyboardFocusRegion(
                debugLabel: 'remembered',
                child: TextButton(
                  focusNode: remembered,
                  onPressed: () {},
                  child: const Text('Remembered'),
                ),
              ),
              TextButton(
                focusNode: outside,
                onPressed: () {},
                child: const Text('Outside'),
              ),
            ],
          ),
        ),
      ),
    );

    expect(controller.focusNext(), isTrue);
    await tester.pump();
    expect(remembered.hasFocus, isTrue);
    outside.requestFocus();
    await tester.pump();

    expect(controller.focusNext(), isTrue);
    await tester.pump();
    expect(remembered.hasFocus, isTrue);
  });

  testWidgets('focusRegion targets an enabled region by identity', (
    tester,
  ) async {
    final controller = KeyboardFocusRegionController();
    final first = FocusNode();
    final second = FocusNode();
    final secondRegionId = Object();
    addTearDown(controller.dispose);
    addTearDown(first.dispose);
    addTearDown(second.dispose);

    await tester.pumpWidget(
      _testApp(
        KeyboardFocusRegionRegistry(
          controller: controller,
          child: Column(
            children: [
              KeyboardFocusRegion(
                debugLabel: 'first',
                preferredFocusNode: first,
                child: TextButton(
                  focusNode: first,
                  onPressed: () {},
                  child: const Text('First'),
                ),
              ),
              KeyboardFocusRegion(
                debugLabel: 'second',
                regionId: secondRegionId,
                preferredFocusNode: second,
                child: TextButton(
                  focusNode: second,
                  onPressed: () {},
                  child: const Text('Second'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(controller.focusRegion(Object()), isFalse);
    expect(controller.focusRegion(secondRegionId), isTrue);
    await tester.pump();
    expect(second.hasFocus, isTrue);
  });

  testWidgets('focusRegion uses an updated region identity', (tester) async {
    final controller = KeyboardFocusRegionController();
    final target = FocusNode();
    final firstRegionId = Object();
    final secondRegionId = Object();
    final activeRegionId = ValueNotifier<Object>(firstRegionId);
    addTearDown(controller.dispose);
    addTearDown(target.dispose);
    addTearDown(activeRegionId.dispose);

    await tester.pumpWidget(
      _testApp(
        KeyboardFocusRegionRegistry(
          controller: controller,
          child: ValueListenableBuilder<Object>(
            valueListenable: activeRegionId,
            builder: (context, regionId, child) => KeyboardFocusRegion(
              debugLabel: 'updated-region',
              regionId: regionId,
              preferredFocusNode: target,
              child: child!,
            ),
            child: TextButton(
              focusNode: target,
              onPressed: () {},
              child: const Text('Target'),
            ),
          ),
        ),
      ),
    );

    activeRegionId.value = secondRegionId;
    await tester.pump();

    expect(controller.focusRegion(firstRegionId), isFalse);
    expect(controller.focusRegion(secondRegionId), isTrue);
    await tester.pump();
    expect(target.hasFocus, isTrue);
  });
}

class _TwoFocusRegions extends StatelessWidget {
  const _TwoFocusRegions({required this.first, required this.second});

  final FocusNode first;
  final FocusNode second;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        KeyboardFocusRegion(
          debugLabel: 'first',
          preferredFocusNode: first,
          child: TextButton(
            focusNode: first,
            onPressed: () {},
            child: const Text('First'),
          ),
        ),
        KeyboardFocusRegion(
          debugLabel: 'second',
          preferredFocusNode: second,
          child: TextButton(
            focusNode: second,
            onPressed: () {},
            child: const Text('Second'),
          ),
        ),
      ],
    );
  }
}

Widget _testApp(Widget child) =>
    makeTestableWidgetNoScroll(Scaffold(body: child));
