import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/audio_import.dart';
import 'package:lotti/logic/image_import.dart';
import 'package:lotti/logic/media/audio_metadata_extractor.dart';
import 'package:lotti/logic/media_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;

import '../mocks/mocks.dart';

enum _GeneratedMediaKind {
  jpg,
  jpeg,
  png,
  m4a,
  txt,
  markdown,
  noExtension,
}

class _GeneratedMediaFile {
  const _GeneratedMediaFile({
    required this.kind,
    required this.seed,
    required this.uppercaseExtension,
  });

  final _GeneratedMediaKind kind;
  final int seed;
  final bool uppercaseExtension;

  bool get isImage => switch (kind) {
    _GeneratedMediaKind.jpg ||
    _GeneratedMediaKind.jpeg ||
    _GeneratedMediaKind.png => true,
    _ => false,
  };

  bool get isAudio => kind == _GeneratedMediaKind.m4a;

  String get filename {
    final extension = _extension;
    if (extension == null) return 'generated_$seed';
    final normalizedExtension = uppercaseExtension
        ? extension.toUpperCase()
        : extension;
    return 'generated_$seed.$normalizedExtension';
  }

  String? get _extension => switch (kind) {
    _GeneratedMediaKind.jpg => 'jpg',
    _GeneratedMediaKind.jpeg => 'jpeg',
    _GeneratedMediaKind.png => 'png',
    _GeneratedMediaKind.m4a => 'm4a',
    _GeneratedMediaKind.txt => 'txt',
    _GeneratedMediaKind.markdown => 'md',
    _GeneratedMediaKind.noExtension => null,
  };

  @override
  String toString() {
    return '_GeneratedMediaFile('
        'kind: $kind, '
        'seed: $seed, '
        'uppercaseExtension: $uppercaseExtension)';
  }
}

class _GeneratedMediaDropScenario {
  const _GeneratedMediaDropScenario({required this.files});

  final List<_GeneratedMediaFile> files;

  int get expectedImageCount => files.where((file) => file.isImage).length;

  int get expectedAudioCount => files.where((file) => file.isAudio).length;

  @override
  String toString() {
    return '_GeneratedMediaDropScenario(files: $files)';
  }
}

extension _AnyGeneratedMediaDropScenario on glados.Any {
  glados.Generator<_GeneratedMediaKind> get mediaKind =>
      glados.AnyUtils(this).choose(_GeneratedMediaKind.values);

  glados.Generator<_GeneratedMediaFile> get mediaFile =>
      glados.CombinableAny(this).combine3(
        mediaKind,
        glados.IntAnys(this).intInRange(0, 100000),
        glados.AnyUtils(this).choose([false, true]),
        (
          _GeneratedMediaKind kind,
          int seed,
          bool uppercaseExtension,
        ) => _GeneratedMediaFile(
          kind: kind,
          seed: seed,
          uppercaseExtension: uppercaseExtension,
        ),
      );

  glados.Generator<_GeneratedMediaDropScenario> get mediaDropScenario =>
      glados.ListAnys(this)
          .listWithLengthInRange(0, 8, mediaFile)
          .map((files) => _GeneratedMediaDropScenario(files: files));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDomainLogger mockLoggingService;
  late MockPersistenceLogic mockPersistenceLogic;
  late MockJournalDb mockJournalDb;
  late Directory tempDir;

  setUpAll(() {
    registerFallbackValue(StackTrace.current);
    registerFallbackValue(FakeJournalImage());
    registerFallbackValue(FakeJournalAudio());
    registerFallbackValue(FakeMetadata());
    registerFallbackValue(DateTime(2024, 3, 15));
  });

