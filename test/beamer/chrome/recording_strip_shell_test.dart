import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/chrome/recording_strip_shell.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/ui/widgets/recording/strip/recording_strip.dart';
import 'package:lotti/features/speech/ui/widgets/recording/strip/recording_strip_layer.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/speech/ui/widgets/recording/strip/strip_test_bench.dart';
import '../../widget_test_utils.dart';

/// Records what bottom inset it was built with, and how many times it was
/// created — a page under the shell.
class _Page extends StatefulWidget {
  const _Page();

  static int created = 0;
  static EdgeInsets? padding;
  static EdgeInsets? viewPadding;

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  @override
  void initState() {
    super.initState();
    _Page.created++;
  }

  @override
  Widget build(BuildContext context) {
    _Page.padding = MediaQuery.paddingOf(context);
    _Page.viewPadding = MediaQuery.viewPaddingOf(context);
    return const SizedBox.expand();
  }
}

void main() {
  late StripBench bench;

  setUp(() {
    bench = StripBench();
    _Page.created = 0;
    _Page.padding = null;
    _Page.viewPadding = null;
  });
  tearDown(() => bench.dispose());

  Future<void> pump(
    WidgetTester tester, {
    bool omitAudio = false,
    MediaQueryData mediaQueryData = phoneMediaQueryData,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        RecordingStripShell(omitAudio: omitAudio, child: const _Page()),
        mediaQueryData: mediaQueryData,
        overrides: bench.overrides,
      ),
    );
    await tester.pump();
  }

  BuildContext shellContext(WidgetTester tester) =>
      tester.element(find.byType(RecordingStripShell));

  testWidgets('with nothing recording the page keeps its own inset', (
    tester,
  ) async {
    await pump(tester);

    expect(find.byType(RecordingStripLayer), findsOneWidget);
    expect(find.byType(RecordingStrip), findsNothing);
    expect(_Page.padding!.bottom, phoneMediaQueryData.padding.bottom);
  });

  testWidgets('a take puts the strip at the bottom edge, inside the gutters, '
      'and lifts the page by its height', (tester) async {
    await pump(tester);
    await bench.startTake(tester);
    await tester.pump(RecordingStripLayer.motion);

    final context = shellContext(tester);
    final offset = RecordingStripShell.bottomOffset(context);
    final reserved = RecordingStripLayer.reservedHeight(
      context,
      RecordingStripContent.strip,
    );
    final gutter = context.designTokens.spacing.step5;
    final strip = tester.getRect(find.byType(RecordingStrip));

    expect(strip.bottom, phoneMediaQueryData.size.height - offset);
    expect(strip.left, gutter);
    expect(strip.right, phoneMediaQueryData.size.width - gutter);
    expect(_Page.padding!.bottom, offset + reserved);
    expect(_Page.viewPadding!.bottom, offset + reserved);
  });

  testWidgets('the page is never torn down when a take starts or ends', (
    tester,
  ) async {
    await pump(tester);
    await bench.startTake(tester);
    await bench.recorder.stop();
    await tester.pump();

    expect(_Page.created, 1);
  });

  testWidgets('on a build without a recorder there is no strip, and the page '
      'keeps its inset through a take', (tester) async {
    await pump(tester, omitAudio: true);
    // Nothing on screen reads the recorder here; build it as the app would.
    ProviderScope.containerOf(
      shellContext(tester),
    ).read(audioRecorderControllerProvider);
    await bench.startTake(tester);

    expect(find.byType(RecordingStripLayer), findsNothing);
    expect(_Page.padding!.bottom, phoneMediaQueryData.padding.bottom);
  });

  testWidgets('bottomOffset is the safe area, never less than step3', (
    tester,
  ) async {
    await pump(tester);
    expect(
      RecordingStripShell.bottomOffset(shellContext(tester)),
      phoneMediaQueryData.padding.bottom,
    );

    await pump(
      tester,
      mediaQueryData: const MediaQueryData(size: Size(390, 844)),
    );
    final context = shellContext(tester);
    expect(
      RecordingStripShell.bottomOffset(context),
      context.designTokens.spacing.step3,
    );
  });
}
