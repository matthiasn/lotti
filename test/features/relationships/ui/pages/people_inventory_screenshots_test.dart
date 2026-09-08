/// Design-handover inventory capture for the People (relationships) feature.
///
/// Renders every People surface the app actually ships — the list and its
/// bands, the person page in each of its shapes, all six agent-card faces,
/// the check-in sheet, the person form, contact import, the agent chat, and
/// the persona-avatar palette the feature draws identity from — and writes
/// one PNG per state. The point is a complete visual inventory to hand to a
/// designer, so states nothing else screenshots (the six agent faces, the
/// avatar palette, the row pill kinds) are captured deliberately rather than
/// as a side effect of photographing a page.
///
/// This is **not** part of the localized manual catalog: it is not in
/// `manual_screenshots_locale`, has no case IDs, and publishes nothing. It
/// exists so the inventory can be regenerated, and so the "after" half of a
/// People redesign's before/after pair comes from the same fixtures as the
/// "before" half.
///
/// Opt in with an external output directory — nothing runs otherwise:
/// `make people_inventory_screenshots` or
/// `LOTTI_SCREENSHOT_DIR=/tmp/people fvm flutter test \
///   test/features/relationships/ui/pages/people_inventory_screenshots_test.dart`
library;

import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_token_usage.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/proposal_row_part.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/keyboard/ui/app_command_host.dart';
import 'package:lotti/features/relationships/model/imported_contact.dart';
import 'package:lotti/features/relationships/model/relationship_health_metrics.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/service/contact_launcher.dart';
import 'package:lotti/features/relationships/service/contacts_service.dart';
import 'package:lotti/features/relationships/service/pending_interaction_store.dart';
import 'package:lotti/features/relationships/state/contact_import_controller.dart';
import 'package:lotti/features/relationships/state/relationship_agent_providers.dart';
import 'package:lotti/features/relationships/state/relationship_proposal_providers.dart';
import 'package:lotti/features/relationships/ui/pages/contact_import_page.dart';
import 'package:lotti/features/relationships/ui/pages/relationship_details_page.dart';
import 'package:lotti/features/relationships/ui/pages/relationships_page.dart';
import 'package:lotti/features/relationships/ui/shared/persona_avatar.dart';
import 'package:lotti/features/relationships/ui/widgets/avatar_crop_sheet.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_capture_sheet.dart';
import 'package:lotti/features/relationships/ui/widgets/people_list_row.dart';
import 'package:lotti/features/relationships/ui/widgets/person_avatar_sheet.dart';
import 'package:lotti/features/relationships/ui/widgets/person_header.dart';
import 'package:lotti/features/relationships/ui/widgets/post_interaction_prompt.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_briefing_card.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_chat_pane.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_form_modal.dart';
import 'package:lotti/features/relationships/util/contact_channel_uri.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/legacy_material_bridge.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:lotti/utils/thumbhash.dart';
import 'package:lotti/widgets/media/journal_image_resolver.dart';
import 'package:lotti/widgets/media/thumb_hash_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fake_entry_controller.dart';
import '../../../../helpers/fallbacks.dart';
import '../../../../helpers/journal_image_fixtures.dart';
import '../../../../helpers/thumb_hash_fixtures.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../agents/test_data/ai_config_factories.dart';
import '../../../agents/test_data/change_set_factories.dart';
import '../../../agents/test_data/entity_factories.dart';
import '../../../categories/test_utils.dart';
import '../../../daily_os_next/screenshot_harness.dart';

const _subdir = 'people';

const _pipId = 'person-pip';
const _skuaId = 'person-skua';
const _tillyId = 'person-tilly';
const _moId = 'person-mo';
const _hanaId = 'person-hana';
const _categoryId = 'penguin-operations';

/// The three sizes the feature draws an avatar at: the People row's default,
/// the import review (`step9`) and the person hero (`step11`).
final List<double> _avatarSizes = [
  40,
  dsTokensDark.spacing.step9,
  dsTokensDark.spacing.step11,
];

/// The three shapes a photograph can be in on a device, one person each:
/// Pip's has landed, Skua's is still syncing but carries a ThumbHash, and
/// Tilly's is known by id alone. Hana and Mo have none, which is the
/// expected steady state for most people, not a placeholder.
final JournalImage _pipPhoto = buildJournalImage(
  id: 'image-pip',
  imageFile: 'pip.png',
);
final JournalImage _skuaArriving = buildJournalImage(
  id: 'image-skua',
  imageFile: 'skua.webp',
  thumbHash: sampleThumbHash,
);
final JournalImage _tillyPending = buildJournalImage(
  id: 'image-tilly',
  imageFile: 'tilly.webp',
);

/// A real, decodable picture for the one avatar that has its file: the
/// design system's own placeholder — a cartoon, not a person.
final List<int> _fixturePngBytes = File(
  'assets/design_system/avatar_placeholder.png',
).readAsBytesSync();

/// A Thursday afternoon. Every cadence pill, "last spoke" line and relative
/// timestamp in the capture is read against this instant, so the inventory is
/// byte-stable across runs and days.
final _now = DateTime(2026, 8, 13, 14, 5);

/// The channels Pip carries — a mobile number and an email, so the Reach card
/// and the action bar both have something real to render.
const _pipMobile = ContactChannel(
  type: ContactChannelType.mobile,
  value: '+15550100123',
  label: 'Mobile',
);
const _pipEmail = ContactChannel(
  type: ContactChannelType.email,
  value: 'pip@frostbeak.example',
  label: 'Work',
);

/// A launcher that reports what the *phone* can do, so the action bar renders
/// its call control instead of resolving to nothing.
class _CapturingContactLauncher implements ContactLauncher {
  @override
  Future<bool> canLaunch(ContactChannel channel, ContactAction action) async =>
      contactChannelUri(channel, action) != null;

  @override
  Future<bool> launch(ContactChannel channel, ContactAction action) async =>
      true;
}

/// The device-local post-call marker, seeded for the one capture that shows
/// the offer and empty for every other.
class _StubPendingInteractionStore implements PendingInteractionStore {
  _StubPendingInteractionStore([this._pending]);

  final PendingInteraction? _pending;

  @override
  Future<void> remember({
    required String relationshipId,
    required CheckInInteractionType interactionType,
  }) async {}

  @override
  Future<PendingInteraction?> read() async => _pending;

