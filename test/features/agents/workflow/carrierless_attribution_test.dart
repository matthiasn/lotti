// The explicit `message: null` / `stackTrace: null` / `errorSummary: null`
// arguments below sit inside `verify(...)` calls, where passing the default
// explicitly *is* the assertion — the point is that the mixin forwarded null
// rather than fabricating a value.
// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/util/agent_error_logging.dart';
import 'package:lotti/features/agents/workflow/carrierless_attribution.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_service.dart';
import 'package:lotti/features/ai_consumption/service/ai_interaction_capture.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../ai_consumption/test_utils.dart';

/// Stands in for the workflow that owns the call.
class _Caller with AgentErrorLogging {
  _Caller(this.domainLogger);

  @override
  final DomainLogger? domainLogger;

  @override
  LogDomain get errorLogDomain => LogDomain.agentWorkflow;
}

void main() {
  late MockAiAttributionService attribution;
  late MockDomainLogger logger;
  late _Caller caller;

  // The shared harness already registers AiWorkAttribution, AiWorkStatus and
  // the artifact list this file's `any(named:)` matchers need.
  setUpAll(registerAllFallbackValues);

  setUp(() {
    attribution = MockAiAttributionService();
    logger = MockDomainLogger();
    caller = _Caller(logger);
    when(
      () => logger.error(
        any<LogDomain>(),
        any<Object>(),
        message: any<String?>(named: 'message'),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
      ),
    ).thenAnswer((_) {});
  });

  tearDown(() async {
    await getIt.reset();
  });

  /// Registers whichever halves of the consumption pair the test needs.
  void register({bool capture = true, bool attribute = true}) {
    if (capture) {
      getIt.registerSingleton<AiInteractionCapture>(MockAiInteractionCapture());
    }
    if (attribute) {
      getIt.registerSingleton<AiAttributionService>(attribution);
    }
  }

  group('canRecordAgentConsumption', () {
    test('requires both halves of the pair', () {
      expect(canRecordAgentConsumption, isFalse);

      register(attribute: false);
      expect(canRecordAgentConsumption, isFalse);
    });

    test('is true only when capture and attribution are both registered', () {
      register();
      expect(canRecordAgentConsumption, isTrue);
    });

    test('is false when attribution is registered without capture', () {
      // Attribution alone would open an envelope over interactions nobody
      // records, which is worse than not accounting at all.
      register(capture: false);
      expect(canRecordAgentConsumption, isFalse);
    });
  });

  group('prepareAgentReportAttribution', () {
    /// Stubs `prepareCompletion` for the two-argument report call, which relies
    /// on the service's default `status`/`errorCode` rather than passing them.
    void stubPrepare() {
      when(
        () => attribution.prepareCompletion(
          attributionId: any(named: 'attributionId'),
          outputs: any(named: 'outputs'),
        ),
      ).thenAnswer((_) async => makeAiWorkAttribution(attributionId: 'a1'));
    }

    test('opens an envelope naming the report as its output', () async {
      register();
      stubPrepare();

      final envelope = await prepareAgentReportAttribution(
        runKey: 'run-1',
        reportId: 'report-1',
      );

      expect(envelope, isNotNull);
      verify(
        () => attribution.prepareCompletion(
          // Derived from the run key, so the envelope the wake later finalizes
          // is the one it opened here.
          attributionId: agentWakeAttributionId('run-1'),
          outputs: const [
            AiArtifactReference(
              type: AiArtifactType.agentReport,
              id: 'report-1',
            ),
          ],
        ),
      ).called(1);
    });

    test('returns null when the wake produced no report', () async {
      register();
      stubPrepare();

      expect(
        await prepareAgentReportAttribution(runKey: 'run-1', reportId: null),
        isNull,
      );
      verifyZeroInteractions(attribution);
    });

    // The regression: attribution alone used to be enough to open an envelope,
    // so a process with attribution but no capture attributed a wake whose
    // interaction rows nobody was recording — an envelope over nothing, with a
    // cost of zero, indistinguishable in the consumption surfaces from a wake
    // that genuinely spent nothing.
    test(
      'returns null when attribution is registered without capture',
      () async {
        register(capture: false);

        expect(
          await prepareAgentReportAttribution(
            runKey: 'run-1',
            reportId: 'report-1',
          ),
          isNull,
        );
        verifyZeroInteractions(attribution);
      },
    );

    test('returns null when neither half is registered', () async {
      register(capture: false, attribute: false);

      expect(
        await prepareAgentReportAttribution(
          runKey: 'run-1',
          reportId: 'report-1',
        ),
        isNull,
      );
      verifyZeroInteractions(attribution);
    });
  });

  group('finalizeCarrierlessAgentAttribution', () {
    test('closes the envelope with the given status and error code', () async {
      register();
      when(
        () => attribution.prepareCompletion(
          attributionId: any(named: 'attributionId'),
          outputs: any(named: 'outputs'),
          status: any(named: 'status'),
          errorCode: any(named: 'errorCode'),
          errorSummary: any(named: 'errorSummary'),
        ),
      ).thenAnswer(
        (_) async => makeAiWorkAttribution(attributionId: 'a1'),
      );
      when(() => attribution.finalize(any())).thenAnswer((_) async {});

      await finalizeCarrierlessAgentAttribution(
        runKey: 'run-1',
        status: AiWorkStatus.failed,
        errorCode: 'inference_unavailable',
        errorSummary: 'no route',
        logger: caller,
      );

      verify(
        () => attribution.prepareCompletion(
          // Derived from the run key, so the envelope closed is the one the
          // wake opened.
          attributionId: agentWakeAttributionId('run-1'),
          outputs: const [],
          status: AiWorkStatus.failed,
          errorCode: 'inference_unavailable',
          errorSummary: 'no route',
        ),
      ).called(1);
      verify(() => attribution.finalize(any())).called(1);
    });

    test('does nothing when the consumption pair is unavailable', () async {
      register(capture: false, attribute: false);

      await finalizeCarrierlessAgentAttribution(
        runKey: 'run-1',
        status: AiWorkStatus.failed,
        errorCode: 'x',
        logger: caller,
      );

      verifyZeroInteractions(attribution);
    });

    test('does nothing when only capture is registered', () async {
      register(attribute: false);

      await expectLater(
        finalizeCarrierlessAgentAttribution(
          runKey: 'run-1',
          status: AiWorkStatus.failed,
          errorCode: 'x',
          logger: caller,
        ),
        completes,
      );
      verifyZeroInteractions(attribution);
    });

    test('contains a prepareCompletion failure and reports it', () async {
      // Bookkeeping must never fail an otherwise-successful wake, so the error
      // is logged and swallowed rather than propagated.
      register();
      when(
        () => attribution.prepareCompletion(
          attributionId: any(named: 'attributionId'),
          outputs: any(named: 'outputs'),
          status: any(named: 'status'),
          errorCode: any(named: 'errorCode'),
          errorSummary: any(named: 'errorSummary'),
        ),
      ).thenAnswer((_) async => throw StateError('session gone'));

      await expectLater(
        finalizeCarrierlessAgentAttribution(
          runKey: 'run-1',
          status: AiWorkStatus.failed,
          errorCode: 'x',
          logger: caller,
        ),
        completes,
      );

      verify(
        () => logger.error(
          LogDomain.agentWorkflow,
          any<Object>(),
          message: 'failed to terminalize carrier-less attribution',
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).called(1);
      verifyNever(() => attribution.finalize(any()));
    });

    test('contains a finalize failure and reports it', () async {
      register();
      when(
        () => attribution.prepareCompletion(
          attributionId: any(named: 'attributionId'),
          outputs: any(named: 'outputs'),
          status: any(named: 'status'),
          errorCode: any(named: 'errorCode'),
          errorSummary: any(named: 'errorSummary'),
        ),
      ).thenAnswer(
        (_) async => makeAiWorkAttribution(attributionId: 'a1'),
      );
      when(
        () => attribution.finalize(any()),
      ).thenAnswer((_) async => throw StateError('write failed'));

      await expectLater(
        finalizeCarrierlessAgentAttribution(
          runKey: 'run-1',
          status: AiWorkStatus.failed,
          errorCode: 'x',
          logger: caller,
        ),
        completes,
      );

      verify(
        () => logger.error(
          LogDomain.agentWorkflow,
          any<Object>(),
          message: 'failed to terminalize carrier-less attribution',
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).called(1);
    });

    test('passes a null errorSummary through unchanged', () async {
      register();
      when(
        () => attribution.prepareCompletion(
          attributionId: any(named: 'attributionId'),
          outputs: any(named: 'outputs'),
          status: any(named: 'status'),
          errorCode: any(named: 'errorCode'),
          errorSummary: any(named: 'errorSummary'),
        ),
      ).thenAnswer(
        (_) async => makeAiWorkAttribution(attributionId: 'a1'),
      );
      when(() => attribution.finalize(any())).thenAnswer((_) async {});

      await finalizeCarrierlessAgentAttribution(
        runKey: 'run-2',
        status: AiWorkStatus.partial,
        errorCode: 'output_carrier_unavailable',
        logger: caller,
      );

      verify(
        () => attribution.prepareCompletion(
          attributionId: agentWakeAttributionId('run-2'),
          outputs: const [],
          status: AiWorkStatus.partial,
          errorCode: 'output_carrier_unavailable',
          errorSummary: null,
        ),
      ).called(1);
    });
  });
}
