import 'dart:io';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/ui/shared/persona_avatar.dart';
import 'package:lotti/features/relationships/ui/widgets/person_photo_actions.dart';
import 'package:lotti/features/relationships/ui/widgets/person_photo_surfaces.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:lotti/utils/platform.dart' as platform;
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fake_entry_controller.dart';
import '../../../../helpers/fallbacks.dart';
import '../../../../helpers/journal_image_fixtures.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

/// The production wiring of [PersonPhotoActions]: the flows over the real
/// repositories, the real picker and the real crop surface. The flows
/// themselves are tested over fakes in `person_photo_actions_test`; what is
/// pinned here is that the factory hands them the *right* real things.
void main() {
  final at = DateTime(2026, 8, 17, 12);
  late Directory documents;
  late MockRelationshipRepository relationships;
  late MockJournalRepository journal;
  late MockPersistenceLogic persistence;

  final person = RelationshipEntry(
    meta: Metadata(
      id: 'rel-1',
      createdAt: at,
      updatedAt: at,
      dateFrom: at,
      dateTo: at,
      categoryId: 'cat-1',
    ),
    data: RelationshipData(
      title: 'Pip',
      status: RelationshipStatus.active(
        id: 'status-1',
        createdAt: at,
        utcOffset: 0,
      ),
    ),
  );

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    documents = Directory.systemTemp.createTempSync('person_photo_surfaces_');
    persistence = MockPersistenceLogic();
    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<Directory>(documents)
          ..registerSingleton<EditorStateService>(MockEditorStateService())
          ..registerSingleton<PersistenceLogic>(persistence);
      },
    );
    relationships = MockRelationshipRepository();
    journal = MockJournalRepository();
  });

  tearDown(() async {
    await tearDownTestGetIt();
    try {
      documents.deleteSync(recursive: true);
    } catch (_) {}
  });

  /// Builds the actions the way a host does — inside a widget, with its
  /// `WidgetRef` and `BuildContext` — over this test's repositories.
  Future<PersonPhotoActions> build(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) async {
    late PersonPhotoActions actions;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              actions = productionPersonPhotoActions(
                ref,
                context: context,
                relationship: person,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
        overrides: [
          relationshipRepositoryProvider.overrideWithValue(relationships),
          journalRepositoryProvider.overrideWithValue(journal),
          ...overrides,
        ],
      ),
    );
    await tester.pump();
    return actions;
  }

  testWidgets("the flows write through the host scope's repositories", (
    tester,
  ) async {
    final actions = await build(tester);

    expect(actions.relationships, same(relationships));
    expect(actions.journal, same(journal));
  });

  testWidgets(
    'chooseCrop opens the crop surface over the host, editing the framing '
    'it was handed, and resolves to nothing when cancelled',
    (tester) async {
      final image = buildJournalImage(imageFile: 'pip.png');
      createImageFile(image);
      final actions = await build(
        tester,
        overrides: [createEntryControllerOverride(image)],
      );

      final result = actions.chooseCrop(
        image.id,
        const AvatarCrop(x: 0.2, y: 0.3, scale: 2),
      );
      await tester.pumpAndSettle();

      expect(find.text('Choose the face'), findsOneWidget);
      final preview = tester.widget<PersonaAvatar>(
        find.byKey(const ValueKey('avatar-crop-preview')),
      );
      expect(
        preview.crop,
        const AvatarCrop(x: 0.2, y: 0.3, scale: 2),
        reason: 'the surface starts from the framing the caller passed',
      );

      await tester.tap(find.byKey(const ValueKey('avatar-crop-cancel')));
      await tester.pumpAndSettle();

      expect(await result, isNull);
    },
  );

  group('pickImage', () {
    late FakeFileSelectorPlatform selector;
    String? categoryOnMetadata;

    setUp(() {
      // The desktop picker path: the gallery picker is plugin-bound and
      // excluded from coverage, the file selector has a shared fake.
      final original = FileSelectorPlatform.instance;
      selector = FakeFileSelectorPlatform();
      FileSelectorPlatform.instance = selector;
      addTearDown(() => FileSelectorPlatform.instance = original);
      final wasLinux = platform.isLinux;
      platform.isLinux = true;
      addTearDown(() => platform.isLinux = wasLinux);

      categoryOnMetadata = null;
      when(
        () => persistence.createMetadata(
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
          uuidV5Input: any(named: 'uuidV5Input'),
          private: any(named: 'private'),
          labelIds: any(named: 'labelIds'),
          categoryId: any(named: 'categoryId'),
          starred: any(named: 'starred'),
          flag: any(named: 'flag'),
        ),
      ).thenAnswer((invocation) async {
        categoryOnMetadata = invocation.namedArguments[#categoryId] as String?;
        return Metadata(
          id: 'image-imported',
          createdAt: at,
          updatedAt: at,
          dateFrom: at,
          dateTo: at,
          categoryId: categoryOnMetadata,
        );
      });
      when(
        () => persistence.createDbEntity(
          any(),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          linkedId: any(named: 'linkedId'),
          linkCollapsed: any(named: 'linkCollapsed'),
        ),
      ).thenAnswer((_) async => true);
    });

    testWidgets(
      'imports the one picture picked as an entry linked to the person, in '
      "the person's category, and hands back its id",
      (tester) async {
        final source = buildJournalImage(imageFile: 'pip.png');
        createImageFile(source);
        selector.filesToReturn = [XFile(getFullImagePath(source))];
        final actions = await build(tester);

        // The import reads and copies a real file, which only completes on
        // the real event loop.
        final picked = await tester.runAsync(actions.pickImage);

        expect(picked, 'image-imported');
        verify(
          () => persistence.createDbEntity(
            any(that: isA<JournalImage>()),
            shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
            enqueueSync: any(named: 'enqueueSync'),
            linkedId: 'rel-1',
            linkCollapsed: any(named: 'linkCollapsed'),
          ),
        ).called(1);
        expect(
          categoryOnMetadata,
          'cat-1',
          reason: "the picture inherits the person's category",
        );
        expect(
          selector.lastAcceptedTypeGroups!.single.extensions,
          contains('png'),
          reason: 'the picker is asked for images only',
        );
      },
    );

    testWidgets('a dismissed picker imports nothing', (tester) async {
      final actions = await build(tester);

      expect(await tester.runAsync(actions.pickImage), isNull);
      verifyNever(
        () => persistence.createDbEntity(
          any(),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          linkedId: any(named: 'linkedId'),
          linkCollapsed: any(named: 'linkCollapsed'),
        ),
      );
    });
  });
}
