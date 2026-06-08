import 'package:glados/glados.dart' as glados;
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

enum GeneratedVerificationDirection {
  incoming,
  outgoing,
}

enum GeneratedVerificationStep {
  request,
  ready,
  key,
}

enum GeneratedVerificationEmojiMode {
  empty,
  one,
  two,
  throws,
}

class GeneratedVerificationObservation {
  const GeneratedVerificationObservation({
    required this.step,
    required this.done,
    required this.canceled,
    required this.emojiMode,
  });

  final GeneratedVerificationStep step;
  final bool done;
  final bool canceled;
  final GeneratedVerificationEmojiMode emojiMode;

  String get wireStep {
    return switch (step) {
      GeneratedVerificationStep.request => 'm.key.verification.request',
      GeneratedVerificationStep.ready => 'm.key.verification.ready',
      GeneratedVerificationStep.key => 'm.key.verification.key',
    };
  }

  List<KeyVerificationEmoji> get emojis {
    return switch (emojiMode) {
      GeneratedVerificationEmojiMode.empty => <KeyVerificationEmoji>[],
      GeneratedVerificationEmojiMode.one => <KeyVerificationEmoji>[
        KeyVerificationEmoji(1),
      ],
      GeneratedVerificationEmojiMode.two => <KeyVerificationEmoji>[
        KeyVerificationEmoji(1),
        KeyVerificationEmoji(2),
      ],
      GeneratedVerificationEmojiMode.throws => <KeyVerificationEmoji>[],
    };
  }

  List<String> get visibleEmojis {
    if (step != GeneratedVerificationStep.key ||
        emojiMode == GeneratedVerificationEmojiMode.throws) {
      return const <String>[];
    }
    return emojis.map((emoji) => emoji.emoji).toList(growable: false);
  }

  String get emojiKey => visibleEmojis.join('|');

  bool get terminal => done || canceled;

  @override
  String toString() {
    return 'GeneratedVerificationObservation('
        'step: $step, '
        'done: $done, '
        'canceled: $canceled, '
        'emojiMode: $emojiMode'
        ')';
  }
}

class GeneratedVerificationEvent {
  const GeneratedVerificationEvent({
    required this.direction,
    required this.observation,
  });

  final GeneratedVerificationDirection direction;
  final GeneratedVerificationObservation observation;

  String get wireDirection => switch (direction) {
    GeneratedVerificationDirection.incoming => 'incoming',
    GeneratedVerificationDirection.outgoing => 'outgoing',
  };
}

class GeneratedVerificationScenario {
  const GeneratedVerificationScenario({
    required this.direction,
    required this.initial,
    required this.updates,
  });

  final GeneratedVerificationDirection direction;
  final GeneratedVerificationObservation initial;
  final List<GeneratedVerificationObservation> updates;

  String get wireDirection => switch (direction) {
    GeneratedVerificationDirection.incoming => 'incoming',
    GeneratedVerificationDirection.outgoing => 'outgoing',
  };

  List<GeneratedVerificationEvent> expectedEvents() {
    final expected = <GeneratedVerificationEvent>[
      GeneratedVerificationEvent(direction: direction, observation: initial),
    ];
    if (initial.terminal) {
      return expected;
    }

    var lastStep = initial.wireStep;
    var lastDone = initial.done;
    var lastCanceled = initial.canceled;
    var lastEmojis = initial.emojiKey;
    var active = true;

    for (final update in updates) {
      if (!active) {
        break;
      }
      final changed =
          lastStep != update.wireStep ||
          lastDone != update.done ||
          lastCanceled != update.canceled ||
          lastEmojis != update.emojiKey;
      if (changed) {
        expected.add(
          GeneratedVerificationEvent(
            direction: direction,
            observation: update,
          ),
        );
        lastStep = update.wireStep;
        lastDone = update.done;
        lastCanceled = update.canceled;
        lastEmojis = update.emojiKey;
      }
      if (update.terminal) {
        active = false;
      }
    }

    return expected;
  }

  bool get expectedActive {
    if (initial.terminal) {
      return false;
    }
    for (final update in updates) {
      if (update.terminal) {
        return false;
      }
    }
    return true;
  }

  @override
  String toString() {
    return 'GeneratedVerificationScenario('
        'direction: $direction, '
        'initial: $initial, '
        'updates: $updates'
        ')';
  }
}

extension AnyGeneratedVerificationScenario on glados.Any {
  glados.Generator<GeneratedVerificationDirection> get verificationDirection =>
      glados.AnyUtils(this).choose(GeneratedVerificationDirection.values);

  glados.Generator<GeneratedVerificationStep> get verificationStep =>
      glados.AnyUtils(this).choose(GeneratedVerificationStep.values);

  glados.Generator<GeneratedVerificationEmojiMode> get verificationEmojiMode =>
      glados.AnyUtils(this).choose(GeneratedVerificationEmojiMode.values);

  glados.Generator<GeneratedVerificationObservation>
  get verificationObservation => glados.CombinableAny(this).combine4(
    verificationStep,
    glados.BoolAny(this).bool,
    glados.BoolAny(this).bool,
    verificationEmojiMode,
    (
      GeneratedVerificationStep step,
      bool done,
      bool canceled,
      GeneratedVerificationEmojiMode emojiMode,
    ) => GeneratedVerificationObservation(
      step: step,
      done: done,
      canceled: canceled,
      emojiMode: emojiMode,
    ),
  );

  glados.Generator<GeneratedVerificationScenario> get verificationScenario =>
      glados.CombinableAny(this).combine3(
        verificationDirection,
        verificationObservation,
        glados.ListAnys(
          this,
        ).listWithLengthInRange(0, 10, verificationObservation),
        (
          GeneratedVerificationDirection direction,
          GeneratedVerificationObservation initial,
          List<GeneratedVerificationObservation> updates,
        ) => GeneratedVerificationScenario(
          direction: direction,
          initial: initial,
          updates: updates,
        ),
      );
}

class VerificationProbe {
  VerificationProbe(this.observation) {
    when(() => verification.lastStep).thenAnswer((_) => observation.wireStep);
    when(() => verification.isDone).thenAnswer((_) => observation.done);
    when(() => verification.canceled).thenAnswer((_) => observation.canceled);
    when(() => verification.sasEmojis).thenAnswer((_) {
      if (observation.emojiMode == GeneratedVerificationEmojiMode.throws) {
        throw StateError('generated emoji failure');
      }
      return observation.emojis;
    });
    when(() => verification.onUpdate).thenAnswer((_) => previousOnUpdate);
    when(() => verification.onUpdate = any()).thenAnswer((invocation) {
      currentOnUpdate =
          invocation.positionalArguments.first as void Function()?;
      return null;
    });
    when(verification.cancel).thenAnswer((_) async {});
  }

  final verification = MockKeyVerification();

  void previousOnUpdate() {}

  GeneratedVerificationObservation observation;
  void Function()? currentOnUpdate;

  void apply(GeneratedVerificationObservation next) {
    observation = next;
    currentOnUpdate?.call();
  }
}
