import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/ui/widgets/entry_image_widget.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/utils/image_utils.dart';
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

Future<void> _runAndWaitForFileSystem(
  WidgetTester tester,
  VoidCallback action,
  bool Function() isReady,
) async {
  await tester.runAsync(() async {
    action();
    for (var i = 0; i < 250 && !isReady(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  });
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

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync(
        'hero_photo_view_test_',
      );
      imageFile = File('${tempDir.path}/photo.png')
        ..writeAsBytesSync(_transparentPng);
    });

    tearDown(() async {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {
        // Ignore cleanup errors.
      }
    });

    Widget buildWrapper({
      BoxDecoration? backgroundDecoration,
      ImageViewerDownloadsDirectoryResolver? downloadsDirectoryResolver,
      ImageViewerFileCopier? fileCopier,
    }) {
      final wrapper = switch ((downloadsDirectoryResolver, fileCopier)) {
        (null, null) => HeroPhotoViewRouteWrapper(
          file: imageFile,
          backgroundDecoration: backgroundDecoration,
        ),
        (final resolver?, null) => HeroPhotoViewRouteWrapper(
          file: imageFile,
          backgroundDecoration: backgroundDecoration,
          downloadsDirectoryResolver: resolver,
        ),
        (null, final copier?) => HeroPhotoViewRouteWrapper(
          file: imageFile,
          backgroundDecoration: backgroundDecoration,
          fileCopier: copier,
        ),
        (final resolver?, final copier?) => HeroPhotoViewRouteWrapper(
          file: imageFile,
          backgroundDecoration: backgroundDecoration,
          downloadsDirectoryResolver: resolver,
          fileCopier: copier,
        ),
      };

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
          home: wrapper,
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
      'download button copies the image to Downloads/Lotti with a unique name',
      (tester) async {
        final downloadsDir = Directory('${tempDir.path}/Downloads')
          ..createSync();
        final lottiDownloads = Directory('${downloadsDir.path}/Lotti')
          ..createSync();
        File('${lottiDownloads.path}/photo.png').writeAsBytesSync([0x01]);
        File('${lottiDownloads.path}/photo 2.png').writeAsBytesSync([0x02]);

        await tester.pumpWidget(
          buildWrapper(
            downloadsDirectoryResolver: () => Future.value(downloadsDir),
            fileCopier: (sourceFile, targetFile) {
              targetFile.writeAsBytesSync(sourceFile.readAsBytesSync());
              return Future.value(targetFile);
            },
          ),
        );
        await tester.pump();

        final copied = File('${lottiDownloads.path}/photo 3.png');
        final downloadButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.download_rounded),
        );
        expect(downloadButton.onPressed, isNotNull);
        await _runAndWaitForFileSystem(
          tester,
          downloadButton.onPressed!,
          copied.existsSync,
        );
        await tester.pump();
        await tester.pump();

        expect(copied.existsSync(), isTrue);
        expect(copied.readAsBytesSync(), _transparentPng);
        expect(
          find.text('Saved photo 3.png to Downloads/Lotti'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'download button uses the default copier when the file name is free',
      (tester) async {
        final downloadsDir = Directory('${tempDir.path}/Downloads')
          ..createSync();
        final lottiDownloads = Directory('${downloadsDir.path}/Lotti')
          ..createSync();
        final copied = File('${lottiDownloads.path}/photo.png');

        await tester.pumpWidget(
          buildWrapper(
            downloadsDirectoryResolver: () => Future.value(downloadsDir),
          ),
        );
        await tester.pump();

        final downloadButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.download_rounded),
        );
        expect(downloadButton.onPressed, isNotNull);
        await _runAndWaitForFileSystem(
          tester,
          downloadButton.onPressed!,
          copied.existsSync,
        );
        await tester.pump();
        await tester.pump();

        expect(copied.existsSync(), isTrue);
        expect(copied.readAsBytesSync(), _transparentPng);
      },
    );

    testWidgets(
      'download button disables while copying and ignores duplicate taps',
      (tester) async {
        final downloadsDir = Directory('${tempDir.path}/Downloads')
          ..createSync();
        Directory('${downloadsDir.path}/Lotti').createSync();
        final copyCompleter = Completer<File>();
        var copyCalls = 0;
        late File pendingTarget;

        await tester.pumpWidget(
          buildWrapper(
            downloadsDirectoryResolver: () => Future.value(downloadsDir),
            fileCopier: (sourceFile, targetFile) {
              copyCalls++;
              pendingTarget = targetFile;
              return copyCompleter.future;
            },
          ),
        );
        await tester.pump();

        final downloadButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.download_rounded),
        );
        expect(downloadButton.onPressed, isNotNull);
        await _runAndWaitForFileSystem(
          tester,
          () {
            downloadButton.onPressed!();
            downloadButton.onPressed!();
          },
          () => copyCalls == 1,
        );
        await tester.pump();

        expect(copyCalls, 1);
        expect(find.byTooltip('Saving image'), findsOneWidget);
        final savingButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.hourglass_top_rounded),
        );
        expect(savingButton.onPressed, isNull);

        pendingTarget.writeAsBytesSync(imageFile.readAsBytesSync());
        copyCompleter.complete(pendingTarget);
        await tester.pump();

        expect(
          find.text('Saved photo.png to Downloads/Lotti'),
          findsOneWidget,
        );
        expect(copyCalls, 1);
      },
    );

    testWidgets(
      'download button reports failure when downloads are unavailable',
      (tester) async {
        await tester.pumpWidget(
          buildWrapper(
            downloadsDirectoryResolver: () async => null,
          ),
        );
        await tester.pump();

        _pressIconButton(tester, Icons.download_rounded);
        await tester.pump();
        await tester.pump();

        expect(find.text('Could not save image'), findsOneWidget);
      },
    );

    testWidgets(
      'download button reports failure when copying throws',
      (tester) async {
        final downloadsDir = Directory('${tempDir.path}/Downloads')
          ..createSync();
        Directory('${downloadsDir.path}/Lotti').createSync();
        var copyAttempted = false;

        await tester.pumpWidget(
          buildWrapper(
            downloadsDirectoryResolver: () => Future.value(downloadsDir),
            fileCopier: (sourceFile, targetFile) {
              copyAttempted = true;
              throw const FileSystemException('copy failed');
            },
          ),
        );
        await tester.pump();

        final downloadButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.download_rounded),
        );
        expect(downloadButton.onPressed, isNotNull);
        await _runAndWaitForFileSystem(
          tester,
          downloadButton.onPressed!,
          () => copyAttempted,
        );
        await tester.pump();

        expect(copyAttempted, isTrue);
        expect(find.text('Could not save image'), findsOneWidget);
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
