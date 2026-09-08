import 'dart:io';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/photo_chrome_tokens.dart';
import 'package:lotti/features/keyboard/ui/list_detail_focus_traversal.dart';
import 'package:lotti/features/relationships/model/imported_contact.dart';
import 'package:lotti/features/relationships/model/relationship_health_metrics.dart';
import 'package:lotti/features/relationships/service/contacts_service.dart';
import 'package:lotti/features/relationships/state/contact_import_controller.dart';
import 'package:lotti/features/relationships/state/contact_link_controller.dart';
import 'package:lotti/features/relationships/ui/shared/persona_avatar.dart';
import 'package:lotti/features/relationships/ui/widgets/person_header.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_briefing_card.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/widgets/app_bar/glass_action_button.dart';
import 'package:lotti/widgets/app_bar/glass_back_button.dart';
import 'package:lotti/widgets/media/thumb_hash_backed_image.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../helpers/fake_entry_controller.dart';
import '../../../../helpers/journal_image_fixtures.dart';
import '../../../../helpers/thumb_hash_fixtures.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

class _FakeContactsService implements ContactsService {
  _FakeContactsService({this.supported = true});

  final bool supported;

  @override
  bool get isSupported => supported;

  @override
  Future<ContactsAccess> requestReadAccess() async => ContactsAccess.granted;

  @override
  Future<ImportedContact?> pickSingle() async => null;

  @override
  Future<List<ImportedContact>> readAll() async => const [];

  @override
  Future<ImportedContact?> readById(String id) async => null;

  @override
  Future<void> openSystemSettings() async {}
}

class _FakeContactLinkController implements ContactLinkController {
  final List<String> calls = [];

  @override
  Future<ContactLinkOutcome> linkContact(RelationshipEntry relationship) async {
    calls.add('link');
    return ContactLinkOutcome.linked;
  }

  @override
  Future<ContactLinkOutcome> refreshFromContact(
    RelationshipEntry relationship,
  ) async {
    calls.add('refresh');
    return ContactLinkOutcome.linked;
  }
}