  setUp(() async {
    mockLoggingService = MockDomainLogger();
    mockPersistenceLogic = MockPersistenceLogic();
    mockJournalDb = MockJournalDb();

    tempDir = await Directory.systemTemp.createTemp('media_import_test_');

    if (getIt.isRegistered<DomainLogger>()) {
      getIt.unregister<DomainLogger>();
    }
    if (getIt.isRegistered<PersistenceLogic>()) {
      getIt.unregister<PersistenceLogic>();
    }
    if (getIt.isRegistered<JournalDb>()) {
      getIt.unregister<JournalDb>();
    }
    if (getIt.isRegistered<Directory>()) {
      getIt.unregister<Directory>();
    }
    if (getIt.isRegistered<AudioMetadataReader>()) {
      getIt.unregister<AudioMetadataReader>();
    }

    getIt
      ..registerSingleton<DomainLogger>(mockLoggingService)
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<Directory>(tempDir)
      ..registerSingleton<AudioMetadataReader>((_) async => Duration.zero);

    when(
      () => mockLoggingService.error(
        any<LogDomain>(),
        any<Object>(),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).thenAnswer((_) async {});

    when(
      () => mockPersistenceLogic.createMetadata(
        dateFrom: any(named: 'dateFrom'),
        dateTo: any(named: 'dateTo'),
        uuidV5Input: any(named: 'uuidV5Input'),
        flag: any(named: 'flag'),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenAnswer(
      (_) async => Metadata(
        id: 'test-id',
        createdAt: DateTime(2024, 3, 15, 10, 30),
        updatedAt: DateTime(2024, 3, 15, 10, 30),
        dateFrom: DateTime(2024, 3, 15, 10, 30),
        dateTo: DateTime(2024, 3, 15, 10, 30),
      ),
    );

    when(
      () => mockPersistenceLogic.createDbEntity(
        any(that: isA<JournalImage>()),
        linkedId: any(named: 'linkedId'),
        shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
        enqueueSync: any(named: 'enqueueSync'),
      ),
    ).thenAnswer((_) async => true);

    when(
      () => mockPersistenceLogic.createDbEntity(
        any(that: isA<JournalAudio>()),
        linkedId: any(named: 'linkedId'),
        shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
        enqueueSync: any(named: 'enqueueSync'),
      ),
    ).thenAnswer((_) async => true);
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}

    if (getIt.isRegistered<DomainLogger>()) {
      getIt.unregister<DomainLogger>();
    }
    if (getIt.isRegistered<PersistenceLogic>()) {
      getIt.unregister<PersistenceLogic>();
    }
    if (getIt.isRegistered<JournalDb>()) {
      getIt.unregister<JournalDb>();
    }
    if (getIt.isRegistered<Directory>()) {
      getIt.unregister<Directory>();
    }
    if (getIt.isRegistered<AudioMetadataReader>()) {
      getIt.unregister<AudioMetadataReader>();
    }
  });

  Future<File> createTestFile(String filename, int sizeBytes) async {
    final file = File(path.join(tempDir.path, filename));
    await file.create(recursive: true);
    await file.writeAsBytes(List<int>.filled(sizeBytes, 0));
    return file;
  }

  DropDoneDetails createDropDetails(List<XFile> xfiles) {
    final dropItems = xfiles.map(FakeDropItem.new).toList();
    return DropDoneDetails(
      files: dropItems,
      localPosition: Offset.zero,
      globalPosition: Offset.zero,
    );
  }

  group('handleDroppedMedia', () {
    test('dispatches image files to importDroppedImages', () async {
      final imageFile = await createTestFile('test.jpg', 1024);
      final dropDetails = createDropDetails([XFile(imageFile.path)]);

      await handleDroppedMedia(
        data: dropDetails,
        linkedId: 'linked-123',
      );

      verify(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalImage>()),
          linkedId: any(named: 'linkedId'),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
        ),
      ).called(1);
    });

    test('dispatches audio files to importDroppedAudio', () async {
      final audioFile = await createTestFile('test.m4a', 1024);
      final dropDetails = createDropDetails([XFile(audioFile.path)]);

      await handleDroppedMedia(
        data: dropDetails,
        linkedId: 'linked-123',
      );

      verify(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalAudio>()),
          linkedId: any(named: 'linkedId'),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
        ),
      ).called(1);
    });

