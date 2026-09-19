import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/services/profile_automation_service.dart';
import 'package:lotti/features/ai/services/skill_inference_runner.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/service/check_in_photo_analysis_trigger.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  final at = DateTime(2026, 9, 19, 18);

  late MockProfileAutomationService automation;
  late MockSkillInferenceRunner runner;
  late MockRelationshipRepository relationships;
  late MockJournalDb journalDb;
  late MockDomainLogger logger;
  late MockJournalDb registeredJournalDb;
  late ProviderContainer container;

  setUpAll(() => registerFallbackValue(AutomationResult.notHandled));

  CheckInEntry checkIn({String relationshipId = 'rel-1'}) => CheckInEntry(
    meta: Metadata(
      id: 'check-in-1',
      createdAt: at,
      updatedAt: at,
      dateFrom: at,
      dateTo: at,
    ),
    data: CheckInData(
      relationshipId: relationshipId,
      interactionType: CheckInInteractionType.inPerson,
    ),
  );

  AutomationResult handled() => AutomationResult(
    handled: true,
    skill:
        AiConfig.skill(
              id: 'skill-vision',
              name: 'Image Analysis',
              skillType: SkillType.imageAnalysis,
              requiredInputModalities: const [Modality.image],
              systemInstructions: 'Analyze.',
              userInstructions: 'Describe.',
              createdAt: DateTime(2024),
            )
            as AiConfigSkill,
  );

  setUp(() async {
    automation = MockProfileAutomationService();
    runner = MockSkillInferenceRunner();
    relationships = MockRelationshipRepository();
    journalDb = MockJournalDb();
    logger = MockDomainLogger();

    final mocks = await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..unregister<DomainLogger>()
          ..registerSingleton<DomainLogger>(logger);
      },
    );
    registeredJournalDb = mocks.journalDb;
    when(
      () => logger.log(
        any<LogDomain>(),
        any<String>(),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).thenReturn(null);
    when(
      () => logger.error(
        any<LogDomain>(),
        any<Object>(),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => automation.tryAnalyzeImage(subjectId: any(named: 'subjectId')),
    ).thenAnswer((_) async => AutomationResult.notHandled);
    when(
      () => runner.runImageAnalysis(
        imageEntryId: any(named: 'imageEntryId'),
        automationResult: any(named: 'automationResult'),
        linkedTaskId: any(named: 'linkedTaskId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => relationships.touchCheckInsHolding(any()),
    ).thenAnswer((_) async {});
    when(
      () => relationships.getImageDescriptions(any()),
    ).thenAnswer((_) async => {'photo-1': 'Pip on the ice.'});
    when(
      () => journalDb.journalEntityById('check-in-1'),
    ).thenAnswer((_) async => checkIn());

    container = ProviderContainer(
      overrides: [
        profileAutomationServiceProvider.overrideWithValue(automation),
        skillInferenceRunnerProvider.overrideWithValue(runner),
        relationshipRepositoryProvider.overrideWithValue(relationships),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestGetIt();
  });

  CheckInPhotoAnalysisTrigger trigger() => CheckInPhotoAnalysisTrigger(
    ref: container.read(_refProvider),
    loggingService: logger,
    relationships: relationships,
    journalDb: journalDb,
  );

  // The person's profile decides, not the check-in's: their agent's profile,
  // falling back to the category they inherit from.
  test(
    'analyses the photo against the person the check-in belongs to',
    () async {
      when(
        () => automation.tryAnalyzeImage(subjectId: 'rel-1'),
      ).thenAnswer((_) async => handled());

      await trigger().triggerAutomaticImageAnalysis(
        imageEntryId: 'photo-1',
        linkedTaskId: 'check-in-1',
      );

      verify(() => automation.tryAnalyzeImage(subjectId: 'rel-1')).called(1);
      verify(
        () => runner.runImageAnalysis(
          imageEntryId: 'photo-1',
          automationResult: any(named: 'automationResult'),
          // The person is the subject; a check-in is no task context.
          // ignore: avoid_redundant_argument_values
          linkedTaskId: null,
        ),
      ).called(1);
    },
  );

  // ADR 0062 Decision 3: a description that lands after the check-in was
  // saved is new evidence, so the check-in is saved again.
  test('saves the check-in again once the photo has been described', () async {
    when(
      () => automation.tryAnalyzeImage(subjectId: 'rel-1'),
    ).thenAnswer((_) async => handled());

    await trigger().triggerAutomaticImageAnalysis(
      imageEntryId: 'photo-1',
      linkedTaskId: 'check-in-1',
    );

    verify(() => relationships.touchCheckInsHolding('photo-1')).called(1);
  });

  // Codex review on #4381: a run that wrote no description — no profile, no
  // usable model, a provider failure, an empty response — must not mark the
  // check-in stale and buy another inference over unchanged evidence.
  test('leaves the check-in alone when no description was written', () async {
    when(
      () => relationships.getImageDescriptions(any()),
    ).thenAnswer((_) async => const {});

    await trigger().triggerAutomaticImageAnalysis(
      imageEntryId: 'photo-1',
      linkedTaskId: 'check-in-1',
    );

    verifyNever(() => relationships.touchCheckInsHolding(any()));
  });

  // Nothing awaits this trigger, so a failed read or write is logged rather
  // than left as an unhandled asynchronous error.
  test('logs, rather than throws, when the check-in cannot be saved', () async {
    when(
      () => relationships.touchCheckInsHolding(any()),
    ).thenThrow(StateError('database closed'));

    await expectLater(
      trigger().triggerAutomaticImageAnalysis(
        imageEntryId: 'photo-1',
        linkedTaskId: 'check-in-1',
      ),
      completes,
    );

    verify(
      () => logger.error(
        LogDomain.ai,
        any<Object>(),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
        subDomain: 'checkInPhotoAnalysis',
      ),
    ).called(1);
  });

  test('describes nothing where no profile assigns an image-analysis '
      'skill', () async {
    await trigger().triggerAutomaticImageAnalysis(
      imageEntryId: 'photo-1',
      linkedTaskId: 'check-in-1',
    );

    verifyNever(
      () => runner.runImageAnalysis(
        imageEntryId: any(named: 'imageEntryId'),
        automationResult: any(named: 'automationResult'),
        linkedTaskId: any(named: 'linkedTaskId'),
      ),
    );
  });

  for (final (reason, stub) in [
    ('the photo belongs to no check-in', null),
    ('the check-in cannot be read', 'throws'),
  ]) {
    test('does nothing when $reason', () async {
      if (stub == null) {
        when(
          () => journalDb.journalEntityById('check-in-1'),
        ).thenAnswer((_) async => null);
      } else {
        when(
          () => journalDb.journalEntityById('check-in-1'),
        ).thenThrow(StateError('database closed'));
      }

      await trigger().triggerAutomaticImageAnalysis(
        imageEntryId: 'photo-1',
        linkedTaskId: 'check-in-1',
      );

      verifyNever(
        () => automation.tryAnalyzeImage(subjectId: any(named: 'subjectId')),
      );
      verifyNever(() => relationships.touchCheckInsHolding(any()));
      verifyNever(() => relationships.getImageDescriptions(any()));
    });
  }

  // The provider is what the importer reads: it must reach the repository of
  // the scope it is read in, and the app's journal database.
  test('the provider wires the trigger to the scope it is read in', () async {
    when(
      () => registeredJournalDb.journalEntityById('check-in-1'),
    ).thenAnswer((_) async => checkIn());
    when(
      () => automation.tryAnalyzeImage(subjectId: 'rel-1'),
    ).thenAnswer((_) async => handled());

    await container
        .read(checkInPhotoAnalysisTriggerProvider)
        .triggerAutomaticImageAnalysis(
          imageEntryId: 'photo-1',
          linkedTaskId: 'check-in-1',
        );

    verify(() => registeredJournalDb.journalEntityById('check-in-1')).called(1);
    verify(() => automation.tryAnalyzeImage(subjectId: 'rel-1')).called(1);
    verify(() => relationships.touchCheckInsHolding('photo-1')).called(1);
  });

  test('does nothing for a photo with no owner at all', () async {
    await trigger().triggerAutomaticImageAnalysis(imageEntryId: 'photo-1');

    verifyNever(
      () => automation.tryAnalyzeImage(subjectId: any(named: 'subjectId')),
    );
  });
}

/// Hands the container's own [Ref] to the trigger under test.
final _refProvider = Provider<Ref>((ref) => ref);
