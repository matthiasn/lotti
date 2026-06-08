
import 'package:glados/glados.dart' as glados;


enum GeneratedNotificationStreamOperationKind {
  matching,
  other,
  mixed,
  empty,
}

class GeneratedNotificationStreamOperation {
  const GeneratedNotificationStreamOperation({
    required this.kind,
    required this.seed,
  });

  final GeneratedNotificationStreamOperationKind kind;
  final int seed;

  Set<String> get ids {
    return switch (kind) {
      GeneratedNotificationStreamOperationKind.matching => {
        if (seed.isEven) 'KEY_A' else 'KEY_B',
      },
      GeneratedNotificationStreamOperationKind.other => {
        'OTHER_${seed % 7}',
      },
      GeneratedNotificationStreamOperationKind.mixed => {
        'OTHER_${seed % 7}',
        if (seed.isEven) 'KEY_A' else 'KEY_B',
      },
      GeneratedNotificationStreamOperationKind.empty => const <String>{},
    };
  }

  bool get triggersFetch => ids.contains('KEY_A') || ids.contains('KEY_B');

  @override
  String toString() {
    return 'GeneratedNotificationStreamOperation(kind: $kind, seed: $seed)';
  }
}

class GeneratedNotificationStreamScenario {
  const GeneratedNotificationStreamScenario({
    required this.operations,
    required this.cancelAfterSlot,
  });

  final List<GeneratedNotificationStreamOperation> operations;
  final int cancelAfterSlot;

  int get cancelAfter {
    if (operations.isEmpty) return 0;
    return cancelAfterSlot % (operations.length + 1);
  }

  @override
  String toString() {
    return 'GeneratedNotificationStreamScenario('
        'operations: $operations, cancelAfterSlot: $cancelAfterSlot)';
  }
}

extension AnyGeneratedNotificationStreamScenario on glados.Any {
  glados.Generator<GeneratedNotificationStreamOperationKind>
  get notificationStreamOperationKind => glados.AnyUtils(this).choose(
    GeneratedNotificationStreamOperationKind.values,
  );

  glados.Generator<GeneratedNotificationStreamOperation>
  get notificationStreamOperation => glados.CombinableAny(this).combine2(
    notificationStreamOperationKind,
    glados.IntAnys(this).intInRange(0, 10000),
    (
      GeneratedNotificationStreamOperationKind kind,
      int seed,
    ) => GeneratedNotificationStreamOperation(kind: kind, seed: seed),
  );

  glados.Generator<GeneratedNotificationStreamScenario>
  get notificationStreamScenario => glados.CombinableAny(this).combine2(
    glados.ListAnys(
      this,
    ).listWithLengthInRange(0, 40, notificationStreamOperation),
    glados.IntAnys(this).intInRange(0, 10000),
    (
      List<GeneratedNotificationStreamOperation> operations,
      int cancelAfterSlot,
    ) => GeneratedNotificationStreamScenario(
      operations: operations,
      cancelAfterSlot: cancelAfterSlot,
    ),
  );
}
