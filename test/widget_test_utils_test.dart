import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import 'widget_test_utils.dart';

class _MarkerTheme extends ThemeExtension<_MarkerTheme> {
  const _MarkerTheme(this.value);

  final int value;

  @override
  _MarkerTheme copyWith({int? value}) => _MarkerTheme(value ?? this.value);

  @override
  _MarkerTheme lerp(_MarkerTheme? other, double t) => this;
}

void main() {
  testWidgets('default media size follows the actual test view', (
    tester,
  ) async {
    const size = Size(1000, 900);
    setTestSurfaceSize(tester, size);
    late Size mediaSize;
    const childKey = ValueKey('surface');
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Builder(
          builder: (context) {
            mediaSize = MediaQuery.sizeOf(context);
            return const SizedBox.expand(key: childKey);
          },
        ),
      ),
    );
    expect(mediaSize, size);
    expect(tester.getSize(find.byKey(childKey)), size);
  });

  testWidgets('flags-only media fixtures preserve the actual viewport', (
    tester,
  ) async {
    const size = Size(1000, 900);
    setTestSurfaceSize(tester, size);
    tester.view.devicePixelRatio = 2;
    late MediaQueryData actual;
    const childKey = ValueKey('flags-only-surface');
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Builder(
          builder: (context) {
            actual = MediaQuery.of(context);
            return const SizedBox.expand(key: childKey);
          },
        ),
        mediaQueryData: const MediaQueryData(disableAnimations: true),
      ),
    );
    expect(actual.disableAnimations, isTrue);
    expect(actual.size, size / 2);
    expect(actual.devicePixelRatio, 2);
    expect(tester.getSize(find.byKey(childKey)), actual.size);
    expect(tester.view.physicalSize, size);
  });

  testWidgets('explicit media size also configures the render viewport', (
    tester,
  ) async {
    const childKey = ValueKey('surface');
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const SizedBox.expand(key: childKey),
        mediaQueryData: phoneMediaQueryData,
      ),
    );
    expect(tester.getSize(find.byKey(childKey)), phoneMediaQueryData.size);
    expect(
      tester.view.physicalSize / tester.view.devicePixelRatio,
      phoneMediaQueryData.size,
    );
  });

  testWidgets('scaffold content is not capped at an unrelated 800 pixels', (
    tester,
  ) async {
    setTestSurfaceSize(tester, const Size(1200, 1000));
    const childKey = ValueKey('content');
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const SizedBox(key: childKey, width: 1000, height: 900),
      ),
    );
    expect(tester.getSize(find.byKey(childKey)), const Size(1000, 900));
  });

  testWidgets('explicit media settings reach the child and reset the view', (
    tester,
  ) async {
    final originalSize = tester.view.physicalSize;
    final originalRatio = tester.view.devicePixelRatio;
    addTearDown(() {
      expect(tester.view.physicalSize, originalSize);
      expect(tester.view.devicePixelRatio, originalRatio);
    });
    const media = MediaQueryData(
      size: Size(412, 915),
      devicePixelRatio: 2,
      padding: EdgeInsets.only(top: 32),
      viewPadding: EdgeInsets.only(top: 32, bottom: 24),
      viewInsets: EdgeInsets.only(bottom: 300),
      textScaler: TextScaler.linear(1.8),
      disableAnimations: true,
    );
    late MediaQueryData observed;
    late String locale;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Builder(
          builder: (context) {
            observed = MediaQuery.of(context);
            locale = AppLocalizations.of(context)!.localeName;
            return const SizedBox.shrink();
          },
        ),
        mediaQueryData: media,
        locale: const Locale('de'),
      ),
    );
    expect(observed, media);
    expect(locale, 'de');
    expect(tester.view.physicalSize, const Size(824, 1830));
    expect(tester.view.devicePixelRatio, 2);
  });

  for (final name in ['scroll', 'plain', 'scaffold', 'noScroll', 'container']) {
    for (final brightness in Brightness.values) {
      testWidgets('$name preserves $brightness theme and explicit width', (
        tester,
      ) async {
        late ThemeData observedTheme;
        late Size mediaSize;
        late double width;
        const marker = _MarkerTheme(17);
        final theme = ThemeData(
          brightness: brightness,
          extensions: const [marker],
        );
        final child = LayoutBuilder(
          builder: (context, constraints) {
            observedTheme = Theme.of(context);
            mediaSize = MediaQuery.sizeOf(context);
            width = constraints.maxWidth;
            return const SizedBox(height: 40);
          },
        );
        const media = MediaQueryData(size: Size(360, 780));
        final Widget widget;
        switch (name) {
          case 'scroll':
            widget = makeTestableWidget(
              child,
              mediaQueryData: media,
              theme: theme,
            );
          case 'plain':
            widget = makeTestableWidget2(
              child,
              mediaQueryData: media,
              theme: theme,
            );
          case 'scaffold':
            widget = makeTestableWidgetWithScaffold(
              child,
              mediaQueryData: media,
              theme: theme,
            );
          case 'noScroll':
            widget = makeTestableWidgetNoScroll(
              child,
              mediaQueryData: media,
              theme: theme,
            );
          case 'container':
            final harness = makeTestableWidgetWithContainer(
              child,
              mediaQueryData: media,
              theme: theme,
            );
            addTearDown(harness.container.dispose);
            widget = harness.widget;
          default:
            throw StateError(name);
        }
        await tester.pumpWidget(widget);
        expect(mediaSize, media.size);
        expect(width, 360);
        expect(observedTheme.brightness, brightness);
        expect(observedTheme.extension<_MarkerTheme>(), same(marker));
        expect(
          observedTheme.extension<DsTokens>(),
          same(brightness == Brightness.dark ? dsTokensDark : dsTokensLight),
        );
      });
    }
  }

  for (final brightness in Brightness.values) {
    test('adds $brightness tokens while retaining caller theme extensions', () {
      const marker = _MarkerTheme(42);
      final resolved = resolveTestTheme(
        ThemeData(brightness: brightness, extensions: const [marker]),
      );
      expect(resolved.extension<_MarkerTheme>(), same(marker));
      expect(
        resolved.extension<DsTokens>(),
        same(brightness == Brightness.dark ? dsTokensDark : dsTokensLight),
      );
    });
  }
}
