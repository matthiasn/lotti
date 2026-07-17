import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/settings_v2/domain/settings_node.dart';
import 'package:lotti/features/settings_v2/ui/mobile/settings_mobile_nav.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

const _theming = SettingsNode(
  id: 'theming',
  icon: Icons.palette_outlined,
  title: 'Theming',
  desc: '',
  panel: 'theming',
);

// A node whose id has no entry in `settingsNodeUrls` — e.g. the
// `whats-new` leaf, which opens a modal instead of beaming. The inert
// path is what guarantees a tap on it never triggers navigation.
const _unrouted = SettingsNode(
  id: 'no-such-node',
  icon: Icons.help_outline,
  title: 'Unrouted',
  desc: '',
);

const _manual = SettingsNode(
  id: 'manual',
  icon: Icons.menu_book_outlined,
  title: 'Manual',
  desc: 'Opens in your browser',
  action: SettingsNodeAction.openManual,
);

Future<void> _tapNode(WidgetTester tester, SettingsNode node) async {
  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      Consumer(
        builder: (context, ref, _) => TextButton(
          onPressed: () => handleSettingsNodeTap(context, ref, node),
          child: const Text('go'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pump();
}

void main() {
  String? beamed;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    beamed = null;
    beamToNamedOverride = (path) => beamed = path;
  });

  tearDown(() => beamToNamedOverride = null);

  testWidgets('a routed node beams to its canonical settings URL', (
    tester,
  ) async {
    await _tapNode(tester, _theming);
    expect(beamed, '/settings/theming');
  });

  testWidgets('a node with no registered URL is inert (no navigation)', (
    tester,
  ) async {
    await _tapNode(tester, _unrouted);
    expect(beamed, isNull);
  });

  testWidgets('the Manual action opens externally instead of beaming', (
    tester,
  ) async {
    final originalLauncher = UrlLauncherPlatform.instance;
    final launcher = MockUrlLauncher();
    UrlLauncherPlatform.instance = launcher;
    addTearDown(() => UrlLauncherPlatform.instance = originalLauncher);
    when(() => launcher.launchUrl(any(), any())).thenAnswer((_) async => true);

    await _tapNode(tester, _manual);

    verify(
      () => launcher.launchUrl(
        'https://matthiasn.github.io/lotti/manual/development/',
        any(),
      ),
    ).called(1);
    expect(beamed, isNull);
  });
}
