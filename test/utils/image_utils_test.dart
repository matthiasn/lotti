import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/utils/image_utils.dart';

void main() {
  group('getRelativeAssetPath', () {
    test('should return the relative path on Android', () {
      const absolutePath = '/data/user/0/com.example.app/app_flutter/image.jpg';
      const expectedPath = '/image.jpg';
      expect(getRelativeAssetPath(absolutePath, isAndroid: true), expectedPath);
    });

    test('should return the relative path on other platforms', () {
      const absolutePath = '/Users/test/Documents/image.jpg';
      const expectedPath = '/image.jpg';
      expect(getRelativeAssetPath(absolutePath), expectedPath);
    });

    test('returns null when absolutePath is null', () {
      expect(getRelativeAssetPath(null), isNull);
    });

    test('returns null when absolutePath is null on Android', () {
      expect(getRelativeAssetPath(null, isAndroid: true), isNull);
    });

    test('handles path with nested Documents directory', () {
      // Note: split('Documents').last is fragile when the separator string
      // appears multiple times — it returns the segment after the LAST
      // occurrence. This documents the current behavior; see image_utils.dart.
      const path = '/Users/test/Documents/Lotti/Documents/image.jpg';
      expect(getRelativeAssetPath(path), '/image.jpg');
    });

    test('handles Android path with nested app_flutter directory', () {
      // Same fragility applies to the Android split('app_flutter').last path.
      const path =
          '/data/user/0/com.example.app/app_flutter/sub/app_flutter/img.jpg';
      expect(getRelativeAssetPath(path, isAndroid: true), '/img.jpg');
    });

    test('handles path with subdirectories after Documents', () {
      const path = '/Users/test/Documents/images/2024/photo.jpg';
      expect(getRelativeAssetPath(path), '/images/2024/photo.jpg');
    });

    glados.Glados(
      glados.any.generatedAssetPathScenario,
      // ignore: avoid_redundant_argument_values
      glados.ExploreConfig(numRuns: 100),
    ).test(
      'matches generated platform marker splitting behavior',
      (scenario) {
        expect(
          getRelativeAssetPath(
            scenario.absolutePath,
            isAndroid: scenario.isAndroid,
          ),
          scenario.expectedRelativePath,
          reason: '$scenario',
        );
      },
      tags: 'glados',
    );

    // The two concrete null tests above pin both platform branches; this
    // property proves the `absolutePath?.split(...)` null-safety guard holds
    // for *either* value of isAndroid, so neither branch can dereference null.
    glados.Glados(
      glados.AnyUtils(glados.any).choose(const [true, false]),
      glados.ExploreConfig(numRuns: 96),
    ).test(
      'returns null for a null absolutePath regardless of platform',
      (isAndroid) {
        expect(
          getRelativeAssetPath(null, isAndroid: isAndroid),
          isNull,
          reason: 'isAndroid=$isAndroid',
        );
      },
      tags: 'glados',
    );
  });

  group('getRelativeImagePath', () {
    test('should return the correct relative image path', () {
      final testDate = DateTime(2024, 3, 15, 10, 30);
      final imageData = ImageData(
        imageId: '123',
        imageFile: 'image.jpg',
        imageDirectory: '/images/',
        capturedAt: testDate,
      );
      final metadata = Metadata(
        id: '1',
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate,
      );
      final journalImage = JournalImage(meta: metadata, data: imageData);
      const expectedPath = '/images/image.jpg';
      expect(getRelativeImagePath(journalImage), expectedPath);
    });

    glados.Glados(
      glados.any.generatedImagePathScenario,
      // ignore: avoid_redundant_argument_values
      glados.ExploreConfig(numRuns: 100),
    ).test(
      'concatenates generated image directories and file names',
      (scenario) {
        expect(
          getRelativeImagePath(scenario.journalImage),
          scenario.expectedRelativePath,
          reason: '$scenario',
        );
      },
      tags: 'glados',
    );
  });

  group('getFullImagePath', () {
    test('should return the correct full image path', () {
      final testDate = DateTime(2024, 3, 15, 10, 30);
      final imageData = ImageData(
        imageId: '123',
        imageFile: 'image.jpg',
        imageDirectory: '/images/',
        capturedAt: testDate,
      );
      final metadata = Metadata(
        id: '1',
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate,
      );
      final journalImage = JournalImage(meta: metadata, data: imageData);
      const documentsDirectory = '/Users/test/Documents';
      const expectedPath = '/Users/test/Documents/images/image.jpg';
      expect(
        getFullImagePath(
          journalImage,
          documentsDirectory: documentsDirectory,
        ),
        expectedPath,
      );
    });

    glados.Glados(
      glados.any.generatedImagePathScenario,
      // ignore: avoid_redundant_argument_values
      glados.ExploreConfig(numRuns: 100),
    ).test(
      'prefixes generated relative image paths with the documents directory',
      (scenario) {
        expect(
          getFullImagePath(
            scenario.journalImage,
            documentsDirectory: scenario.documentsDirectory,
          ),
          scenario.expectedFullPath,
          reason: '$scenario',
        );
      },
      tags: 'glados',
    );
  });
}

