import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/workflow/agent_template_context.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../test_data/constants.dart';
import '../test_data/soul_factories.dart';
import '../test_data/template_factories.dart';

void main() {
  late MockAgentTemplateService templateService;
  late MockSoulDocumentService soulDocumentService;
  late List<String> trace;

  final template = makeTestTemplate();
  final version = makeTestTemplateVersion(id: 'version-4');
  final soul = makeTestSoulDocumentVersion(id: 'soul-version-2', version: 2);

  setUp(() {
    templateService = MockAgentTemplateService();
    soulDocumentService = MockSoulDocumentService();
    trace = [];
    when(
      () => templateService.getTemplateForAgent('agent-1'),
    ).thenAnswer((_) async => template);
    when(
      () => templateService.getActiveVersion(kTestTemplateId),
    ).thenAnswer((_) async => version);
    when(
      () => soulDocumentService.resolveActiveSoulForTemplate(kTestTemplateId),
    ).thenAnswer((_) async => soul);
  });

  Future<AgentTemplateContext?> resolve({bool withSoulService = true}) =>
      resolveAgentTemplateContext(
        templateService: templateService,
        soulDocumentService: withSoulService ? soulDocumentService : null,
        agentId: 'agent-1',
        onTrace: trace.add,
      );

  test('resolves the template, its active version and its soul', () async {
    final ctx = await resolve();

    expect(ctx!.template, same(template));
    expect(ctx.version, same(version));
    expect(ctx.soulVersion, same(soul));
    expect(trace, ['resolved soul v2 for template']);
  });

  test('is null when the agent has no template', () async {
    when(
      () => templateService.getTemplateForAgent('agent-1'),
    ).thenAnswer((_) async => null);

    expect(await resolve(), isNull);
    expect(trace, ['no template assigned']);
    verifyNever(() => templateService.getActiveVersion(any()));
  });

  test('is null when the template has no active version', () async {
    when(
      () => templateService.getActiveVersion(kTestTemplateId),
    ).thenAnswer((_) async => null);

    expect(await resolve(), isNull);
    expect(trace, ['no active version for template']);
    verifyNever(
      () => soulDocumentService.resolveActiveSoulForTemplate(any()),
    );
  });

  test('a template without a soul resolves with no soul version', () async {
    when(
      () => soulDocumentService.resolveActiveSoulForTemplate(kTestTemplateId),
    ).thenAnswer((_) async => null);

    final ctx = await resolve();

    expect(ctx!.version, same(version));
    expect(ctx.soulVersion, isNull);
    expect(trace, isEmpty);
  });

  test('without a soul service the soul is skipped, not an error', () async {
    final ctx = await resolve(withSoulService: false);

    expect(ctx!.template, same(template));
    expect(ctx.soulVersion, isNull);
  });

  test('a broken soul chain propagates instead of degrading', () async {
    when(
      () => soulDocumentService.resolveActiveSoulForTemplate(kTestTemplateId),
    ).thenThrow(StateError('soul head points nowhere'));

    await expectLater(resolve(), throwsStateError);
  });

  test('tracing is optional', () async {
    when(
      () => templateService.getTemplateForAgent('agent-1'),
    ).thenAnswer((_) async => null);

    final ctx = await resolveAgentTemplateContext(
      templateService: templateService,
      soulDocumentService: soulDocumentService,
      agentId: 'agent-1',
    );

    expect(ctx, isNull);
  });
}
