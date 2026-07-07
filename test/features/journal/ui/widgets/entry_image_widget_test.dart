import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/ui/widgets/entry_image_widget.dart';
import 'package:lotti/features/journal/util/image_export_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_view/photo_view.dart';

import '../../../../helpers/fake_entry_controller.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

const _transparentPng = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];

void _pressIconButton(WidgetTester tester, IconData icon) {
  final button = tester.widget<IconButton>(
    find.widgetWithIcon(IconButton, icon),
  );
  expect(button.onPressed, isNotNull);
  button.onPressed!();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory mockDocumentsDirectory;

  JournalImage buildJournalImage({
    String id = 'image-1',
    String imageFile = 'test.jpg',
    String imageDirectory = '/images/',
  }) {
    final now = DateTime(2025, 12, 31, 12);
    return JournalImage(
      meta: Metadata(
        id: id,
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
      ),
      data: ImageData(
        imageId: 'img-uuid-$id',
        imageFile: imageFile,
        imageDirectory: imageDirectory,
        capturedAt: now,
      ),
    );
  }

  String createInvalidImageFile(JournalImage image) {
    final fullPath = getFullImagePath(image);
    Directory(
      fullPath.substring(0, fullPath.lastIndexOf('/')),
    ).createSync(recursive: true);
    File(fullPath).writeAsBytesSync([0x00, 0x01, 0x02, 0x03]);
    return fullPath;
  }

  group('EntryImageWidget', () {
    setUp(() async {
      mockDocumentsDirectory = Directory.systemTemp.createTempSync(
        'entry_image_widget_test_',
      );
      await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..registerSingleton<EditorStateService>(MockEditorStateService())
            ..registerSingleton<Directory>(mockDocumentsDirectory);
        },
      );
    });

    tearDown(() async {
      await tearDownTestGetIt();
      try {
        mockDocumentsDirectory.deleteSync(recursive: true);
      } catch (_) {
        // Ignore cleanup errors
      }
    });

    Widget makeSubject(JournalImage image) {
      return makeTestableWidget(
        EntryImageWidget(image),
        overrides: [createEntryControllerOverride(image)],
        mediaQueryData: phoneMediaQueryData.copyWith(devicePixelRatio: 3),
      );
    }

    testWidgets('decodes via ResizeImage with a positive cacheHeight cap', (
      tester,
    ) async {
      final image = buildJournalImage();
      createInvalidImageFile(image);

      await tester.pumpWidget(makeSubject(image));
      await tester.pump();

      final imageWidget = tester.widget<Image>(find.byType(Image));
      expect(imageWidget.fit, BoxFit.contain);
      expect(imageWidget.errorBuilder, isNotNull);

      // Both axes are capped via ResizeImage so extreme aspect ratios —
      // e.g. panoramas — can't balloon along the unconstrained axis. Source
      // images can be up to 10000×10000 per image_utils.compressAndSave
      // limits. ResizeImagePolicy.fit keeps the source aspect ratio at
      // decode time so the displayed bitmap isn't squashed.
      expect(imageWidget.image, isA<ResizeImage>());
      final resize = imageWidget.image as ResizeImage;
      expect(resize.width, isNotNull);
      expect(resize.width, greaterThan(0));
      expect(resize.height, isNotNull);
      expect(resize.height, greaterThan(0));
      expect(resize.policy, ResizeImagePolicy.fit);
      expect(resize.imageProvider, isA<FileImage>());
    });

    testWidgets(
      'errorBuilder swaps the failed Image without tearing the tree',
      (tester) async {
        final image = buildJournalImage();
        createInvalidImageFile(image);

        await tester.pumpWidget(makeSubject(image));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // Outer scaffolding (GestureDetector → ColoredBox → Hero) must still
        // be in the tree even after the inner Image.file fails to decode the
        // invalid bytes.
        expect(find.byType(EntryImageWidget), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(EntryImageWidget),
            matching: find.byType(Hero),
          ),
          findsOneWidget,
        );
        final hero = tester.widget<Hero>(find.byType(Hero));
        expect(hero.tag, 'entry_img');
      },
    );

    testWidgets(
      'errorBuilder returns SizedBox.shrink and exercises cache eviction',
      (tester) async {
        final image = buildJournalImage();
        createInvalidImageFile(image);

        await tester.pumpWidget(makeSubject(image));
        await tester.pump();

        final imageWidget = tester.widget<Image>(find.byType(Image));
        final builder = imageWidget.errorBuilder!;
        final element = tester.element(find.byType(Image));
        final result = builder(element, Object(), StackTrace.current);

        expect(result, isA<SizedBox>());
        final shrink = result as SizedBox;
        expect(shrink.width, 0.0);
        expect(shrink.height, 0.0);
      },
    );

    testWidgets(
      'tapping the image pushes HeroPhotoViewRouteWrapper onto the navigator',
      (tester) async {
        final image = buildJournalImage();
        createInvalidImageFile(image);

        // Wrap in a fixed-size container so the GestureDetector has non-zero
        // area to receive the tap even though the inner Image collapses on
        // error.
        final subject = ProviderScope(
          overrides: [createEntryControllerOverride(image)],
          child: MaterialApp(
            theme: resolveTestTheme(),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 390,
                height: 400,
                child: EntryImageWidget(image),
              ),
            ),
          ),
        );

        await tester.pumpWidget(subject);
        await tester.pump();

        // Before tap, only EntryImageWidget is in the tree.
        expect(find.byType(HeroPhotoViewRouteWrapper), findsNothing);

        await tester.ensureVisible(find.byType(GestureDetector).first);
        await tester.tap(find.byType(GestureDetector).first);
        // One pump to schedule the route push, one more to build the new route.
        await tester.pump();
        await tester.pump();

        // After navigation, HeroPhotoViewRouteWrapper should be rendered.
        expect(find.byType(HeroPhotoViewRouteWrapper), findsOneWidget);
        // The close icon from the wrapper should be visible.
        expect(find.byIcon(Icons.close_rounded), findsWidgets);
      },
    );
  });

  group('HeroPhotoViewRouteWrapper', () {
    late Directory tempDir;
    late File imageFile;
    late MockLoggingService mockLoggingService;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync(
        'hero_photo_view_test_',
      );
      imageFile = File('${tempDir.path}/photo.png')
        ..writeAsBytesSync(_transparentPng);
      // The viewer logs a swallowed save failure through getIt; register a mock
      // so that path can be asserted without a real logging backend.
      mockLoggingService = MockLoggingService();
      await getIt.reset();
      getIt.registerSingleton<LoggingService>(mockLoggingService);
    });

    tearDown(() async {
      await getIt.reset();
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {
        // Ignore cleanup errors.
      }
    });

    Widget buildWrapper({
      BoxDecoration? backgroundDecoration,
      ImageExporter? imageExporter,
    }) {
      return ProviderScope(
        child: MaterialApp(
          theme: resolveTestTheme(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: HeroPhotoViewRouteWrapper(
            file: imageFile,
            backgroundDecoration: backgroundDecoration,
            imageExporter: imageExporter,
          ),
        ),
      );
    }

    testWidgets(
      'renders PhotoView with download, close, and zoom controls',
      (tester) async {
        await tester.pumpWidget(buildWrapper());
        await tester.pump();

        // Scaffold body must be present.
        expect(find.byType(Scaffold), findsOneWidget);

        // PhotoView carries the hero tag for the shared-element transition.
        expect(find.byType(PhotoView), findsOneWidget);
        final photoView = tester.widget<PhotoView>(find.byType(PhotoView));
        expect(photoView.imageProvider, isA<FileImage>());
        expect(photoView.minScale, PhotoViewComputedScale.contained);
        expect(photoView.initialScale, PhotoViewComputedScale.contained);
        expect(photoView.maxScale, PhotoViewComputedScale.covered * 4);
        expect(photoView.strictScale, isTrue);
        expect(photoView.controller, isA<PhotoViewController>());
        expect(
          photoView.scaleStateController,
          isA<PhotoViewScaleStateController>(),
        );
        expect(
          photoView.heroAttributes?.tag,
          'entry_img',
        );

        expect(find.byTooltip('Download image'), findsOneWidget);
        expect(find.byTooltip('Close'), findsOneWidget);
        expect(find.byTooltip('Zoom In'), findsOneWidget);
        expect(find.byTooltip('Zoom Out'), findsOneWidget);
        expect(find.byTooltip('Actual Size'), findsOneWidget);
        expect(find.text('100%'), findsOneWidget);

        final zoomOutButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.remove_rounded),
        );
        expect(zoomOutButton.onPressed, isNull);
      },
    );

    testWidgets(
      'passes backgroundDecoration to PhotoView when provided',
      (tester) async {
        const decoration = BoxDecoration(color: Colors.red);
        await tester.pumpWidget(buildWrapper(backgroundDecoration: decoration));
        await tester.pump();

        final photoView = tester.widget<PhotoView>(find.byType(PhotoView));
        expect(photoView.backgroundDecoration, decoration);
      },
    );

    testWidgets(
      'close button pops the route when tapped',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        // Push HeroPhotoViewRouteWrapper so there is a route beneath it to
        // pop back to.
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: resolveTestTheme(),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) {
                  return Scaffold(
                    body: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute<void>(
                            builder: (_) => HeroPhotoViewRouteWrapper(
                              file: imageFile,
                            ),
                          ),
                        );
                      },
                      child: const Text('Open'),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pump();

        // Push the wrapper route.
        await tester.tap(find.text('Open'));
        await tester.pump();
        await tester.pump();

        // Wrapper is visible.
        expect(find.byType(HeroPhotoViewRouteWrapper), findsOneWidget);

        _pressIconButton(tester, Icons.close_rounded);
        await tester.pump();
        await tester.pump();

        // The wrapper route has been popped.
        expect(find.byType(HeroPhotoViewRouteWrapper), findsNothing);
        // We're back on the home screen.
        expect(find.text('Open'), findsOneWidget);
      },
    );

    testWidgets(
      'escape key pops the route',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: resolveTestTheme(),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) {
                  return Scaffold(
                    body: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context, rootNavigator: true).push(
                          PageRouteBuilder<void>(
                            opaque: false,
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    HeroPhotoViewRouteWrapper(
                                      file: imageFile,
                                    ),
                          ),
                        );
                      },
                      child: const Text('Open'),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Open'));
        await tester.pump();
        await tester.pump();
        expect(find.byType(HeroPhotoViewRouteWrapper), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        await tester.pump();

        expect(find.byType(HeroPhotoViewRouteWrapper), findsNothing);
        expect(find.text('Open'), findsOneWidget);
      },
    );

    testWidgets(
      'zoom controls update the visible scale and reset to actual size',
      (tester) async {
        await tester.pumpWidget(buildWrapper());
        await tester.pump();

        expect(find.text('100%'), findsOneWidget);

        _pressIconButton(tester, Icons.add_rounded);
        await tester.pump();
        expect(find.text('125%'), findsOneWidget);

        _pressIconButton(tester, Icons.remove_rounded);
        await tester.pump();
        expect(find.text('100%'), findsOneWidget);

        _pressIconButton(tester, Icons.add_rounded);
        await tester.pump();
        expect(find.text('125%'), findsOneWidget);

        await tester.tap(find.text('125%'));
        await tester.pump();
        expect(find.text('100%'), findsOneWidget);
      },
    );

    testWidgets(
      'layout size changes reset the cached minimum zoom scale',
      (tester) async {
        tester.view
          ..physicalSize = const Size(1200, 900)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(buildWrapper());
        await tester.pump();

        _pressIconButton(tester, Icons.add_rounded);
        await tester.pump();
        expect(find.text('125%'), findsOneWidget);
        var zoomOutButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.remove_rounded),
        );
        expect(zoomOutButton.onPressed, isNotNull);

        tester.view.physicalSize = const Size(900, 1200);
        await tester.pump();

        zoomOutButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.remove_rounded),
        );
        expect(zoomOutButton.onPressed, isNull);
      },
    );

    testWidgets(
      'download button echoes the saved file name after a desktop save',
      (tester) async {
        File? savedFile;
        await tester.pumpWidget(
          buildWrapper(
            imageExporter: (file) async {
              savedFile = file;
              return const ImageExportResult.savedToFile('photo 3.png');
            },
          ),
        );
        await tester.pump();

        _pressIconButton(tester, Icons.download_rounded);
        await tester.pump();
        await tester.pump();

        // The original file is handed to the exporter untouched.
        expect(savedFile?.path, imageFile.path);
        expect(find.text('Saved photo 3.png'), findsOneWidget);
      },
    );

    testWidgets(
      'download button confirms a photo-library save on mobile',
      (tester) async {
        await tester.pumpWidget(
          buildWrapper(
            imageExporter: (_) async =>
                const ImageExportResult.savedToGallery(),
          ),
        );
        await tester.pump();

        _pressIconButton(tester, Icons.download_rounded);
        await tester.pump();
        await tester.pump();

        expect(find.text('Saved to Photos'), findsOneWidget);
      },
    );

    testWidgets(
      'download button surfaces a permission-denied message',
      (tester) async {
        await tester.pumpWidget(
          buildWrapper(
            imageExporter: (_) async =>
                const ImageExportResult.permissionDenied(),
          ),
        );
        await tester.pump();

        _pressIconButton(tester, Icons.download_rounded);
        await tester.pump();
        await tester.pump();

        expect(
          find.text('Photo access denied — enable it in Settings'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'download button stays silent and re-enables when the save is cancelled',
      (tester) async {
        await tester.pumpWidget(
          buildWrapper(
            imageExporter: (_) async => const ImageExportResult.cancelled(),
          ),
        );
        await tester.pump();

        _pressIconButton(tester, Icons.download_rounded);
        await tester.pump();
        await tester.pump();

        // A dismissed save panel is not an error: no feedback, button ready.
        expect(find.byType(SnackBar), findsNothing);
        expect(find.byIcon(Icons.hourglass_top_rounded), findsNothing);
        final downloadButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.download_rounded),
        );
        expect(downloadButton.onPressed, isNotNull);
      },
    );

    testWidgets(
      'download button disables while saving and ignores duplicate taps',
      (tester) async {
        final completer = Completer<ImageExportResult>();
        var calls = 0;

        await tester.pumpWidget(
          buildWrapper(
            imageExporter: (_) {
              calls++;
              return completer.future;
            },
          ),
        );
        await tester.pump();

        final downloadButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.download_rounded),
        );
        expect(downloadButton.onPressed, isNotNull);
        // Two taps in the same frame: the second must be ignored while saving.
        downloadButton.onPressed!();
        downloadButton.onPressed!();
        await tester.pump();

        expect(calls, 1);
        expect(find.byTooltip('Saving image'), findsOneWidget);
        final savingButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.hourglass_top_rounded),
        );
        expect(savingButton.onPressed, isNull);

        completer.complete(const ImageExportResult.savedToFile('photo.png'));
        await tester.pump();
        await tester.pump();

        expect(calls, 1);
        expect(find.text('Saved photo.png'), findsOneWidget);
      },
    );

    testWidgets(
      'download button reports failure and logs when the exporter throws',
      (tester) async {
        await tester.pumpWidget(
          buildWrapper(
            imageExporter: (_) async =>
                throw const FileSystemException('save failed'),
          ),
        );
        await tester.pump();

        _pressIconButton(tester, Icons.download_rounded);
        await tester.pump();
        await tester.pump();

        expect(find.text('Could not save image'), findsOneWidget);
        verify(
          () => mockLoggingService.captureException(
            any<dynamic>(),
            domain: 'entry_image_widget',
            subDomain: 'downloadImage',
            stackTrace: any<dynamic>(named: 'stackTrace'),
            level: any(named: 'level'),
            type: any(named: 'type'),
          ),
        ).called(1);
      },
    );

    testWidgets(
      'FileImage is constructed from the provided file',
      (tester) async {
        await tester.pumpWidget(buildWrapper());
        await tester.pump();

        final photoView = tester.widget<PhotoView>(find.byType(PhotoView));
        final fileImage = photoView.imageProvider! as FileImage;
        expect(fileImage.file.path, imageFile.path);
      },
    );
  });
}
