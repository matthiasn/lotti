import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/projects/ui/widgets/projects_header.dart';

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
}