  @override
  Future<void> clear() async {}
}

/// An address book with a handful of penguins in it, for the import capture.
class _StubContactsService implements ContactsService {
  _StubContactsService(this.contacts);

  final List<ImportedContact> contacts;

  @override
  bool get isSupported => true;

  @override
  Future<ContactsAccess> requestReadAccess() async => ContactsAccess.granted;

  @override
  Future<List<ImportedContact>> readAll() async => contacts;

  @override
  Future<ImportedContact?> pickSingle() async => null;

  @override
  Future<ImportedContact?> readById(String id) async => null;

  @override
  Future<void> openSystemSettings() async {}
}

/// Opens a modal on a bare host, so a sheet can be captured in the same shell
/// the app opens it in rather than as a detached widget.
class _ModalHost extends StatelessWidget {
  const _ModalHost({required this.open});

  final Future<void> Function(BuildContext context) open;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        key: const ValueKey('open-modal'),
        onPressed: () => open(context),
        child: const Text('Open'),
      ),
    ),
  );
}

/// What the shell is pumped under. Its `devicePixelRatio` is the one the
/// avatar reads when it caps its decode, so the warm-up must use it too — not
/// the view's — or the cache keys will not match.
MediaQueryData _mediaQueryFor(ScreenshotDevice device) =>
    MediaQueryData(size: device.size);

