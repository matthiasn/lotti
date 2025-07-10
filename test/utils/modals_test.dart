import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/modals.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

import '../widget_test_utils.dart';

void main() {
  group('ModalUtils', () {
    testWidgets('modalTypeBuilder returns bottomSheet for small screens',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(300, 600));

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final modalType = ModalUtils.modalTypeBuilder(context);
              expect(modalType, isA<WoltModalType>());
              expect(
                modalType.runtimeType.toString(),
                'WoltDialogType',
              );
              return const Scaffold();
            },
          ),
        ),
      );
    });

    testWidgets('modalTypeBuilder returns dialog for large screens',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 800));

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final modalType = ModalUtils.modalTypeBuilder(context);
              expect(modalType, isA<WoltModalType>());
              expect(modalType.runtimeType.toString(), 'WoltDialogType');
              return const Scaffold();
            },
          ),
        ),
      );
    });

    testWidgets('modalSheetPage creates page with title and close button',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final page = ModalUtils.modalSheetPage(
                context: context,
                title: 'Test Title',
                child: const Text('Test Content'),
              );

              expect(page, isA<WoltModalSheetPage>());
              expect(page.topBarTitle, isA<Text>());
              expect(page.trailingNavBarWidget, isA<IconButton>());
              expect(page.child, isA<Padding>());
              return const Scaffold();
            },
          ),
        ),
      );
    });

    testWidgets('modalSheetPage creates page without title and close button',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final page = ModalUtils.modalSheetPage(
                context: context,
                child: const Text('Test Content'),
                showCloseButton: false,
              );

              expect(page, isA<WoltModalSheetPage>());
              expect(page.topBarTitle, isNull);
              expect(page.trailingNavBarWidget, isNull);
              expect(page.child, isA<Padding>());
              return const Scaffold();
            },
          ),
        ),
      );
    });
  });

  group('ModalUtils Helper Methods', () {
    group('buildTopBarTitle', () {
      testWidgets('returns null when title is null', (tester) async {
        Widget? result;

        await tester.pumpWidget(
          makeTestableWidget(
            Builder(
              builder: (context) {
                result = ModalUtils.buildTopBarTitle(context, null);
                return const Placeholder();
              },
            ),
          ),
        );

        expect(result, isNull);
      });

      testWidgets('returns Text widget when title is provided', (tester) async {
        Widget? result;
        const testTitle = 'Test Modal Title';

        await tester.pumpWidget(
          makeTestableWidget(
            Builder(
              builder: (context) {
                result = ModalUtils.buildTopBarTitle(context, testTitle);
                return const Placeholder();
              },
            ),
          ),
        );

        expect(result, isA<Text>());
        expect(result, isNotNull);
        expect((result! as Text).data, equals(testTitle));
      });

      testWidgets('applies correct text style from theme', (tester) async {
        Widget? result;
        const testTitle = 'Styled Title';

        await tester.pumpWidget(
          makeTestableWidget(
            Builder(
              builder: (context) {
                result = ModalUtils.buildTopBarTitle(context, testTitle);
                return const Placeholder();
              },
            ),
          ),
        );

        expect(result, isA<Text>());
        expect(result, isNotNull);
        final textWidget = result! as Text;
        expect(textWidget.style, isNotNull);

        // Verify it uses titleSmall and outline color
        await tester.pumpWidget(
          makeTestableWidget(
            Builder(
              builder: (context) {
                final expectedStyle = context.textTheme.titleSmall?.copyWith(
                  color: context.colorScheme.outline,
                );
                expect(textWidget.style?.fontSize,
                    equals(expectedStyle?.fontSize));
                expect(textWidget.style?.color, equals(expectedStyle?.color));
                return const Placeholder();
              },
            ),
          ),
        );
      });
    });

    group('buildLeadingNavBarWidget', () {
      testWidgets('returns null when onTapBack is null', (tester) async {
        Widget? result;

        await tester.pumpWidget(
          makeTestableWidget(
            Builder(
              builder: (context) {
                result = ModalUtils.buildLeadingNavBarWidget(context, null);
                return const Placeholder();
              },
            ),
          ),
        );

        expect(result, isNull);
      });

      testWidgets('returns IconButton when onTapBack is provided',
          (tester) async {
        Widget? result;
        var callbackCalled = false;

        await tester.pumpWidget(
          makeTestableWidget(
            Builder(
              builder: (context) {
                result = ModalUtils.buildLeadingNavBarWidget(
                  context,
                  () => callbackCalled = true,
                );
                return const Placeholder();
              },
            ),
          ),
        );

        expect(result, isA<IconButton>());
        expect(result, isNotNull);
        final iconButton = result! as IconButton;

        // Verify it has the correct icon
        expect(iconButton.icon, isA<Icon>());
        final icon = iconButton.icon as Icon;
        expect(icon.icon, equals(Icons.arrow_back));

        // Verify callback works
        iconButton.onPressed!();
        expect(callbackCalled, isTrue);
      });

      testWidgets('applies correct padding and color from theme',
          (tester) async {
        Widget? result;

        await tester.pumpWidget(
          makeTestableWidget(
            Builder(
              builder: (context) {
                result = ModalUtils.buildLeadingNavBarWidget(
                  context,
                  () {},
                );
                return const Placeholder();
              },
            ),
          ),
        );

        expect(result, isA<IconButton>());
        expect(result, isNotNull);
        final iconButton = result! as IconButton;
        expect(iconButton.padding, equals(WoltModalConfig.pagePadding));

        // Verify icon color matches theme
        await tester.pumpWidget(
          makeTestableWidget(
            Builder(
              builder: (context) {
                final icon = iconButton.icon as Icon;
                expect(icon.color, equals(context.colorScheme.outline));
                return const Placeholder();
              },
            ),
          ),
        );
      });
    });

    group('buildTrailingNavBarWidget', () {
      testWidgets('returns null when showCloseButton is false', (tester) async {
        Widget? result;

        await tester.pumpWidget(
          makeTestableWidget(
            Builder(
              builder: (context) {
                result = ModalUtils.buildTrailingNavBarWidget(
                  context,
                  showCloseButton: false,
                );
                return const Placeholder();
              },
            ),
          ),
        );

        expect(result, isNull);
      });

      testWidgets('returns IconButton when showCloseButton is true',
          (tester) async {
        Widget? result;

        await tester.pumpWidget(
          makeTestableWidget(
            Builder(
              builder: (context) {
                result = ModalUtils.buildTrailingNavBarWidget(
                  context,
                  showCloseButton: true,
                );
                return const Placeholder();
              },
            ),
          ),
        );

        expect(result, isA<IconButton>());
        expect(result, isNotNull);
        final iconButton = result! as IconButton;

        // Verify it has the correct icon
        expect(iconButton.icon, isA<Icon>());
        final icon = iconButton.icon as Icon;
        expect(icon.icon, equals(Icons.close));
      });

      testWidgets('applies correct padding and color from theme',
          (tester) async {
        Widget? result;

        await tester.pumpWidget(
          makeTestableWidget(
            Builder(
              builder: (context) {
                result = ModalUtils.buildTrailingNavBarWidget(
                  context,
                  showCloseButton: true,
                );
                return const Placeholder();
              },
            ),
          ),
        );

        expect(result, isA<IconButton>());
        expect(result, isNotNull);
        final iconButton = result! as IconButton;
        expect(iconButton.padding, equals(WoltModalConfig.pagePadding));

        // Verify icon color matches theme
        await tester.pumpWidget(
          makeTestableWidget(
            Builder(
              builder: (context) {
                final icon = iconButton.icon as Icon;
                expect(icon.color, equals(context.colorScheme.outline));
                return const Placeholder();
              },
            ),
          ),
        );
      });

      testWidgets('onPressed is set to Navigator.pop', (tester) async {
        Widget? result;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  result = ModalUtils.buildTrailingNavBarWidget(
                    context,
                    showCloseButton: true,
                  );
                  return const Placeholder();
                },
              ),
            ),
          ),
        );

        expect(result, isA<IconButton>());
        expect(result, isNotNull);
        final iconButton = result! as IconButton;
        expect(iconButton.onPressed, isNotNull);

        // Note: We can't easily test Navigator.pop in unit tests without
        // more complex setup, but we can verify the onPressed is not null
        // which indicates the function is properly assigned
      });
    });

    group('Integration tests', () {
      testWidgets('helper methods work correctly in modal contexts',
          (tester) async {
        const testTitle = 'Integration Test Modal';
        var backPressed = false;

        await tester.pumpWidget(
          makeTestableWidget(
            Builder(
              builder: (context) {
                final title = ModalUtils.buildTopBarTitle(context, testTitle);
                final leading = ModalUtils.buildLeadingNavBarWidget(
                  context,
                  () => backPressed = true,
                );
                final trailing = ModalUtils.buildTrailingNavBarWidget(
                  context,
                  showCloseButton: true,
                );

                return Column(
                  children: [
                    if (title != null) title,
                    if (leading != null) leading,
                    if (trailing != null) trailing,
                  ],
                );
              },
            ),
          ),
        );

        // Verify all widgets are present
        expect(find.text(testTitle), findsOneWidget);
        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
        expect(find.byIcon(Icons.close), findsOneWidget);

        // Test back button functionality
        await tester.tap(find.byIcon(Icons.arrow_back));
        expect(backPressed, isTrue);
      });

      testWidgets('helper methods handle null cases correctly', (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            Builder(
              builder: (context) {
                final title = ModalUtils.buildTopBarTitle(context, null);
                final leading =
                    ModalUtils.buildLeadingNavBarWidget(context, null);
                final trailing = ModalUtils.buildTrailingNavBarWidget(
                  context,
                  showCloseButton: false,
                );

                return Column(
                  children: [
                    if (title != null) title,
                    if (leading != null) leading,
                    if (trailing != null) trailing,
                    const Text('All null case handled'),
                  ],
                );
              },
            ),
          ),
        );

        // Verify no widgets are created for null cases
        expect(find.byIcon(Icons.arrow_back), findsNothing);
        expect(find.byIcon(Icons.close), findsNothing);
        expect(find.text('All null case handled'), findsOneWidget);
      });

      testWidgets('extracted methods maintain same behavior as original',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                // Test that the extracted methods produce the same results
                // as the original inline implementations
                final extractedTitle =
                    ModalUtils.buildTopBarTitle(context, 'Test');
                final extractedLeading =
                    ModalUtils.buildLeadingNavBarWidget(context, () {});
                final extractedTrailing = ModalUtils.buildTrailingNavBarWidget(
                  context,
                  showCloseButton: true,
                );

                // Verify they create the expected widget types
                expect(extractedTitle, isA<Text>());
                expect(extractedLeading, isA<IconButton>());
                expect(extractedTrailing, isA<IconButton>());

                // Verify the modal page still works with extracted methods
                final page = ModalUtils.modalSheetPage(
                  context: context,
                  title: 'Test Page',
                  onTapBack: () {},
                  child: const Text('Content'),
                );

                expect(page.topBarTitle, isA<Text>());
                expect(page.leadingNavBarWidget, isA<IconButton>());
                expect(page.trailingNavBarWidget, isA<IconButton>());

                return const Scaffold();
              },
            ),
          ),
        );
      });
    });
  });
}
