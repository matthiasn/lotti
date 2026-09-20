import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/theme/icon_tokens.dart';
import 'package:lotti/features/settings/ui/pages/flags_page.dart';
import 'package:lotti/features/settings/ui/widgets/config_flag_labels.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

/// Every flag either settings page lists. Deriving it from the two production
/// lists is the point: a flag added to a page without a catalog entry has to
/// fail here rather than render its bare name and a gear.
final _listedFlags = <String>[
  ...sectionFlags,
  ...FlagsBody.defaultDisplayedItems,
];

ConfigFlag _flag(String name) =>
    ConfigFlag(name: name, description: 'raw $name', status: false);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(ensureThemingServicesRegistered);

  /// Pumps a bare host and hands its context to [body]. The catalog resolves
  /// through `context.messages`, so a real `Localizations` ancestor is needed;
  /// nothing here paints.
  Future<void> withContext(
    WidgetTester tester,
    void Function(BuildContext context) body,
  ) async {
    late BuildContext captured;
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    body(captured);
  }

  group('ConfigFlagLabels', () {
    testWidgets('resolves a distinct, non-empty title for every listed flag', (
      tester,
    ) async {
      await withContext(tester, (context) {
        final titles = <String, String>{};
        for (final name in _listedFlags) {
          final title = ConfigFlagLabels.titleFor(context, _flag(name));
          expect(title, isNotEmpty, reason: name);
          // The fallback arm returns the flag name itself, a developer
          // identifier — seeing one means the wiring was forgotten.
          expect(title, isNot(name), reason: '$name has no localized title');
          final clash = titles[title];
          expect(
            clash,
            isNull,
            reason: '$name and $clash share the title "$title"',
          );
          titles[title] = name;
        }
      });
    });

    testWidgets('resolves a subtitle that is never the raw database text', (
      tester,
    ) async {
      await withContext(tester, (context) {
        for (final name in _listedFlags) {
          final flag = _flag(name);
          final subtitle = ConfigFlagLabels.subtitleFor(context, flag);
          expect(subtitle, isNotEmpty, reason: name);
          expect(
            subtitle,
            isNot(flag.description),
            reason: '$name falls back to its English developer description',
          );
        }
      });
    });

    test('gives every listed flag its own glyph rather than the fallback', () {
      for (final name in _listedFlags) {
        expect(
          ConfigFlagLabels.iconFor(name),
          isNot(LottiIcons.settings),
          reason: '$name has no icon of its own',
        );
      }
    });

    testWidgets('falls back to the stored values for a flag it does not know', (
      tester,
    ) async {
      const unknown = ConfigFlag(
        name: 'totally_unknown_flag',
        description: 'Raw description fallback',
        status: false,
      );
      await withContext(tester, (context) {
        // Deliberate, not an oversight: a row the app has stopped defining
        // must still render something rather than crash.
        expect(ConfigFlagLabels.titleFor(context, unknown), unknown.name);
        expect(
          ConfigFlagLabels.subtitleFor(context, unknown),
          unknown.description,
        );
      });
      expect(ConfigFlagLabels.iconFor(unknown.name), LottiIcons.settings);
    });

    testWidgets('resolverFor bundles the title and subtitle a filter reads', (
      tester,
    ) async {
      await withContext(tester, (context) {
        final resolved = ConfigFlagLabels.resolverFor(context)(
          _flag(privateFlag),
        );
        expect(resolved.title, context.messages.configFlagPrivate);
        expect(
          resolved.subtitle,
          context.messages.configFlagPrivateDescription,
        );
      });
    });
  });
}