enum _GeneratedImagePathToken {
  alpha,
  numeric,
  spaced,
  dashed,
  underscored,
  percentEncoded,
}

class _GeneratedAssetPathScenario {
  const _GeneratedAssetPathScenario({
    required this.isAndroid,
    required this.includePlatformMarker,
    required this.prefixParts,
    required this.relativeParts,
  });

  final bool isAndroid;
  final bool includePlatformMarker;
  final List<_GeneratedImagePathToken> prefixParts;
  final List<_GeneratedImagePathToken> relativeParts;

  String get marker => isAndroid ? 'app_flutter' : 'Documents';

  String get absolutePath {
    final prefix = _joinPath(prefixParts);
    final relative = _joinPath(relativeParts);
    if (!includePlatformMarker) {
      return '$prefix$relative';
    }
    return '$prefix/$marker$relative';
  }

  String get expectedRelativePath => absolutePath.split(marker).last;

  @override
  String toString() {
    return '_GeneratedAssetPathScenario('
        'isAndroid: $isAndroid, '
        'includePlatformMarker: $includePlatformMarker, '
        'absolutePath: $absolutePath)';
  }
}

class _GeneratedImagePathScenario {
  const _GeneratedImagePathScenario({
    required this.directoryParts,
    required this.fileStem,
    required this.extension,
    required this.documentsParts,
  });

  final List<_GeneratedImagePathToken> directoryParts;
  final _GeneratedImagePathToken fileStem;
  final _GeneratedImagePathToken extension;
  final List<_GeneratedImagePathToken> documentsParts;

  String get imageDirectory => '${_joinPath(directoryParts)}/';

  String get imageFile => '${fileStem.text}.${extension.text}';

  String get documentsDirectory =>
      '/Users/test/Documents${_joinPath(documentsParts)}';

  String get expectedRelativePath => '$imageDirectory$imageFile';

  String get expectedFullPath => '$documentsDirectory$expectedRelativePath';

  JournalImage get journalImage {
    final testDate = DateTime(2024, 3, 15, 10, 30);
    return JournalImage(
      meta: Metadata(
        id: 'generated-image',
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate,
      ),
      data: ImageData(
        imageId: 'generated-image',
        imageFile: imageFile,
        imageDirectory: imageDirectory,
        capturedAt: testDate,
      ),
    );
  }

  @override
  String toString() {
    return '_GeneratedImagePathScenario('
        'imageDirectory: $imageDirectory, '
        'imageFile: $imageFile, '
        'documentsDirectory: $documentsDirectory)';
  }
}

String _joinPath(List<_GeneratedImagePathToken> parts) {
  if (parts.isEmpty) {
    return '';
  }
  return '/${parts.map((part) => part.text).join('/')}';
}

extension on _GeneratedImagePathToken {
  String get text => switch (this) {
    _GeneratedImagePathToken.alpha => 'alpha',
    _GeneratedImagePathToken.numeric => '2024',
    _GeneratedImagePathToken.spaced => 'file name',
    _GeneratedImagePathToken.dashed => 'dash-name',
    _GeneratedImagePathToken.underscored => 'under_score',
    _GeneratedImagePathToken.percentEncoded => 'hello%20world',
  };
}

extension _AnyImageUtils on glados.Any {
  glados.Generator<_GeneratedImagePathToken> get _imagePathToken =>
      glados.AnyUtils(this).choose(_GeneratedImagePathToken.values);

  glados.Generator<bool> get _boolean =>
      glados.AnyUtils(this).choose(const [true, false]);

  glados.Generator<List<_GeneratedImagePathToken>> get _imagePathParts =>
      glados.ListAnys(this).listWithLengthInRange(0, 4, _imagePathToken);

  glados.Generator<_GeneratedAssetPathScenario>
  get generatedAssetPathScenario => glados.CombinableAny(this).combine4(
    _boolean,
    _boolean,
    _imagePathParts,
    _imagePathParts,
    (
      bool isAndroid,
      bool includePlatformMarker,
      List<_GeneratedImagePathToken> prefixParts,
      List<_GeneratedImagePathToken> relativeParts,
    ) => _GeneratedAssetPathScenario(
      isAndroid: isAndroid,
      includePlatformMarker: includePlatformMarker,
      prefixParts: prefixParts,
      relativeParts: relativeParts,
    ),
  );

  glados.Generator<_GeneratedImagePathScenario>
  get generatedImagePathScenario => glados.CombinableAny(this).combine4(
    _imagePathParts,
    _imagePathToken,
    _imagePathToken,
    _imagePathParts,
    (
      List<_GeneratedImagePathToken> directoryParts,
      _GeneratedImagePathToken fileStem,
      _GeneratedImagePathToken extension,
      List<_GeneratedImagePathToken> documentsParts,
    ) => _GeneratedImagePathScenario(
      directoryParts: directoryParts,
      fileStem: fileStem,
      extension: extension,
      documentsParts: documentsParts,
    ),
  );
}
