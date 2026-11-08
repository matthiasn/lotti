import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/chat_input/design_system_chat_input.dart';
import 'package:lotti/features/design_system/components/chat_input/design_system_chat_input_mentions.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_chat_input_widgetbook.dart';
import 'package:material_ui/material_ui.dart';

import 'widgetbook_test_helpers.dart';

void main() {
  testWidgets('the overview shows every state of the chat input', (
    tester,
  ) async {
    // Tall enough that the lazily built list builds every state.
    tester.view
      ..physicalSize = const Size(1000, 4000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpWidgetbookOverview(
      tester,
      buildDesignSystemChatInputWidgetbookComponent(),
      expectedName: 'Chat input',
    );
    await tester.pump();

    expect(find.text('Chat input states'), findsOne);
    expect(find.byType(DesignSystemChatInput), findsNWidgets(7));
    final phases = tester
        .widgetList<DesignSystemChatInput>(find.byType(DesignSystemChatInput))
        .map((input) => input.phase);
    expect(phases, contains(DesignSystemChatInputPhase.recording));
    expect(phases, contains(DesignSystemChatInputPhase.transcribing));
    // The @ state opens its list with the sample's word.
    expect(find.byKey(DesignSystemChatInputMentionKeys.list), findsOne);
    expect(find.byKey(DesignSystemChatInputKeys.error), findsOne);
    expect(DesignSystemChatInputWidgetbook.sampleLevels, hasLength(400));
  });
}
