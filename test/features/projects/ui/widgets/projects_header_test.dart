import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/ui/widgets/projects_header.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Widget wrap(
    Widget child, {
    required Size size,
  }) {
    return makeTestableWidget2(
      Theme(
        data: DesignSystemTheme.dark(),
        child: Scaffold(body: child),
      ),
      mediaQueryData: MediaQueryData(size: size),
    );
  }

  testWidgets('uses the compact Figma title scale on mobile widths', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const ProjectsHeader(
          title: 'Projects',
          searchEnabled: false,
        ),
        size: const Size(402, 874),
      ),
    );
    await tester.pump();

    final title = tester.widget<Text>(find.text('Projects'));

    expect(title.style?.fontSize, 20);
    expect(title.style?.height, 1.4);
  });

  testWidgets('keeps the larger title scale on wider layouts', (tester) async {
    await tester.pumpWidget(
      wrap(
        const ProjectsHeader(
          title: 'Projects',
          searchEnabled: false,
        ),
        size: const Size(1024, 874),
      ),
    );
    await tester.pump();

    final title = tester.widget<Text>(find.text('Projects'));

    expect(title.style?.fontSize, 25);
    expect(title.style?.height, 1.28);
  });

  testWidgets('a centred title without a trailing action uses the display '
      'heading, centred over the header', (tester) async {
    const size = Size(1024, 874);
    await tester.pumpWidget(
      wrap(
        const ProjectsHeader(
          title: 'Projects',
          searchEnabled: false,
          centerTitle: true,
        ),
        size: size,
      ),
    );
    await tester.pump();

    final title = tester.widget<Text>(find.text('Projects'));
    final heading1 = DesignSystemTheme.dark()
        .extension<DsTokens>()!
        .typography
        .styles
        .heading
        .heading1;
    expect(title.textAlign, TextAlign.center);
    expect(title.style?.fontSize, heading1.fontSize);
    expect(
      tester.getCenter(find.text('Projects')).dx,
      moreOrLessEquals(size.width / 2, epsilon: 1),
    );
  });

  testWidgets('a trailing action keeps the centred title in the row', (
    tester,
  ) async {
    const trailingKey = Key('trailing');
    await tester.pumpWidget(
      wrap(
        const ProjectsHeader(
          title: 'Projects',
          searchEnabled: false,
          centerTitle: true,
          titleTrailing: SizedBox(key: trailingKey, width: 40, height: 40),
        ),
        size: const Size(1024, 874),
      ),
    );
    await tester.pump();

    final title = tester.widget<Text>(find.text('Projects'));
    expect(title.textAlign, TextAlign.center);
    expect(title.style?.fontSize, 25, reason: 'row layout keeps heading2');
    expect(
      tester.getCenter(find.byKey(trailingKey)).dy,
      moreOrLessEquals(tester.getCenter(find.text('Projects')).dy, epsilon: 8),
    );
  });
}
