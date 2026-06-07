import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_chat_state.dart';
import 'package:lotti/features/agents/ui/evolution/soul_evolution_chat_state.dart';

/// Shared fake notifiers for the evolution chat page tests — the template
/// (`EvolutionChatState`) and soul (`SoulEvolutionChatState`) controllers are
/// distinct riverpod codegen classes, so each needs its own subclass, but the
/// three behavioural shapes (canned build, send-capture, state-push) are
/// defined once here instead of per test file.

/// Fake [EvolutionChatState] that returns a pre-configured
/// [EvolutionChatData].
class FakeEvolutionChatState extends EvolutionChatState {
  FakeEvolutionChatState(this._buildFn);

  final Future<EvolutionChatData> Function(String) _buildFn;

  @override
  Future<EvolutionChatData> build(String templateId) => _buildFn(templateId);
}

/// Fake [EvolutionChatState] that captures [sendMessage] calls without
/// actually invoking the real workflow.
class CapturingSendEvolutionChatState extends EvolutionChatState {
  CapturingSendEvolutionChatState(this._initialData);

  final EvolutionChatData _initialData;
  final List<String> sentMessages = [];

  @override
  Future<EvolutionChatData> build(String templateId) async => _initialData;

  @override
  Future<void> sendMessage(
    String text, {
    bool skipApprovalCheck = false,
  }) async {
    sentMessages.add(text);
  }
}

/// Fake [EvolutionChatState] that allows its state to be mutated from the
/// test after the initial build (exercises `didUpdateWidget` paths).
class MutableEvolutionChatState extends EvolutionChatState {
  MutableEvolutionChatState(this._initialData);

  final EvolutionChatData _initialData;

  @override
  Future<EvolutionChatData> build(String templateId) async => _initialData;

  void pushData(EvolutionChatData data) {
    state = AsyncData(data);
  }
}

/// Fake [SoulEvolutionChatState] that returns pre-configured data.
class FakeSoulEvolutionChatState extends SoulEvolutionChatState {
  FakeSoulEvolutionChatState(this._buildFn);

  final Future<EvolutionChatData> Function(String) _buildFn;

  @override
  Future<EvolutionChatData> build(String soulId) => _buildFn(soulId);
}

/// Fake that records the last [sendMessage] call without calling the real
/// implementation (which would require a wired-up workflow).
class TrackingSoulEvolutionChatState extends SoulEvolutionChatState {
  TrackingSoulEvolutionChatState(this._buildFn);

  final Future<EvolutionChatData> Function(String) _buildFn;
  String? lastSentMessage;

  @override
  Future<EvolutionChatData> build(String soulId) => _buildFn(soulId);

  @override
  Future<void> sendMessage(
    String text, {
    bool skipApprovalCheck = false,
  }) async {
    lastSentMessage = text;
  }
}

/// Fake that exposes a [pushUpdate] helper so tests can drive state changes
/// after the initial build.
class ControllableSoulEvolutionChatState extends SoulEvolutionChatState {
  ControllableSoulEvolutionChatState(this._buildFn);

  final Future<EvolutionChatData> Function(String) _buildFn;

  @override
  Future<EvolutionChatData> build(String soulId) => _buildFn(soulId);

  void pushUpdate(EvolutionChatData data) {
    state = AsyncData(data);
  }
}
