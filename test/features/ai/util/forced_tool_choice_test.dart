import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/util/forced_tool_choice.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:openai_dart/openai_dart.dart';

void main() {
  String? pinnedName(String modelId) => forcedToolChoiceFor(
    modelId: modelId,
    toolName: 'update_goal_report',
  )?.mapOrNull(tool: (choice) => choice.value.function.name);

  test('DeepSeek models get no pinned tool choice', () {
    // Measured against Melious: with `tool_choice` pinned these answer with
    // `<｜DSML｜ invoke name="…">` prose and an empty `tool_calls`, so the
    // forced retry silently produced nothing.
    for (final modelId in [
      meliousDeepseekV41FlashModelId,
      '$meliousDeepseekV41FlashModelId:speed',
      meliousDeepseekV4FlashModelId,
      meliousDeepseekV4ProModelId,
      'DeepSeek-V4.1-Flash',
    ]) {
      expect(
        forcedToolChoiceFor(modelId: modelId, toolName: 'update_goal_report'),
        isNull,
        reason: modelId,
      );
    }
  });

  test('every other model keeps the named tool choice', () {
    for (final modelId in [
      meliousGlm53FlashModelId,
      '$meliousGlm53FlashModelId:speed',
      meliousGlm52ModelId,
      meliousQwen35122BA10BModelId,
      meliousMistralSmall4119BInstructModelId,
    ]) {
      expect(pinnedName(modelId), 'update_goal_report', reason: modelId);
    }
  });

  test('the pinned choice names the tool it is asked for', () {
    expect(
      forcedToolChoiceFor(
        modelId: meliousGlm53FlashModelId,
        toolName: 'draft_day_plan',
      )?.mapOrNull(tool: (choice) => choice.value.function.name),
      'draft_day_plan',
    );
  });
}
