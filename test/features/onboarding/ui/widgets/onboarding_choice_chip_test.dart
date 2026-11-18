import 'dart:ui' show SemanticsAction, Tristate;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_choice_chip.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<void> pumpChip(
    WidgetTester tester,
    OnboardingChoiceChip chip, {
    double width = 320,
    bool inWrap = false,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Center(
          child: SizedBox(
            width: width,
            child: inWrap ? Wrap(children: [chip]) : chip,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  BoxDecoration decorationOf(WidgetTester tester) =>
      tester
              .widget<Ink>(
                find.descendant(
                  of: find.byType(OnboardingChoiceChip),
                  matching: find.byType(Ink),
                ),
              )
              .decoration!
          as BoxDecoration;

  DsTokens tokensOf(WidgetTester tester) =>
      tester.element(find.byType(OnboardingChoiceChip)).designTokens;

  testWidgets('a chosen chip wears the accent on its outline and a check; '
      'an unchosen one a quiet outline and no check, on the same surface and '
      'at the same size', (tester) async {
    var taps = 0;
    await pumpChip(
      tester,
      OnboardingChoiceChip(
        label: 'Work',
        selected: true,
        onTap: () => taps++,
      ),
    );
    final tokens = tokensOf(tester);
    final chosen = decorationOf(tester);
    final chosenSize = tester.getSize(find.byType(OnboardingChoiceChip));
    expect(
      (chosen.border! as Border).top.color,
      tokens.colors.interactive.enabled,
    );
    expect(chosen.color, tokens.colors.background.level01);
    expect(find.byIcon(LottiIcons.confirm), findsOneWidget);
    await tester.tap(find.text('Work'));
    expect(taps, 1);

    await pumpChip(
      tester,
      OnboardingChoiceChip(label: 'Work', selected: false, onTap: () {}),
    );
    final quiet = decorationOf(tester);
    expect(
      (quiet.border! as Border).top.color,
      tokens.colors.decorative.level03,
    );
    expect(quiet.color, chosen.color);
    // Choosing never moves anything: the outline is one width either way.
    expect(
      (quiet.border! as Border).top.width,
      (chosen.border! as Border).top.width,
    );
    expect(find.byIcon(LottiIcons.confirm), findsNothing);
    expect(
      tester.getSize(find.byType(OnboardingChoiceChip)).height,
      chosenSize.height,
    );
  });

  testWidgets('says to a screen reader whether it is chosen, and that it '
      'can be tapped; an action chip is no choice at all', (tester) async {
    await pumpChip(
      tester,
      OnboardingChoiceChip(label: 'Work', selected: true, onTap: () {}),
    );
    var data = tester
        .getSemantics(find.bySemanticsLabel('Work'))
        .getSemanticsData();
    expect(data.flagsCollection.isSelected, Tristate.isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue);

    await pumpChip(
      tester,
      OnboardingChoiceChip(
        label: 'Add your own',
        icon: LottiIcons.add,
        onTap: () {},
      ),
    );
    data = tester
        .getSemantics(find.bySemanticsLabel('Add your own'))
        .getSemanticsData();
    expect(data.flagsCollection.isSelected, Tristate.none);
    expect(find.byIcon(LottiIcons.add), findsOneWidget);
    expect(find.byIcon(LottiIcons.confirm), findsNothing);
  });

  testWidgets('activates from the keyboard', (tester) async {
    var taps = 0;
    await pumpChip(
      tester,
      OnboardingChoiceChip(label: 'Work', selected: false, onTap: () => taps++),
    );

    final focus = Focus.of(tester.element(find.text('Work')))..requestFocus();
    await tester.pump();
    expect(focus.hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('a grid chip fills its cell and ends a long label in an '
      'ellipsis; one with the row to itself wraps it; a dense pill hugs its '
      'label', (tester) async {
    const long = 'A rather long name for an area of life';
    await pumpChip(
      tester,
      OnboardingChoiceChip(label: long, onTap: () {}),
      width: 160,
    );
    expect(tester.getSize(find.byType(OnboardingChoiceChip)).width, 160);
    expect(
      tester.widget<Text>(find.text(long)).overflow,
      TextOverflow.ellipsis,
    );

    await pumpChip(
      tester,
      OnboardingChoiceChip(label: long, wrapLabel: true, onTap: () {}),
      width: 160,
    );
    expect(tester.widget<Text>(find.text(long)).overflow, isNull);
    expect(tester.takeException(), isNull);

    // In a wrap, as the pills sit.
    await pumpChip(
      tester,
      OnboardingChoiceChip(label: 'Work', dense: true, onTap: () {}),
      inWrap: true,
    );
    final chip = find.byType(Ink);
    expect(tester.getSize(chip).width, lessThan(320));
    expect(
      tester.widget<Text>(find.text('Work')).style?.fontSize,
      tokensOf(tester).typography.styles.subtitle.subtitle2.fontSize,
    );
  });

  testWidgets('an action chip ends in its own icon where a choice has its '
      'check', (tester) async {
    await pumpChip(
      tester,
      OnboardingChoiceChip(
        label: 'Plan my week',
        trailing: LottiIcons.forward,
        onTap: () {},
      ),
    );
    expect(find.byIcon(LottiIcons.forward), findsOneWidget);
    expect(find.byIcon(LottiIcons.confirm), findsNothing);
  });

  testWidgets('a surface that only shows something keeps what it holds '
      "readable, as a rejected key's message on the key card", (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const Center(
          child: SizedBox(
            width: 320,
            child: OnboardingSelectableSurface(
              label: 'Mistral',
              onTap: null,
              child: Column(
                children: [Text('Mistral'), Text('That key was rejected.')],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Read with the card, not dropped.
    expect(
      find.bySemanticsLabel(RegExp('That key was rejected')),
      findsOneWidget,
    );

    // A choice, by contrast, is read as its label alone.
    await pumpChip(
      tester,
      OnboardingChoiceChip(label: 'Work', selected: false, onTap: () {}),
    );
    expect(find.bySemanticsLabel('Work'), findsOneWidget);
  });

  testWidgets('a surface with no action only shows a choice made elsewhere: '
      'it is not a button and takes no focus', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const Center(
          child: SizedBox(
            width: 320,
            child: OnboardingSelectableSurface(
              label: 'Ollama',
              onTap: null,
              selected: true,
              child: Text('Ollama'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final data = tester
        .getSemantics(find.bySemanticsLabel('Ollama'))
        .getSemanticsData();
    expect(data.hasAction(SemanticsAction.tap), isFalse);
    expect(data.flagsCollection.isSelected, Tristate.isTrue);
    expect(find.byIcon(LottiIcons.confirm), findsOneWidget);
    expect(
      tester.widget<InkWell>(find.byType(InkWell)).canRequestFocus,
      isFalse,
    );
  });
}
