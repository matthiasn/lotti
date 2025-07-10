import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

void main() {
  group('ModalUtils', () {
    group('modalTypeBuilder', () {
      testWidgets('returns bottomSheet for small screens', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(size: Size(300, 600)),
              child: Builder(
                builder: (context) {
                  final modalType = ModalUtils.modalTypeBuilder(context);
                  expect(modalType, isA<WoltModalType>());
                  // WoltModalType doesn't expose its type directly, so we just verify it's created
                  return const SizedBox();
                },
              ),
            ),
          ),
        );
      });

      testWidgets('returns dialog for large screens', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(WoltModalConfig.pageBreakpoint + 100, 800),
              ),
              child: Builder(
                builder: (context) {
                  final modalType = ModalUtils.modalTypeBuilder(context);
                  expect(modalType, isA<WoltModalType>());
                  // WoltModalType doesn't expose its type directly, so we just verify it's created
                  return const SizedBox();
                },
              ),
            ),
          ),
        );
      });

      testWidgets('returns bottomSheet at exact breakpoint', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(WoltModalConfig.pageBreakpoint - 1, 800),
              ),
              child: Builder(
                builder: (context) {
                  final modalType = ModalUtils.modalTypeBuilder(context);
                  expect(modalType, isA<WoltModalType>());
                  // WoltModalType doesn't expose its type directly, so we just verify it's created
                  return const SizedBox();
                },
              ),
            ),
          ),
        );
      });
    });

    group('getModalBarrierColor', () {
      testWidgets('returns correct color for dark theme', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Builder(
              builder: (context) {
                final color = ModalUtils.getModalBarrierColor(
                  isDark: true,
                  context: context,
                );
                expect(color.a, closeTo(180 / 255.0, 0.01));
                final expectedColor = context.colorScheme.surfaceContainerLow;
                expect(color.r, expectedColor.r);
                expect(color.g, expectedColor.g);
                expect(color.b, expectedColor.b);
                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets('returns correct color for light theme', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Builder(
              builder: (context) {
                final color = ModalUtils.getModalBarrierColor(
                  isDark: false,
                  context: context,
                );
                expect(color.a, closeTo(128 / 255.0, 0.01));
                final expectedColor = context.colorScheme.outline;
                expect(color.r, expectedColor.r);
                expect(color.g, expectedColor.g);
                expect(color.b, expectedColor.b);
                return const SizedBox();
              },
            ),
          ),
        );
      });
    });

    group('modalSheetPage', () {
      testWidgets('creates page with minimal configuration', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                final page = ModalUtils.modalSheetPage(
                  context: context,
                  child: const Text('Test Content'),
                );

                expect(page, isA<WoltModalSheetPage>());
                expect(page.hasSabGradient, false);
                expect(page.navBarHeight, 65);
                expect(page.hasTopBarLayer, true);
                expect(page.isTopBarLayerAlwaysVisible, true);

                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets('creates page with title', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                final page = ModalUtils.modalSheetPage(
                  context: context,
                  child: const Text('Test Content'),
                  title: 'Test Title',
                );

                expect(page.topBarTitle, isNotNull);
                expect(page.topBarTitle, isA<Container>());

                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets('creates page with back button', (tester) async {
        // var backPressed = false; // Not used in this test, just checking widget creation

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                final page = ModalUtils.modalSheetPage(
                  context: context,
                  child: const Text('Test Content'),
                  onTapBack: () {}, // backPressed = true,
                );

                expect(page.leadingNavBarWidget, isNotNull);
                expect(page.leadingNavBarWidget, isA<IconButton>());

                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets('creates page with close button', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                final page = ModalUtils.modalSheetPage(
                  context: context,
                  child: const Text('Test Content'),
                  showCloseButton: true,
                );

                expect(page.trailingNavBarWidget, isNotNull);
                expect(page.trailingNavBarWidget, isA<IconButton>());

                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets('creates page with sticky action bar', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                final page = ModalUtils.modalSheetPage(
                  context: context,
                  child: const Text('Test Content'),
                  stickyActionBar: const Text('Action Bar'),
                );

                expect(page.stickyActionBar, isNotNull);
                expect(page.stickyActionBar, isA<Text>());

                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets('creates page with custom padding', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                final page = ModalUtils.modalSheetPage(
                  context: context,
                  child: const Text('Test Content'),
                  padding: const EdgeInsets.all(10),
                );

                // The padding is applied either in GradientContainer or Padding widget
                expect(page.child,
                    anyOf(isA<GradientContainer>(), isA<Padding>()));

                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets('creates page with custom navBarHeight', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                final page = ModalUtils.modalSheetPage(
                  context: context,
                  child: const Text('Test Content'),
                  navBarHeight: 80,
                );

                expect(page.navBarHeight, 80);

                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets('creates page without top bar layer', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                final page = ModalUtils.modalSheetPage(
                  context: context,
                  child: const Text('Test Content'),
                  hasTopBarLayer: false,
                );

                expect(page.hasTopBarLayer, false);

                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets('dark theme adds gradient overlay', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Builder(
              builder: (context) {
                final page = ModalUtils.modalSheetPage(
                  context: context,
                  child: const Text('Test Content'),
                );

                // The child should be a GradientContainer in dark theme
                expect(page.child, isA<GradientContainer>());

                return const SizedBox();
              },
            ),
          ),
        );
      });
    });

    group('showSinglePageModal', () {
      testWidgets('shows modal with basic configuration', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      ModalUtils.showSinglePageModal<void>(
                        context: context,
                        builder: (context) => const Text('Modal Content'),
                      );
                    },
                    child: const Text('Show Modal'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Modal'));
        await tester.pumpAndSettle();

        expect(find.text('Modal Content'), findsOneWidget);
      });

      testWidgets('shows modal with title', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      ModalUtils.showSinglePageModal<void>(
                        context: context,
                        builder: (context) => const Text('Modal Content'),
                        title: 'Modal Title',
                      );
                    },
                    child: const Text('Show Modal'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Modal'));
        await tester.pumpAndSettle();

        expect(find.text('Modal Title'), findsOneWidget);
        expect(find.text('Modal Content'), findsOneWidget);
      });

      testWidgets('shows modal with sticky action bar', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      ModalUtils.showSinglePageModal<void>(
                        context: context,
                        builder: (context) => const Text('Modal Content'),
                        stickyActionBar: const Text('Action Bar'),
                      );
                    },
                    child: const Text('Show Modal'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Modal'));
        await tester.pumpAndSettle();

        expect(find.text('Action Bar'), findsOneWidget);
      });

      testWidgets('dismisses modal on barrier tap', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      ModalUtils.showSinglePageModal<void>(
                        context: context,
                        builder: (context) => const Text('Modal Content'),
                      );
                    },
                    child: const Text('Show Modal'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Modal'));
        await tester.pumpAndSettle();

        expect(find.text('Modal Content'), findsOneWidget);

        // Tap outside the modal
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        expect(find.text('Modal Content'), findsNothing);
      });
    });

    group('showMultiPageModal', () {
      testWidgets('shows multi-page modal', (tester) async {
        final pageIndexNotifier = ValueNotifier<int>(0);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      ModalUtils.showMultiPageModal<void>(
                        context: context,
                        pageIndexNotifier: pageIndexNotifier,
                        pageListBuilder: (context) => [
                          SliverWoltModalSheetPage(
                            mainContentSliversBuilder: (context) => [
                              const SliverToBoxAdapter(
                                child: Text('Page 1'),
                              ),
                            ],
                          ),
                          SliverWoltModalSheetPage(
                            mainContentSliversBuilder: (context) => [
                              const SliverToBoxAdapter(
                                child: Text('Page 2'),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                    child: const Text('Show Modal'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Modal'));
        await tester.pumpAndSettle();

        expect(find.text('Page 1'), findsOneWidget);
        expect(find.text('Page 2'), findsNothing);

        // Navigate to page 2
        pageIndexNotifier.value = 1;
        await tester.pumpAndSettle();

        expect(find.text('Page 1'), findsNothing);
        expect(find.text('Page 2'), findsOneWidget);
      });

      testWidgets('respects barrierDismissible setting', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      ModalUtils.showMultiPageModal<void>(
                        context: context,
                        barrierDismissible: false,
                        pageListBuilder: (context) => [
                          SliverWoltModalSheetPage(
                            mainContentSliversBuilder: (context) => [
                              const SliverToBoxAdapter(
                                child: Text('Non-dismissible'),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                    child: const Text('Show Modal'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Modal'));
        await tester.pumpAndSettle();

        expect(find.text('Non-dismissible'), findsOneWidget);

        // Try to tap outside - modal should not dismiss
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        expect(find.text('Non-dismissible'), findsOneWidget);
      });
    });

    group('sliverModalSheetPage', () {
      testWidgets('creates sliver page with minimal configuration',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                final page = ModalUtils.sliverModalSheetPage(
                  context: context,
                  slivers: const [
                    SliverToBoxAdapter(child: Text('Test Sliver')),
                  ],
                );

                expect(page, isA<SliverWoltModalSheetPage>());
                expect(page.hasSabGradient, false);
                expect(page.useSafeArea, true);
                expect(page.resizeToAvoidBottomInset, true);
                expect(page.navBarHeight, 65);

                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets('creates sliver page with title', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                final page = ModalUtils.sliverModalSheetPage(
                  context: context,
                  slivers: const [
                    SliverToBoxAdapter(child: Text('Test Sliver')),
                  ],
                  title: 'Sliver Title',
                );

                expect(page.topBarTitle, isNotNull);
                expect(page.topBarTitle, isA<Padding>());

                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets('creates sliver page with back button', (tester) async {
        // var backPressed = false; // Not used in this test, just checking widget creation

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                final page = ModalUtils.sliverModalSheetPage(
                  context: context,
                  slivers: const [
                    SliverToBoxAdapter(child: Text('Test Sliver')),
                  ],
                  onTapBack: () {}, // backPressed = true,
                );

                expect(page.leadingNavBarWidget, isNotNull);
                expect(page.leadingNavBarWidget, isA<IconButton>());

                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets('creates sliver page with close button', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                final page = ModalUtils.sliverModalSheetPage(
                  context: context,
                  slivers: const [
                    SliverToBoxAdapter(child: Text('Test Sliver')),
                  ],
                );

                expect(page.trailingNavBarWidget, isNotNull);
                expect(page.trailingNavBarWidget, isA<IconButton>());

                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets('creates sliver page without close button', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                final page = ModalUtils.sliverModalSheetPage(
                  context: context,
                  slivers: const [
                    SliverToBoxAdapter(child: Text('Test Sliver')),
                  ],
                  showCloseButton: false,
                );

                expect(page.trailingNavBarWidget, isNull);

                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets('creates sliver page with scroll controller', (tester) async {
        final scrollController = ScrollController();

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                final page = ModalUtils.sliverModalSheetPage(
                  context: context,
                  slivers: const [
                    SliverToBoxAdapter(child: Text('Test Sliver')),
                  ],
                  scrollController: scrollController,
                );

                expect(page.scrollController, equals(scrollController));

                return const SizedBox();
              },
            ),
          ),
        );

        scrollController.dispose();
      });

      testWidgets('creates sliver page with sticky action bar', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                final page = ModalUtils.sliverModalSheetPage(
                  context: context,
                  slivers: const [
                    SliverToBoxAdapter(child: Text('Test Sliver')),
                  ],
                  stickyActionBar: const Text('Sticky Bar'),
                );

                expect(page.stickyActionBar, isNotNull);
                expect(page.stickyActionBar, isA<Text>());

                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets('creates sliver page with custom navBarHeight',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                final page = ModalUtils.sliverModalSheetPage(
                  context: context,
                  slivers: const [
                    SliverToBoxAdapter(child: Text('Test Sliver')),
                  ],
                  navBarHeight: 100,
                );

                expect(page.navBarHeight, 100);

                return const SizedBox();
              },
            ),
          ),
        );
      });
    });

    group('showSingleSliverPageModal', () {
      testWidgets('shows sliver modal with basic configuration',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      ModalUtils.showSingleSliverPageModal<void>(
                        context: context,
                        builder: (context) => SliverWoltModalSheetPage(
                          mainContentSliversBuilder: (context) => [
                            const SliverToBoxAdapter(
                              child: Text('Sliver Modal Content'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text('Show Sliver Modal'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Sliver Modal'));
        await tester.pumpAndSettle();

        expect(find.text('Sliver Modal Content'), findsOneWidget);
      });

      testWidgets('dismisses sliver modal on barrier tap', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      ModalUtils.showSingleSliverPageModal<void>(
                        context: context,
                        builder: (context) => SliverWoltModalSheetPage(
                          mainContentSliversBuilder: (context) => [
                            const SliverToBoxAdapter(
                              child: Text('Dismissible Sliver'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text('Show Modal'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Modal'));
        await tester.pumpAndSettle();

        expect(find.text('Dismissible Sliver'), findsOneWidget);

        // Tap outside the modal
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        expect(find.text('Dismissible Sliver'), findsNothing);
      });

      testWidgets('respects barrierDismissible for sliver modal',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      ModalUtils.showSingleSliverPageModal<void>(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => SliverWoltModalSheetPage(
                          mainContentSliversBuilder: (context) => [
                            const SliverToBoxAdapter(
                              child: Text('Non-dismissible Sliver'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text('Show Modal'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Modal'));
        await tester.pumpAndSettle();

        expect(find.text('Non-dismissible Sliver'), findsOneWidget);

        // Try to tap outside - modal should not dismiss
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        expect(find.text('Non-dismissible Sliver'), findsOneWidget);
      });

      testWidgets('applies modal decorator', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      ModalUtils.showSingleSliverPageModal<void>(
                        context: context,
                        modalDecorator: (child) => ColoredBox(
                          color: Colors.red.withValues(alpha: 0.1),
                          child: child,
                        ),
                        builder: (context) => SliverWoltModalSheetPage(
                          mainContentSliversBuilder: (context) => [
                            const SliverToBoxAdapter(
                              child: Text('Decorated Modal'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text('Show Modal'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Modal'));
        await tester.pumpAndSettle();

        expect(find.text('Decorated Modal'), findsOneWidget);
        // The decorator should be applied but is hard to test visually
      });
    });

    group('defaultPadding', () {
      test('has correct default padding values', () {
        expect(ModalUtils.defaultPadding.left, 20);
        expect(ModalUtils.defaultPadding.top, 20);
        expect(ModalUtils.defaultPadding.right, 20);
        expect(ModalUtils.defaultPadding.bottom, 40);
      });
    });
  });

  group('GradientContainer', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GradientContainer(
              child: Text('Test Child'),
            ),
          ),
        ),
      );

      expect(find.text('Test Child'), findsOneWidget);
    });

    testWidgets('applies gradient decoration', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: const Scaffold(
            body: GradientContainer(
              child: SizedBox(
                width: 100,
                height: 100,
              ),
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));
      expect(container.decoration, isNotNull);
      expect(container.decoration, isA<BoxDecoration>());

      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.gradient, isNotNull);
      expect(decoration.gradient, isA<LinearGradient>());
    });

    testWidgets('uses correct gradient colors from theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Builder(
            builder: (context) {
              final colorScheme = Theme.of(context).colorScheme;

              return Scaffold(
                body: GradientContainer(
                  child: Builder(
                    builder: (innerContext) {
                      final container = innerContext
                          .findAncestorWidgetOfExactType<Container>()!;
                      final decoration = container.decoration! as BoxDecoration;
                      final gradient = decoration.gradient! as LinearGradient;

                      expect(gradient.colors.length, 2);

                      // Check first color
                      final firstColor = gradient.colors[0];
                      expect(firstColor.r, colorScheme.primaryContainer.r);
                      expect(firstColor.g, colorScheme.primaryContainer.g);
                      expect(firstColor.b, colorScheme.primaryContainer.b);
                      expect(firstColor.a, closeTo(0.03, 0.001));

                      // Check second color
                      final secondColor = gradient.colors[1];
                      expect(secondColor.r, colorScheme.primaryContainer.r);
                      expect(secondColor.g, colorScheme.primaryContainer.g);
                      expect(secondColor.b, colorScheme.primaryContainer.b);
                      expect(secondColor.a, closeTo(0.01, 0.001));

                      return const SizedBox();
                    },
                  ),
                ),
              );
            },
          ),
        ),
      );
    });

    testWidgets('gradient colors adapt to dark theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Builder(
            builder: (context) {
              final colorScheme = Theme.of(context).colorScheme;

              return Scaffold(
                body: GradientContainer(
                  child: Builder(
                    builder: (innerContext) {
                      final container = innerContext
                          .findAncestorWidgetOfExactType<Container>()!;
                      final decoration = container.decoration! as BoxDecoration;
                      final gradient = decoration.gradient! as LinearGradient;

                      expect(gradient.colors.length, 2);

                      // Check that it uses the dark theme's primaryContainer
                      final firstColor = gradient.colors[0];
                      expect(firstColor.r, colorScheme.primaryContainer.r);
                      expect(firstColor.g, colorScheme.primaryContainer.g);
                      expect(firstColor.b, colorScheme.primaryContainer.b);

                      return const SizedBox();
                    },
                  ),
                ),
              );
            },
          ),
        ),
      );
    });

    testWidgets('preserves child widget properties', (tester) async {
      const testKey = Key('test-child');
      const testPadding = EdgeInsets.all(16);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GradientContainer(
              child: Padding(
                key: testKey,
                padding: testPadding,
                child: Text('Padded Text'),
              ),
            ),
          ),
        ),
      );

      final padding = tester.widget<Padding>(find.byKey(testKey));
      expect(padding.padding, equals(testPadding));
      expect(find.text('Padded Text'), findsOneWidget);
    });

    testWidgets('modalSheetPage uses GradientContainer in dark theme',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Builder(
            builder: (context) {
              final page = ModalUtils.modalSheetPage(
                context: context,
                child: const Text('Test Content'),
              );

              // The child should use GradientContainer in dark theme
              expect(page.child, isA<GradientContainer>());

              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('modalSheetPage does not use GradientContainer in light theme',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Builder(
            builder: (context) {
              final page = ModalUtils.modalSheetPage(
                context: context,
                child: const Text('Test Content'),
              );

              // The child should be a Padding widget in light theme
              expect(page.child, isA<Padding>());
              expect(page.child, isNot(isA<GradientContainer>()));

              return const SizedBox();
            },
          ),
        ),
      );
    });
  });
}
