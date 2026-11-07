import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/chat/chat_composer_field.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../test_utils/material_ui_finders.dart';
import '../../../../widget_test_utils.dart';

/// Hosts the field with its draft held the way every real host holds it.
class _Host extends StatefulWidget {
  const _Host({
    required this.onSend,
    required this.onStartRecording,
    this.isSending = false,
    this.sendingLabel,
    this.enabled = true,
  });

  final void Function(String draft) onSend;
  final VoidCallback onStartRecording;
  final bool isSending;
  final String? sendingLabel;
  final bool enabled;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  final _controller = TextEditingController();
  String _draft = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChatComposerField(
    controller: _controller,
    hintText: 'Say something',
    draft: _draft,
    isSending: widget.isSending,
    sendingLabel: widget.sendingLabel,
    enabled: widget.enabled,
    onDraftChanged: (value) => setState(() => _draft = value),
    onSend: () => widget.onSend(_draft),
    onStartRecording: widget.onStartRecording,
  );
}

void main() {
  Future<void> pump(WidgetTester tester, _Host host) async {
    await tester.pumpWidget(makeTestableWidget2(Material(child: host)));
    await tester.pump();
  }

  String recordTooltip(WidgetTester tester) => tester
      .element(find.byType(ChatComposerField))
      .messages
      .chatInputRecordVoice;
  String sendTooltip(WidgetTester tester) => tester
      .element(find.byType(ChatComposerField))
      .messages
      .chatInputSendTooltip;

  testWidgets('an empty field offers the mic, and the mic only records', (
    tester,
  ) async {
    var recordings = 0;
    final sent = <String>[];
    await pump(
      tester,
      _Host(onSend: sent.add, onStartRecording: () => recordings++),
    );

    expect(findMaterialTooltip(sendTooltip(tester)), findsNothing);
    await tester.tap(findMaterialTooltip(recordTooltip(tester)));
    await tester.pump();

    expect(recordings, 1);
    expect(sent, isEmpty);
  });

  testWidgets('words turn the mic into send, which sends them', (
    tester,
  ) async {
    var recordings = 0;
    final sent = <String>[];
    await pump(
      tester,
      _Host(onSend: sent.add, onStartRecording: () => recordings++),
    );

    await tester.enterText(find.byType(TextField), 'Ship the deck');
    await tester.pump();
    expect(findMaterialTooltip(recordTooltip(tester)), findsNothing);

    await tester.tap(findMaterialTooltip(sendTooltip(tester)));
    await tester.pump();

    expect(sent, ['Ship the deck']);
    expect(recordings, 0);
  });

  testWidgets('Enter sends words', (tester) async {
    final sent = <String>[];
    await pump(tester, _Host(onSend: sent.add, onStartRecording: () {}));

    await tester.enterText(find.byType(TextField), 'Call mom');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(sent, ['Call mom']);
  });

  testWidgets('Enter on a blank field sends nothing', (tester) async {
    final sent = <String>[];
    await pump(tester, _Host(onSend: sent.add, onStartRecording: () {}));

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(sent, isEmpty);
  });

  testWidgets('while sending the field is closed and says why', (
    tester,
  ) async {
    var recordings = 0;
    await pump(
      tester,
      _Host(
        onSend: (_) {},
        onStartRecording: () => recordings++,
        isSending: true,
        sendingLabel: 'Answering…',
      ),
    );

    expect(find.text('Answering…'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    // No mic to tap mid-send: a recording cannot start over a reply.
    expect(findMaterialTooltip(recordTooltip(tester)), findsNothing);
    expect(recordings, 0);
  });

  testWidgets('a closed field takes no words and offers no mic', (
    tester,
  ) async {
    var recordings = 0;
    await pump(
      tester,
      _Host(
        onSend: (_) {},
        onStartRecording: () => recordings++,
        enabled: false,
      ),
    );

    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(findMaterialTooltip(recordTooltip(tester)), findsNothing);
    expect(recordings, 0);
  });
}
