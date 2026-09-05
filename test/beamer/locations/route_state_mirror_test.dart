import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/locations/route_state_mirror.dart';
import 'package:material_ui/material_ui.dart';

/// Calls [mirrorRouteState] from inside a build, the way Beamer's delegate
/// calls `buildPages`, and records what the listener beside it sees.
class _MirrorsDuringBuild extends StatelessWidget {
  const _MirrorsDuringBuild({required this.flag, required this.value});

  final ValueNotifier<bool> flag;
  final bool value;

  @override
  Widget build(BuildContext context) {
    mirrorRouteState(() => flag.value = value);
    return const SizedBox.shrink();
  }
}

void main() {
  test('outside a frame the write applies at once', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    final flag = ValueNotifier<bool>(false);
    addTearDown(flag.dispose);

    mirrorRouteState(() => flag.value = true);

    expect(flag.value, isTrue);
  });

  testWidgets(
    'inside a build the write waits for the end of the frame, so a sibling '
    'listener is not marked dirty mid-build',
    (tester) async {
      final flag = ValueNotifier<bool>(false);
      addTearDown(flag.dispose);
      final seen = <bool>[];

      await tester.pumpWidget(
        Row(
          textDirection: TextDirection.ltr,
          children: [
            // The listener sits beside the writer, as the sidebar entries sit
            // beside the Beamer delegate — a synchronous notify from the
            // writer's build would be a setState() during build here.
            ValueListenableBuilder<bool>(
              valueListenable: flag,
              builder: (context, value, _) {
                seen.add(value);
                return const SizedBox.shrink();
              },
            ),
            _MirrorsDuringBuild(flag: flag, value: true),
          ],
        ),
      );

      // The frame that built the writer painted the old value; the mirror
      // landed once that frame ended, and the next frame shows it.
      expect(seen, [false]);
      expect(flag.value, isTrue);
      await tester.pump();
      expect(seen, [false, true]);
      expect(tester.takeException(), isNull);
    },
  );
}