/// The app shell every capture is rendered inside — the production theme,
/// the production localization delegates and the keyboard command host, so
/// the pixels are the ones the app draws rather than a bare `MaterialApp`'s.
Widget _app({
  required Widget home,
  required Brightness brightness,
  required ScreenshotDevice device,
  required List<Override> overrides,
  required TargetPlatform platform,
}) => RepaintBoundary(
  key: screenshotBoundaryKey,
  child: ProviderScope(
    overrides: overrides,
    child: MediaQuery(
      data: _mediaQueryFor(device),
      child: MaterialApp(
        builder: LegacyMaterialBridge.builder,
        debugShowCheckedModeBanner: false,
        theme: brightness == Brightness.dark
            ? DesignSystemTheme.dark()
            : DesignSystemTheme.light(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: manualScreenshotLocale,
        home: AppCommandHost(
          handlers: const {},
          platform: platform,
          child: Material(type: MaterialType.transparency, child: home),
        ),
      ),
    ),
  ),
);

void main() {
  if (!screenshotCaptureEnabled) {
    test(
      'people inventory screenshot harness (opt-in)',
      () {},
      skip: 'Set LOTTI_SCREENSHOT_DIR to capture the People inventory.',
    );
    return;
  }

  setUpAll(() async {
    registerAllFallbackValues();
    await loadScreenshotFonts();
  });

  final agentId = relationshipAgentIdFor(_pipId);

  late MockRelationshipRepository repository;
  late MockRelationshipAgentService agentService;
  late MockRelationshipReminderService reminders;
  late MockNavService navService;
  late ValueNotifier<String?> selectedRelationshipId;
  late ValueNotifier<bool> chatOpen;

  Metadata meta(String id, {DateTime? at, Duration? length}) {
    final from = at ?? _now;
    return Metadata(
      id: id,
      createdAt: from,
      updatedAt: from,
      dateFrom: from,
      dateTo: from.add(length ?? Duration.zero),
      categoryId: _categoryId,
    );
  }

  RelationshipEntry person(
    String id, {
    required String title,
    String? nickname,
    bool important = false,
    int? cadenceDays,
    List<ContactChannel> channels = const [],
    String? avatarImageId,
    AvatarCrop? avatarCrop,
    String? bannerImageId,
  }) => RelationshipEntry(
    meta: meta(id, at: DateTime(2026, 3, 2)),
    data: RelationshipData(
      title: title,
      nickname: nickname,
      important: important,
      checkInCadenceDays: cadenceDays,
      contactChannels: channels,
      avatarImageId: avatarImageId,
      avatarCrop: avatarCrop,
      bannerImageId: bannerImageId,
      status: RelationshipStatus.active(
        id: 'status-$id',
        createdAt: DateTime(2026, 3, 2),
        utcOffset: 0,
      ),
    ),
  );

  CheckInEntry checkIn(
    String id, {
    required String relationshipId,
    required DateTime at,
    CheckInInteractionType type = CheckInInteractionType.call,
    CheckInSentiment? sentiment,
    List<String> topics = const [],
    String? narrative,
    String? payAttentionTo,
    String? avoid,
    Duration length = Duration.zero,
  }) => CheckInEntry(
    meta: meta(id, at: at, length: length),
    data: CheckInData(
      relationshipId: relationshipId,
      interactionType: type,
      sentiment: sentiment,
      topics: topics,
      payAttentionTo: payAttentionTo,
      avoid: avoid,
    ),
    entryText: narrative == null ? null : EntryText(plainText: narrative),
  );

  Task task(String id, String title, {TaskStatus? status}) =>
      JournalEntity.task(
            meta: meta(id),
            data: TaskData(
              status:
                  status ??
                  TaskStatus.open(
                    id: 'ts-$id',
                    createdAt: _now,
                    utcOffset: 0,
                  ),
              dateFrom: _now,
              dateTo: _now,
              statusHistory: const [],
              title: title,
            ),
          )
          as Task;

  // Pip is the person every detail capture is about: enrolled, weekly, and
  // twelve days since the last call — five days over, so the header, the
  // agent card and the list row all have a lapsed cadence to render.
  final pip = person(
    _pipId,
    title: 'Commander Pip Frostbeak',
    nickname: 'Pip',
    important: true,
    cadenceDays: 7,
    channels: const [_pipMobile, _pipEmail],
    avatarImageId: _pipPhoto.id,
    avatarCrop: const AvatarCrop(y: 0.35, scale: 1.4),
    // The same picture as the banner: a wide crop of it is what a person's
    // "something that reminds me of them" is likely to be anyway.
    bannerImageId: _pipPhoto.id,
  );
  final pipCheckIns = [
    checkIn(
      'check-pip-3',
      relationshipId: _pipId,
      at: DateTime(2026, 8, 1, 12, 44),
      sentiment: CheckInSentiment.good,
      topics: const ['launch window', 'krill logistics'],
      narrative:
          'Walked through the launch window slipping a week. Pip is calm '
          'about it but wants the krill contract signed before the freeze.',
      payAttentionTo: 'The krill contract deadline on the 28th.',
      avoid: 'Re-litigating the pad-3 decision.',
      length: const Duration(minutes: 11),
    ),
    checkIn(
      'check-pip-2',
      relationshipId: _pipId,
      at: DateTime(2026, 7, 24, 9, 15),
      type: CheckInInteractionType.inPerson,
      sentiment: CheckInSentiment.delightful,
      topics: const ['ice garden'],
      narrative: 'Toured the ice garden. Best mood in months.',
      length: const Duration(hours: 1, minutes: 30),
    ),
    checkIn(
      'check-pip-1',
      relationshipId: _pipId,
      at: DateTime(2026, 7, 11, 18, 2),
      type: CheckInInteractionType.message,
      sentiment: CheckInSentiment.neutral,
      length: const Duration(minutes: 4),
    ),
  ];
  final pipTasks = [
    task('task-krill', 'Send Pip the krill contract draft'),
    task(
      'task-pad',
      'Book the pad-3 walkthrough',
      status: TaskStatus.done(id: 'ts-done', createdAt: _now, utcOffset: 0),
    ),
  ];

  final skua = person(
    _skuaId,
    title: 'Dr. Skua Brightwing',
    nickname: 'Skua',
    important: true,
    cadenceDays: 14,
    avatarImageId: _skuaArriving.id,
  );
  final tilly = person(
    _tillyId,
    title: 'Tilly Snowdrift',
    important: true,
    cadenceDays: 30,
    avatarImageId: _tillyPending.id,
  );
  final mo = person(_moId, title: 'Mo Krillson', nickname: 'Mo');
  final hana = person(_hanaId, title: 'Hana Iceberg');

  final listItems = <RelationshipListItem>[
    (relationship: pip, lastCheckIn: pipCheckIns.first),
    (
      relationship: tilly,
      lastCheckIn: checkIn(
        'check-tilly',
        relationshipId: _tillyId,
        at: DateTime(2026, 7, 20, 16, 30),
        type: CheckInInteractionType.videoCall,
      ),
    ),
    (
      relationship: skua,
      lastCheckIn: checkIn(
        'check-skua',
        relationshipId: _skuaId,
        at: DateTime(2026, 8, 12, 19, 5),
        type: CheckInInteractionType.inPerson,
      ),
    ),
    (
      relationship: mo,
      lastCheckIn: checkIn(
        'check-mo',
        relationshipId: _moId,
        at: DateTime(2026, 6, 2, 11),
        type: CheckInInteractionType.message,
      ),
    ),
    (relationship: hana, lastCheckIn: null),
  ];

  AgentReportEntity briefing({DateTime? createdAt, String band = 'thriving'}) =>
      AgentDomainEntity.agentReport(
            id: 'report-pip',
            agentId: agentId,
            scope: AgentReportScopes.current,
            createdAt: createdAt ?? _now.subtract(const Duration(hours: 3)),
            vectorClock: null,
            content:
                'Pip has been steady across three check-ins. The launch '
                'slip is the live thread; the krill contract is the thing '
                'they asked you to carry.\n\n'
                '- Two calls and one visit since July.\n'
                '- Sentiment has not dipped below neutral.\n'
                '- The pad-3 decision is settled — leave it alone.',
            tldr:
                'Pip is in good spirits but the krill contract deadline is '
                'the thing to bring up.',
            provenance: {
              RelationshipReportProvenanceKeys.healthBand: band,
              RelationshipReportProvenanceKeys.healthRationale:
                  'Three check-ins in five weeks, none strained.',
            },
          )
          as AgentReportEntity;

  ResolvedAgentSetup resolvedSetup() => ResolvedAgentSetup(
    status: AgentSetupResolutionStatus.resolved,
    profile: ResolvedProfile(
      thinkingModelId: 'claude-opus-5',
      thinkingProvider: testInferenceProvider(),
      thinkingModel: testAiModel(),
    ),
    source: AgentSetupResolutionSource.baseProfile,
    setupOrigin: AgentInferenceSetupOrigin.user,
  );

  late Directory documents;

  setUp(() async {
    documents = Directory.systemTemp.createTempSync('people_inventory_');
    repository = MockRelationshipRepository();
    agentService = MockRelationshipAgentService();
    reminders = MockRelationshipReminderService();
    selectedRelationshipId = ValueNotifier<String?>(null);
    chatOpen = ValueNotifier<bool>(false);
    navService = MockNavService();

    when(() => agentService.requestBriefing(any())).thenAnswer((_) async {});
    when(
      () => agentService.handleRelationshipDeleted(any()),
    ).thenAnswer((_) async => true);
    when(() => reminders.clearFor(any())).thenAnswer((_) async {});
    when(() => navService.isDesktopMode).thenReturn(false);
    when(
      () => navService.desktopSelectedRelationshipId,
    ).thenReturn(selectedRelationshipId);
    when(() => navService.desktopRelationshipChatOpen).thenReturn(chatOpen);

    when(
      () => repository.getRelationshipsByRecency(),
    ).thenAnswer((_) async => listItems);
    for (final entry in [pip, skua, tilly, mo, hana]) {
      when(
        () => repository.getRelationshipById(entry.id),
      ).thenAnswer((_) async => entry);
      when(
        () => repository.getCheckInsForRelationship(entry.id),
      ).thenAnswer((_) async => const []);
      when(
        () => repository.getLinkedTasks(entry.id),
      ).thenAnswer((_) async => const []);
    }
    when(
      () => repository.getCheckInsForRelationship(_pipId),
    ).thenAnswer((_) async => pipCheckIns);
    when(
      () => repository.getLinkedTasks(_pipId),
    ).thenAnswer((_) async => pipTasks);
    when(
      () => repository.updateRelationship(any()),
    ).thenAnswer((_) async => true);

    await setUpTestGetIt(
      additionalSetup: () {
        final cache = MockEntitiesCacheService();
        final category = CategoryTestUtils.createTestCategory(
          id: _categoryId,
          name: 'Penguin Operations',
          color: '#3CB371',
        );
        when(() => cache.getCategoryById(_categoryId)).thenReturn(category);
        when(() => cache.getCategoryById(any())).thenReturn(category);
        when(() => cache.sortedCategories).thenReturn(<CategoryDefinition>[
          category,
        ]);
        getIt
          ..registerSingleton<EntitiesCacheService>(cache)
          ..registerSingleton<NavService>(navService)
          // The avatar resolves its picture through EntryController, which
          // reads the documents directory and these two services.
          ..registerSingleton<Directory>(documents)
          ..registerSingleton<EditorStateService>(MockEditorStateService())
          ..registerSingleton<PersistenceLogic>(MockPersistenceLogic());
      },
    );
    // Only Pip's file exists; Skua's and Tilly's are deliberately absent.
    createImageFile(_pipPhoto, bytes: _fixturePngBytes);
  });

  tearDown(() async {
    selectedRelationshipId.dispose();
    chatOpen.dispose();
    await tearDownTestGetIt();
    try {
      documents.deleteSync(recursive: true);
    } catch (_) {}
  });

  /// Everything the person page and the agent card read, in one place: the
  /// capture varies only the few signals that decide which face is drawn.
  List<Override> personOverrides({
    AgentReportEntity? report,
    AgentStateEntity? state,
    bool running = false,
    bool modelResolved = true,
    int totalTokens = 0,
    RelationshipProposalSnapshot? proposals,
    PendingInteraction? pending,
    List<ImportedContact> contacts = const [],
  }) => [
    relationshipRepositoryProvider.overrideWithValue(repository),
    relationshipAgentServiceProvider.overrideWithValue(agentService),
    relationshipReminderServiceProvider.overrideWithValue(reminders),
    contactLauncherProvider.overrideWithValue(_CapturingContactLauncher()),
    pendingInteractionStoreProvider.overrideWithValue(
      _StubPendingInteractionStore(pending),
    ),
    contactsServiceProvider.overrideWithValue(_StubContactsService(contacts)),
    contactRefKeyProvider.overrideWith((ref) async => 'ios:capture-host'),
    agentReportProvider(agentId).overrideWith((ref) async => report),
    agentStateProvider(agentId).overrideWith((ref) async => state),
    agentIsRunningProvider(
      agentId,
    ).overrideWith((ref) => Stream.value(running)),
    agentIdentityProvider(agentId).overrideWith(
      (ref) async => makeTestIdentity(
        agentId: agentId,
        kind: AgentKinds.relationshipAgent,
        displayName: 'Commander Pip Frostbeak',
      ),
    ),
    taskAgentResolvedSetupProvider(agentId).overrideWith(
      (ref) async => modelResolved
          ? resolvedSetup()
          : const ResolvedAgentSetup(
              status: AgentSetupResolutionStatus.disabled,
            ),
    ),
    agentTokenUsageSummariesProvider(agentId).overrideWith(
      (ref) async => [
        if (totalTokens > 0)
          AgentTokenUsageSummary(
            modelId: 'claude-opus-5',
            inputTokens: totalTokens,
          ),
      ],
    ),
    taskAgentSetupOptionsProvider.overrideWith(
      (ref) async => const TaskAgentSetupOptions(
        profiles: [],
        models: [],
        providers: [],
      ),
    ),
    relationshipBriefingDisclosureProvider(
      _pipId,
    ).overrideWith((ref) async => null),
    relationshipSuggestionListProvider(_pipId).overrideWith(
      (ref) async => proposals ?? const RelationshipProposalSnapshot.empty(),
    ),
    createEntryControllerOverride(_pipPhoto),
    createEntryControllerOverride(_skuaArriving),
    createEntryControllerOverride(_tillyPending),
  ];

  /// Decodes Pip's photograph at every size an avatar draws it — and Skua's
  /// ThumbHash stand-in, whose raster also goes through the engine — *before*
  /// the surface is mounted.
  ///
  /// Order is the whole point. A `FileImage` decodes on real async IO, which
  /// only progresses inside `runAsync`; but once a mounted `Image` has begun
  /// resolving the provider under the test's fake-async zone, the shared
  /// cache stream's completion is bound to that zone and never fires inside
  /// a later `runAsync` — a precache attached afterwards waits forever. So
  /// the decode is done first, on a throwaway host, and the real surface
  /// then finds every key already in the image cache. The keys come from the
  /// production `cappedFileImage` at the avatar's inner (ring-less) size and
  /// this shell's pixel ratio, so they are exactly what `PersonaAvatar`
  /// builds.
  Future<void> warmAvatarDecodes(
    WidgetTester tester,
    ScreenshotDevice device,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: SizedBox(key: ValueKey('precache-host'))),
    );
    final context = tester.element(find.byKey(const ValueKey('precache-host')));
    final path = getFullImagePath(_pipPhoto);
    final ring = PersonaAvatar.ringWidth(dsTokensDark);
    final devicePixelRatio = _mediaQueryFor(device).devicePixelRatio;
    await tester.runAsync(() async {
      // The banner decodes bounded to the hero's strip at rest, at the
      // shell's full width — the same key the hero builds.
      await precacheImage(
        boundedFileImage(
          path,
          bounds: Size(
            device.size.width,
            PersonHeroAppBar.bannerStripExtent(dsTokensDark, topPadding: 0),
          ),
          devicePixelRatio: devicePixelRatio,
        ),
        context,
      );
      // The stand-in is keyed on the hash, so this is the exact entry the
      // list row's arriving avatar resolves to.
      await precacheImage(
        ThumbHashImage(ThumbHash.fromBase64(sampleThumbHash)),
        context,
      );
      for (final size in _avatarSizes) {
        await precacheImage(
          cappedFileImage(
            path,
            size: size - ring * 2,
            devicePixelRatio: devicePixelRatio,
          ),
          context,
        );
      }
    });
  }

  /// Pumps [home] in the app shell under the fixed clock and settles it.
  Future<void> pumpSurface(
    WidgetTester tester, {
    required Widget home,
    required ScreenshotDevice device,
    required Brightness brightness,
    List<Override> overrides = const [],
    String? selectedId,
    bool desktopChat = false,
  }) async {
    selectedRelationshipId.value = selectedId;
    chatOpen.value = desktopChat;
    when(() => navService.isDesktopMode).thenReturn(!device.isPhone);
    tester.view
      ..physicalSize = device.size * device.devicePixelRatio
      ..devicePixelRatio = device.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await warmAvatarDecodes(tester, device);

    await withClock(Clock.fixed(_now), () async {
      await tester.pumpWidget(
        _app(
          home: home,
          brightness: brightness,
          device: device,
          overrides: overrides,
          platform: device.isPhone ? TargetPlatform.iOS : TargetPlatform.macOS,
        ),
      );
      await tester.pumpAndSettle();
    });
  }

  /// Opens a modal from [_ModalHost] and settles it, under the same clock.
  Future<void> openModal(WidgetTester tester) async {
    await withClock(Clock.fixed(_now), () async {
      await tester.tap(find.byKey(const ValueKey('open-modal')));
      await tester.pumpAndSettle();
    });
  }

  for (final (device, viewport) in [
    (proDevice, 'mobile'),
    (desktopDevice, 'desktop'),
  ]) {
    for (final (brightness, theme) in [
      (Brightness.dark, 'dark'),
      (Brightness.light, 'light'),
    ]) {
      // ---------------------------------------------------------------
      // The People list.
      // ---------------------------------------------------------------
      testWidgets('$viewport people list — $theme', (tester) async {
        await pumpSurface(
          tester,
          home: const RelationshipsPage(),
          device: device,
          brightness: brightness,
          overrides: personOverrides(),
        );

        expect(
          find.text('Commander Pip Frostbeak'),
          findsOneWidget,
          reason: 'the lapsed person leads the Due band',
        );
        expect(
          find.byType(PeopleListRow),
          findsNWidgets(listItems.length),
          reason: 'every band renders its rows: due, on track, not enrolled',
        );
        await captureScreenshot(
          tester,
          'people_list_${viewport}_$theme',
          subdir: _subdir,
        );
      });

      testWidgets('$viewport people list empty — $theme', (tester) async {
        when(
          () => repository.getRelationshipsByRecency(),
        ).thenAnswer((_) async => const []);

        await pumpSurface(
          tester,
          home: const RelationshipsPage(),
          device: device,
          brightness: brightness,
          overrides: personOverrides(),
        );

        expect(find.byType(PeopleListRow), findsNothing);
        expect(
          find.text('Add the people you want to stay close to.'),
          findsOneWidget,
          reason: "the empty state is the tab's first impression",
        );
        await captureScreenshot(
          tester,
          'people_list_empty_${viewport}_$theme',
          subdir: _subdir,
        );
      });

      // ---------------------------------------------------------------
      // The person page, with a current briefing.
      // ---------------------------------------------------------------
      testWidgets('$viewport person page — $theme', (tester) async {
        await pumpSurface(
          tester,
          home: device.isPhone
              ? const RelationshipDetailsPage(relationshipId: _pipId)
              : const RelationshipsPage(),
          device: device,
          brightness: brightness,
          selectedId: _pipId,
          overrides: personOverrides(
            report: briefing(),
            state: makeTestState(
              agentId: agentId,
              lastWakeAt: _now.subtract(const Duration(hours: 3)),
            ),
            totalTokens: 18432,
          ),
        );

        expect(find.text('Commander Pip Frostbeak'), findsWidgets);
        expect(
          find.byType(RelationshipBriefingCard),
          findsOneWidget,
          reason: 'the page leads with the agent briefing',
        );
        await captureScreenshot(
          tester,
          'person_page_${viewport}_$theme',
          subdir: _subdir,
        );
      });
    }
  }

  // -----------------------------------------------------------------
  // The person page's other shapes, phone only — the desktop split puts
  // the same page in the same column, so a second viewport would say
  // nothing new about these states.
  // -----------------------------------------------------------------
  testWidgets('mobile person page, no briefing yet — dark', (tester) async {
    await pumpSurface(
      tester,
      home: const RelationshipDetailsPage(relationshipId: _pipId),
      device: proDevice,
      brightness: Brightness.dark,
      overrides: personOverrides(),
    );

    expect(
      find.byKey(const ValueKey('relationship-brief-me')),
      findsOneWidget,
      reason: 'an enrolled person without a report is offered the first one',
    );
    await captureScreenshot(
      tester,
      'person_page_no_briefing_mobile_dark',
      subdir: _subdir,
    );
  });

  testWidgets('mobile person page, not enrolled — dark', (tester) async {
    when(
      () => repository.getRelationshipById(_moId),
    ).thenAnswer((_) async => mo);
    when(
      () => repository.getCheckInsForRelationship(_moId),
    ).thenAnswer((_) async => const []);

    await pumpSurface(
      tester,
      home: const RelationshipDetailsPage(relationshipId: _moId),
      device: proDevice,
      brightness: Brightness.dark,
      overrides: personOverrides(),
    );

    expect(find.text('Mo Krillson'), findsWidgets);
    expect(
      find.byKey(const ValueKey('relationship-agent-mark-important')),
      findsOneWidget,
      reason: 'the unenrolled card offers the consent switch, not AI chrome',
    );
    await captureScreenshot(
      tester,
      'person_page_not_enrolled_mobile_dark',
      subdir: _subdir,
    );
  });

  testWidgets('mobile person page, scrolled to Reach and Tasks — dark', (
    tester,
  ) async {
    await pumpSurface(
      tester,
      home: const RelationshipDetailsPage(relationshipId: _pipId),
      device: proDevice,
      brightness: Brightness.dark,
      overrides: personOverrides(
        report: briefing(),
        state: makeTestState(agentId: agentId),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Send Pip the krill contract draft'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(
      find.text('pip@frostbeak.example'),
      findsOneWidget,
      reason: 'the Reach card lists the channels behind the privacy line',
    );
    await captureScreenshot(
      tester,
      'person_page_reach_tasks_mobile_dark',
      subdir: _subdir,
    );
  });

  testWidgets('mobile person page, post-call offer — dark', (tester) async {
    await pumpSurface(
      tester,
      home: const RelationshipDetailsPage(relationshipId: _pipId),
      device: proDevice,
      brightness: Brightness.dark,
      overrides: personOverrides(
        report: briefing(),
        state: makeTestState(agentId: agentId),
        pending: (
          relationshipId: _pipId,
          interactionType: CheckInInteractionType.call,
          startedAt: _now.subtract(const Duration(minutes: 11)),
        ),
      ),
    );

    final offer = find.byType(PostInteractionPrompt);
    await tester.scrollUntilVisible(
      offer,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('11 minutes ago'),
      findsOneWidget,
      reason: 'the offer names the evidence it was built from',
    );
    await captureScreenshot(
      tester,
      'person_page_post_call_mobile_dark',
      subdir: _subdir,
    );
  });

  // -----------------------------------------------------------------
  // The banner's other two states: on its way, and folded.
  // -----------------------------------------------------------------
  testWidgets('mobile person page, banner arriving — dark', (tester) async {
    when(() => repository.getRelationshipById(_pipId)).thenAnswer(
      (_) async => pip.copyWith(
        data: pip.data.copyWith(bannerImageId: _skuaArriving.id),
      ),
    );

    await pumpSurface(
      tester,
      home: const RelationshipDetailsPage(relationshipId: _pipId),
      device: proDevice,
      brightness: Brightness.dark,
      overrides: personOverrides(report: briefing()),
    );

    expect(
      find.byKey(const ValueKey('person-hero-scrim')),
      findsOneWidget,
      reason: 'the stand-in wears the same scrim the picture will',
    );
    await captureScreenshot(
      tester,
      'person_page_banner_arriving_mobile_dark',
      subdir: _subdir,
    );
  });

  testWidgets('mobile person page, hero folded onto the banner — dark', (
    tester,
  ) async {
    await pumpSurface(
      tester,
      home: const RelationshipDetailsPage(relationshipId: _pipId),
      device: proDevice,
      brightness: Brightness.dark,
      overrides: personOverrides(report: briefing()),
    );
    await withClock(Clock.fixed(_now), () async {
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -320),
      );
      await tester.pumpAndSettle();
    });

    expect(
      find.byKey(const ValueKey('person-hero-title')),
      findsOneWidget,
      reason: 'the name has swapped into the bar, over the picture',
    );
    await captureScreenshot(
      tester,
      'person_page_banner_folded_mobile_dark',
      subdir: _subdir,
    );
  });

  // -----------------------------------------------------------------
  // The six faces of the relationship agent card, captured on the card
  // itself: five of them never appear on a page in any other fixture.
  // -----------------------------------------------------------------
  // Built lazily: the overrides close over mocks that only exist per test.
  final agentFaces = <String, List<Override> Function()>{
    'not_enrolled': personOverrides,
    'no_briefing': () =>
        personOverrides(state: makeTestState(agentId: agentId)),
    'running': () => personOverrides(
      state: makeTestState(agentId: agentId),
      running: true,
    ),
    'failed': () => personOverrides(
      state: makeTestState(
        agentId: agentId,
        consecutiveFailureCount: 2,
        lastWakeAt: _now.subtract(const Duration(minutes: 20)),
      ),
    ),
    'current': () => personOverrides(
      report: briefing(),
      state: makeTestState(agentId: agentId),
      totalTokens: 18432,
    ),
    'out_of_date': () => personOverrides(
      report: briefing(createdAt: _now.subtract(const Duration(days: 6))),
      state: makeTestState(
        agentId: agentId,
      ).copyWith(reportStaleAt: _now.subtract(const Duration(hours: 2))),
      totalTokens: 24096,
    ),
  };

  for (final face in agentFaces.entries) {
    testWidgets('mobile agent card, ${face.key} — dark', (tester) async {
      final enrolled = face.key != 'not_enrolled';
      await pumpSurface(
        tester,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: RelationshipBriefingCard(
              relationship: enrolled ? pip : mo,
              checkIns: enrolled ? pipCheckIns : const [],
            ),
          ),
        ),
        device: proDevice,
        brightness: Brightness.dark,
        overrides: face.value(),
      );

      expect(
        find.byType(RelationshipBriefingCard),
        findsOneWidget,
        reason: 'the ${face.key} face renders as a card, not an error',
      );
      await captureScreenshot(
        tester,
        'agent_card_${face.key}_mobile_dark',
        subdir: _subdir,
      );
    });
  }

  testWidgets('mobile agent card with task proposals — dark', (tester) async {
    const item = ChangeItem(
      toolName: 'create_and_link_task',
      args: {'title': 'Send Pip the krill contract draft'},
      humanSummary: 'Create task: Send Pip the krill contract draft',
    );
    const second = ChangeItem(
      toolName: 'create_and_link_task',
      args: {'title': 'Book the pad-3 walkthrough'},
      humanSummary: 'Create task: Book the pad-3 walkthrough',
    );
    final set = makeTestChangeSet(
      id: 'set-pip',
      runKey: 'run-pip',
      agentId: agentId,
      taskId: _pipId,
      items: [item, second],
    );

    await pumpSurface(
      tester,
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: RelationshipBriefingCard(
            relationship: pip,
            checkIns: pipCheckIns,
          ),
        ),
      ),
      device: proDevice,
      brightness: Brightness.dark,
      overrides: personOverrides(
        report: briefing(),
        state: makeTestState(agentId: agentId),
        proposals: RelationshipProposalSnapshot(
          suggestions: UnifiedSuggestionList(
            open: [
              PendingSuggestion(
                changeSet: set,
                itemIndex: 0,
                item: item,
                fingerprint: ChangeItem.fingerprint(item),
              ),
              PendingSuggestion(
                changeSet: set,
                itemIndex: 1,
                item: second,
                fingerprint: ChangeItem.fingerprint(second),
              ),
            ],
            activity: const [],
          ),
        ),
      ),
    );

    expect(
      find.byType(ProposalRow),
      findsNWidgets(2),
      reason: 'the band lists the commitments the agent read out of check-ins',
    );
    await captureScreenshot(
      tester,
      'agent_card_proposals_mobile_dark',
      subdir: _subdir,
    );
  });

  // -----------------------------------------------------------------
  // Modals: the check-in sheet and the person form, on both viewports —
  // the modal system takes its bottom-sheet branch on a phone and its
  // centred-dialog branch on a desktop, so both are worth having.
  // -----------------------------------------------------------------
  for (final (device, viewport) in [
    (proDevice, 'mobile'),
    (desktopDevice, 'desktop'),
  ]) {
    testWidgets('$viewport check-in capture sheet — dark', (tester) async {
      await pumpSurface(
        tester,
        home: _ModalHost(
          open: (context) => showCheckInCaptureSheet(
            context: context,
            relationshipId: _pipId,
          ),
        ),
        device: device,
        brightness: Brightness.dark,
        overrides: personOverrides(),
      );
      await openModal(tester);

      expect(
        find.byKey(const ValueKey('check-in-save')),
        findsOneWidget,
        reason: 'Save is pinned, not below the fold',
      );
      expect(
        find.byKey(const ValueKey('check-in-more')),
        findsOneWidget,
        reason: 'topics and the next-time fields start folded',
      );
      await captureScreenshot(
        tester,
        'check_in_capture_${viewport}_dark',
        subdir: _subdir,
      );
    });

    testWidgets('$viewport check-in edit sheet — dark', (tester) async {
      await pumpSurface(
        tester,
        home: _ModalHost(
          open: (context) => showCheckInEditSheet(
            context: context,
            checkIn: pipCheckIns.first,
          ),
        ),
        device: device,
        brightness: Brightness.dark,
        overrides: personOverrides(),
      );
      await openModal(tester);

      expect(
        find.byKey(const ValueKey('check-in-delete')),
        findsOneWidget,
        reason: 'editing adds delete to the pinned bar',
      );
      expect(
        find.text('The krill contract deadline on the 28th.'),
        findsOneWidget,
        reason: 'More is unfolded when the check-in carries next-time fields',
      );
      await captureScreenshot(
        tester,
        'check_in_edit_${viewport}_dark',
        subdir: _subdir,
      );
    });

    testWidgets('$viewport person form, add — dark', (tester) async {
      await pumpSurface(
        tester,
        home: _ModalHost(
          open: (context) => showRelationshipCreateModal(context: context),
        ),
        device: device,
        brightness: Brightness.dark,
        overrides: personOverrides(),
      );
      await openModal(tester);

      expect(
        find.byKey(const ValueKey('person-form-who-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('person-form-reach-card')),
        findsOneWidget,
        reason: 'the form is three cards: Who, Important, How to reach them',
      );
      await captureScreenshot(
        tester,
        'person_form_add_${viewport}_dark',
        subdir: _subdir,
      );
    });

    testWidgets('$viewport person form, edit — dark', (tester) async {
      await pumpSurface(
        tester,
        home: _ModalHost(
          open: (context) =>
              showRelationshipEditModal(context: context, relationship: pip),
        ),
        device: device,
        brightness: Brightness.dark,
        overrides: personOverrides(),
      );
      await openModal(tester);

      expect(
        find.text('Commander Pip Frostbeak'),
        findsOneWidget,
        reason: 'the edit form is prefilled from the person',
      );
      expect(
        find.byKey(const ValueKey('person-form-save')),
        findsOneWidget,
      );
      await captureScreenshot(
        tester,
        'person_form_edit_${viewport}_dark',
        subdir: _subdir,
      );
    });

    // ---------------------------------------------------------------
    // The agent conversation: a page on a phone, the detail pane on a
    // desktop.
    // ---------------------------------------------------------------
    testWidgets('$viewport person chat — dark', (tester) async {
      await pumpSurface(
        tester,
        home: device.isPhone
            ? const Scaffold(
                body: RelationshipChatPane(relationshipId: _pipId),
              )
            : const RelationshipsPage(),
        device: device,
        brightness: Brightness.dark,
        selectedId: _pipId,
        desktopChat: true,
        overrides: [
          ...personOverrides(report: briefing()),
          agentChatProjectionProvider(agentId).overrideWith(
            (ref) async => [
              AgentChatMessage(
                id: 'm1',
                role: AgentChatRole.user,
                text: 'What should I bring up with Pip this week?',
                createdAt: _now.subtract(const Duration(minutes: 6)),
              ),
              AgentChatMessage(
                id: 'm2',
                role: AgentChatRole.agent,
                text:
                    'The krill contract. Pip asked you to carry it on the '
                    'call of 1 August and the deadline is the 28th.',
                createdAt: _now.subtract(const Duration(minutes: 5)),
                runKey: 'run-pip',
              ),
            ],
          ),
        ],
      );

      expect(
        find.text('Commander Pip Frostbeak · briefing agent'),
        findsOneWidget,
        reason: 'the identity header says who is answering',
      );
      expect(
        find.text('Knows your check-ins, not the channels'),
        findsOneWidget,
        reason: 'and what they can see, before the user asks',
      );
      await captureScreenshot(
        tester,
        'person_chat_${viewport}_dark',
        subdir: _subdir,
      );
    });
  }

  // -----------------------------------------------------------------
  // The avatar's own surfaces: the sheet under it, and the crop.
  // -----------------------------------------------------------------
  for (final (device, viewport) in [
    (proDevice, 'mobile'),
    (desktopDevice, 'desktop'),
  ]) {
    testWidgets('$viewport person photo sheet — dark', (tester) async {
      await pumpSurface(
        tester,
        home: _ModalHost(
          open: (context) =>
              showPersonAvatarSheet(context: context, relationship: pip),
        ),
        device: device,
        brightness: Brightness.dark,
        overrides: personOverrides(),
      );
      await openModal(tester);

      expect(find.text('Photo of Commander Pip Frostbeak'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('person-photo-remove')),
        findsOneWidget,
        reason: 'Pip has a photo, so the sheet offers all three rows',
      );
      await captureScreenshot(
        tester,
        'person_photo_sheet_${viewport}_dark',
        subdir: _subdir,
      );
    });

    testWidgets('$viewport avatar crop — dark', (tester) async {
      Future<void> open() => openModal(tester);
      await pumpSurface(
        tester,
        home: _ModalHost(
          open: (context) => showAvatarCropSheet(
            context: context,
            relationship: pip,
            imageId: _pipPhoto.id,
            initial: pip.data.avatarCrop,
          ),
        ),
        device: device,
        brightness: Brightness.dark,
        overrides: personOverrides(),
      );

      // The surface decodes the picture at its own viewport size, which is
      // only known once laid out. Open once to measure, close, warm that
      // exact key on the real event loop, then open again to capture — the
      // same before-mount rule the avatars follow, applied after a dry run.
      await open();
      final viewportSide = tester
          .getSize(find.byKey(const ValueKey('avatar-crop-viewport')))
          .width;
      await tester.tap(find.byKey(const ValueKey('avatar-crop-cancel')));
      await tester.pumpAndSettle();
      final key = cappedFileImage(
        getFullImagePath(_pipPhoto),
        size: viewportSide,
        devicePixelRatio: _mediaQueryFor(device).devicePixelRatio,
      );
      final context = tester.element(find.byKey(const ValueKey('open-modal')));
      await tester.runAsync(() async {
        // The dry run left a completer bound to the fake clock under this
        // key; evict it so the precache starts a fresh one here.
        await key.evict();
        await precacheImage(key, context);
      });
      await open();

      expect(find.text('Choose the face'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('avatar-crop-preview')),
        findsOneWidget,
        reason: 'the live preview at list size is the commitment moment',
      );
      await captureScreenshot(
        tester,
        'avatar_crop_${viewport}_dark',
        subdir: _subdir,
      );
    });
  }

  // -----------------------------------------------------------------
  // Contact import, phone only: the address book exists on Android and
  // iOS, and desktop keeps manual channel entry instead.
  // -----------------------------------------------------------------
  final addressBook = <ImportedContact>[
    (
      id: 'c1',
      displayName: 'Commander Pip Frostbeak',
      channels: const [_pipMobile, _pipEmail],
    ),
    (
      id: 'c2',
      displayName: 'Dr. Skua Brightwing',
      channels: const [
        ContactChannel(
          type: ContactChannelType.mobile,
          value: '+15550100456',
        ),
      ],
    ),
    (
      id: 'c3',
      displayName: 'Tilly Snowdrift',
      channels: const [
        ContactChannel(
          type: ContactChannelType.email,
          value: 'tilly@snowdrift.example',
        ),
      ],
    ),
    (id: 'c4', displayName: 'Mo Krillson', channels: const []),
  ];

  testWidgets('mobile contact import, select step — dark', (tester) async {
    await pumpSurface(
      tester,
      home: const ContactImportPage(),
      device: proDevice,
      brightness: Brightness.dark,
      overrides: personOverrides(contacts: addressBook),
    );

    expect(
      find.byType(CheckboxListTile),
      findsNWidgets(addressBook.length),
      reason: 'picking is the bulk half of the two-step import',
    );
    await captureScreenshot(
      tester,
      'contact_import_select_mobile_dark',
      subdir: _subdir,
    );
  });

  testWidgets('mobile contact import, review step — dark', (tester) async {
    await pumpSurface(
      tester,
      home: const ContactImportPage(),
      device: proDevice,
      brightness: Brightness.dark,
      overrides: personOverrides(contacts: addressBook),
    );

    await tester.tap(find.text('Commander Pip Frostbeak'));
    await tester.tap(find.text('Dr. Skua Brightwing'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review 2'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('contact-import-review-c1')),
      findsOneWidget,
      reason: 'the review step is where importance and cadence are decided',
    );
    expect(
      find.textContaining('contact details stay on this device'),
      findsOneWidget,
      reason: 'the boundary is named before anything is written',
    );
    await captureScreenshot(
      tester,
      'contact_import_review_mobile_dark',
      subdir: _subdir,
    );
  });

  // -----------------------------------------------------------------
  // The identity primitives themselves — the whole accent palette and
  // the avatar at every size the feature draws it. This is the surface
  // a photo would replace, so it is captured on its own rather than
  // only as a detail of a page.
  // -----------------------------------------------------------------
  for (final (brightness, theme) in [
    (Brightness.dark, 'dark'),
    (Brightness.light, 'light'),
  ]) {
    testWidgets('persona avatar palette — $theme', (tester) async {
      // Ids chosen so the FNV-1a hash lands one on each palette slot: the
      // sheet shows the whole accent range, not six draws of the same hue.
      final ids = <String>[];
      final seen = <int>{};
      for (var i = 0; seen.length < 6 && i < 500; i++) {
        final id = 'palette-$i';
        final accent = personaAccentForId(id, brightness);
        if (seen.add(accent.toARGB32())) ids.add(id);
      }

      await pumpSurface(
        tester,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final id in ids)
                      PersonaAvatar(initial: id.split('-').last, id: id),
                  ],
                ),
                const SizedBox(height: 32),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // The three sizes the feature actually draws: 40 on a
                    // People row (the default), 48 (step9) in the import
                    // review, 80 (step11) on the person page hero.
                    for (final size in _avatarSizes) ...[
                      PersonaAvatar(initial: 'P', id: _pipId, size: size),
                      const SizedBox(width: 16),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        device: proDevice,
        brightness: brightness,
        overrides: personOverrides(),
      );

      expect(
        ids,
        hasLength(6),
        reason: 'the palette has six accents and the sheet shows all six',
      );
      expect(find.byType(PersonaAvatar), findsNWidgets(9));
      await captureScreenshot(
        tester,
        'persona_avatar_palette_mobile_$theme',
        subdir: _subdir,
      );
    });
  }

  for (final (brightness, theme) in [
    (Brightness.dark, 'dark'),
    (Brightness.light, 'light'),
  ]) {
    testWidgets('persona avatar, the four faces — $theme', (tester) async {
      // One row per face, the three sizes across: no photo, photo, arriving
      // (stand-in under the ring), id known with nothing to show yet.
      final faces = <(String, String?)>[
        ('No photo', null),
        ('Photo', _pipPhoto.id),
        ('Arriving', _skuaArriving.id),
        ('Id known', _tillyPending.id),
      ];
      await pumpSurface(
        tester,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (label, imageId) in faces) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final size in _avatarSizes) ...[
                        PersonaAvatar(
                          initial: 'P',
                          id: _pipId,
                          size: size,
                          imageId: imageId,
                        ),
                        const SizedBox(width: 16),
                      ],
                      Text(label),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
        ),
        device: proDevice,
        brightness: brightness,
        overrides: personOverrides(),
      );

      expect(find.byType(PersonaAvatar), findsNWidgets(12));
      expect(
        find.byKey(const ValueKey('persona-avatar-ring')),
        findsNWidgets(9),
        reason: 'every face but "no photo" wears the ring, at all three sizes',
      );
      await captureScreenshot(
        tester,
        'persona_avatar_faces_mobile_$theme',
        subdir: _subdir,
      );
    });
  }

  testWidgets('people list rows, every pill kind — dark', (tester) async {
    await pumpSurface(
      tester,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final item in listItems)
                PeopleListRow(
                  item: item,
                  onTap: () {},
                ),
            ],
          ),
        ),
      ),
      device: proDevice,
      brightness: Brightness.dark,
      overrides: personOverrides(),
    );

    expect(find.byType(PeopleListRow), findsNWidgets(listItems.length));
    expect(
      find.text('5 days over'),
      findsOneWidget,
      reason: 'an overdue person never reads as "Due <weekday>"',
    );
    await captureScreenshot(
      tester,
      'people_list_rows_mobile_dark',
      subdir: _subdir,
    );
  });
}
