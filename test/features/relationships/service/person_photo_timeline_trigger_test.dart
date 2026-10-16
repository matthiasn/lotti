import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/services/profile_automation_service.dart';
import 'package:lotti/features/ai/services/skill_inference_runner.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/features/relationships/repository/person_timeline_repository.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/service/person_photo_timeline_trigger.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/service_overrides.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

final _refProvider = Provider<Ref>((ref) => ref);

void main() {
  late MockProfileAutomationService automation;
  late MockSkillInferenceRunner runner;
  late MockPersonTimelineRepository timeline;
  late MockRelationshipRepository relationships;
  late MockDomainLogger logger;
  late ProviderContainer container;

  setUpAll(() => registerFallbackValue(AutomationResult.notHandled));

  setUp(() async {
    automation = MockProfileAutomationService();
    runner = MockSkillInferenceRunner();
    timeline = MockPersonTimelineRepository();
    relationships = MockRelationshipRepository();
    // No description by default: the analysis ran but wrote nothing.
    when(
      () => relationships.getImageDescriptions(any()),
    ).thenAnswer((_) async => const {});
    when(() => timeline.touch(any())).thenAnswer((_) async => true);
    logger = MockDomainLogger();
    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..unregister<DomainLogger>()
          ..registerSingleton<DomainLogger>(logger);
      },
    );
    when(
      () => logger.error(
        any<LogDomain>(),
        any<Object>(),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => logger.log(
        any<LogDomain>(),
        any<String>(),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).thenReturn(null);
    when(
      () => automation.tryAnalyzeImage(subjectId: any(named: 'subjectId')),
    ).thenAnswer((_) async => AutomationResult.notHandled);
    when(
      () => timeline.addToTimeline(
        personId: any(named: 'personId'),
        entryId: any(named: 'entryId'),
      ),
    ).thenAnswer((_) async => true);
    container = ProviderContainer(
      overrides: withServiceOverrides([
        profileAutomationServiceProvider.overrideWithValue(automation),
        skillInferenceRunnerProvider.overrideWithValue(runner),
      ]),
    );
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestGetIt();
  });

  PersonPhotoTimelineTrigger trigger() => PersonPhotoTimelineTrigger(
    ref: container.read(_refProvider),
    loggingService: logger,
    timeline: timeline,
    relationships: relationships,
  );

  test("puts each imported photo on the person's timeline, then asks the "
      "person's profile whether to describe it", () async {
    await trigger().triggerAutomaticImageAnalysis(
      imageEntryId: 'photo-1',
      linkedTaskId: 'pip',
    );

    verify(
      () => timeline.addToTimeline(personId: 'pip', entryId: 'photo-1'),
    ).called(1);
    verify(() => automation.tryAnalyzeImage(subjectId: 'pip')).called(1);
  });

  test("the page's trigger puts photos on the timeline its repository "
      'keeps', () async {
    final wired = ProviderContainer(
      overrides: withServiceOverrides([
        profileAutomationServiceProvider.overrideWithValue(automation),
        skillInferenceRunnerProvider.overrideWithValue(runner),
        personTimelineRepositoryProvider.overrideWithValue(timeline),
        relationshipRepositoryProvider.overrideWithValue(relationships),
        domainLoggerProvider.overrideWithValue(logger),
      ]),
    );
    addTearDown(wired.dispose);

    await wired
        .read(personPhotoTimelineTriggerProvider)
        .triggerAutomaticImageAnalysis(
          imageEntryId: 'photo-9',
          linkedTaskId: 'pip',
        );

    verify(
      () => timeline.addToTimeline(personId: 'pip', entryId: 'photo-9'),
    ).called(1);
  });

  test('a description that landed saves the photo again, so the briefing '
      'reads it; a run that wrote none touches nothing', () async {
    await trigger().triggerAutomaticImageAnalysis(
      imageEntryId: 'photo-1',
      linkedTaskId: 'pip',
    );
    verifyNever(() => timeline.touch(any()));

    when(
      () => relationships.getImageDescriptions({'photo-2'}),
    ).thenAnswer((_) async => {'photo-2': 'Pip on the launch pad.'});
    await trigger().triggerAutomaticImageAnalysis(
      imageEntryId: 'photo-2',
      linkedTaskId: 'pip',
    );
    verify(() => timeline.touch('photo-2')).called(1);
  });

  test('a description lookup that throws is logged, not thrown', () async {
    when(
      () => relationships.getImageDescriptions(any()),
    ).thenThrow(Exception('database locked'));

    await trigger().triggerAutomaticImageAnalysis(
      imageEntryId: 'photo-1',
      linkedTaskId: 'pip',
    );

    verifyNever(() => timeline.touch(any()));
    verify(
      () => logger.error(
        LogDomain.persistence,
        any<Object>(),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
        subDomain: 'personPhotoTimeline',
      ),
    ).called(1);
  });

  test('a photo the journal already held goes on the timeline without being '
      'analysed again, and a link that throws is logged, not thrown', () async {
    await trigger().putOnTimeline(personId: 'pip', entryId: 'old-photo');

    verify(
      () => timeline.addToTimeline(personId: 'pip', entryId: 'old-photo'),
    ).called(1);
    verifyNever(
      () => automation.tryAnalyzeImage(subjectId: any(named: 'subjectId')),
    );

    when(
      () => timeline.addToTimeline(
        personId: any(named: 'personId'),
        entryId: any(named: 'entryId'),
      ),
    ).thenThrow(Exception('database locked'));
    await trigger().putOnTimeline(personId: 'pip', entryId: 'old-photo');
    verify(
      () => logger.error(
        LogDomain.persistence,
        any<Object>(),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
        subDomain: 'personPhotoTimeline',
      ),
    ).called(1);
  });

  test('does nothing for an import that names no person', () async {
    await trigger().triggerAutomaticImageAnalysis(imageEntryId: 'photo-1');

    verifyNever(
      () => timeline.addToTimeline(
        personId: any(named: 'personId'),
        entryId: any(named: 'entryId'),
      ),
    );
    verifyNever(
      () => automation.tryAnalyzeImage(subjectId: any(named: 'subjectId')),
    );
  });

  test('a link that was refused is logged and the photo is still '
      'described', () async {
    when(
      () => timeline.addToTimeline(
        personId: any(named: 'personId'),
        entryId: any(named: 'entryId'),
      ),
    ).thenAnswer((_) async => false);

    await trigger().triggerAutomaticImageAnalysis(
      imageEntryId: 'photo-1',
      linkedTaskId: 'pip',
    );

    verify(
      () => logger.error(
        LogDomain.persistence,
        'person photo timeline link rejected for photo-1',
        subDomain: 'personPhotoTimeline',
      ),
    ).called(1);
    verify(() => automation.tryAnalyzeImage(subjectId: 'pip')).called(1);
  });

  // Nothing awaits this trigger: a throw must be logged, never left as an
  // unhandled asynchronous error.
  test('a link that throws is logged, not thrown', () async {
    when(
      () => timeline.addToTimeline(
        personId: any(named: 'personId'),
        entryId: any(named: 'entryId'),
      ),
    ).thenThrow(StateError('database closed'));

    await expectLater(
      trigger().triggerAutomaticImageAnalysis(
        imageEntryId: 'photo-1',
        linkedTaskId: 'pip',
      ),
      completes,
    );
    verify(
      () => logger.error(
        LogDomain.persistence,
        any<Object>(that: isA<StateError>()),
        stackTrace: any(named: 'stackTrace'),
        subDomain: 'personPhotoTimeline',
      ),
    ).called(1);
  });
}