    test('handles mixed image and audio files', () async {
      final imageFile = await createTestFile('photo.png', 1024);
      final audioFile = await createTestFile('audio.m4a', 1024);
      final dropDetails = createDropDetails([
        XFile(imageFile.path),
        XFile(audioFile.path),
      ]);

      await handleDroppedMedia(
        data: dropDetails,
        linkedId: 'linked-123',
      );

      verify(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalImage>()),
          linkedId: any(named: 'linkedId'),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
        ),
      ).called(1);
      verify(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalAudio>()),
          linkedId: any(named: 'linkedId'),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
        ),
      ).called(1);
    });

    test('ignores unsupported file types', () async {
      final textFile = await createTestFile('readme.txt', 100);
      final dropDetails = createDropDetails([XFile(textFile.path)]);

      await handleDroppedMedia(
        data: dropDetails,
        linkedId: 'linked-123',
      );

      verifyNever(
        () => mockPersistenceLogic.createDbEntity(
          any(),
          linkedId: any(named: 'linkedId'),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
        ),
      );
    });

    test('passes categoryId to both image and audio imports', () async {
      final imageFile = await createTestFile('photo.jpg', 1024);
      final audioFile = await createTestFile('audio.m4a', 1024);
      final dropDetails = createDropDetails([
        XFile(imageFile.path),
        XFile(audioFile.path),
      ]);

      await handleDroppedMedia(
        data: dropDetails,
        linkedId: 'linked-123',
        categoryId: 'cat-456',
      );

      verify(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalImage>()),
          linkedId: any(named: 'linkedId'),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
        ),
      ).called(1);
      verify(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalAudio>()),
          linkedId: any(named: 'linkedId'),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
        ),
      ).called(1);
    });

    test('recognizes all supported image extensions', () {
      expect(
        ImageImportConstants.supportedExtensions,
        containsAll(['jpg', 'jpeg', 'png']),
      );
    });

    test('recognizes all supported audio extensions', () {
      expect(
        AudioImportConstants.supportedExtensions,
        contains('m4a'),
      );
    });

    glados.Glados(
      glados.any.mediaDropScenario,
      glados.ExploreConfig(),
    ).test('routes generated dropped media by supported extensions', (
      scenario,
    ) async {
      clearInteractions(mockPersistenceLogic);

      final xFiles = <XFile>[];
      for (final (index, generatedFile) in scenario.files.indexed) {
        final file = await createTestFile(
          '$index-${generatedFile.filename}',
          128,
        );
        xFiles.add(XFile(file.path));
      }

      await handleDroppedMedia(
        data: createDropDetails(xFiles),
        linkedId: 'linked-generated',
        categoryId: 'category-generated',
      );

      if (scenario.expectedImageCount == 0) {
        verifyNever(
          () => mockPersistenceLogic.createDbEntity(
            any(that: isA<JournalImage>()),
            linkedId: any(named: 'linkedId'),
            shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
            enqueueSync: any(named: 'enqueueSync'),
          ),
        );
      } else {
        verify(
          () => mockPersistenceLogic.createDbEntity(
            any(that: isA<JournalImage>()),
            linkedId: any(named: 'linkedId'),
            shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
            enqueueSync: any(named: 'enqueueSync'),
          ),
        ).called(scenario.expectedImageCount);
      }

      if (scenario.expectedAudioCount == 0) {
        verifyNever(
          () => mockPersistenceLogic.createDbEntity(
            any(that: isA<JournalAudio>()),
            linkedId: any(named: 'linkedId'),
            shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
            enqueueSync: any(named: 'enqueueSync'),
          ),
        );
      } else {
        verify(
          () => mockPersistenceLogic.createDbEntity(
            any(that: isA<JournalAudio>()),
            linkedId: any(named: 'linkedId'),
            shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
            enqueueSync: any(named: 'enqueueSync'),
          ),
        ).called(scenario.expectedAudioCount);
      }
    }, tags: 'glados');
  });
}
