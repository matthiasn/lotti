import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wisely/main.dart';

import 'helpers/hydrated_bloc.dart';

void main() {
  setUpAll(() {
    initHydratedBloc();
  });

  testWidgets('Audio page controls exist', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const WiselyApp());

    // Tap the 'mic' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.mic));
    await tester.pump();

    // test that buttons exist
    expect(find.text('0:00:00'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.byIcon(Icons.fast_rewind), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsOneWidget);
    expect(find.byIcon(Icons.fast_forward), findsOneWidget);
    expect(find.byIcon(Icons.stop), findsNWidgets(2));
  });
}