void main() {
  // A Thursday; the crew's dates are chosen around it.
  final now = DateTime(2026, 8, 13, 14);
  const deviceKey = 'android:host-a';

  RelationshipEntry person({
    bool important = false,
    int? cadenceDays,
    String? nickname,
    RelationshipStatus? status,
    Map<String, String> refs = const {},
    String? avatarImageId,
    AvatarCrop? avatarCrop,
    String? bannerImageId,
    double bannerCropX = 0.5,
  }) => RelationshipEntry(
    meta: Metadata(
      id: 'rel-1',
      createdAt: DateTime(2026, 7),
      updatedAt: DateTime(2026, 7),
      dateFrom: DateTime(2026, 7),
      dateTo: DateTime(2026, 7),
    ),
    data: RelationshipData(
      title: 'Commander Pip Frostbeak',
      nickname: nickname,
      important: important,
      checkInCadenceDays: cadenceDays,
      contactRefs: refs,
      avatarImageId: avatarImageId,
      avatarCrop: avatarCrop,
      bannerImageId: bannerImageId,
      bannerCropX: bannerCropX,
      status:
          status ??
          RelationshipStatus.active(
            id: 'status-1',
            createdAt: DateTime(2026, 7),
            utcOffset: 0,
          ),
    ),
  );

  CheckInEntry checkIn(DateTime at) => CheckInEntry(
    meta: Metadata(
      id: 'check-1',
      createdAt: at,
      updatedAt: at,
      dateFrom: at,
      dateTo: at,
    ),
    data: const CheckInData(
      relationshipId: 'rel-1',
      interactionType: CheckInInteractionType.call,
    ),
  );

  group('PersonHeroAppBar', () {
    var backs = 0;
    var chats = 0;
    var deletes = 0;
    late _FakeContactLinkController linkController;

    setUp(() {
      backs = 0;
      chats = 0;
      deletes = 0;
      linkController = _FakeContactLinkController();
    });

    Future<void> pump(
      WidgetTester tester, {
      RelationshipEntry? relationship,
      bool contactsSupported = false,
      Size size = const Size(400, 800),
      bool tall = false,
      List<Override> overrides = const [],
      VoidCallback? onAvatarTap,
      ThemeData? theme,
    }) async {
      setTestSurfaceSize(tester, size);
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          theme: theme,
          // A Scaffold, because the menu's link intents report in toasts.
          Scaffold(
            body: CustomScrollView(
              slivers: [
                PersonHeroAppBar(
                  relationship: relationship ?? person(),
                  onBack: () => backs++,
                  onTalkToAgent: () => chats++,
                  onDelete: () async => deletes++,
                  onAvatarTap: onAvatarTap,
                ),
                SliverToBoxAdapter(
                  child: SizedBox(height: tall ? 3000 : 100),
                ),
              ],
            ),
          ),
          mediaQueryData: MediaQueryData(size: size),
          overrides: [
            contactsServiceProvider.overrideWithValue(
              _FakeContactsService(supported: contactsSupported),
            ),
            contactLinkControllerProvider.overrideWithValue(linkController),
            contactRefKeyProvider.overrideWith((ref) async => deviceKey),
            ...overrides,
          ],
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('carries back, talk to agent, edit and the menu; the wash is '
        'the interactive tint over the page surface', (tester) async {
      await pump(tester);

      final bar = tester.widget<SliverPersistentHeader>(
        find.byKey(const ValueKey('person-hero')),
      );
      final tokens = tester
          .element(find.byKey(const ValueKey('person-hero')))
          .designTokens;
      expect(bar.pinned, isTrue);
      expect(
        tester
            .widget<ColoredBox>(find.byKey(const ValueKey('person-hero-wash')))
            .color,
        PersonHeroAppBar.washColor(tokens),
      );
      expect(find.byKey(const ValueKey('person-talk-to-agent')), findsOne);
      expect(find.byKey(const ValueKey('person-edit')), findsOneWidget);
      expect(find.byKey(const ValueKey('person-menu')), findsOneWidget);
      // The name belongs to the header block; the open hero shows none.
      expect(find.text('Commander Pip Frostbeak'), findsNothing);
    });

    testWidgets('edit opens the person form prefilled with this person', (
      tester,
    ) async {
      // The form behind the button reads GetIt: the shared setup, plus the
      // category cache its category row consults.
      await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..registerSingleton<EntitiesCacheService>(
              MockEntitiesCacheService(),
            )
            ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
            ..registerSingleton<EditorStateService>(MockEditorStateService());
        },
      );
      addTearDown(tearDownTestGetIt);
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('person-edit')));
      await tester.pumpAndSettle();

      expect(find.text('Edit person'), findsOneWidget);
      expect(
        find.widgetWithText(TextField, person().data.title),
        findsOneWidget,
        reason: 'the form edits this person, not a blank one',
      );
    });

    testWidgets('back and talk-to-agent call back', (tester) async {
      await pump(tester);

      await tester.tap(find.byIcon(LottiIcons.chevronLeft));
      await tester.tap(find.byKey(const ValueKey('person-talk-to-agent')));
      await tester.pump();

      expect(backs, 1);
      expect(chats, 1);
    });

    testWidgets('on desktop Talk to agent is a labelled button', (
      tester,
    ) async {
      await pump(tester, size: const Size(1280, 800));

      final button = tester.widget<DesignSystemButton>(
        find.byKey(const ValueKey('person-talk-to-agent')),
      );
      expect(button.label, 'Talk to agent');
      expect(button.variant, DesignSystemButtonVariant.secondary);
    });

    testWidgets('names the person in the bar only once the band has folded, '
        'and fades the avatar with the band', (tester) async {
      await pump(tester, tall: true);
      expect(find.byKey(const ValueKey('person-hero-title')), findsNothing);
      Opacity avatar() => tester.widget<Opacity>(
        find.byKey(const ValueKey('person-hero-avatar')),
      );
      expect(avatar().opacity, 1);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('person-hero-title')), findsOneWidget);
      expect(find.text('Commander Pip Frostbeak'), findsOneWidget);
      expect(avatar().opacity, 0);
    });

    testWidgets('the avatar hangs half its diameter below the hero, on the '
        'content inset', (tester) async {
      await pump(tester);

      final hero = find.byKey(const ValueKey('person-hero-wash'));
      final avatar = find.byType(PersonaAvatar);
      final tokens = tester.element(hero).designTokens;
      expect(
        tester.getBottomLeft(avatar).dy,
        tester.getBottomLeft(hero).dy + PersonHeroAppBar.avatarSize(tokens) / 2,
      );
      expect(tester.getTopLeft(avatar).dx, 0);
    });

    testWidgets("hands the person's photo and framing to the hero avatar, at "
        'the hero size', (tester) async {
      const crop = AvatarCrop(x: 0.4, y: 0.2, scale: 1.5);
      // A non-image entry behind the id: the resolver hands its host null
      // without reading the filesystem, which this test does not set up.
      final notAPicture = JournalEntry(
        meta: Metadata(
          id: 'image-1',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
        ),
        entryText: const EntryText(plainText: 'not a picture'),
      );

      await pump(
        tester,
        relationship: person(avatarImageId: 'image-1', avatarCrop: crop),
        overrides: [createEntryControllerOverride(notAPicture)],
      );

      final avatar = tester.widget<PersonaAvatar>(find.byType(PersonaAvatar));
      expect(avatar.imageId, 'image-1');
      expect(avatar.crop, crop);
      expect(avatar.id, 'rel-1', reason: 'the accent still comes from the id');
      final tokens = tester
          .element(find.byKey(const ValueKey('person-hero-wash')))
          .designTokens;
      expect(avatar.size, PersonHeroAppBar.avatarSize(tokens));
      expect(
        find.byKey(const ValueKey('persona-avatar-ring')),
        findsOneWidget,
        reason: 'an id the device cannot resolve yet still earns the ring',
      );
    });

    testWidgets('the avatar is a button while the band is open, and stops '
        'being one once the hero has folded', (tester) async {
      var taps = 0;
      await pump(tester, tall: true, onAvatarTap: () => taps++);
      final avatar = find.byKey(const ValueKey('person-hero-avatar-tap'));

      await tester.tap(avatar);
      expect(taps, 1);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();
      // The faded avatar still exists but must not catch a tap meant for the
      // content under it.
      await tester.tap(avatar, warnIfMissed: false);
      expect(taps, 1);
    });

    testWidgets('every pixel of the avatar is tappable — including the half '
        'below the wash, which a sliver could not hit-test if it hung past '
        'the hero', (tester) async {
      var taps = 0;
      await pump(tester, tall: true, onAvatarTap: () => taps++);
      final avatar = find.byKey(const ValueKey('person-hero-avatar-tap'));
      final wash = find.byKey(const ValueKey('person-hero-wash'));

      // Just inside the avatar's bottom edge, below the wash.
      final nearBottom = tester.getBottomLeft(avatar) + const Offset(20, -1);
      expect(nearBottom.dy, greaterThan(tester.getBottomLeft(wash).dy));
      await tester.tapAt(nearBottom);
      expect(taps, 1);
    });

    testWidgets('the avatar names the sheet it opens', (tester) async {
      await pump(tester, onAvatarTap: () {});
      final semantics = tester.getSemantics(
        find.byKey(const ValueKey('person-hero-avatar-tap')),
      );
      expect(semantics.label, 'Photo of Commander Pip Frostbeak');
      expect(semantics.flagsCollection.isButton, isTrue);
    });

    testWidgets('without a handler the avatar is inert, not a dead button', (
      tester,
    ) async {
      await pump(tester);
      final semantics = tester.getSemantics(
        find.byKey(const ValueKey('person-hero-avatar-tap')),
      );
      expect(semantics.flagsCollection.isButton, isFalse);
    });

    group('with a banner (design 2026-09-08, direction 2b)', () {
      late Directory documents;

      setUp(() async {
        documents = Directory.systemTemp.createTempSync('person_hero_banner_');
        await setUpTestGetIt(
          additionalSetup: () {
            getIt
              ..registerSingleton<Directory>(documents)
              ..registerSingleton<EditorStateService>(MockEditorStateService())
              ..registerSingleton<PersistenceLogic>(MockPersistenceLogic());
          },
        );
      });

      tearDown(() async {
        await tearDownTestGetIt();
        try {
          documents.deleteSync(recursive: true);
        } catch (_) {}
      });

      final banner = find.byKey(const ValueKey('person-hero-banner'));
      final scrim = find.byKey(const ValueKey('person-hero-scrim'));
      final wash = find.byKey(const ValueKey('person-hero-wash'));
      DsTokens tokensOf(WidgetTester tester) =>
          tester.element(wash).designTokens;
      Color chatGlyph(WidgetTester tester) => tester
          .widget<Icon>(
            find.descendant(
              of: find.byKey(const ValueKey('person-talk-to-agent')),
              matching: find.byType(Icon),
            ),
          )
          .color!;

      testWidgets('without a banner the hero is the wash it always was: no '
          'strip, no scrim, themed chrome', (tester) async {
        await pump(tester);

        expect(banner, findsNothing);
        expect(scrim, findsNothing);
        expect(tester.getTopLeft(wash).dy, 0);
        expect(chatGlyph(tester), tokensOf(tester).colors.text.highEmphasis);
        for (final button in tester.widgetList<GlassActionButton>(
          find.byType(GlassActionButton),
        )) {
          expect(button.fill, isNull);
        }
      });

      testWidgets('with a banner: the picture above, a one-toolbar wash bar '
          'below, the scrim over the top, and photo-neutral chrome', (
        tester,
      ) async {
        final image = buildJournalImage(imageFile: 'banner.jpg');
        createImageFile(image);

        await pump(
          tester,
          relationship: person(bannerImageId: image.id, bannerCropX: 0.25),
          overrides: [createEntryControllerOverride(image)],
        );
        final tokens = tokensOf(tester);
        // No status bar in the test shell.
        final strip = PersonHeroAppBar.bannerStripExtent(
          tokens,
          topPadding: 0,
        );

        expect(tester.getSize(banner).height, strip);
        expect(tester.getTopLeft(wash).dy, strip);
        expect(
          tester.getSize(wash).height,
          PersonHeroAppBar.bannerBarExtent,
          reason: 'the wash keeps exactly one toolbar of its band',
        );
        expect(
          tester.getSize(scrim).height,
          closeTo(strip * PhotoScrim.fadeExtent, 1e-9),
        );
        final picture = tester.widget<ThumbHashBackedImage>(
          find.descendant(
            of: banner,
            matching: find.byType(ThumbHashBackedImage),
          ),
        );
        expect(picture.alignment, const Alignment(-0.5, 0));
        expect(picture.image, isA<ResizeImage>());
        expect(chatGlyph(tester), PhotoNeutralGlass.glyph);
        for (final button in tester.widgetList<GlassActionButton>(
          find.byType(GlassActionButton),
        )) {
          expect(button.fill, PhotoNeutralGlass.fill);
        }
        final back = tester.widget<GlassBackButton>(
          find.byType(GlassBackButton),
        );
        expect(back.iconColor, PhotoNeutralGlass.glyph);
        expect(back.backgroundColor, PhotoNeutralGlass.fill);
        // The kebab is the one control on the photo that is not glass; its
        // glyph has to go neutral too or it vanishes in the light theme.
        final kebab = tester.widget<Icon>(
          find.descendant(
            of: find.byKey(const ValueKey('person-menu')),
            matching: find.byType(Icon),
          ),
        );
        expect(kebab.color, PhotoNeutralGlass.glyph);
      });

      testWidgets(
        'the kebab goes neutral on the banner, but the menu it opens keeps '
        'the theme ink — white rows would vanish on a light popup',
        (tester) async {
          final image = buildJournalImage(imageFile: 'banner.jpg');
          createImageFile(image);
          // With an address book the menu has a plain row (Link contact)
          // beside the red Delete row, so both inks are on show.
          await pump(
            tester,
            relationship: person(bannerImageId: image.id),
            contactsSupported: true,
            overrides: [createEntryControllerOverride(image)],
            theme: ThemeData(brightness: Brightness.light),
          );
          final ink = tokensOf(tester).colors.text.highEmphasis;
          expect(
            ink,
            isNot(PhotoNeutralGlass.glyph),
            reason: 'the light theme is where the two colours differ',
          );

          await tester.tap(find.byKey(const ValueKey('person-menu')));
          await tester.pumpAndSettle();

          final rows = tester.widgetList<Text>(
            find.descendant(
              of: find.byType(PopupMenuItem<PersonMenuAction>),
              matching: find.byType(Text),
            ),
          );
          final colours = rows.map((row) => row.style?.color).toList();
          expect(colours, isNotEmpty);
          expect(
            colours,
            everyElement(isNot(PhotoNeutralGlass.glyph)),
            reason: "no row borrows the trigger's photo-neutral glyph",
          );
          expect(
            colours,
            contains(ink),
            reason:
                'the plain rows read in the theme ink; delete keeps its own',
          );
        },
      );

      testWidgets('folding: the bar goes first, then the picture shrinks to '
          'the toolbar, and the scrim still covers the toolbar', (
        tester,
      ) async {
        final image = buildJournalImage(imageFile: 'banner.jpg');
        createImageFile(image);
        await pump(
          tester,
          tall: true,
          relationship: person(bannerImageId: image.id),
          overrides: [createEntryControllerOverride(image)],
        );
        final tokens = tokensOf(tester);
        final strip = PersonHeroAppBar.bannerStripExtent(
          tokens,
          topPadding: 0,
        );
        final overhang = PersonHeroAppBar.avatarSize(tokens) / 2;

        // Past the overhang and the bar: the bar is gone, the picture whole.
        await tester.drag(
          find.byType(CustomScrollView),
          Offset(0, -(overhang + PersonHeroAppBar.bannerBarExtent)),
        );
        await tester.pumpAndSettle();
        expect(tester.getSize(wash).height, closeTo(0, 1e-9));
        expect(tester.getSize(banner).height, closeTo(strip, 1e-9));

        // Fully folded: the picture is the toolbar, still under the scrim.
        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -600),
        );
        await tester.pumpAndSettle();
        expect(tester.getSize(banner).height, kToolbarHeight);
        expect(
          tester.getSize(scrim).height,
          closeTo(
            math.min(kToolbarHeight, strip * PhotoScrim.fadeExtent),
            1e-9,
          ),
        );
        expect(
          find.byKey(const ValueKey('person-hero-title')),
          findsOneWidget,
        );
      });

      testWidgets('a banner still on its way shows its stand-in under the '
          'scrim, with the chrome already photo-neutral', (tester) async {
        final image = buildJournalImage(
          imageFile: 'downloading.webp',
          thumbHash: sampleThumbHash,
        );

        await pump(
          tester,
          relationship: person(bannerImageId: image.id),
          overrides: [createEntryControllerOverride(image)],
        );

        final picture = tester.widget<ThumbHashBackedImage>(
          find.descendant(
            of: banner,
            matching: find.byType(ThumbHashBackedImage),
          ),
        );
        expect(picture.image, isNull);
        expect(picture.thumbHash, isNotNull);
        expect(scrim, findsOneWidget);
        expect(chatGlyph(tester), PhotoNeutralGlass.glyph);
      });

      testWidgets('a banner id with nothing to show yet is the wash exactly '
          'as without one', (tester) async {
        final image = buildJournalImage(imageFile: 'downloading.webp');

        await pump(
          tester,
          relationship: person(bannerImageId: image.id),
          overrides: [createEntryControllerOverride(image)],
        );

        expect(banner, findsNothing);
        expect(scrim, findsNothing);
        expect(tester.getTopLeft(wash).dy, 0);
        expect(chatGlyph(tester), tokensOf(tester).colors.text.highEmphasis);
      });
    });

    testWidgets('the menu offers delete, and delete calls back', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('person-menu')));
      await tester.pumpAndSettle();
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Link contact'), findsNothing);
      // Destructive ink on the body token — not an ad hoc TextStyle.
      final tokens = tester.element(find.text('Delete')).designTokens;
      final style = tester.widget<Text>(find.text('Delete')).style!;
      expect(style.color, tokens.colors.alert.error.ink);
      expect(
        style.fontSize,
        tokens.typography.styles.body.bodyMedium.fontSize,
      );

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(deletes, 1);
    });

    testWidgets('with an address book, an unlinked person gets Link contact', (
      tester,
    ) async {
      await pump(tester, contactsSupported: true);

      await tester.tap(find.byKey(const ValueKey('person-menu')));
      await tester.pumpAndSettle();
      expect(find.text('Link contact'), findsOneWidget);
      expect(find.text('Update from contact'), findsNothing);

      await tester.tap(find.text('Link contact'));
      await tester.pumpAndSettle();

      expect(linkController.calls, ['link']);
    });

    testWidgets('a linked person gets refresh and re-link as separate '
        'intents', (tester) async {
      await pump(
        tester,
        contactsSupported: true,
        relationship: person(refs: {deviceKey: 'os-1'}),
      );

      await tester.tap(find.byKey(const ValueKey('person-menu')));
      await tester.pumpAndSettle();
      expect(find.text('Link contact'), findsNothing);
      expect(find.text('Update from contact'), findsOneWidget);
      expect(find.text('Link a different contact'), findsOneWidget);

      await tester.tap(find.text('Update from contact'));
      await tester.pumpAndSettle();
      expect(linkController.calls, ['refresh']);

      await tester.tap(find.byKey(const ValueKey('person-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Link a different contact'));
      await tester.pumpAndSettle();
      expect(linkController.calls, ['refresh', 'link']);
    });

    testWidgets('shows the show-list-pane control only while the desktop '
        'list pane is folded away', (tester) async {
      var visible = true;
      Widget host({required bool listVisible}) => makeTestableWidgetNoScroll(
        ListDetailFocusTraversal(
          debugLabel: 'test',
          listPaneVisible: listVisible,
          canHideListPane: true,
          onListPaneVisibilityChanged: (v) => visible = v,
          listPane: const SizedBox(width: 200),
          divider: const SizedBox(width: 1),
          detailPane: CustomScrollView(
            slivers: [
              PersonHeroAppBar(
                relationship: person(),
                onBack: () {},
                onTalkToAgent: () {},
                onDelete: () async {},
              ),
            ],
          ),
        ),
        mediaQueryData: const MediaQueryData(size: Size(1280, 800)),
        overrides: [
          contactsServiceProvider.overrideWithValue(_FakeContactsService()),
        ],
      );
      setTestSurfaceSize(tester, const Size(1280, 800));

      await tester.pumpWidget(host(listVisible: true));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('people-show-list-pane')), findsNothing);

      await tester.pumpWidget(host(listVisible: false));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('people-show-list-pane')), findsOne);
      expect(find.byType(GlassActionButton), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('people-show-list-pane')));
      await tester.pump();
      expect(visible, isTrue);
    });
  });

  group('PersonHeaderBlock', () {
    Future<void> pump(
      WidgetTester tester, {
      required RelationshipEntry relationship,
      CheckInEntry? lastCheckIn,
      String? categoryName,
      RelationshipHealthBand? healthBand,
    }) async {
      await withClock(Clock.fixed(now), () async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            PersonHeaderBlock(
              item: (relationship: relationship, lastCheckIn: lastCheckIn),
              categoryName: categoryName,
              healthBand: healthBand,
            ),
          ),
        );
        await tester.pumpAndSettle();
      });
    }

    DsPill pill(WidgetTester tester, String key) =>
        tester.widget<DsPill>(find.byKey(ValueKey(key)));

    testWidgets('eyebrow joins category and Important; the one-liner joins '
        'the nickname and the last contact', (tester) async {
      await pump(
        tester,
        relationship: person(important: true, nickname: 'Pip'),
        lastCheckIn: checkIn(DateTime(2026, 8, 13, 12, 44)),
        categoryName: 'Penguin Operations',
      );

      expect(
        tester.widget<Text>(find.byKey(const ValueKey('person-eyebrow'))).data,
        'Penguin Operations · Important',
      );
      expect(find.text('Commander Pip Frostbeak'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('person-one-liner')))
            .data,
        '"Pip" · last spoke Today 12:44',
      );
    });

    testWidgets('no category and not important leaves the eyebrow out; no '
        'check-in reads as just added', (tester) async {
      await pump(tester, relationship: person());

      expect(find.byKey(const ValueKey('person-eyebrow')), findsNothing);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('person-one-liner')))
            .data,
        'Just added',
      );
    });

    testWidgets('on track: the cadence pill names the effective rhythm and '
        'the next-due pill the day', (tester) async {
      await pump(
        tester,
        relationship: person(important: true, cadenceDays: 7),
        lastCheckIn: checkIn(DateTime(2026, 8, 12, 19, 5)),
      );

      expect(pill(tester, 'person-pill-cadence').label, 'On track · Weekly');
      expect(pill(tester, 'person-pill-next-due').label, 'Next due Wed 19 Aug');
      expect(find.byKey(const ValueKey('person-pill-due')), findsNothing);
      expect(find.byKey(const ValueKey('person-pill-status')), findsNothing);
    });

    testWidgets('an enrolled person with no cadence set is on the default '
        'rhythm, and the pill says so', (tester) async {
      await pump(
        tester,
        relationship: person(important: true),
        lastCheckIn: checkIn(DateTime(2026, 8, 12)),
      );

      expect(pill(tester, 'person-pill-cadence').label, 'On track · Monthly');
    });

    testWidgets('overdue: one warning-tinted pill saying since when and how '
        'far over, and no next-due pill', (tester) async {
      await pump(
        tester,
        relationship: person(important: true, cadenceDays: 7),
        lastCheckIn: checkIn(DateTime(2026, 8)),
      );

      final due = pill(tester, 'person-pill-due');
      final tokens = tester
          .element(find.byType(PersonHeaderBlock))
          .designTokens;
      expect(due.label, 'Due since Sat · 5 days over');
      expect(due.variant, DsPillVariant.tinted);
      expect(due.color, tokens.colors.alert.warning.defaultColor);
      expect(find.byKey(const ValueKey('person-pill-next-due')), findsNothing);
      expect(find.byKey(const ValueKey('person-pill-cadence')), findsNothing);
    });

    testWidgets('not enrolled, dormant and archived each get the status pill', (
      tester,
    ) async {
      await pump(tester, relationship: person(cadenceDays: 7));
      expect(pill(tester, 'person-pill-status').label, 'Not enrolled');

      await pump(
        tester,
        relationship: person(
          important: true,
          status: RelationshipStatus.dormant(
            id: 's',
            createdAt: now,
            utcOffset: 0,
          ),
        ),
      );
      expect(pill(tester, 'person-pill-status').label, 'Dormant');

      await pump(
        tester,
        relationship: person(
          important: true,
          status: RelationshipStatus.archived(
            id: 's',
            createdAt: now,
            utcOffset: 0,
          ),
        ),
      );
      expect(pill(tester, 'person-pill-status').label, 'Archived');
    });

    testWidgets('the health band pill appears only with a briefing, tinted '
        'with the band colour', (tester) async {
      await pump(tester, relationship: person(important: true));
      expect(find.byKey(const ValueKey('person-pill-health')), findsNothing);

      await pump(
        tester,
        relationship: person(important: true),
        healthBand: RelationshipHealthBand.thriving,
      );
      final health = pill(tester, 'person-pill-health');
      final tokens = tester
          .element(find.byType(PersonHeaderBlock))
          .designTokens;
      expect(health.label, 'Thriving');
      expect(
        health.color,
        relationshipHealthBandColor(tokens, RelationshipHealthBand.thriving),
      );
    });
  });
}
