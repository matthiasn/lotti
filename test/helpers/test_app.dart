import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/themes/legacy_material_bridge.dart';
import 'package:material_ui/material_ui.dart';

const phoneMediaQueryData = MediaQueryData(
  size: Size(390, 844),
  padding: EdgeInsets.only(top: 47, bottom: 34),
);

ThemeData resolveTestTheme([ThemeData? theme]) {
  final baseTheme = theme ?? ThemeData(useMaterial3: true);
  if (baseTheme.extension<DsTokens>() != null) {
    return baseTheme;
  }

  final tokens = baseTheme.brightness == Brightness.dark
      ? dsTokensDark
      : dsTokensLight;

  return baseTheme.copyWith(
    extensions: baseTheme.extensions.values.followedBy([tokens]),
  );
}

/// Uses the actual test viewport by default. Explicit device fixtures update
/// the render viewport as well as MediaQuery, and restore view overrides after
/// the test so a subsequent suite cannot inherit this device's dimensions.
MediaQueryData _resolveTestMediaQuery(MediaQueryData? data) {
  final view =
      TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
  final viewData = MediaQueryData.fromView(view);
  if (data == null) return viewData;
  // Flags-only fixtures (for example reduced motion) inherit the viewport.
  if (data.size == Size.zero) {
    return data.copyWith(
      size: viewData.size,
      devicePixelRatio: viewData.devicePixelRatio,
    );
  }
  view
    ..devicePixelRatio = data.devicePixelRatio
    ..physicalSize = data.size * data.devicePixelRatio;
  addTearDown(() {
    view
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });
  return data;
}

Widget _testApp(
  Widget child, {
  MediaQueryData? mediaQueryData,
  ThemeData? theme,
  Locale? locale,
  List<NavigatorObserver> navigatorObservers = const [],
  GlobalKey<NavigatorState>? navigatorKey,
}) => MediaQuery(
  data: _resolveTestMediaQuery(mediaQueryData),
  child: MaterialApp(
    builder: LegacyMaterialBridge.builder,
    debugShowCheckedModeBanner: false,
    navigatorKey: navigatorKey,
    navigatorObservers: navigatorObservers,
    theme: resolveTestTheme(theme),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      FormBuilderLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    locale: locale,
    home: child,
  ),
);

Widget makeTestableWidget(
  Widget child, {
  MediaQueryData? mediaQueryData,
  List<Override> overrides = const [],
  ThemeData? theme,
  Locale? locale,
}) => makeTestableWidgetNoScroll(
  SingleChildScrollView(child: child),
  mediaQueryData: mediaQueryData,
  overrides: overrides,
  theme: theme,
  locale: locale,
);

Widget makeTestableWidget2(
  Widget child, {
  MediaQueryData? mediaQueryData,
  ThemeData? theme,
  Locale? locale,
}) => _testApp(
  child,
  mediaQueryData: mediaQueryData,
  theme: theme,
  locale: locale,
);

Widget makeTestableWidgetWithScaffold(
  Widget child, {
  List<Override> overrides = const [],
  ThemeData? theme,
  MediaQueryData? mediaQueryData,
  Locale? locale,
}) => makeTestableWidgetNoScroll(
  Scaffold(body: SingleChildScrollView(child: child)),
  mediaQueryData: mediaQueryData,
  overrides: overrides,
  theme: theme,
  locale: locale,
);

Widget makeTestableWidgetNoScroll(
  Widget child, {
  List<Override> overrides = const [],
  MediaQueryData? mediaQueryData,
  ThemeData? theme,
  Locale? locale,
  List<NavigatorObserver> navigatorObservers = const [],
  GlobalKey<NavigatorState>? navigatorKey,
}) => ProviderScope(
  overrides: overrides,
  child: _testApp(
    child,
    mediaQueryData: mediaQueryData,
    theme: theme,
    locale: locale,
    navigatorObservers: navigatorObservers,
    navigatorKey: navigatorKey,
  ),
);

/// Like [makeTestableWidgetNoScroll], but exposes the [ProviderContainer].
/// Callers must dispose the container, usually with `addTearDown`.
/// Set [retry] to `(_, _) => null` when deliberately testing provider errors.
({Widget widget, ProviderContainer container}) makeTestableWidgetWithContainer(
  Widget child, {
  List<Override> overrides = const [],
  MediaQueryData? mediaQueryData,
  ThemeData? theme,
  Locale? locale,
  Duration? Function(int retryCount, Object error)? retry,
}) {
  final container = ProviderContainer(overrides: overrides, retry: retry);
  return (
    container: container,
    widget: UncontrolledProviderScope(
      container: container,
      child: _testApp(
        child,
        mediaQueryData: mediaQueryData,
        theme: theme,
        locale: locale,
      ),
    ),
  );
}
