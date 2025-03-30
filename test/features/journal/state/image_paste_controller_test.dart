import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/features/journal/repository/clipboard_repository.dart';
import 'package:lotti/features/journal/state/image_paste_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod/riverpod.dart';
import 'package:super_clipboard/super_clipboard.dart';

import '../../../helpers/path_provider.dart';

class MockSystemClipboard extends Mock implements SystemClipboard {}

class MockClipboardReader extends Mock implements ClipboardReader {}

class MockDataReaderFile extends Mock implements DataReaderFile {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late MockSystemClipboard mockClipboard;
  late MockClipboardReader mockReader;
  late MockDataReaderFile mockFile;

  setUpAll(() async {
    setFakeDocumentsPath();
    getIt
      ..registerSingleton<Directory>(await getApplicationDocumentsDirectory())
      ..registerSingleton<LoggingDb>(LoggingDb(inMemoryDatabase: true));
  });

  setUp(() {
    mockClipboard = MockSystemClipboard();
    mockReader = MockClipboardReader();
    mockFile = MockDataReaderFile();

    container = ProviderContainer(
      overrides: [
        clipboardRepositoryProvider.overrideWithValue(mockClipboard),
      ],
    );

    when(() => mockClipboard.read()).thenAnswer((_) async => mockReader);
  });

  group('ImagePasteController', () {
    test('build returns false when clipboard is null', () async {
      final container = ProviderContainer(
        overrides: [
          clipboardRepositoryProvider.overrideWithValue(null),
        ],
      );

      final result = await container.read(
        imagePasteControllerProvider(
          linkedFromId: null,
          categoryId: null,
        ).future,
      );

      expect(result, false);
    });

    test('build returns true when PNG is available', () async {
      when(() => mockReader.canProvide(Formats.png)).thenReturn(true);
      when(() => mockReader.canProvide(Formats.jpeg)).thenReturn(false);

      final result = await container.read(
        imagePasteControllerProvider(
          linkedFromId: null,
          categoryId: null,
        ).future,
      );

      expect(result, true);
    });

    test('build returns true when JPEG is available', () async {
      when(() => mockReader.canProvide(Formats.png)).thenReturn(false);
      when(() => mockReader.canProvide(Formats.jpeg)).thenReturn(true);

      final result = await container.read(
        imagePasteControllerProvider(
          linkedFromId: null,
          categoryId: null,
        ).future,
      );

      expect(result, true);
    });

    test('paste handles PNG data correctly', () async {
      when(() => mockReader.canProvide(Formats.png)).thenReturn(true);
      when(() => mockReader.canProvide(Formats.jpeg)).thenReturn(false);

      when(() => mockReader.getFile(Formats.png, any()))
          .thenAnswer((invocation) {
        final callback =
            invocation.positionalArguments[1] as void Function(DataReaderFile);
        callback(mockFile);
        return null;
      });

      when(() => mockFile.readAll())
          .thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));

      final controller = container.read(
        imagePasteControllerProvider(
          linkedFromId: 'testLink',
          categoryId: 'testCategory',
        ).notifier,
      );

      await controller.paste();

      verify(() => mockReader.getFile(Formats.png, any())).called(1);
      verify(() => mockFile.readAll()).called(1);
    });

    test('paste handles JPEG data correctly', () async {
      when(() => mockReader.canProvide(Formats.png)).thenReturn(false);
      when(() => mockReader.canProvide(Formats.jpeg)).thenReturn(true);

      when(() => mockReader.getFile(Formats.jpeg, any()))
          .thenAnswer((invocation) {
        final callback =
            invocation.positionalArguments[1] as void Function(DataReaderFile);
        callback(mockFile);
        return null;
      });

      when(() => mockFile.readAll())
          .thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));

      final controller = container.read(
        imagePasteControllerProvider(
          linkedFromId: 'testLink',
          categoryId: 'testCategory',
        ).notifier,
      );

      await controller.paste();

      verify(() => mockReader.getFile(Formats.jpeg, any())).called(1);
      verify(() => mockFile.readAll()).called(1);
    });
  });
}
